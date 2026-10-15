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
use Test::More tests => 6;
use Test::Exception;
use Test::MockModule;

use t::lib::TestBuilder;

use File::Temp qw( tempdir );

use Koha::Database;
use Koha::DateUtils qw( dt_from_string );
use Koha::Patron::Attributes;
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

    plan tests => 3;

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
                }
                )
            }
        ];
    };

    is_deeply( $matching_fines->('patron'),      [ $fine_1, $fine_2 ], 'patron: fines of patrons from the library' );
    is_deeply( $matching_fines->('accountline'), [$fine_2],            'accountline: fines created at the library' );
    is_deeply( $matching_fines->('item_home'),   [$fine_1],            'item_home: fines for items owned by the library' );

    $schema->storage->txn_rollback;
};
