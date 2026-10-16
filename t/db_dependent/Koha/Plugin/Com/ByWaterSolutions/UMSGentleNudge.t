#!/usr/bin/env perl

# Copyright 2026 ByWater Solutions
#
# This file is part of the UMS Gentle Nudge plugin.
#
# The UMS Gentle Nudge plugin is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# The UMS Gentle Nudge plugin is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with The UMS Gentle Nudge plugin; if not, see <https://www.gnu.org/licenses>.

use Modern::Perl;

use Test::NoWarnings;
use Test::More tests => 11;
use Test::Exception;
use Test::MockModule;
use Test::MockObject;

use t::lib::TestBuilder;

use File::Temp qw( tempdir );
use Text::CSV_XS;

use Koha::Database;
use Koha::DateUtils qw( dt_from_string );
use Koha::Account::Lines;
use Koha::Patron::Attributes;
use Koha::Patron::Restrictions;
use Koha::Patron::Debarments qw( AddDebarment );
use Koha::Patrons;

BEGIN {
    use_ok('Koha::Plugin::Com::ByWaterSolutions::UMSGentleNudge');
}

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

my $class = 'Koha::Plugin::Com::ByWaterSolutions::UMSGentleNudge';

# Minimal stand-ins for the config iterators returned by
# UMS::GentleNudge::Configs, so cronjob_nightly can be tested without
# building full configurations.
package Test::UMS::Config {
    sub new         { my ( $c, $name ) = @_; return bless { name => $name }, $c }
    sub config_name { return $_[0]->{name} }
}

package Test::UMS::Iterator {
    sub new  { my ( $c, @names ) = @_; return bless [ map { Test::UMS::Config->new($_) } @names ], $c }
    sub next { return shift @{ $_[0] } }
}

package Test::UMS::Configs {
    sub today_enabled_configs     { return Test::UMS::Iterator->new(qw( today_1 today_2 today_3 )) }
    sub not_today_enabled_configs { return Test::UMS::Iterator->new(qw( other_1 other_2 )) }
}

package main;

subtest 'cronjob_nightly() tests' => sub {

    plan tests => 3;

    my $global_enabled = 1;
    my ( @submissions_run, @updates_run );
    my %fail;

    my $plugin_mock = Test::MockModule->new($class);
    my $original_retrieve_data = $class->can('retrieve_data');
    $plugin_mock->mock(
        retrieve_data => sub {
            my ( $self, $key ) = @_;
            return $global_enabled if $key eq 'global_enabled';
            return 'patron'        if $key eq 'global_fine_branch';
            return $original_retrieve_data->(@_);
        }
    );
    $plugin_mock->mock( prune_old_logs => sub { } );
    $plugin_mock->mock( configs        => sub { return 'Test::UMS::Configs' } );
    $plugin_mock->mock(
        build_params => sub {
            my ( $self, $config ) = @_;
            return { config_code => $config->config_name, config_name => $config->config_name };
        }
    );
    $plugin_mock->mock(
        run_submissions_report => sub {
            my ( $self, $params ) = @_;
            push @submissions_run, $params->{config_name};
            die "submission failed\n" if $fail{ $params->{config_name} };
        }
    );
    $plugin_mock->mock(
        run_update_report_and_clear_paid => sub {
            my ( $self, $params ) = @_;
            push @updates_run, $params->{config_name};
            die "update failed\n" if $fail{ $params->{config_name} };
        }
    );

    # Skip archive clean up
    local $Koha::Plugin::Com::ByWaterSolutions::UMSGentleNudge::archive_dir;

    my $plugin = $class->new;

    subtest 'A failing configuration does not stop the others' => sub {

        plan tests => 4;

        @submissions_run = @updates_run = ();
        %fail            = ( today_2 => 1, other_1 => 1 );

        throws_ok { $plugin->cronjob_nightly( {}, {} ) }
        qr/New submissions for config 'today_2' failed: submission failed/,
            'Dies at the end, reporting the failed submission';
        like(
            $@, qr/Update report for config 'other_1' failed: update failed/,
            'The same error also reports the failed update'
        );
        is_deeply(
            \@submissions_run, [qw( today_1 today_2 today_3 )],
            'Every submission configuration ran'
        );
        is_deeply( \@updates_run, [qw( other_1 other_2 )], 'Every update configuration ran' );
    };

    subtest 'No errors when every configuration succeeds' => sub {

        plan tests => 3;

        @submissions_run = @updates_run = ();
        %fail            = ();

        lives_ok { $plugin->cronjob_nightly( {}, {} ) } 'Does not die';
        is( scalar @submissions_run, 3, 'All submission configurations ran' );
        is( scalar @updates_run,     2, 'All update configurations ran' );
    };

    subtest 'Nothing runs when the plugin is not enabled' => sub {

        plan tests => 3;

        @submissions_run = @updates_run = ();
        %fail            = ();
        $global_enabled  = 0;

        lives_ok { $plugin->cronjob_nightly( {}, {} ) } 'Does not die';
        is( scalar @submissions_run, 0, 'No submission reports ran' );
        is( scalar @updates_run,     0, 'No update reports ran' );
    };
};

