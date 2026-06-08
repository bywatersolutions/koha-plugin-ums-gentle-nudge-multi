#!/usr/bin/env perl

use Modern::Perl;

use Test::More tests => 6;
use t::lib::TestBuilder;

use Koha::Database;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'debit_types() empty' => sub {
    plan tests => 2;

    $schema->storage->txn_begin;

    my $config = $builder->build_object(
        { class => 'UMS::GentleNudge::Configs', value => { config_type => 'global', enabled => 1, config_debit_type => 'MANUAL', require_lost => 0 } }
    );

    my $debit_types = $config->debit_types;
    isa_ok( $debit_types, 'Koha::Account::DebitTypes' );
    is( $debit_types->count, 0, 'No debit types linked' );

    $schema->storage->txn_rollback;
};

subtest 'add_debit_type()' => sub {
    plan tests => 2;

    $schema->storage->txn_begin;

    my $config = $builder->build_object(
        { class => 'UMS::GentleNudge::Configs', value => { config_type => 'global', enabled => 1, config_debit_type => 'MANUAL', require_lost => 0 } }
    );

    $config->add_debit_type('LOST');
    $config->add_debit_type('MANUAL');

    my $debit_types = $config->debit_types;
    is( $debit_types->count, 2, 'Two debit types linked' );
    my @codes = sort map { $_->code } $debit_types->as_list;
    is_deeply( \@codes, [ 'LOST', 'MANUAL' ], 'Correct codes linked' );

    $schema->storage->txn_rollback;
};

subtest 'set_debit_types()' => sub {
    plan tests => 3;

    $schema->storage->txn_begin;

    my $config = $builder->build_object(
        { class => 'UMS::GentleNudge::Configs', value => { config_type => 'global', enabled => 1, config_debit_type => 'MANUAL', require_lost => 0 } }
    );

    $config->set_debit_types( [ 'LOST', 'MANUAL', 'ACCOUNT' ] );
    is( $config->debit_types->count, 3, 'Three debit types after set' );

    $config->set_debit_types( ['LOST'] );
    is( $config->debit_types->count, 1, 'One debit type after reset' );
    is( $config->debit_types->next->code, 'LOST', 'Correct code remains' );

    $schema->storage->txn_rollback;
};

subtest 'patron_categories() empty' => sub {
    plan tests => 2;

    $schema->storage->txn_begin;

    my $config = $builder->build_object(
        { class => 'UMS::GentleNudge::Configs', value => { config_type => 'global', enabled => 1, config_debit_type => 'MANUAL', require_lost => 0 } }
    );

    my $categories = $config->patron_categories;
    isa_ok( $categories, 'Koha::Patron::Categories' );
    is( $categories->count, 0, 'No patron categories linked' );

    $schema->storage->txn_rollback;
};

subtest 'add_patron_category()' => sub {
    plan tests => 2;

    $schema->storage->txn_begin;

    my $cat1 = $builder->build_object( { class => 'Koha::Patron::Categories' } );
    my $cat2 = $builder->build_object( { class => 'Koha::Patron::Categories' } );

    my $config = $builder->build_object(
        { class => 'UMS::GentleNudge::Configs', value => { config_type => 'global', enabled => 1, config_debit_type => 'MANUAL', require_lost => 0 } }
    );

    $config->add_patron_category( $cat1->categorycode );
    $config->add_patron_category( $cat2->categorycode );

    my $categories = $config->patron_categories;
    is( $categories->count, 2, 'Two patron categories linked' );
    my @codes = sort map { $_->categorycode } $categories->as_list;
    is_deeply( \@codes, [ sort( $cat1->categorycode, $cat2->categorycode ) ], 'Correct categorycodes linked' );

    $schema->storage->txn_rollback;
};

subtest 'set_patron_categories()' => sub {
    plan tests => 3;

    $schema->storage->txn_begin;

    my $cat1 = $builder->build_object( { class => 'Koha::Patron::Categories' } );
    my $cat2 = $builder->build_object( { class => 'Koha::Patron::Categories' } );
    my $cat3 = $builder->build_object( { class => 'Koha::Patron::Categories' } );

    my $config = $builder->build_object(
        { class => 'UMS::GentleNudge::Configs', value => { config_type => 'global', enabled => 1, config_debit_type => 'MANUAL', require_lost => 0 } }
    );

    $config->set_patron_categories( [ $cat1->categorycode, $cat2->categorycode, $cat3->categorycode ] );
    is( $config->patron_categories->count, 3, 'Three categories after set' );

    $config->set_patron_categories( [ $cat2->categorycode ] );
    is( $config->patron_categories->count, 1, 'One category after reset' );
    is( $config->patron_categories->next->categorycode, $cat2->categorycode, 'Correct category remains' );

    $schema->storage->txn_rollback;
};
