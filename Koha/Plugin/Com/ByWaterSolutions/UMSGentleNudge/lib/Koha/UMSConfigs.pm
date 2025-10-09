package Koha::UMSConfigs;

use Modern::Perl;
use C4::Context;
use Koha::Database;
use Koha::Library::Group;
use Koha::Libraries;
use base qw(Koha::Objects);

=head1 NAME

Koha::UMSConfigs object set class

=head2 Class methods

=head3 get_configs

my @configs = $self->get_configs()

=cut

sub get_configs {
    my ($self) = @_;

    return $self->search( { }, { order_by => ''});

}



=head3 object_class

=cut

sub object_class {
        return 'Koha::UMSConfig';
}

1;