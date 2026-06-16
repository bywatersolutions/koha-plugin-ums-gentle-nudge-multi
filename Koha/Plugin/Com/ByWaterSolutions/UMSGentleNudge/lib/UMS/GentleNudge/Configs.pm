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


=head3 sub today_enabled_configs {
    my ( $self ) = @_;

    my $todays_configs = UMS::GentleNudge::Configs->search( { enabled => "1" }, { run_on_dow => });
    if ( $todays_configs->count > 0 ) {
        return { $todays_configs };
    }
    return { 'no_enabled_configs' => 1 };
}

=cut

sub today_enabled_configs {
    my ( $self ) = @_;
    my $today = dt_from_string->day_of_week();
    warn $today;
    my $todays_configs;
    $todays_configs = UMS::GentleNudge::Configs->search({ run_on_dow => $today });
    
    if ( defined $todays_configs) {
        warn "defined";
        return { $todays_configs };
    } else {
        warn "undefined";
    return { 'no_enabled_configs'};
}
}

1;
