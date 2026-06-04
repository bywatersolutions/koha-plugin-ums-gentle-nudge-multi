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

use Test::More tests => 5;
use Test::Mojo;
use t::lib::TestBuilder;
use t::lib::Mocks;

use Koha::Database;
use Koha::Plugin::Com::ByWaterSolutions::UMSGentleNudge;
use JSON qw( encode_json );
use URI::Escape qw( uri_escape_utf8 );

my $schema   = Koha::Database->new->schema;
my $builder  = t::lib::TestBuilder->new;
my $password = 'thePassword123';

my $plugin = Koha::Plugin::Com::ByWaterSolutions::UMSGentleNudge->new;
my $base   = "/api/v1/contrib/" . $plugin->api_namespace;

t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );

my $t = Test::Mojo->new('Koha::REST::V1');

subtest 'list() tests' => sub {

    plan tests => 3;

    $schema->storage->txn_begin;

    my $librarian = $builder->build_object( { class => 'Koha::Patrons', value => { flags => 2**19 } } );
    $librarian->set_password( { password => $password, skip_validation => 1 } );

    my $config = $builder->build_object(
        { class => 'UMS::GentleNudge::Configs', value => { config_type => 'global', enabled => 1 } }
    );

    $t->get_ok( "//" . $librarian->userid . ":$password\@$base/configs?q=" . uri_escape_utf8( encode_json( { config_id => $config->config_id } ) ) )
      ->status_is(200)
      ->json_is( '/0/config_id' => $config->config_id );

    $schema->storage->txn_rollback;
};

subtest 'get() tests' => sub {

    plan tests => 5;

    $schema->storage->txn_begin;

    my $librarian = $builder->build_object( { class => 'Koha::Patrons', value => { flags => 2**19 } } );
    $librarian->set_password( { password => $password, skip_validation => 1 } );

    my $config = $builder->build_object(
        { class => 'UMS::GentleNudge::Configs', value => { config_type => 'global', enabled => 0 } }
    );

    $t->get_ok( "//" . $librarian->userid . ":$password\@$base/config/" . $config->config_id )
      ->status_is(200)
      ->json_is( '/config_id' => $config->config_id );

    # Non-existent
    $t->get_ok( "//" . $librarian->userid . ":$password\@$base/config/999999999" )
      ->status_is(404);

    $schema->storage->txn_rollback;
};

subtest 'add() tests' => sub {

    plan tests => 3;

    $schema->storage->txn_begin;

    my $librarian = $builder->build_object( { class => 'Koha::Patrons', value => { flags => 2**19 } } );
    $librarian->set_password( { password => $password, skip_validation => 1 } );

    my $body = {
        config_type  => 'global',
        config_name  => 'Test Config',
        enabled      => 1,
        threshold    => "25",
        day_of_week  => "1",
        debit_type   => 'manual',
        require_lost => "0",
    };

    $t->post_ok( "//" . $librarian->userid . ":$password\@$base/configs" => json => $body )
      ->status_is(200)
      ->json_has('/config_id');

    $schema->storage->txn_rollback;
};

subtest 'delete() tests' => sub {

    plan tests => 4;

    $schema->storage->txn_begin;

    my $librarian = $builder->build_object( { class => 'Koha::Patrons', value => { flags => 2**19 } } );
    $librarian->set_password( { password => $password, skip_validation => 1 } );

    my $config = $builder->build_object(
        { class => 'UMS::GentleNudge::Configs', value => { config_type => 'global', enabled => 0 } }
    );

    $t->delete_ok( "//" . $librarian->userid . ":$password\@$base/config/" . $config->config_id )
      ->status_is(204);

    # Already deleted
    $t->delete_ok( "//" . $librarian->userid . ":$password\@$base/config/" . $config->config_id )
      ->status_is(404);

    $schema->storage->txn_rollback;
};

subtest 'add() duplicate detection tests' => sub {

    plan tests => 3;

    $schema->storage->txn_begin;

    my $librarian = $builder->build_object( { class => 'Koha::Patrons', value => { flags => 2**19 } } );
    $librarian->set_password( { password => $password, skip_validation => 1 } );

    my $library = $builder->build_object( { class => 'Koha::Libraries' } );

    my $config = $builder->build_object(
        {
            class => 'UMS::GentleNudge::Configs',
            value => { config_type => 'library', branch => $library->branchcode, enabled => 1 },
        }
    );

    my $body = {
        config_type  => 'library',
        branch       => $library->branchcode,
        enabled      => 1,
        debit_type   => 'manual',
        require_lost => "0",
    };

    $t->post_ok( "//" . $librarian->userid . ":$password\@$base/configs" => json => $body )
      ->status_is(409)
      ->json_has('/error');

    $schema->storage->txn_rollback;
};
