package Koha::Plugin::Com::ByWaterSolutions::UMSGentleNudge;

## It's good practice to use Modern::Perl
use Modern::Perl;

## Required for all plugins
use base qw(Koha::Plugins::Base);

## We will also need to include any Koha libraries we want to access
use C4::Auth;
use C4::Context;
use C4::Installer qw(TableExists);
use C4::Log       qw(logaction);
use C4::Templates;
use Koha::Account::DebitTypes;
require UMS::GentleNudge::CSV;
use Koha::DateUtils qw(dt_from_string);
use Koha::File::Transports;
use Koha::Libraries;
use Koha::Library::Groups;
use Koha::Patron::Attribute::Types;
use Koha::Patron::Debarments qw(AddDebarment);
use Koha::Patrons;
use Koha::Plugins;
use Koha::Schema;
use Koha::SMTP::Servers;

use File::Path qw( make_path );
use JSON;
use Module::Metadata;
use Net::SFTP::Foreign;
use Try::Tiny;
use POSIX qw( strftime );

use constant LOG_INFO_LL  => 1;
use constant LOG_DEBUG_LL => 2;
use constant LOG_TRACE_LL => 3;

## Here we set our plugin version
our $VERSION         = "0.8.0";
our $MINIMUM_VERSION = "24.05";
our $debug           = $ENV{UMS_COLLECTIONS_DEBUG}        // 0;
our $no_email        = $ENV{UMS_COLLECTIONS_NO_EMAIL}     // 0;
our $archive_dir     = $ENV{UMS_COLLECTIONS_ARCHIVES_DIR} // undef;

our $metadata = {
    name            => 'Unique Management Services - Gentle Nudge Multi-Configuration',
    author          => 'Lisette Scheer',
    date_authored   => '2026-04-23',
    date_updated    => "2026-04-23",
    minimum_version => $MINIMUM_VERSION,
    maximum_version => undef,
    version         => $VERSION,
    description     =>
        'Plugin to forward messages to Unique Collections for processing and sending with multiple configurations',
    plugin_title => "UMS Collections Multi-Configuration",
};

BEGIN {
    my $path = Module::Metadata->find_module_by_name(__PACKAGE__);
    $path =~ s!\.pm$!/lib!;
    unshift @INC, $path;

    require Koha::Schema::Result::KohaPluginComBywatersolutionsUmsgentlenudgeConfig;
    require Koha::Schema::Result::KohaPluginComBywatersolutionsUmsgentlenudgeConfigDebitType;
    require Koha::Schema::Result::KohaPluginComBywatersolutionsUmsgentlenudgeConfigPatronCategory;

    #register the additional schema classes
    Koha::Schema->register_class( KohaPluginComBywatersolutionsUmsgentlenudgeConfig =>
            'Koha::Schema::Result::KohaPluginComBywatersolutionsUmsgentlenudgeConfig' );
    Koha::Schema->register_class( KohaPluginComBywatersolutionsUmsgentlenudgeConfigDebitType =>
            'Koha::Schema::Result::KohaPluginComBywatersolutionsUmsgentlenudgeConfigDebitType' );
    Koha::Schema->register_class( KohaPluginComBywatersolutionsUmsgentlenudgeConfigPatronCategory =>
            'Koha::Schema::Result::KohaPluginComBywatersolutionsUmsgentlenudgeConfigPatronCategory' );

    # force a refresh of the database handle so that it includes the new classes
    Koha::Database->schema( { new => 1 } );
}

our $json = JSON->new;
$json->pretty(1);
$json->convert_blessed(1);

=head2 Internal methods


=head3 _table_exists (helper)

Method to check if a table exists in Koha.

FIXME: Should be made available to plugins in core

=cut

sub _table_exists {
    my ( $self, $table ) = @_;
    eval {
        C4::Context->dbh->{PrintError} = 0;
        C4::Context->dbh->{RaiseError} = 1;
        C4::Context->dbh->do(qq{SELECT * FROM $table WHERE 1 = 0 });
    };
    return 1 unless $@;
    return 0;
}

=head3 _column_exists (helper)

Method to check if a column exists in a table in Koha.


=cut

sub _column_exists {
    my ( $self, $table, $column ) = @_;
    eval {
        C4::Context->dbh->{PrintError} = 0;
        C4::Context->dbh->{RaiseError} = 1;
        C4::Context->dbh->do(qq{SELECT $column FROM $table WHERE 1 = 0 });
    };
    return 1 unless $@;
    return 0;

}

=head3 new

=cut

sub new {
    my ( $class, $args ) = @_;

    ## We need to add our metadata here so our base class can access it
    $args->{'metadata'} = $metadata;
    my $self = $class->SUPER::new($args);

    return $self;
}

=head3 configure

=cut

