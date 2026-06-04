#!/usr/bin/env perl

use Modern::Perl;
use Test::More tests => 5;
use Test::Mojo;

use t::lib::TestBuilder;
use t::lib::Mocks;

use Koha::Database;
use Koha::Plugin::Com::ByWaterSolutions::UMSGentleNudge;
use JSON qw( encode_json );
use URI::Escape qw( uri_escape_utf8 );

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

my $t = Test::Mojo->new('Koha::REST::V1');

subtest 'list configs' => sub {
    plan tests => 3;

    $schema->storage->txn_begin;

    my $patron = $builder->build_object(
        { class => 'Koha::Patrons', value => { flags => 1 } }
    );
    t::lib::Mocks::mock_userenv( { patron => $patron } );

    my $config = $builder->build_object(
        {
            class => 'UMS::GentleNudge::Configs',
            value => { config_type => 'global', enabled => 1 },
        }
    );

    $t->get_ok( "/api/v1/contrib/ums/configs?q=" . uri_escape_utf8(encode_json({ config_id => $config->config_id })) )
      ->status_is(200)
      ->json_is( '/0/config_id' => $config->config_id )
      ->or( sub { diag $t->tx->res->body } );

    $schema->storage->txn_rollback;
};

subtest 'get config' => sub {
    plan tests => 5;

    $schema->storage->txn_begin;

    my $patron = $builder->build_object(
        { class => 'Koha::Patrons', value => { flags => 1 } }
    );
    t::lib::Mocks::mock_userenv( { patron => $patron } );

    my $config = $builder->build_object(
        {
            class => 'UMS::GentleNudge::Configs',
            value => { config_type => 'global', enabled => 0 },
        }
    );

    $t->get_ok( "/api/v1/contrib/ums/config/" . $config->config_id )
      ->status_is(200)
      ->json_is( '/config_id' => $config->config_id )
      ->or( sub { diag $t->tx->res->body } );

    # Non-existent
    $t->get_ok( "/api/v1/contrib/ums/config/999999999" )
      ->status_is(404);

    $schema->storage->txn_rollback;
};

subtest 'add config' => sub {
    plan tests => 3;

    $schema->storage->txn_begin;

    my $patron = $builder->build_object(
        { class => 'Koha::Patrons', value => { flags => 1 } }
    );
    t::lib::Mocks::mock_userenv( { patron => $patron } );

    my $body = {
        config_type  => 'global',
        config_name  => 'Test Config',
        enabled      => 1,
        threshold    => "25",
        day_of_week  => "1",
        debit_type   => 'manual',
        require_lost => "0",
    };

    $t->post_ok( "/api/v1/contrib/ums/configs" => json => $body )
      ->status_is(200)
      ->json_has('/config_id')
      ->or( sub { diag $t->tx->res->body } );

    $schema->storage->txn_rollback;
};

subtest 'delete config' => sub {
    plan tests => 4;

    $schema->storage->txn_begin;

    my $patron = $builder->build_object(
        { class => 'Koha::Patrons', value => { flags => 1 } }
    );
    t::lib::Mocks::mock_userenv( { patron => $patron } );

    my $config = $builder->build_object(
        {
            class => 'UMS::GentleNudge::Configs',
            value => { config_type => 'global', enabled => 0 },
        }
    );

    $t->delete_ok( "/api/v1/contrib/ums/config/" . $config->config_id )
      ->status_is(204);

    # Already deleted
    $t->delete_ok( "/api/v1/contrib/ums/config/" . $config->config_id )
      ->status_is(404);

    $schema->storage->txn_rollback;
};

subtest 'add config - duplicate detection' => sub {
    plan tests => 3;

    $schema->storage->txn_begin;

    my $patron = $builder->build_object(
        { class => 'Koha::Patrons', value => { flags => 1 } }
    );
    t::lib::Mocks::mock_userenv( { patron => $patron } );

    my $library = $builder->build_object( { class => 'Koha::Libraries' } );

    # Create a library config
    my $config = $builder->build_object(
        {
            class => 'UMS::GentleNudge::Configs',
            value => {
                config_type => 'library',
                branch      => $library->branchcode,
                enabled     => 1,
            },
        }
    );

    # Attempt to create a duplicate library config
    my $body = {
        config_type  => 'library',
        branch       => $library->branchcode,
        enabled      => 1,
        debit_type   => 'manual',
        require_lost => "0",
    };

    $t->post_ok( "/api/v1/contrib/ums/configs" => json => $body )
      ->status_is(409)
      ->json_has('/error')
      ->or( sub { diag $t->tx->res->body } );

    $schema->storage->txn_rollback;
};
