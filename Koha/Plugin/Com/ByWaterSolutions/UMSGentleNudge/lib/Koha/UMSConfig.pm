package Koha::UMSConfig;

use Modern::Perl;
use C4::Context;
use Koha::Database;
use Koha::Library::Group;
use base qw(Koha::Objects);

=head1 NAME

Koha::UMSConfig - Koha UMS Configuration Object set class

=head2 Class methods

=cut

=head3 store

=cut

sub store {
    my ($self) = @_;

    $self->created_on( dt_from_string() ) unless $self->in_storage();

    return $self->SUPER::store(@_);
}

=head2 Internal methods

=head3 _type

=cut

sub _type {
    return 'KohaPluginComBywatersolutionsUMSConfig';
}

1;

=head1 AUTHOR

Lisette Scheer <lisette@bywatersolutions.com>

=cut