sub configure {

    my ( $self, $args ) = @_;
    my $cgi          = $self->{'cgi'};
    my $template     = $self->get_template( { file => 'templates/ums2.tt' } );
    my $dbh          = C4::Context->dbh;
    my $config_table = $self->get_qualified_table_name('config');
    my $action       = $cgi->param('op');
    my $config       = $cgi->param('config');
    my $groups       = Koha::Library::Groups->search( { branchcode => undef }, { order_by => ['title'] } );
    my @debit_types  = Koha::Account::DebitTypes->search()->as_list;
    my @smtp_servers = Koha::SMTP::Servers->search();
    my @sftp_servers = Koha::File::Transports->search();
    my @group_array  = Koha::Library::Groups->search();
    my @branch_array = Koha::Libraries->search();
    my $action_type  = scalar $cgi->param('step');


    if ($action) {
        if ( $action eq 'cud-save' ) {
            if ( $action_type eq 'plugin_settings' ) {
                $self->store_data(
                    {
                        global_enabled     => scalar $cgi->param('global_enabled_selector'),
                        global_fine_branch => scalar $cgi->param('global_fine_branch_selector'),
                    }
                );
            } else {
                $self->store_data(
                    {
                        config_id => scalar $cgi->param('config_id'),
                    }
                );
            }
        } elsif ( $action eq 'sync-report' ) {
            my $sync_id = $cgi->param('config_id');
            my $sync = { sync_id => $sync_id };
            $sync->{send_sync_report} = "1";
            $self->cronjob_nightly($sync);
        }
    }

    $template->param(
        groups             => $groups, 
        debit_types => \@debit_types, 
        smtp_servers => @smtp_servers,
        sftp_servers => @sftp_servers,
        global_enabled     => $self->retrieve_data('global_enabled'),
        global_fine_branch => $self->retrieve_data('global_fine_branch')
    );
    $self->output_html( $template->output() );
}

# =head3 intranet_js

# Get the configure.js file

# =cut

# sub intranet_js {
#     my ( $self ) = @_;

#     return q|
#     <script src="/api/v1/contrib/ums/static/js/configure.js"></script>
#     |;
# }

sub static_routes {
    my ( $self, $args ) = @_;

    my $spec_str = $self->mbf_read('staticapi.json');
    my $spec     = decode_json($spec_str);

    return $spec;
}

# =head3 cronjob_nightly

# =cut

=head3 cronjob_nightly

=cut

