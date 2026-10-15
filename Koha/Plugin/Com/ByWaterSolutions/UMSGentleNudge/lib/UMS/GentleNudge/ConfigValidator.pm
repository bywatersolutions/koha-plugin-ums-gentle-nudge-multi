package UMS::GentleNudge::ConfigValidator;

use Modern::Perl;

use DateTime;
use Scalar::Util qw( blessed );

use Koha::Account::DebitTypes;
use Koha::Email;
use Koha::File::Transports;
use Koha::Library::Groups;
use Koha::Libraries;
use Koha::Patron::Attribute::Types;
use Koha::Patron::Categories;
use Koha::SMTP::Servers;

=head1 NAME

UMS::GentleNudge::ConfigValidator - Checks configuration values before they are saved

=head1 SYNOPSIS

    my @errors = UMS::GentleNudge::ConfigValidator::validate($body);

=head1 API

=head2 Functions

=head3 validate

    my @errors = validate($config_data);

Checks configuration data, as sent to the configs API, and returns a list of
error messages, one per invalid field. An empty list means the data is valid.

Empty strings in optional fields are changed to undef in C<$config_data>, so
they are stored as NULL rather than rejected by the database.

=cut

my @whole_number_fields = (
    [ threshold       => 'Threshold',                        1 ],
    [ fees_newer      => 'Fees starting age (days)',         1 ],
    [ fees_older      => 'Fees ending age (days)',           1 ],
    [ processing_fee  => 'Processing fee',                   0 ],
    [ clear_threshold => 'Clear collections flag threshold', 0 ],
);

my @yes_no_fields = qw( enabled restriction remove_restriction remove_minors clear_below require_lost );

my @optional_fields = qw(
    branch config_group processing_fee clear_threshold ignore_before
    unique_email additional_email sftp_server smtp_server exemptions_flag
);

