package UMS::GentleNudge::Configs;

use Modern::Perl;
use C4::Context;
use Koha::Database;
use Koha::Library::Group;
use Koha::Libraries;
use UMS::GentleNudge::Config;
use base qw(Koha::Objects);
use Koha::DateUtils qw(dt_from_string);

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
    return 'UMS::GentleNudge::Config';
}

=head3 check_for_existing_group {
    my ( $self, $group ) = @_;

    my $existing_group = UMS::GentleNudge::Configs->search( {config_group=>$group} );
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

    my $existing_group = UMS::GentleNudge::Configs->search( { config_group => $group } );
    if ( $existing_group->count > 0 ) {
        return { 'duplicate_found' => 1 };
    }
    return { 'duplicate_found' => 0 };
}

=head3 check_for_existing_branch {
    my ( $self, $branch ) = @_;

    my $existing_branch = UMS::GentleNudge::Configs->search( {branch=>$branch} );
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

    my $existing_branch = UMS::GentleNudge::Configs->search( { branch => $branch } );
    if ( $existing_branch->count > 0 ) {
        return { 'duplicate_found' => 1 };
    }
    return { 'duplicate_found' => 0 };
}


=head3 today_enabled_configs

    my $configs = UMS::GentleNudge::Configs->today_enabled_configs;

Returns the resultset of configs that are enabled and scheduled for today.

=cut

sub today_enabled_configs {
    my ($self) = @_;

    my $dow = dt_from_string->day_of_week;

    return $self->search(
        {
            enabled     => 1,
            day_of_week => $dow,
        }
    );
}

1;