sub cronjob_nightly {

    my ( $self, $p, $sync ) = @_;

    my $branch_query;
    my $global_enabled     = $self->retrieve_data('global_enabled');
    my $global_fine_branch = $self->retrieve_data('global_fine_branch');

    if ( $global_enabled == '1' ) {
        if ( $global_fine_branch eq 'patron' ) {
            $branch_query = "AND borrowers.branchcode ";
        }
        if ( $global_fine_branch eq 'item_home' ) {
            my $item_join =
                " LEFT JOIN items ON accountlines.itemnumber = items.itemnumber $branch_query = AND items.homebranch ";
        }
        if ( $global_fine_branch eq 'accountline' ) {
            $branch_query = "AND accountlines.branchcode ";
        }
    } else {
        return 0;
    }
    $self->prune_old_logs();

    my $todays_configs = $self->configs->today_enabled_configs;
    while ( my $config = $todays_configs->next ) {
        my $config_code           = "global";
        my $config_type           = "global";
        my $collections_flag      = $config->collections_flag || undef;
        my $collections_flag_type = 'attribute';
        my $exemptions_flag       = $config->exemptions_flag || undef;
        my $exemptions_flag_type  = 'attribute';

        if ($collections_flag) {
            if ( $collections_flag eq 'sort1' ) {
                $collections_flag_type = 'sort';
            }
        }
        if ($collections_flag) {
            if ( $collections_flag eq 'sort2' ) {
                $collections_flag_type = 'sort';
            }
        }
        if ($exemptions_flag) {
            if ( $exemptions_flag eq 'sort1' ) {
                $exemptions_flag_type = 'sort';
            }
        }
        if ($exemptions_flag) {
            if ( $exemptions_flag eq 'sort2' ) {
                $exemptions_flag_type = 'sort';
            }
        }
        my $config_branch_where;
        my $config_branch_helper;
        if ( $config->config_type eq 'group' ) {
            $config_code = $config->config_group;
            $config_type = "group";
        }
        if ( $config->config_type eq 'library' ) {
            $config_code = $config->branch;
            $config_type = "library";
        }

        # Clear up archives older than 30 days
        if ($archive_dir) {
            if ( -d $archive_dir ) {
                my $dt = dt_from_string();
                $dt->subtract( days => 30 );
                my $age_threshold = $dt->ymd;
                opendir my $dir, $archive_dir or die "Cannot open directory: $!";
                my @files = readdir $dir;
                closedir $dir;
                my $thresholds = {
                    new_submissions => "$config_code-ums-new-submissions-$age_threshold.csv",
                    sync            => "$config_code-ums-sync-$age_threshold.csv",
                    updates         => "$config_code-ums-updates-$age_threshold.csv",
                };

                foreach my $f (@files) {
                    next unless $f =~ /csv$/;

                    my $threshold_filename =
                          $f =~ /^$config_code-ums-new-submissions/ ? $thresholds->{new_submissions}
                        : $f =~ /^$config_code-ums-sync/            ? $thresholds->{sync}
                        : $f =~ /^$config_code-ums-updates/         ? $thresholds->{updates}
                        :                                             undef;

                    next unless $threshold_filename;

                    if ( $f lt $threshold_filename ) {
                        unlink( $archive_dir . "/" . $f );
                    }
                }
            } else {
                make_path $archive_dir or die "Failed to create path: $archive_dir";

            }
        }
        if ( $config_type eq "library" ) {
            $config_branch_helper = "$branch_query ='$config_code'";
        }
        if ( $config_type eq "group" ) {
            $config_branch_helper = $branch_query . "IN (SELECT library_groups.branchcode 
                FROM library_groups WHERE library_groups.parent_id = " . $config_code . "
                AND library_groups.branchcode NOT IN 
                        (SELECT koha_plugin_com_bywatersolutions_umsgentlenudge_config.branch 
                        FROM koha_plugin_com_bywatersolutions_umsgentlenudge_config 
                     WHERE koha_plugin_com_bywatersolutions_umsgentlenudge_config.branch IS NOT NULL)
     )"
        }
        if ( $config_type eq "global" ) {
            $config_branch_helper = $branch_query . "IN (SELECT branches.branchcode 
            FROM branches
            WHERE branches.branchcode NOT IN 
                (SELECT branch 
                FROM koha_plugin_com_bywatersolutions_umsgentlenudge_config
                WHERE koha_plugin_com_bywatersolutions_umsgentlenudge_config.branch IS NOT NULL)
            AND branches.branchcode NOT IN 
                (SELECT branchcode 
                FROM library_groups
                WHERE library_groups.parent_id IN
                    (SELECT koha_plugin_com_bywatersolutions_umsgentlenudge_config.config_group 
                    FROM koha_plugin_com_bywatersolutions_umsgentlenudge_config
                    WHERE koha_plugin_com_bywatersolutions_umsgentlenudge_config.config_group IS NOT NULL)
                ))"
        }
        my $params = { send_sync_report => $sync->{send_sync_report} };
        $params->{require_lost_fee}     = $config->require_lost;
        $params->{fees_threshold}       = $config->threshold;
        $params->{exemptions_flag}      = $config->exemptions_flag;
        $params->{processing_fee}       = $config->processing_fee || 0;
        $params->{collections_flag}     = $config->collections_flag;
        $params->{fees_newer}           = $config->fees_newer;
        $params->{fees_older}           = $config->fees_older;
        $params->{clear_below}          = $config->clear_below;
        $params->{restriction}          = $config->restriction;
        $params->{remove_restriction}   = $config->remove_restriction;
        $params->{remove_minors}        = $config->remove_minors;
        $params->{clear_threshold}      = $config->clear_threshold;
        $params->{ignore_before}        = $config->ignore_before;
        $params->{unique_email}         = $config->unique_email;
        $params->{additional_email}     = $config->additional_email;
        $params->{config_name}          = $config->config_name;
        $params->{umsconfig_type}       = $config_type;
        $params->{collection_flag_type} = $collections_flag_type;
        $params->{exemptions_flag_type} = $exemptions_flag_type;
        $params->{file_id}              = $config_code;
        $params->{config_code}          = $config_code;
        $params->{config_branch_helper} = $config_branch_helper;
        $params->{sftp_server_id}       = $config->sftp_server;
        $params->{smtp_server}          = $config->smtp_server;
        my $today = dt_from_string();
        $params->{date} = $today->ymd();

        my @patron_cat_codes = map { $_->categorycode } $config->patron_categories->as_list;
        $params->{categorycodes} = \@patron_cat_codes;

        my @debit_codes = map { $_->code } $config->debit_types->as_list;
        $params->{debit_type_codes} = \@debit_codes;

        $params->{config_debit_type} = $config->config_debit_type;

        #fees_newer should be the large of the two numbers
        #  ( $params->{fees_newer}, $params->{fees_older} ) =
        #  ( $params->{fees_older}, $params->{fees_newer} )
        #      if $params->{fees_newer} < $params->{fees_older}; {
        # #        # warn?
        #      }

        #  ### Process new submissions
        #  if ( !$params->{send_sync_report} ) {
        $self->run_submissions_report($params);

        #  } elsif ( !$params->{send_sync_report} ) {
        #  log_info("NOT THE DOW TO RUN SUBMISSIONS");
        #  }

        #     ### Process UMS Update Report
        $self->run_update_report_and_clear_paid($params);
    }    #/foreach config

}    # /cronjob_nightly

