package UMS::GentleNudge::CSV;

use Modern::Perl;

# TODO: When $MINIMUM_VERSION is raised to 26.05, make this a subclass
# of Koha::CSV instead of wrapping Text::CSV_XS directly.

use Text::CSV_XS;
use C4::Context;

=head1 NAME

UMS::GentleNudge::CSV - CSV helper for UMS collections reports

=head1 SYNOPSIS

    use UMS::GentleNudge::CSV;

    my $csv = UMS::GentleNudge::CSV->new;
    $csv->print( $fh, \@header );
    $csv->print( $fh, \@row );

=head1 DESCRIPTION

Thin wrapper around Text::CSV_XS with Koha-compatible defaults:
sep_char from CSVDelimiter preference, binary mode for UTF-8,
formula injection protection.

=cut

sub new {
    my ( $class, $params ) = @_;
    $params //= {};

    my $sep_char = $params->{sep_char} // C4::Context->csv_delimiter;

    my $csv = Text::CSV_XS->new(
        {
            binary       => 1,
            formula      => 'empty',
            always_quote => $params->{always_quote} // 0,
            eol          => $params->{eol} // "\n",
            sep_char     => $sep_char,
        }
    );

    return bless { _csv => $csv }, $class;
}

sub print {
    my ( $self, $fh, $fields ) = @_;
    return $self->{_csv}->print( $fh, $fields );
}

sub combine {
    my ( $self, @fields ) = @_;
    return $self->{_csv}->combine(@fields);
}

sub string {
    my ($self) = @_;
    return $self->{_csv}->string;
}

sub error_diag {
    my ($self) = @_;
    return $self->{_csv}->error_diag;
}

1;
