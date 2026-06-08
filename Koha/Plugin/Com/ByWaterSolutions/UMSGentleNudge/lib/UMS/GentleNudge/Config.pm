package UMS::GentleNudge::Config;

use Modern::Perl;
use C4::Context;
use Koha::Database;
use Koha::Library::Group;
use Koha::Account::DebitTypes;
use Koha::Patron::Categories;
use base qw(Koha::Object);

=head1 NAME

UMS::GentleNudge::Config - UMS Configuration Object class

=head1 API

=head2 Class methods

=head3 debit_types

Returns the linked Koha::Account::DebitTypes resultset

=cut

sub debit_types {
    my ($self) = @_;

    my @codes = $self->_result->config_debit_types->get_column('debit_type_code')->all;
    return Koha::Account::DebitTypes->new->empty unless @codes;
    return Koha::Account::DebitTypes->search( { code => { -in => \@codes } } );
}

=head3 add_debit_type

    $config->add_debit_type($code);

=cut

sub add_debit_type {
    my ( $self, $code ) = @_;
    $self->_result->add_to_config_debit_types( { debit_type_code => $code } );
    return $self;
}

=head3 set_debit_types

    $config->set_debit_types(\@codes);

=cut

sub set_debit_types {
    my ( $self, $codes ) = @_;
    $self->_result->config_debit_types->delete;
    $self->add_debit_type($_) for @{ $codes // [] };
    return $self;
}

=head3 patron_categories

Returns the linked Koha::Patron::Categories resultset

=cut

sub patron_categories {
    my ($self) = @_;

    my @codes = $self->_result->config_patron_categories->get_column('category_code')->all;
    return Koha::Patron::Categories->new->empty unless @codes;
    return Koha::Patron::Categories->search( { categorycode => { -in => \@codes } } );
}

=head3 add_patron_category

    $config->add_patron_category($code);

=cut

sub add_patron_category {
    my ( $self, $code ) = @_;
    $self->_result->add_to_config_patron_categories( { category_code => $code } );
    return $self;
}

=head3 set_patron_categories

    $config->set_patron_categories(\@codes);

=cut

sub set_patron_categories {
    my ( $self, $codes ) = @_;
    $self->_result->config_patron_categories->delete;
    $self->add_patron_category($_) for @{ $codes // [] };
    return $self;
}

=head2 Internal methods

=head3 _type

=cut

sub _type {
    return 'KohaPluginComBywatersolutionsUmsgentlenudgeConfig';
}

1;

=head1 AUTHOR

Lisette Scheer <lisette@bywatersolutions.com>

=cut