sub run_submissions_report {
    my ( $self, $params ) = @_;
    my $remove_minors = $params->{remove_minors};
    my $dbh = C4::Context->dbh;
    $dbh->{RaiseError} = 1;    # die if a query has problems

    my $info = {};
    try {
        my $sth;

        my $ums_submission_query = q{
            SELECT
        };
        $ums_submission_query .= qq{
            MAX(borrower_attributes.attribute) AS "collections_flag",
         } if $params->{collection_flag_type} eq 'attribute';

        $ums_submission_query .= q{
            MAX(borrowers.cardnumber)         AS "cardnumber",
            MAX(borrowers.borrowernumber)     AS "borrowernumber",
            MAX(borrowers.surname)            AS "surname",
            MAX(borrowers.firstname)          AS "firstname",
            MAX(borrowers.address)            AS "address",
            MAX(borrowers.address2)           AS "address2",
            MAX(borrowers.city)               AS "city",
            MAX(borrowers.zipcode)            AS "zipcode",
            MAX(borrowers.state)              AS "state",
            MAX(borrowers.phone)              AS "phone",
            MAX(borrowers.mobile)             AS "mobile",
            MAX(borrowers.phonepro)           AS "Alt Ph 1",
            MAX(borrowers.b_phone)            AS "Alt Ph 2",
            MAX(borrowers.branchcode)         AS "branchcode",
            MAX(categories.category_type)     AS "Adult or Child",
            MAX(borrowers.dateofbirth)        AS "dateofbirth",
            MAX(accountlines.date)            AS "Most recent charge",
            FORMAT(Sum(amountoutstanding), 2) AS "Amt_In_Range",
            MAX(sub.due)                      AS "Total_Due",
            MAX(sub.dueplus)                  AS "Total_Plus_Fee",
            MAX(borrowers.email)              AS "email"
            FROM accountlines
         };

        $ums_submission_query .= qq{
            LEFT JOIN borrower_attributes ON accountlines.borrowernumber = borrower_attributes.borrowernumber
            AND code = '$params->{collections_flag}'
             } if $params->{collection_flag_type} eq 'attribute';

        $ums_submission_query .= qq{
            LEFT JOIN borrowers ON ( accountlines.borrowernumber = borrowers.borrowernumber )
            LEFT JOIN (
                SELECT borrowernumber, COUNT(*) AS lost_fees_count
            FROM accountlines
            WHERE debit_type_code = 'LOST'
                AND amountoutstanding > 0
            GROUP BY borrowernumber
            ) AS lost_fees_count ON ( lost_fees_count.borrowernumber = borrowers.borrowernumber)
            LEFT JOIN categories ON ( categories.categorycode = borrowers.categorycode )
            LEFT JOIN ( SELECT
                REPLACE( FORMAT( SUM( accountlines.amountoutstanding ), 2), ',', '' ) AS Due,
                REPLACE( FORMAT( SUM(accountlines.amountoutstanding), '$params->{processing_fee}' , 2), ',', '' ) AS DuePlus,
                borrowernumber
            FROM accountlines
            GROUP BY borrowernumber) AS sub ON ( borrowers.borrowernumber = sub.borrowernumber)
            WHERE DATE(accountlines.date) >= DATE_SUB(CURDATE(), INTERVAL $params->{fees_newer} DAY)
                AND DATE(accountlines.date) <= DATE_SUB(CURDATE(), INTERVAL $params->{fees_older} DAY)
            };

        if ( @{ $params->{debit_type_codes} } ) {
            my $codes = join( ',', map { $dbh->quote($_) } @{ $params->{debit_type_codes} } );
            $ums_submission_query .= qq{
                AND accountlines.debit_type_code IN ( $codes )
            };
        }

        $ums_submission_query .= qq{
                AND ( borrowers.$params->{collections_flag} = 'no' OR borrowers.$params->{collections_flag} IS NULL OR borrowers.$params->{collections_flag} = "" OR borrowers.$params->{collections_flag} = "0")
            } if $params->{collection_flag_type} eq 'sort';

        $ums_submission_query .= qq{
                AND ( borrower_attributes.attribute = 'no' OR borrower_attributes.attribute IS NULL OR borrower_attributes.attribute = "" OR borrower_attributes.attribute = "0" )
            } if $params->{collection_flag_type} eq 'attribute';

        $ums_submission_query .= q{
                AND ( attribute = '0' OR attribute IS NULL )
            } if $params->{exemptions_flag_type} eq 'attribute';

        $ums_submission_query .= q{
                AND ( attribute = '0' OR attribute IS NULL )
            } if $params->{exemptions_flag_type} eq 'attribute';

        if ( @{ $params->{categorycodes} } ) {
            my $codes = join( ',', map { qq{"$_"} } @{ $params->{categorycodes} } );
            $ums_submission_query .= qq{
                    AND borrowers.categorycode IN ( $codes )
                };
        }

        if ( $remove_minors == 1 ) {
            $ums_submission_query .= qq{ AND TIMESTAMPDIFF( YEAR, borrowers.dateofbirth, CURDATE() ) >= 18 };
        }

        if ( $params->{ignore_before} ) {
            $ums_submission_query .= qq{ AND accountlines.date > "$params->{ignore_before}" };
        }

        $ums_submission_query .= qq{
                $params->{config_branch_helper} 
                GROUP BY borrowers.borrowernumber
                    HAVING Sum(amountoutstanding) >= $params->{fees_threshold}
                    ORDER BY borrowers.surname ASC
            };

        log_debug("UMS SUBMISSION QUERY:\n$ums_submission_query");

### Update new submissions patrons, add fee, mark as being in collections
        $sth = $dbh->prepare($ums_submission_query);
        $sth->execute();

        my $columns = [
            "borrowernumber",     "surname",
            "firstname",          "cardnumber",
            "address",            "address2",
            "city",               "zipcode",
            "state",              "phone",
            "mobile",             "Alt Ph 1",
            "Alt Ph 2",           "branchcode",
            "Adult or Child",     "dateofbirth",
            "Most recent charge", "Amt_In_Range",
            "Total_Due",          "Total_Plus_Fee",
            "email"
        ];

        my $csv = UMS::GentleNudge::CSV->new;

        $archive_dir ||= C4::Context->temporary_directory;

        my $filename  = "ums-new-submissions-$params->{date}-$params->{config_code}.csv";
        my $file_path = "$archive_dir/$filename";

        open( my $fh, '>:encoding(UTF-8)', $file_path ) or die "Cannot write to $file_path: $!";
        $csv->print( $fh, $columns );

        my @ums_new_submissions;
        while ( my $r = $sth->fetchrow_hashref ) {
            log_debug( "QUERY RESULT: " . Data::Dumper::Dumper($r) );

            my $patron = Koha::Patrons->find( $r->{borrowernumber} );
            next unless $patron;
            if ( $params->{restriction} eq 'yes' ) {
                AddDebarment(
                    {
                        borrowernumber => $patron->borrowernumber,
                        expiration     => undef,
                        type           => 'MANUAL',
                        comment        => "Patron sent to collections on $params->{date}",
                    }
                );
            }

            if ( $params->{collection_flag_type} eq 'sort' ) {
                $patron->update( { $params->{collections_flag} => 'yes' } );
            }
            if ( $params->{collection_flag_type} eq 'attribute' ) {
                my $a = Koha::Patron::Attributes->find(
                    {
                        borrowernumber => $patron->id,
                        code           => $params->{collections_flag},
                    }
                );

                if ($a) {
                    $a->attribute(1)->store();
                } else {
                    Koha::Patron::Attribute->new(
                        {
                            borrowernumber => $patron->id,
                            code           => $params->{collections_flag},
                            attribute      => 1,
                        }
                    )->store();
                }
            }

            my $processing_fee = $params->{processing_fee};
            $patron->account->add_debit(
                {
                    amount      => $params->{processing_fee},
                    description => "UMS Processing Fee",
                    interface   => 'cron',
                    type        => $params->{config_debit_type},
                }
            ) if $processing_fee && $processing_fee > 0;
            my @row = @{$r}{@$columns};
            $csv->print( $fh, \@row );
            push( @ums_new_submissions, $r );

        }
        close $fh;

        log_info("ARCHIVE WRITTEN TO $file_path");

            if ($params->{sftp_server}) {
                my $transport_id = $params->{sftp_server};
                my $transport = Koha::File::Transports->find($transport_id);
                $transport->upload_file($file_path, $filename);
            }


        ## Email the results

        my $email_to   = $params->{unique_email};
        my $email_from = C4::Context->preference('KohaAdminEmailAddress');
        my $email_cc   = $params->{additional_email};

        $info = {
            count     => scalar @ums_new_submissions,
            filename  => $filename,
            file_path => $file_path,
        };
        foreach my $email_address ( $email_to, $email_cc ) {
            next unless $email_address;
            log_info("ATTEMPTING TO SEND NEW SUBMISSIONS REPORT TO $email_address");

            $info->{email_to}   = $email_address;
            $info->{email_from} = $email_from;

            my $p = {
                to      => $email_address,
                from    => $email_from,
                subject => "UMS New Submissions for $params->{config_name}",
            };
            my $email = Koha::Email->new($p);

            $email->attach(
                Encode::encode_utf8($csv),
                content_type => "text/csv",
                filename     => "ums-new-submissions-$params->{date}-$params->{config_code}.csv",
                name         => "ums-new-submissions-$params->{date}-$params->{config_code}.csv",
                disposition  => 'attachment',
            );
            my $smtp_id =$params->{smtp_server};
            my $smtp_server;
            if ( $smtp_id ) {

                $smtp_server = Koha::SMTP::Servers->find($smtp_id);
            } else {
            $smtp_server = Koha::SMTP::Servers->get_default;
            }
            $email->transport( $smtp_server->transport );

            try {
                $email->send_or_die unless $no_email;
            } catch {
                $info->{email_failed}  = 'true';
                $info->{email_address} = $email_address;
                $info->{email_error}   = $_;

                die "Mail not sent: $_";
            };
        }

    } catch {
        if ( $_->isa('Koha::Exception') ) {
            $info->{error} = $_->error . "\n" . $_->trace->as_string;
        } else {
            $info->{error} = $_;
        }

        die "error in  run_submissions_report: " . $info->{error};
    };
}

