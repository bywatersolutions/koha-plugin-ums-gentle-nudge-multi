package Koha::Plugin::Com::ByWaterSolutions::UMSGentleNudge::ConfigController;
use C4::Context;
use C4::Log qw( logaction );
use Modern::Perl;
use Mojo::Base 'Mojolicious::Controller';
use Koha::Plugin::Com::ByWaterSolutions::UMSGentleNudge;
use Koha::UMSConfigs;
use Koha::UMSConfig;
use Data::Dumper qw( Dumper );
use Koha::Library::Groups;

=head1 NAME

 Koha::Plugin::Com::ByWaterSolutions::UMSGentleNudge::ConfigController

=head1 API

=head2 Class Methods

=head3 list

List all configs

=cut

sub list {
    my $c = shift->openapi->valid_input or return;

    return try {
        return $c->render(
            status  => 200,
            openapi => $c->objects->search( Koha::UMSConfigs->new ),
        );
    } catch {
        $c->unhandled_exception;
    };
}

=head3 get

Get a specific config

=cut

sub get {
    my $c = shift->openapi->valid_input or return;

    my $config = $c->objects->find( Koha::UMSConfigs->new, $c->param('config_id') );
    return $c->render_resource_not_found("Config") unless $config;

    return try {
        return $c->render(
            status  => 200,
            openapi => $config,
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 add

Create a new config

=cut

sub add {
    my $c = shift->openapi->valid_input or return;

    my $body        = $c->req->json;
    my $config_type = $body->{'config_type'};

    if ( $config_type eq "group" ) {
        my $group = Koha::Library::Groups->find( $body->{'config_group'} );
        return $c->render_resource_not_found("Library group") unless $group;
        $body->{'config_name'} = $group->title;
    }
    if ( $config_type eq "library" ) {
        my $library = Koha::Libraries->find( $body->{'branch'} );
        return $c->render_resource_not_found("Library") unless $library;
        $body->{'config_name'} = $library->branchname;
    }

    return try {
        my $config = Koha::UMSConfig->new_from_api($body)->store;

        return $c->render(
            status  => 200,
            openapi => $c->objects->find( Koha::UMSConfigs->new, $config->config_id ),
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 update

 Update an existing config

=cut

sub update {
    my $c = shift->openapi->valid_input or return;

    my $config = $c->objects->find_rs( Koha::UMSConfigs->new, $c->param('config_id') );
    return $c->render_resource_not_found("Config") unless $config;

    my $body        = $c->req->json;
    my $config_type = $body->{'config_type'};

    if ( $config_type eq "group" ) {
        my $group = Koha::Library::Groups->find( $body->{'config_group'} );
        return $c->render_resource_not_found("Library group") unless $group;
        $body->{'config_name'} = $group->title;
    }
    if ( $config_type eq "library" ) {
        my $library = Koha::Libraries->find( $body->{'branch'} );
        return $c->render_resource_not_found("Library") unless $library;
        $body->{'config_name'} = $library->branchname;
    }

    return try {
        $config->set_from_api($body)->store;

        return $c->render(
            status  => 200,
            openapi => $c->objects->find( Koha::UMSConfigs->new, $c->param('config_id') ),
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 delete

Delete a configuration

=cut

sub delete {
    my $c         = shift->openapi->valid_input or return;
    my $config_id = $c->param('config_id');
    my $config    = Koha::UMSConfigs->find({ config_id => $config_id });

    return $c->render_resource_not_found("Config") unless $config;

    return try {
        logaction( 'SYSTEMPREFERENCE', 'DELETE', $config_id, $config );
        $config->delete;
        return $c->render( status => 204, openapi => q{} );
    } catch {
        $c->unhandled_exception($_);
    };
}

1;