subtest 'clear_patron_from_collections() tests' => sub {

    plan tests => 3;

    my $plugin = $class->new;

    subtest 'sort1/sort2 flag is reset to 0' => sub {

        plan tests => 2;

        $schema->storage->txn_begin;

        my $patron = $builder->build_object( { class => 'Koha::Patrons', value => { sort1 => '1', sort2 => '1' } } );

        $plugin->clear_patron_from_collections(
            { collection_flag_type => 'sort', collections_flag => 'sort1' },
            $patron->borrowernumber
        );

        $patron->discard_changes;
        is( $patron->sort1, '0', 'The configured flag field is set to 0' );
        is( $patron->sort2, '1', 'The other sort field is left alone' );

        $schema->storage->txn_rollback;
    };

    subtest 'Patron attribute flag is reset to 0' => sub {

        plan tests => 2;

        $schema->storage->txn_begin;

        my $attribute_type = $builder->build_object(
            {
                class => 'Koha::Patron::Attribute::Types',
                value => { repeatable => 0, unique_id => 0, authorised_value_category => undef }
            }
        );
        my $patron = $builder->build_object( { class => 'Koha::Patrons' } );
        Koha::Patron::Attribute->new(
            {
                borrowernumber => $patron->borrowernumber,
                code           => $attribute_type->code,
                attribute      => 1,
            }
        )->store;

        $plugin->clear_patron_from_collections(
            { collection_flag_type => 'attribute', collections_flag => $attribute_type->code },
            $patron->borrowernumber
        );

        my $attributes = Koha::Patron::Attributes->search(
            { borrowernumber => $patron->borrowernumber, code => $attribute_type->code } );
        is( $attributes->count,              1,   'The patron still has exactly one flag attribute' );
        is( $attributes->next->attribute, '0', 'The flag attribute is set to 0' );

        $schema->storage->txn_rollback;
    };

    subtest 'A missing patron does not break out of the calling loop' => sub {

        plan tests => 2;

        $schema->storage->txn_begin;

        my $patron = $builder->build_object( { class => 'Koha::Patrons' } );
        my $missing_borrowernumber = $patron->borrowernumber;
        $patron->delete;

        my $iterations = 0;
        my @warnings;
        local $SIG{__WARN__} = sub { push @warnings, @_ };
        for ( 1 .. 2 ) {
            $plugin->clear_patron_from_collections(
                { collection_flag_type => 'sort', collections_flag => 'sort1' },
                $missing_borrowernumber
            );
            $iterations++;
        }

        is( $iterations, 2, 'The loop continued after each call' );
        is_deeply( \@warnings, [], 'No "Exiting subroutine via next" warning' );

        $schema->storage->txn_rollback;
    };
};