sub run_update_report_and_clear_paid {
    my ( $self, $params ) = @_;

    my $dbh = C4::Context->dbh;
    $dbh->{RaiseError} = 1;    # die if a query has problems

    my $type = $params->{send_sync_report} ? 'sync' : 'updates';
    my $info = {};
    try {
        my $sth;

        my $ums_update_query = q{
             SELECT borrowers.cardnumber,
                    borrowers.borrowernumber,
                    MAX(borrowers.surname)                         AS "surname",
                    MAX(borrowers.firstname)                       AS "firstname",
                    FORMAT(Sum(accountlines.amountoutstanding), 2) AS "Due"
                        FROM   accountlines
                        LEFT JOIN borrowers USING(borrowernumber)
                        LEFT JOIN categories USING(categorycode)
         };

        $ums_update_query .= qq{
            LEFT JOIN borrower_attributes ON accountlines.borrowernumber = borrower_attributes.borrowernumber
            AND code = '$params->{collections_flag}'
             } if $params->{collection_flag_type} eq 'attribute';

        $ums_update_query .= q{
             WHERE  1=1
         };

        $ums_update_query .= qq{
             AND ( attribute = '1' OR attribute = 'yes' )
         } if $params->{collection_flag_type} eq 'attribute';

        $ums_update_query .= qq{
             AND ( borrowers.$params->{collections_flag} = 'yes' OR  borrowers.$params->{collections_flag} = '1' )
         } if $params->{collection_flag_type} eq 'sort';

        $ums_update_query .= qq{
                $params->{config_branch_helper} 
            };

        $ums_update_query .= q{
             GROUP BY borrowers.borrowernumber, borrowers.cardnumber
                 ORDER BY borrowers.surname ASC
         };

        log_debug("UMS UPDATE QUERY:\n$ums_update_query")
            if ( !$params->{send_sync_report} );
        $sth = $dbh->prepare($ums_update_query);
        $sth->execute();
        my @ums_updates;
        while ( my $r = $sth->fetchrow_hashref ) {
            log_debug( "QUERY RESULT: " . Data::Dumper::Dumper($r) );
            push( @ums_updates, $r );

            my $due = $r->{Due} || 0;
            $due =~ s/,//;
            if ( $params->{remove_restriction} eq 'yes' && $due <= $params->{clear_threshold} ) {
                $self->clear_patron_from_collections( $params, $r->{borrowernumber} );
                if ( $params->{remove_restriction} ) {
                    Koha::Patron::Restrictions->search(
                        {
                            borrowernumber => $r->{borrowernumber},
                            comment        => { 'like' => "Patron sent to collections on %" }
                        }
                    )->delete();
                    Koha::Patron::Debarments::UpdateBorrowerDebarmentFlags( $r->{borrowernumber} );
                }
            }
        }
        ## Email the results
        $archive_dir ||= C4::Context->temporary_directory;
        my $filename  = "ums-$type-$params->{date}.csv";
        my $file_path = "$archive_dir/$filename";
        $info = {
            count     => scalar @ums_updates,
            type      => $type,
            filename  => $filename,
            file_path => $file_path,
        };

        my $columns = [ "borrowernumber", "surname", "firstname", "cardnumber", "Due" ];

        my $csv;    #=
                    #          @ums_updates
                    #          ? Koha::CSV->new( input => \@ums_updates, field_order => $columns )
                    #         : 'No qualifying records';
                    # log_trace( "CSV:\n" . $csv );
                    #write_file( $file_path, $csv )
                    # if $archive_dir;
        log_info("ARCHIVE WRITTEN TO $archive_dir/ums-$type-$params->{date}.csv")
            if $archive_dir;

        my $email_from = C4::Context->preference('KohaAdminEmailAddress');
        my $email_to   = $self->retrieve_data('unique_email');
        my $email_cc   = $self->retrieve_data('cc_email');
        foreach my $email_address ( $email_to, $email_cc ) {
            next unless $email_address;
            log_info("ATTEMPTING TO SEND ${\(uc($type))} REPORT TO $email_address");

            my $p = {
                to      => $email_address,
                from    => $email_from,
                subject => sprintf(
                    "UMS %s for %s",
                    ucfirst($type), C4::Context->preference('LibraryName')
                ),
            };
            my $email = Koha::Email->new($p);
            $email->attach(
                Encode::encode_utf8($csv),
                content_type => "text/csv",
                filename     => $filename,
                name         => $filename,
                disposition  => 'attachment',
            );
            my $smtp_server = Koha::SMTP::Servers->get_default;
            $email->transport( $smtp_server->transport );

            try {
                $email->send_or_die unless $no_email;
            } catch {
                $info->{email_failed}  = 'true';
                $info->{email_address} = $email_address;
                $info->{email_error}   = $_;
                logaction(
                    'GENTLENUDGE',        uc($type) . "_ERROR", undef,
                    $json->encode($info), 'cron'
                );

                die "Mail not sent: $_";
            };
        }

        logaction(
            'GENTLENUDGE',        uc($type), undef,
            $json->encode($info), 'cron'
        );

    } catch {
        if ( $_->isa('Koha::Exception') ) {
            $info->{error} = $_->error . "\n" . $_->trace->as_string;
        } else {
            $info->{error} = $_;
        }

        logaction(
            'GENTLENUDGE',        uc($type) . "_ERROR", undef,
            $json->encode($info), 'cron'
        );
        die "error in run_update_report_and_clear_paid: $_";
    };
}