sub validate {
    my ($data) = @_;

    my @errors;

    for my $field (@optional_fields) {
        $data->{$field} = undef if defined $data->{$field} && !ref $data->{$field} && $data->{$field} =~ /^\s*$/;
    }

    my $config_type = $data->{config_type} // '';
    if ( $config_type !~ /^(?:global|library|group)$/ ) {
        push @errors, "Configuration type must be global, library or group";
    } elsif ( $config_type eq 'library' && !( $data->{branch} && Koha::Libraries->find( $data->{branch} ) ) ) {
        push @errors, "Library does not exist";
    } elsif ( $config_type eq 'group' && !( $data->{config_group} && Koha::Library::Groups->find( $data->{config_group} ) ) )
    {
        push @errors, "Library group does not exist";
    }

    my $day = $data->{day_of_week};
    push @errors, "Day of week must be 0 (Sunday) to 6 (Saturday)"
        unless defined $day && $day =~ /^[0-6]$/;

    for my $field (@whole_number_fields) {
        my ( $name, $label, $required ) = @$field;
        my $value = $data->{$name};
        if ( !defined $value || $value eq '' ) {
            push @errors, "$label is required" if $required;
            next;
        }
        push @errors, "$label must be a whole number of 0 or more" unless $value =~ /^\d+$/;
    }

    if (   defined $data->{fees_newer}
        && defined $data->{fees_older}
        && $data->{fees_newer} =~ /^\d+$/
        && $data->{fees_older} =~ /^\d+$/
        && $data->{fees_newer} < $data->{fees_older} )
    {
        push @errors, "Fees starting age must be greater than or equal to fees ending age";
    }

    for my $field (@yes_no_fields) {
        next unless exists $data->{$field};
        my $value = $data->{$field};
        my $ok =
              blessed $value && $value->isa('JSON::PP::Boolean') ? 1
            : defined $value                                     ? $value =~ /^(?:0|1|true|false)$/
            :                                                      0;
        push @errors, "$field must be yes (1) or no (0)" unless $ok;
    }

    if ( !defined $data->{collections_flag} || $data->{collections_flag} eq '' ) {
        push @errors, "Collections flag is required";
    } elsif ( !_is_flag( $data->{collections_flag} ) ) {
        push @errors, "Collections flag must be sort1, sort2 or an existing patron attribute type";
    }

    if ( defined $data->{exemptions_flag} ) {
        if ( !_is_flag( $data->{exemptions_flag} ) ) {
            push @errors, "Exemptions flag must be sort1, sort2 or an existing patron attribute type";
        } elsif ( defined $data->{collections_flag} && $data->{exemptions_flag} eq $data->{collections_flag} ) {
            push @errors, "Exemptions flag must be different from the collections flag";
        }
    }

    if ( defined $data->{ignore_before} && !_is_iso_date( $data->{ignore_before} ) ) {
        push @errors, "Ignore fees created before must be a date in YYYY-MM-DD format";
    }

    # Both accept a comma separated list of addresses
    for my $field ( [ unique_email => 'UMS email address' ], [ additional_email => 'Additional email address' ] ) {
        my ( $name, $label ) = @$field;
        next unless defined $data->{$name};
        my @invalid = grep { !Koha::Email->is_valid($_) } split /\s*,\s*/, $data->{$name};
        push @errors, "$label is not valid: " . join( ', ', map { "'$_'" } @invalid ) if @invalid;
    }

    if ( !defined $data->{config_debit_type} || $data->{config_debit_type} eq '' ) {
        push @errors, "Processing fee debit type is required";
    } elsif ( !Koha::Account::DebitTypes->find( $data->{config_debit_type} ) ) {
        push @errors, "Processing fee debit type does not exist";
    }

    my @debit_types = @{ $data->{debit_type_codes} // [] };
    my @unknown_debit_types = grep { !Koha::Account::DebitTypes->find($_) } @debit_types;
    push @errors, "Unknown debit types: " . join( ', ', @unknown_debit_types ) if @unknown_debit_types;

    my @categories = @{ $data->{patron_category_codes} // $data->{patron_categories} // [] };
    my @unknown_categories = grep { !Koha::Patron::Categories->find($_) } @categories;
    push @errors, "Unknown patron categories: " . join( ', ', @unknown_categories ) if @unknown_categories;

    push @errors, "SFTP server does not exist"
        if defined $data->{sftp_server} && !Koha::File::Transports->find( $data->{sftp_server} );
    push @errors, "SMTP server does not exist"
        if defined $data->{smtp_server} && !Koha::SMTP::Servers->find( $data->{smtp_server} );

    # Without either, new submissions never reach UMS and nobody is sent to collections
    push @errors, "An enabled configuration needs an SFTP server or a UMS email address"
        if _is_yes( $data->{enabled} ) && !defined $data->{sftp_server} && !defined $data->{unique_email};

    return @errors;
}

=head3 _is_flag

Whether a collections or exemptions flag is sort1, sort2 or an existing patron
attribute type code.

=cut

sub _is_flag {
    my ($flag) = @_;
    return 1 if $flag eq 'sort1' || $flag eq 'sort2';
    return Koha::Patron::Attribute::Types->find($flag) ? 1 : 0;
}

=head3 _is_iso_date

Whether a string is a real date in YYYY-MM-DD format.

=cut

sub _is_iso_date {
    my ($date) = @_;
    my ( $y, $m, $d ) = $date =~ /^(\d{4})-(\d{2})-(\d{2})$/ or return 0;
    return eval { DateTime->new( year => $y, month => $m, day => $d ); 1 } ? 1 : 0;
}

=head3 _is_yes

Whether a yes/no value (0/1, true/false or a JSON boolean) is yes.

=cut

sub _is_yes {
    my ($value) = @_;
    return 0 unless defined $value;
    return $value ? 1 : 0 if blessed $value;
    return $value =~ /^(?:1|true)$/ ? 1 : 0;
}

1;
