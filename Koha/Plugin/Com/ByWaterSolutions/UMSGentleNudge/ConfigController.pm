package Koha::Plugin::Com::ByWaterSolutions::UMSGentleNudge::ConfigController;
use C4::Context;
use C4::Log qw( logaction );
use Modern::Perl;
use Mojo::Base 'Mojolicious::Controller';
use Koha::Plugin::Com::ByWaterSolutions::UMSGentleNudge;
use UMS::GentleNudge::Configs;
use Koha::Libraries;
use Koha::Library::Groups;
use JSON qw( encode_json );

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
            openapi => $c->objects->search( UMS::GentleNudge::Configs->new ),
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 get

Get a specific config

=cut

sub get {
    my $c = shift->openapi->valid_input or return;

    my $config = $c->objects->find( UMS::GentleNudge::Configs->new, $c->param('config_id') );
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
        my $match_result = UMS::GentleNudge::Configs->check_for_existing_group($group->id);
        if ( $match_result->{duplicate_found} ) {
            return $c->render(
                status  => 409,
                openapi => { error => 'A configuration matching this group already exists.' },
            );
        }
    }
    if ( $config_type eq "library" ) {
        my $library = Koha::Libraries->find( $body->{'branch'} );
        return $c->render_resource_not_found("Library") unless $library;
        $body->{'config_name'} = $library->branchname;
        my $match_result = UMS::GentleNudge::Configs->check_for_existing_branch($library->branchcode);
        if ( $match_result->{duplicate_found} ) {
            return $c->render(
                status  => 409,
                openapi => { error => 'A configuration matching this library already exists.' },
            );
        }
    }

    return try {
        $body->{patron_categories} = encode_json( $body->{patron_categories} )
            if $body->{patron_categories};
        my $config = UMS::GentleNudge::Config->new_from_api($body)->store;
        $c->res->headers->location( $c->req->url->to_string . '/' . $config->config_id );

        logaction( 'SYSTEMPREFERENCE', 'ADD', $config->config_id, $config );

        return $c->render(
            status  => 200,
            openapi => $c->objects->find( UMS::GentleNudge::Configs->new, $config->config_id ),
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

    my $config = $c->objects->find_rs( UMS::GentleNudge::Configs->new, $c->param('config_id') );
    return $c->render_resource_not_found("Config") unless $config;

    my $config_before = $config->unblessed;
    my $body          = $c->req->json;
    my $config_type   = $body->{'config_type'};

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
        $body->{patron_categories} = encode_json( $body->{patron_categories} )
            if $body->{patron_categories};
        $config->set_from_api($body)->store;
        $c->res->headers->location( $c->req->url->to_string );

        logaction( 'SYSTEMPREFERENCE', 'MODIFY', $c->param('config_id'),
            $config, undef, $config_before );

        return $c->render(
            status  => 200,
            openapi => $c->objects->find( UMS::GentleNudge::Configs->new, $c->param('config_id') ),
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 delete

Delete a configuration

=cut

sub delete {
    my $c = shift->openapi->valid_input or return;

    my $config_id = $c->param('config_id');
    my $config    = UMS::GentleNudge::Configs->new->find({ config_id => $config_id });
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