sub clear_patron_from_collections {

    my ( $self, $params, $borrowernumber ) = @_;

    log_info("CLEARING PATRON $borrowernumber FROM COLLECTIONS");

    my $patron = Koha::Patrons->find($borrowernumber);
    next unless $patron;

    if ( $params->{collection_flag_type} eq 'sort' ) {
        $patron->_result->update( { $params->{collections_flag} => 'no' } );
    }
    if ( $params->{collection_flag_type} eq 'attribute' ) {
        my $a = Koha::Patron::Attributes->find(
            {
                borrowernumber => $patron->id,
                code           => $params->{collections_flag},
            }
        );

        # At the time of this writing it is not possible to update a repeatable
        # attribute. Instead, it must be deleted and recreated.
        if ($a) {
            $a->delete();
            $a->attribute(0);
            Koha::Patron::Attribute->new( $a->unblessed )->store();
        }
    }

}

sub api_routes {
    my ($self) = @_;

    my $spec_str = $self->mbf_read('lib/api/openapi.json');
    my $spec     = decode_json($spec_str);

    return $spec;
}

sub api_namespace {
    my ($self) = @_;

    return 'ums';
}

=head3 configs

    my $configs = $plugin->configs;

Returns a new I<UMS::GentleNudge::Configs> resultset.

