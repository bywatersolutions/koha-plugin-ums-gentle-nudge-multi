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
use Test::More tests => 3;

use t::lib::TestBuilder;

use JSON;
use Koha::Database;

BEGIN {
    use_ok('UMS::GentleNudge::ConfigValidator');
}

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'validate() tests' => sub {

    plan tests => 6;

    $schema->storage->txn_begin;

    my $library        = $builder->build_object( { class => 'Koha::Libraries' } );
    my $attribute_type = $builder->build_object( { class => 'Koha::Patron::Attribute::Types' } );
    my $category       = $builder->build_object( { class => 'Koha::Patron::Categories' } );

    # Data as the configuration form sends it
    my $valid = sub {
        return {
            config_type        => 'library',
            branch             => $library->branchcode,
            config_group       => undef,
            day_of_week        => '3',
            threshold          => '25',
            processing_fee     => '10',
            fees_newer         => '90',
            fees_older         => '60',
            clear_below        => '1',
            clear_threshold    => '0',
            restriction        => '1',
            remove_restriction => '0',
            remove_minors      => '0',
            require_lost       => '0',
            enabled            => '1',
            collections_flag   => 'sort1',
            exemptions_flag    => 'sort2',
            ignore_before      => '',
            unique_email       => 'ums@example.org',
            additional_email   => '',
            config_debit_type  => 'MANUAL',
            debit_type_codes   => ['OVERDUE'],
            patron_categories  => [ $category->categorycode ],
            sftp_server        => '',
            smtp_server        => '',
            @_,
        };
    };
    my $errors_for = sub { return [ UMS::GentleNudge::ConfigValidator::validate( $valid->(@_) ) ] };

    subtest 'Valid data passes and blank optional fields become undef' => sub {

        plan tests => 6;

        my $data = $valid->();
        is_deeply( [ UMS::GentleNudge::ConfigValidator::validate($data) ], [], 'No errors' );
        is( $data->{$_}, undef, "Blank $_ becomes undef" ) for qw( ignore_before additional_email sftp_server smtp_server );

        is_deeply(
            $errors_for->(
                collections_flag => $attribute_type->code,
                exemptions_flag  => undef,
                enabled          => JSON::true,
                ignore_before    => '2026-02-28',
                additional_email => 'a@example.org, b@example.org',
                config_type      => 'global',
                branch           => undef,
            ),
            [],
            'Attribute flag, JSON boolean, date, address list and global config are valid'
        );
    };

    subtest 'Configuration type and library or group' => sub {

        plan tests => 3;

        is_deeply(
            $errors_for->( config_type => 'branch' ), ['Configuration type must be global, library or group'],
            'Unknown type'
        );
        is_deeply( $errors_for->( branch => 'NOPE_LIB' ), ['Library does not exist'], 'Unknown library' );
        is_deeply(
            $errors_for->( config_type => 'group', config_group => -1 ), ['Library group does not exist'],
            'Unknown group'
        );
    };

    subtest 'Numbers, days and yes/no fields' => sub {

        plan tests => 7;

        is_deeply(
            $errors_for->( day_of_week => '7' ), ['Day of week must be 0 (Sunday) to 6 (Saturday)'],
            'Day out of range'
        );
        is_deeply( $errors_for->( threshold => '' ), ['Threshold is required'], 'Missing required number' );
        is_deeply(
            $errors_for->( processing_fee => '10.50' ), ['Processing fee must be a whole number of 0 or more'],
            'Decimal in a whole number field'
        );
        is_deeply(
            $errors_for->( fees_newer => '90) OR (1=1' ),
            ['Fees starting age (days) must be a whole number of 0 or more'],
            'SQL in a number field'
        );
        is_deeply(
            $errors_for->( fees_newer => '30', fees_older => '60' ),
            ['Fees starting age must be greater than or equal to fees ending age'],
            'Empty fee age window'
        );
        is_deeply( $errors_for->( processing_fee => '' ), [], 'Optional number may be blank' );
        is_deeply( $errors_for->( restriction => 'yes' ), ['restriction must be yes (1) or no (0)'], 'yes is not 1' );
    };

    subtest 'Collections and exemption flags' => sub {

        plan tests => 4;

        is_deeply( $errors_for->( collections_flag => '' ), ['Collections flag is required'], 'Missing' );
        is_deeply(
            $errors_for->( collections_flag => 'sort3' ),
            ['Collections flag must be sort1, sort2 or an existing patron attribute type'],
            'Unknown collections flag'
        );
        is_deeply(
            $errors_for->( exemptions_flag => 'NOPE_ATTR' ),
            ['Exemptions flag must be sort1, sort2 or an existing patron attribute type'],
            'Unknown exemptions flag'
        );
        is_deeply(
            $errors_for->( exemptions_flag => 'sort1' ),
            ['Exemptions flag must be different from the collections flag'],
            'Same flag for both'
        );
    };

    subtest 'Dates, email addresses and linked records' => sub {

        plan tests => 8;

        is_deeply(
            $errors_for->( ignore_before => '2026-02-30' ),
            ['Ignore fees created before must be a date in YYYY-MM-DD format'],
            'Impossible date'
        );
        is_deeply(
            $errors_for->( ignore_before => '02/01/2026' ),
            ['Ignore fees created before must be a date in YYYY-MM-DD format'],
            'Wrong date format'
        );
        is_deeply(
            $errors_for->( unique_email => 'not an email' ), [q{UMS email address is not valid: 'not an email'}],
            'Invalid email'
        );
        is_deeply(
            $errors_for->( additional_email => 'a@example.org, nope' ),
            [q{Additional email address is not valid: 'nope'}],
            'Invalid address in a list'
        );
        is_deeply(
            $errors_for->( config_debit_type => 'NOPE_TYPE' ), ['Processing fee debit type does not exist'],
            'Unknown processing fee type'
        );
        is_deeply(
            $errors_for->( debit_type_codes => [ 'OVERDUE', 'NOPE_TYPE' ] ), ['Unknown debit types: NOPE_TYPE'],
            'Unknown debit type'
        );
        is_deeply(
            $errors_for->( patron_categories => ['NOPE_CAT'] ), ['Unknown patron categories: NOPE_CAT'],
            'Unknown category'
        );
        is_deeply(
            $errors_for->( sftp_server => -1, smtp_server => -1 ),
            [ 'SFTP server does not exist', 'SMTP server does not exist' ],
            'Unknown servers'
        );
    };

    subtest 'Enabled configuration needs somewhere to send reports' => sub {

        plan tests => 2;

        is_deeply(
            $errors_for->( unique_email => '' ),
            ['An enabled configuration needs an SFTP server or a UMS email address'],
            'Enabled with no destination'
        );
        is_deeply( $errors_for->( unique_email => '', enabled => '0' ), [], 'Disabled with no destination is allowed' );
    };

    $schema->storage->txn_rollback;
};