subtest 'prune_archives() tests' => sub {

    plan tests => 2;

    my $plugin = $class->new;

    subtest 'Removes only this configuration\'s archives older than 30 days' => sub {

        plan tests => 8;

        my $dir = tempdir( CLEANUP => 1 );
        local $Koha::Plugin::Com::ByWaterSolutions::UMSGentleNudge::archive_dir = $dir;

        my $old    = dt_from_string()->subtract( days => 31 )->ymd;
        my $recent = dt_from_string()->subtract( days => 29 )->ymd;

        my %expect_kept = (
            "ums-new-submissions-$recent-MAIN.csv" => 1,
            "ums-updates-$recent-MAIN.csv"         => 1,
            "ums-new-submissions-$old-MAIN2.csv"   => 1,    # another config
            "ums-updates-$old-MAINX.csv"           => 1,    # code only differs by suffix
            "notes-$old-MAIN.csv"                  => 1,    # not a report archive
        );
        my @expect_removed = (
            "ums-new-submissions-$old-MAIN.csv",
            "ums-sync-$old-MAIN.csv",
            "ums-updates-$old-MAIN.csv",
        );
        for my $f ( keys %expect_kept, @expect_removed ) {
            open my $fh, '>', "$dir/$f" or die $!;
            close $fh;
        }

        $plugin->prune_archives('MAIN');

        ok( !-e "$dir/$_", "Removed $_" ) for @expect_removed;
        ok( -e "$dir/$_",  "Kept $_" )    for sort keys %expect_kept;
    };

    subtest 'Creates the archive directory if missing' => sub {

        plan tests => 1;

        my $dir = tempdir( CLEANUP => 1 ) . '/archives';
        local $Koha::Plugin::Com::ByWaterSolutions::UMSGentleNudge::archive_dir = $dir;

        $plugin->prune_archives('MAIN');
        ok( -d $dir, 'Directory created' );
    };
};

subtest 'build_params() tests' => sub {

    plan tests => 4;

    $schema->storage->txn_begin;

    my $plugin = $class->new;

    my $library_a = $builder->build_object( { class => 'Koha::Libraries' } );
    my $library_b = $builder->build_object( { class => 'Koha::Libraries' } );

    my $config = $builder->build_object(
        {
            class => 'UMS::GentleNudge::Configs',
            value => {
                config_type       => 'library',
                branch            => $library_a->branchcode,
                config_group      => undef,
                enabled           => 1,
                config_debit_type => 'MANUAL',
                require_lost      => 0,
                sftp_server       => undef,
                smtp_server       => undef,
            }
        }
    );

    my $patron_a = $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library_a->branchcode } } );
    my $patron_b = $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library_b->branchcode } } );
    my $item_a   = $builder->build_sample_item( { library => $library_a->branchcode } );
    my $item_b   = $builder->build_sample_item( { library => $library_b->branchcode } );

    my $build_fine = sub {
        my ( $patron, $branchcode, $item ) = @_;
        return $builder->build_object(
            {
                class => 'Koha::Account::Lines',
                value => {
                    borrowernumber    => $patron->borrowernumber,
                    branchcode        => $branchcode,
                    itemnumber        => $item ? $item->itemnumber : undef,
                    debit_type_code   => 'OVERDUE',
                    credit_type_code  => undef,
                    amount            => 5,
                    amountoutstanding => 5,
                }
            }
        )->accountlines_id;
    };

    # Patron home | fine branch | item home
    my $fine_1 = $build_fine->( $patron_a, $library_b->branchcode, $item_a );    # A | B | A
    my $fine_2 = $build_fine->( $patron_a, $library_a->branchcode, $item_b );    # A | A | B
    my $fine_3 = $build_fine->( $patron_b, $library_b->branchcode, undef );      # B | B | -

    # Runs the branch filter the same way the reports do and returns the
    # matching fines
    my $matching_fines = sub {
        my ($fine_branch) = @_;
        my $params = $plugin->build_params( $config, { global_enabled => 1, global_fine_branch => $fine_branch } );
        return [
            sort { $a <=> $b } map { $_->[0] } @{
                C4::Context->dbh->selectall_arrayref(
                    qq{
                    SELECT accountlines.accountlines_id
                    FROM accountlines
                    LEFT JOIN borrowers ON ( accountlines.borrowernumber = borrowers.borrowernumber )
                    WHERE accountlines.accountlines_id IN ( $fine_1, $fine_2, $fine_3 )
                    $params->{config_branch_helper}
                },
                    undef,
                    @{ $params->{config_branch_binds} }
                )
            }
        ];
    };

    is_deeply( $matching_fines->('patron'),      [ $fine_1, $fine_2 ], 'patron: fines of patrons from the library' );
    is_deeply( $matching_fines->('accountline'), [$fine_2],            'accountline: fines created at the library' );
    is_deeply( $matching_fines->('item_home'),   [$fine_1],            'item_home: fines for items owned by the library' );

    throws_ok { $plugin->build_params( $config, { global_enabled => 1, global_fine_branch => 'bogus' } ) }
    qr/Unknown global_fine_branch setting 'bogus'/, 'Unknown fine branch setting dies';

    $schema->storage->txn_rollback;
};

