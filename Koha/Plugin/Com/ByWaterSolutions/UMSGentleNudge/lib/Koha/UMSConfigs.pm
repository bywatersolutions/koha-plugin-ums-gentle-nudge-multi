package Koha::UMSConfigs;

use Modern::Perl;
use C4::Context;
use Koha::Database;
use Koha::Library::Group;
use Koha::Libraries;
use Koha::UMSConfig;
use base qw(Koha::Objects);

=head1 NAME

Koha::UMSConfig object set class

=head1 API

=head2 Internal methods

=head3 _type
=cut

sub _type {
    return 'KohaPluginComBywatersolutionsUmsgentlenudgeConfig';
}

=head3 object_class

=cut

sub object_class {
        return 'Koha::UMSConfig';
}


=head3 check_for_existing_group {
    my ( $self, $group ) = @_;

    my $existing_group = Koha::UMSConfigs->search( {config_group=>$group} );
    if ( $existing_group->count > 0 ) {
        return {
            'duplicate_found'  => 1
        };
    }
    return { 'duplicate_found' => 0 };
}

=cut

sub check_for_existing_group {
    my ( $self, $group ) = @_;

    my $existing_group = Koha::UMSConfigs->search( {config_group=>$group} );
    if ( $existing_group->count > 0 ) {
        return {
            'duplicate_found'  => 1
        };
    }
    return { 'duplicate_found' => 0 };
}

=head3 check_for_existing_branch {
    my ( $self, $branch ) = @_;

    my $existing_branch = Koha::UMSConfigs->search( {branch=>$branch} );
    if ( $existing_branch->count > 0 ) {
        return {
            'duplicate_found'  => 1
        };
    }
    return { 'duplicate_found' => 0 };
}

=cut

sub check_for_existing_branch {
    my ( $self, $branch ) = @_;

    my $existing_branch = Koha::UMSConfigs->search( {branch=>$branch} );
    if ( $existing_branch->count > 0 ) {
        return {
            'duplicate_found'  => 1
        };
    }
    return { 'duplicate_found' => 0 };
}

1;