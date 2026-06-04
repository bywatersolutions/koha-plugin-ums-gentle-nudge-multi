package UMS::GentleNudge::Config;

use Modern::Perl;
use C4::Context;
use Koha::Database;
use Koha::Library::Group;
use base qw(Koha::Object);
use JSON qw( encode_json decode_json );

=head1 NAME

UMS::GentleNudge::Config - UMS Configuration Object class

=head1 API

=head2 Class methods

=cut

sub to_api {
    my ($self, $params) = @_;
    my $json;
    my %json;
    return $self;
};

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
