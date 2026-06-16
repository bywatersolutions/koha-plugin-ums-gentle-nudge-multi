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

use Test::More tests => 1;
use Test::MockModule;
use t::lib::TestBuilder;

use DateTime;
use Koha::Database;
use Koha::DateUtils qw( dt_from_string );

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'today_enabled_configs() tests' => sub {

    plan tests => 7;

    $schema->storage->txn_begin;

    # Fixed dates: Wednesday (dow=3) and Thursday (dow=4)
    my $wednesday = DateTime->new( year => 2026, month => 6, day => 17 );    # Wednesday
    my $thursday  = DateTime->new( year => 2026, month => 6, day => 18 );    # Thursday

    my $mock_configs = Test::MockModule->new('UMS::GentleNudge::Configs');
    $mock_configs->mock( 'dt_from_string', sub { return $wednesday->clone } );

    # Config: enabled, scheduled Wednesday
    my $config_wed_enabled = $builder->build_object(
        {
            class => 'UMS::GentleNudge::Configs',
            value => {
                enabled           => 1,
                day_of_week       => 3,
                config_type       => 'global',
                config_debit_type => 'MANUAL',
                require_lost      => 0,
            },
        }
    );

    # Config: enabled, scheduled Thursday
    my $config_thu_enabled = $builder->build_object(
        {
            class => 'UMS::GentleNudge::Configs',
            value => {
                enabled           => 1,
                day_of_week       => 4,
                config_type       => 'global',
                config_debit_type => 'MANUAL',
                require_lost      => 0,
            },
        }
    );

    # Config: disabled, scheduled Wednesday
    my $config_wed_disabled = $builder->build_object(
        {
            class => 'UMS::GentleNudge::Configs',
            value => {
                enabled           => 0,
                day_of_week       => 3,
                config_type       => 'global',
                config_debit_type => 'MANUAL',
                require_lost      => 0,
            },
        }
    );

    # Mocked to Wednesday
    my $results = UMS::GentleNudge::Configs->today_enabled_configs;

    isa_ok( $results, 'UMS::GentleNudge::Configs', 'Returns a resultset' );

    my @ids = map { $_->config_id } $results->as_list;

    ok(
        ( grep { $_ == $config_wed_enabled->config_id } @ids ),
        'Includes config enabled and scheduled for mocked day (Wednesday)'
    );

    ok(
        !( grep { $_ == $config_thu_enabled->config_id } @ids ),
        'Excludes config scheduled for a different day (Thursday)'
    );

    ok(
        !( grep { $_ == $config_wed_disabled->config_id } @ids ),
        'Excludes disabled config even if scheduled for mocked day'
    );

    # Switch mock to Thursday
    $mock_configs->mock( 'dt_from_string', sub { return $thursday->clone } );

    my $thu_results = UMS::GentleNudge::Configs->today_enabled_configs;
    my @thu_ids = map { $_->config_id } $thu_results->as_list;

    ok(
        ( grep { $_ == $config_thu_enabled->config_id } @thu_ids ),
        'After switching to Thursday, includes Thursday config'
    );

    ok(
        !( grep { $_ == $config_wed_enabled->config_id } @thu_ids ),
        'After switching to Thursday, excludes Wednesday config'
    );

    ok(
        !( grep { $_ == $config_wed_disabled->config_id } @thu_ids ),
        'After switching to Thursday, still excludes disabled configs'
    );

    $schema->storage->txn_rollback;
};