=cut

sub configs {
    my ($self) = @_;
    require UMS::GentleNudge::Configs;
    return UMS::GentleNudge::Configs->new;
}

=head3 install

This is the 'install' method. Any database tables or other setup that should
be done when the plugin if first installed should be executed in this method.
The installation method should always return true if the installation succeeded
or false if it failed.

=cut

sub install() {
    my ( $self, $args ) = @_;

    my $dbh = C4::Context->dbh;

    my $configuration = $self->get_qualified_table_name('config');

    unless ( $self->_table_exists('config') ) {
        C4::Context->dbh->do( "
        CREATE TABLE IF NOT EXISTS $configuration (
                    config_id int(11) NOT NULL AUTO_INCREMENT COMMENT 'unique id for each config',
                    config_name VARCHAR(100) NULL COMMENT 'Name of the group or library',
                    branch VARCHAR(10) NULL COMMENT 'Selected branch',
                    config_group int(11) NULL COMMENT 'Selected group',
                    day_of_week int(1)  NULL COMMENT 'Which day of the week should the report run on',
                    threshold int(11) NULL COMMENT 'Minimum amount owed to be sent to collections.',
                    processing_fee int(11) NULL COMMENT 'Amount of the processing fee added to the patron account',
                    collections_flag VARCHAR(191) NULL COMMENT 'Specify how the patron is flagged as being in collections. If using a patron attribute, it is recommended that the attribute be mapped to the YES_NO category.',
                    exemptions_flag VARCHAR (191) NULL COMMENT 'Patrons with the selected attribute will not be flagged.',
                    fees_newer int(11) NULL COMMENT 'fees newer than this number of days will be totaled to check if a patron should be sent to collections',
                    fees_older int(11) NULL COMMENT 'fewers older than this number of days will be totaled to check if a patron should be sent to collections',
                    ignore_before date NULL COMMENT 'fees created before this date will not be part of the total to check if a patron should be sent to collections',
                    clear_below tinyint(1) NULL COMMENT '0, patrons who have paid their fines to below the threshold will not be removed from collections.',
                    clear_threshold int(11) NULL COMMENT 'The patron will be cleared from collections if if they do not exceed this threshold.',
                    restriction tinyint(1) NULL COMMENT 'Newly flagged patrons will have a restriction added to their account.',
                    remove_restriction tinyint (1) NULL COMMENT 'IF 1, patrons will have the restriction removed if they are removed from collections.',
                    remove_minors tinyint(1) NULL COMMENT 'If 1, patrons under the age of 18 years old will not be included on the collections report.',
                    unique_email VARCHAR(191) NULL COMMENT 'If email information is set, plugin will email files to the given addresses.',
                    additional_email VARCHAR(191) NULL COMMENT 'If you would like to send to another email address as well',
                    enabled int(1) NOT NULL COMMENT 'If there is a default configuration, all branches/groups will be included. 0=disabled, 1=enabled',
                    config_type VARCHAR(15) NOT NULL COMMENT 'Options are global (can only have 1 global), branch, or group',
                    config_debit_type VARCHAR(191) NOT NULL,
                    # updated_at timestamp NOT NULL COMMENT 'When the config was last updated',
                    require_lost TINYINT(1) NOT NULL COMMENT 'Does patron require a lost fee to go to collections',
                    smtp_server int(11) NULL COMMENT 'The ID of the SMPT server to use',
                    sftp_server int(11) NULL COMMENT 'The ID of the SFTP server to use',
                    PRIMARY KEY (config_id),
                    KEY branch (branch),
                    KEY config_group (config_group),
                    KEY smtp_server (smtp_server),
                    KEY sftp_server (sftp_server),
                    CONSTRAINT config_branch FOREIGN KEY (branch) REFERENCES branches (branchcode) ON DElETE CASCADE ON UPDATE CASCADE,
                    CONSTRAINT config_library_group FOREIGN KEY (config_group) REFERENCES library_groups (id) ON DELETE CASCADE ON UPDATE CASCADE,
                    CONSTRAINT config_smtp FOREIGN KEY (smtp_server) REFERENCES smtp_servers (id) ON DELETE CASCADE ON UPDATE CASCADE,
                    CONSTRAINT config_sftp FOREIGN KEY (sftp_server) REFERENCES file_transports (file_transport_id) ON DELETE CASCADE ON UPDATE CASCADE
                    ) ENGINE=INNODB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

       " );
    }
    $dbh->do(
        "INSERT IGNORE INTO $configuration (config_name, config_type, day_of_week, threshold, config_debit_type, clear_below, require_lost, remove_minors, fees_newer, fees_older, remove_restriction, restriction, collections_flag, exemptions_flag) VALUES ('Global', 'global', 0, '10', 'MANUAL', 0, 0, 0, '90', '60', 0, 0, 'sort1', 'sort2')"
    );    #Create default configuration

$self->store_data(
                    {
                        global_enabled => '0',
                        global_fine_branch => 'patron',
                    }
                );

    my $config_debit_type = $self->get_qualified_table_name('config_dt');
    $dbh->do( "
        CREATE TABLE IF NOT EXISTS $config_debit_type (
            config_id int(11) NOT NULL,
            debit_type_code VARCHAR(64) NOT NULL,
            PRIMARY KEY (config_id, debit_type_code),
            CONSTRAINT config_dt_cfg_fk FOREIGN KEY (config_id) REFERENCES $configuration (config_id) ON DELETE CASCADE ON UPDATE CASCADE,
            CONSTRAINT config_dt_code_fk FOREIGN KEY (debit_type_code) REFERENCES account_debit_types (code) ON DELETE CASCADE ON UPDATE CASCADE
        ) ENGINE=INNODB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    " );

    my $config_patron_category = $self->get_qualified_table_name('config_pc');
    $dbh->do( "
        CREATE TABLE IF NOT EXISTS $config_patron_category (
            config_id int(11) NOT NULL,
            category_code VARCHAR(10) NOT NULL,
            PRIMARY KEY (config_id, category_code),
            CONSTRAINT config_pc_cfg_fk FOREIGN KEY (config_id) REFERENCES $configuration (config_id) ON DELETE CASCADE ON UPDATE CASCADE,
            CONSTRAINT config_pc_code_fk FOREIGN KEY (category_code) REFERENCES categories (categorycode) ON DELETE CASCADE ON UPDATE CASCADE
        ) ENGINE=INNODB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    " );

    my $default_config = $dbh->selectcol_arrayref("SELECT config_id FROM $configuration");
    return 1;
}

=head3 upgrade

This is the 'upgrade' method. It will be triggered when a newer version of a
plugin is installed over an existing older version of a plugin

=cut

sub upgrade {
    my ( $self, $args ) = @_;
    my $database_version = $self->retrieve_data('__INSTALLED_VERSION__') || 0;

    if ( $self->_version_compare( $database_version, "2.20.0" ) == -1 ) {

        my $configuration = $self->get_qualified_table_name('config');

        return 1;
    }
    $database_version = "3.00.0";
    $self->store_data( { '__INSTALLED_VERSION__' => $database_version } );
}

=head3 uninstall

This method will be run just before the plugin files are deleted
when a plugin is uninstalled. It is good practice to clean up
after ourselves!

=cut

sub uninstall() {

    my ( $self, $args ) = @_;

    return 1;
}

sub _log_file {

    my $home   = $ENV{HOME} || ( getpwuid($<) )[7];
    my $logdir = File::Spec->catdir( $home, 'gentle_nudge_logs' );
    mkdir $logdir unless -d $logdir;

    my $date = strftime( "%Y-%m-%d", localtime );
    return File::Spec->catfile( $logdir, "gentle_nudge.$date.log" );
}

sub prune_old_logs {

    my $home   = $ENV{HOME} || ( getpwuid($<) )[7];
    my $logdir = File::Spec->catdir( $home, 'gentle_nudge_logs' );
    mkdir $logdir unless -d $logdir;

    my $cutoff = time - ( 30 * 24 * 60 * 60 );    # 30 days in seconds
    opendir my $dh, $logdir or return;
    while ( my $file = readdir $dh ) {
        next unless $file =~ /^gentle_nudge\.(\d{4}-\d{2}-\d{2})\.log$/;
        my $path  = File::Spec->catfile( $logdir, $file );
        my $mtime = ( stat($path) )[9];
        unlink $path if $mtime && $mtime < $cutoff;
    }
    closedir $dh;
}

sub _log {

    my ( $level, $msg ) = @_;
    my $ts   = strftime( "%Y-%m-%d %H:%M:%S", localtime );
    my $line = "[$ts] [$level] $msg\n";
    my $file = _log_file();
    if ( open my $fh, ">>", $file ) {
        print $fh $line;
        close $fh;
    }
    prune_old_logs();

}

sub log_info  { _log( "INFO",  shift ) if $debug >= 1; }
sub log_debug { _log( "DEBUG", shift ) if $debug >= 2; }
sub log_trace { _log( "TRACE", shift ) if $debug >= 3; }

1;
