package Koha::UMSConfig;

use Modern::Perl;
use C4::Context;
use Koha::Database;
use Koha::Library::Group;
use base qw(Koha::Object);

=head1 NAME

Koha::UMSConfig - Koha UMS Configuration Object set class

=head1 API

=head2 Class methods

=cut

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