subtest 'run_submissions_report() tests' => sub {

    plan tests => 9;

    my $plugin = $class->new;

    local $Koha::Plugin::Com::ByWaterSolutions::UMSGentleNudge::archive_dir = tempdir( CLEANUP => 1 );

    # Record deliveries instead of sending, failing any destination in %fail
    my ( @delivered_to, %fail );
    my $plugin_mock = Test::MockModule->new($class);
    $plugin_mock->mock(
        _upload_report => sub {
            die "sftp down\n" if $fail{sftp};
            push @delivered_to, 'sftp';
        }
    );
    $plugin_mock->mock(
        _send_report_email => sub {
            my ( $self, $params, $email_address ) = @_;
            die "smtp down\n" if $fail{$email_address};
            push @delivered_to, $email_address;
        }
    );
    $plugin_mock->mock( retrieve_data => sub { return } );

    # Builds a library config, plus a patron at that library with a fine old
    # enough to be sent to collections. Returns the report params and patron.
    my $setup = sub {
        my (%config_values) = @_;

        @delivered_to = ();
        %fail         = ();

        my $library = $builder->build_object( { class => 'Koha::Libraries' } );
        my $config  = $builder->build_object(
            {
                class => 'UMS::GentleNudge::Configs',
                value => {
                    config_type        => 'library',
                    branch             => $library->branchcode,
                    config_group       => undef,
                    enabled            => 1,
                    threshold          => 10,
                    processing_fee     => 10,
                    collections_flag   => 'sort1',
                    exemptions_flag    => 'sort2',
                    fees_newer         => 90,
                    fees_older         => 60,
                    ignore_before      => undef,
                    restriction        => 1,
                    remove_minors      => 0,
                    unique_email       => 'ums@example.org',
                    additional_email   => 'library@example.org',
                    config_debit_type  => 'MANUAL',
                    require_lost       => 0,
                    sftp_server        => undef,
                    smtp_server        => undef,
                    %config_values,
                }
            }
        );

        my $patron = $builder->build_object(
            { class => 'Koha::Patrons', value => { branchcode => $library->branchcode, sort1 => undef, sort2 => undef } } );
        $builder->build_object(
            {
                class => 'Koha::Account::Lines',
                value => {
                    borrowernumber    => $patron->borrowernumber,
                    branchcode        => $library->branchcode,
                    itemnumber        => undef,
                    debit_type_code   => 'OVERDUE',
                    credit_type_code  => undef,
                    amount            => 20,
                    amountoutstanding => 20,
                    date              => dt_from_string()->subtract( days => 70 )->ymd,
                }
            }
        );

        my $params = $plugin->build_params(
            $config,
            { global_enabled => 1, global_fine_branch => 'patron', send_sync_report => 'new' }
        );
        return ( $params, $patron );
    };

    # What happened to the patron: [ in collections, restricted, charged the processing fee ]
    my $sent_to_collections = sub {
        my ($patron) = @_;
        $patron->discard_changes;
        return [
            ( $patron->sort1 // '' ) eq '1' ? 1 : 0,
            Koha::Patron::Restrictions->search( { borrowernumber => $patron->borrowernumber } )->count ? 1 : 0,
            Koha::Account::Lines->search(
                { borrowernumber => $patron->borrowernumber, description => 'UMS Processing Fee' }
            )->count ? 1 : 0,
        ];
    };

    subtest 'Report delivered: patron is sent to collections' => sub {

        plan tests => 6;

        $schema->storage->txn_begin;

        my ( $params, $patron ) = $setup->();

        lives_ok { $plugin->run_submissions_report($params) } 'Does not die';
        is_deeply( $sent_to_collections->($patron), [ 1, 1, 1 ], 'Patron flagged, restricted and charged' );
        is_deeply( \@delivered_to, [ 'ums@example.org', 'library@example.org' ], 'Sent to UMS and the library' );

        my $report = Text::CSV_XS->new( { binary => 1 } );
        open my $fh, '<:encoding(UTF-8)',
            "$Koha::Plugin::Com::ByWaterSolutions::UMSGentleNudge::archive_dir/"
            . "ums-new-submissions-$params->{date}-$params->{config_code}.csv"
            or die $!;
        $report->column_names( $report->getline($fh) );
        my $row = $report->getline_hr($fh);
        close $fh;
        is( $row->{borrowernumber}, $patron->borrowernumber, 'Report lists the patron' );
        is( $row->{Total_Due},      '20.00',                 'Total_Due is the outstanding balance' );
        is( $row->{Total_Plus_Fee}, '30.00',                 'Total_Plus_Fee adds the 10.00 processing fee' );

        $schema->storage->txn_rollback;
    };

    subtest 'UMS email fails: patron changes are rolled back' => sub {

        plan tests => 3;

        $schema->storage->txn_begin;

        my ( $params, $patron ) = $setup->();
        $fail{'ums@example.org'} = 1;

        throws_ok { $plugin->run_submissions_report($params) }
        qr/Report was not delivered to UMS.*Email to ums\@example.org failed: smtp down/,
            'Dies explaining the report was not delivered';
        is_deeply( $sent_to_collections->($patron), [ 0, 0, 0 ], 'Patron not flagged, restricted or charged' );
        is_deeply( \@delivered_to, [], 'Library copy not sent either' );

        $schema->storage->txn_rollback;
    };

    subtest 'SFTP fails but UMS email succeeds: run is kept, error reported' => sub {

        plan tests => 3;

        $schema->storage->txn_begin;

        my ( $params, $patron ) = $setup->();
        $params->{sftp_server_id} = 1;
        $fail{sftp} = 1;

        throws_ok { $plugin->run_submissions_report($params) } qr/SFTP upload failed: sftp down/,
            'Dies reporting the SFTP failure';
        is_deeply( $sent_to_collections->($patron), [ 1, 1, 1 ], 'Patron flagged, restricted and charged' );
        is_deeply( \@delivered_to, [ 'ums@example.org', 'library@example.org' ], 'Emails still sent' );

        $schema->storage->txn_rollback;
    };

    subtest 'Library copy fails: run is kept, error reported' => sub {

        plan tests => 2;

        $schema->storage->txn_begin;

        my ( $params, $patron ) = $setup->();
        $fail{'library@example.org'} = 1;

        throws_ok { $plugin->run_submissions_report($params) } qr/Email to library\@example.org failed: smtp down/,
            'Dies reporting the failed library copy';
        is_deeply( $sent_to_collections->($patron), [ 1, 1, 1 ], 'Patron flagged, restricted and charged' );

        $schema->storage->txn_rollback;
    };

    subtest 'Exemption flag in a sort field is respected' => sub {

        plan tests => 2;

        $schema->storage->txn_begin;

        my ( $params, $patron ) = $setup->();
        $patron->set( { sort2 => '1' } )->store;

        lives_ok { $plugin->run_submissions_report($params) } 'Does not die';
        is_deeply( $sent_to_collections->($patron), [ 0, 0, 0 ], 'Exempt patron not sent to collections' );

        $schema->storage->txn_rollback;
    };

    subtest 'Collections and exemption flags both patron attributes' => sub {

        plan tests => 4;

        $schema->storage->txn_begin;

        my ( $collections_type, $exemption_type ) = map {
            $builder->build_object(
                {
                    class => 'Koha::Patron::Attribute::Types',
                    value => { repeatable => 0, unique_id => 0, authorised_value_category => undef }
                }
            )
        } 1 .. 2;

        my $flag_of = sub {
            my ($patron) = @_;
            my $attribute = Koha::Patron::Attributes->find(
                { borrowernumber => $patron->borrowernumber, code => $collections_type->code } );
            return $attribute ? $attribute->attribute : undef;
        };

        my ( $params, $patron ) = $setup->(
            collections_flag => $collections_type->code,
            exemptions_flag  => $exemption_type->code,
        );
        lives_ok { $plugin->run_submissions_report($params) } 'Query runs';
        is( $flag_of->($patron), '1', 'Patron flagged with the collections attribute' );

        ( $params, $patron ) = $setup->(
            collections_flag => $collections_type->code,
            exemptions_flag  => $exemption_type->code,
        );
        Koha::Patron::Attribute->new(
            { borrowernumber => $patron->borrowernumber, code => $exemption_type->code, attribute => 1 } )->store;
        lives_ok { $plugin->run_submissions_report($params) } 'Query runs';
        is( $flag_of->($patron), undef, 'Exempt patron not flagged' );

        $schema->storage->txn_rollback;
    };

    subtest 'Require lost fee' => sub {

        plan tests => 3;

        $schema->storage->txn_begin;

        my ( $params, $patron ) = $setup->( require_lost => 1 );

        $plugin->run_submissions_report($params);
        is_deeply(
            $sent_to_collections->($patron), [ 0, 0, 0 ],
            'Patron without an outstanding lost fee not sent to collections'
        );

        $builder->build_object(
            {
                class => 'Koha::Account::Lines',
                value => {
                    borrowernumber    => $patron->borrowernumber,
                    branchcode        => $patron->branchcode,
                    itemnumber        => undef,
                    debit_type_code   => 'LOST',
                    credit_type_code  => undef,
                    amount            => 1,
                    amountoutstanding => 1,
                    date              => dt_from_string()->ymd,
                }
            }
        );

        lives_ok { $plugin->run_submissions_report($params) } 'Does not die';
        is_deeply(
            $sent_to_collections->($patron), [ 1, 1, 1 ],
            'Patron with an outstanding lost fee sent to collections'
        );

        $schema->storage->txn_rollback;
    };

    subtest 'Configuration values containing quotes' => sub {

        plan tests => 2;

        $schema->storage->txn_begin;

        my $category = $builder->build_object( { class => 'Koha::Patron::Categories', value => { categorycode => q{Q"'1} } } );
        my ( $params, $patron ) = $setup->();
        $patron->set( { categorycode => $category->categorycode } )->store;
        $params->{categorycodes} = [ $category->categorycode ];

        lives_ok { $plugin->run_submissions_report($params) } 'Query runs';
        is_deeply( $sent_to_collections->($patron), [ 1, 1, 1 ], 'Patron in the quoted category sent to collections' );

        $schema->storage->txn_rollback;
    };

    subtest 'No UMS destination configured: nothing is changed' => sub {

        plan tests => 3;

        $schema->storage->txn_begin;

        my ( $params, $patron ) = $setup->( unique_email => undef );

        throws_ok { $plugin->run_submissions_report($params) }
        qr/no SFTP server or UMS email address is configured/,
            'Dies explaining nothing is configured';
        is_deeply( $sent_to_collections->($patron), [ 0, 0, 0 ], 'Patron not flagged, restricted or charged' );
        is_deeply( \@delivered_to, [], 'Nothing sent' );

        $schema->storage->txn_rollback;
    };
};

subtest '_upload_report() tests' => sub {

    plan tests => 3;

    my $plugin = $class->new;

    my $upload_result;
    my $transport = Test::MockObject->new;
    $transport->mock( upload_file => sub { return $upload_result } );

    my $transports_mock = Test::MockModule->new('Koha::File::Transports');
    my $found;
    $transports_mock->mock( find => sub { return $found ? $transport : undef } );

    my $params = { sftp_server_id => 42 };

    $found = 0;
    throws_ok { $plugin->_upload_report( $params, '/tmp/report.csv', 'report.csv' ) }
    qr/SFTP server 42 not found/, 'Dies when the SFTP server does not exist';

    $found         = 1;
    $upload_result = 0;
    throws_ok { $plugin->_upload_report( $params, '/tmp/report.csv', 'report.csv' ) }
    qr/Upload of report.csv to SFTP server 42 failed/, 'Dies when upload_file returns false';

    $upload_result = 1;
    lives_ok { $plugin->_upload_report( $params, '/tmp/report.csv', 'report.csv' ) } 'Succeeds when the upload works';
};

subtest 'run_update_report_and_clear_paid() tests' => sub {

    plan tests => 5;

    my $plugin = $class->new;

    local $Koha::Plugin::Com::ByWaterSolutions::UMSGentleNudge::archive_dir = tempdir( CLEANUP => 1 );

    my $plugin_mock = Test::MockModule->new($class);
    $plugin_mock->mock( _upload_report     => sub { } );
    $plugin_mock->mock( _send_report_email => sub { } );
    $plugin_mock->mock( retrieve_data      => sub { return } );

    # Builds a library config and a patron at that library who is in
    # collections, with a collections restriction and the given balance.
    # Runs the update report and returns whether the patron is still
    # [ in collections, restricted ].
    my $run = sub {
        my ( $balance, %config_values ) = @_;

        my $library = $builder->build_object( { class => 'Koha::Libraries' } );
        my $config  = $builder->build_object(
            {
                class => 'UMS::GentleNudge::Configs',
                value => {
                    config_type        => 'library',
                    branch             => $library->branchcode,
                    config_group       => undef,
                    enabled            => 1,
                    collections_flag   => 'sort1',
                    exemptions_flag    => 'sort2',
                    clear_below        => 1,
                    clear_threshold    => 5,
                    remove_restriction => 1,
                    unique_email       => 'ums@example.org',
                    additional_email   => undef,
                    config_debit_type  => 'MANUAL',
                    require_lost       => 0,
                    sftp_server        => undef,
                    smtp_server        => undef,
                    %config_values,
                }
            }
        );

        my $patron = $builder->build_object(
            {
                class => 'Koha::Patrons',
                value => { branchcode => $library->branchcode, sort1 => '1', sort2 => undef, debarred => undef }
            }
        );
        $builder->build_object(
            {
                class => 'Koha::Account::Lines',
                value => {
                    borrowernumber    => $patron->borrowernumber,
                    branchcode        => $library->branchcode,
                    itemnumber        => undef,
                    debit_type_code   => 'OVERDUE',
                    credit_type_code  => undef,
                    amount            => 20,
                    amountoutstanding => $balance,
                }
            }
        );
        AddDebarment(
            {
                borrowernumber => $patron->borrowernumber,
                type           => 'MANUAL',
                comment        => 'Patron sent to collections on 2026-01-01',
            }
        );

        my $params = $plugin->build_params(
            $config,
            { global_enabled => 1, global_fine_branch => 'patron', send_sync_report => 'updates' }
        );
        $plugin->run_update_report_and_clear_paid($params);

        $patron->discard_changes;
        return [
            ( $patron->sort1 // '' ) eq '1' ? 1 : 0,
            Koha::Patron::Restrictions->search( { borrowernumber => $patron->borrowernumber } )->count ? 1 : 0,
        ];
    };

    subtest 'clear_below on: cleared at or below clear_threshold' => sub {

        plan tests => 3;

        $schema->storage->txn_begin;

        is_deeply( $run->(3),  [ 0, 0 ], 'Balance below the threshold: cleared and restriction removed' );
        is_deeply( $run->(5),  [ 0, 0 ], 'Balance at the threshold: cleared and restriction removed' );
        is_deeply( $run->(10), [ 1, 1 ], 'Balance above the threshold: still in collections' );

        $schema->storage->txn_rollback;
    };

    subtest 'clear_below off: never cleared' => sub {

        plan tests => 2;

        $schema->storage->txn_begin;

        is_deeply( $run->( 3, clear_below => 0 ), [ 1, 1 ], 'Balance below the threshold: still in collections' );
        is_deeply( $run->( 0, clear_below => 0 ), [ 1, 1 ], 'Paid in full: still in collections' );

        $schema->storage->txn_rollback;
    };

    subtest 'remove_restriction off: cleared but restriction kept' => sub {

        plan tests => 1;

        $schema->storage->txn_begin;

        is_deeply( $run->( 3, remove_restriction => 0 ), [ 0, 1 ], 'Cleared from collections, still restricted' );

        $schema->storage->txn_rollback;
    };

    subtest 'Balance of 1,000,000 or more is compared correctly' => sub {

        plan tests => 1;

        $schema->storage->txn_begin;

        is_deeply( $run->( 1_000_000, clear_threshold => 5 ), [ 1, 1 ], 'Large balance: still in collections' );

        $schema->storage->txn_rollback;
    };

    subtest 'No clear_threshold set with clear_below on' => sub {

        plan tests => 1;

        $schema->storage->txn_begin;

        is_deeply( $run->( 0, clear_threshold => undef ), [ 0, 0 ], 'Paid in full: cleared' );

        $schema->storage->txn_rollback;
    };
};

subtest '_sort_column() tests' => sub {

    plan tests => 4;

    my $sort_column = \&Koha::Plugin::Com::ByWaterSolutions::UMSGentleNudge::_sort_column;

    is( $sort_column->('sort1'), 'sort1', 'sort1 allowed' );
    is( $sort_column->('sort2'), 'sort2', 'sort2 allowed' );
    throws_ok { $sort_column->('sort1 = 1 OR 1') } qr/Invalid sort field flag/, 'Anything else dies';
    throws_ok { $sort_column->(undef) } qr/Invalid sort field flag ''/, 'Undefined dies';
};

subtest 'upgrade() tests' => sub {

    plan tests => 6;

    # ALTER TABLE cannot be rolled back, so work on a copy of the config
    # table without its unique keys
    my $dbh   = C4::Context->dbh;
    my $real  = $class->new->get_qualified_table_name('config');
    my $table = 'ums_gentle_nudge_upgrade_test';
    $dbh->do("DROP TABLE IF EXISTS $table");
    $dbh->do("CREATE TABLE $table LIKE $real");
    for my $key (qw( branch_unique config_group_unique )) {
        $dbh->do("ALTER TABLE $table DROP INDEX $key") if $class->new->_index_exists( $table, $key );
    }

    my $plugin_mock = Test::MockModule->new($class);
    $plugin_mock->mock( get_qualified_table_name => sub { return $table } );
    $plugin_mock->mock( logaction                => sub { } );

    my $plugin = $class->new;
    my $insert = sub {
        $dbh->do(
            "INSERT INTO $table ( branch, config_group, enabled, config_type, config_debit_type, require_lost ) VALUES ( ?, ?, 0, 'library', 'MANUAL', 0 )",
            undef, @_
        );
    };

    $insert->( 'UPGRADE_A', undef );
    $insert->( 'UPGRADE_A', undef );
    throws_ok { $plugin->upgrade } qr/more than one configuration exists for UPGRADE_A/,
        'Refuses to add the key while duplicates exist';

    $dbh->do("DELETE FROM $table");
    $insert->( 'UPGRADE_A', 1 );
    $insert->( 'UPGRADE_B', undef );
    $insert->( undef,       undef );
    $insert->( undef,       undef );
    ok( $plugin->upgrade, 'Upgrade succeeds; repeated NULLs are allowed' );
    ok( $plugin->_index_exists( $table, 'branch_unique' ),       'branch_unique added' );
    ok( $plugin->_index_exists( $table, 'config_group_unique' ), 'config_group_unique added' );
    ok( $plugin->upgrade, 'Running upgrade again succeeds' );

    # Newer Koha turns the DBI error into Koha::Exceptions::Object::DuplicateID
    throws_ok { $insert->( 'UPGRADE_A', undef ) }
    qr/Duplicate (?:ID|entry 'UPGRADE_A' for key '(?:\w+\.)?branch_unique')/,
        'Second config for a library is refused by branch_unique';

    $dbh->do("DROP TABLE IF EXISTS $table");
};
