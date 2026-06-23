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

use Test::More tests => 4;
use Test::MockModule;
use File::Temp qw( tempfile );

use t::lib::Mocks;

subtest 'new() tests' => sub {

    plan tests => 3;

    t::lib::Mocks::mock_preference( 'CSVDelimiter', ',' );

    require UMS::GentleNudge::CSV;

    my $csv = UMS::GentleNudge::CSV->new;
    isa_ok( $csv, 'UMS::GentleNudge::CSV', 'Constructor returns correct class' );

    my $csv_semi = UMS::GentleNudge::CSV->new( { sep_char => ';' } );
    $csv_semi->combine( 'a', 'b' );
    like( $csv_semi->string, qr/a;b/, 'sep_char override works' );

    t::lib::Mocks::mock_preference( 'CSVDelimiter', 'tabulation' );
    my $csv_tab = UMS::GentleNudge::CSV->new;
    $csv_tab->combine( 'x', 'y' );
    like( $csv_tab->string, qr/x\ty/, 'Tabulation preference honored' );
};

subtest 'combine() and string() tests' => sub {

    plan tests => 3;

    t::lib::Mocks::mock_preference( 'CSVDelimiter', ',' );

    my $csv = UMS::GentleNudge::CSV->new;

    ok( $csv->combine( 'one', 'two', 'three' ), 'combine succeeds' );
    is( $csv->string, qq{one,two,three\n}, 'string returns correct CSV line' );

    # Fields with commas get quoted
    $csv->combine( 'hello, world', 'plain' );
    like( $csv->string, qr/"hello, world"/, 'Fields with delimiter are quoted' );
};

subtest 'print() tests' => sub {

    plan tests => 2;

    t::lib::Mocks::mock_preference( 'CSVDelimiter', ',' );

    my $csv = UMS::GentleNudge::CSV->new;

    my ( $fh, $filename ) = tempfile( UNLINK => 1, SUFFIX => '.csv' );
    binmode( $fh, ':encoding(UTF-8)' );

    $csv->print( $fh, [ 'name', 'age', 'city' ] );
    $csv->print( $fh, [ 'Alice', '30', 'New York' ] );
    close $fh;

    open( my $read_fh, '<:encoding(UTF-8)', $filename );
    my @lines = <$read_fh>;
    close $read_fh;

    is( $lines[0], "name,age,city\n", 'Header row written correctly' );
    like( $lines[1], qr/Alice,30,.*New York/, 'Data row written correctly' );
};

subtest 'formula injection protection' => sub {

    plan tests => 1;

    t::lib::Mocks::mock_preference( 'CSVDelimiter', ',' );

    my $csv = UMS::GentleNudge::CSV->new;
    $csv->combine( '=SUM(A1:A10)', 'normal' );

    # formula => 'empty' strips leading formula characters
    unlike( $csv->string, qr/^=SUM/, 'Formula characters are neutralized' );
};
