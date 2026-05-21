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
    my $configs = $c->objects->search( Koha::UMSConfigs->new );
        return $c->render_resource_not_found('UMS config entries')
            unless $configs;
    return try {
        return $c->render(
            status  => 200,
            openapi => $configs
        );
    } catch {
        $c->unhandled_exception;
    };
}

=head3 get

Get a specific config

=cut

sub get {
    my $c         = shift->openapi->valid_input or return;
    my $config = $c->objects->find( Koha::UMSConfigs->new, $c->param('config_id') );

    return $c->render_resource_not_found('UMS config entry')
        unless $config;

    return try {
        return $c->render(
            status  => 200,
            openapi => $c->objects->to_api( $config )
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
    my $body = $c->req->json;

    if ( $body->{config_type} eq "group" ) {
        my $group = Koha::Library::Groups->find($body->{config_group});
                $body->{config_name} = $group->title;
        my $match_result = 
            Koha::UMSConfigs->check_for_existing_group($group);
            if ( $match_result->{duplicate_found} ) {
                return $c->render(
                    status => 409,
                    openapi => { error => 'A configuration matching this group already exists.'}
                );
            }
    }
    if ( $body->{config_type} eq "library" ) {
        my $library = Koha::Libraries->find($body->{branch});
        my $library_name = Koha::Libraries->find($library);
        my $config_name = $library_name->branchname;
        my $match_result = 
            Koha::UMSConfigs->check_for_existing_branch($library);
            if ( $match_result->{duplicate_found} ) {
                return $c->render(
                    status => 409,
                    openapi => { error => 'A configuration matching this library already exists.'}
                );
            }
    }
    return try {
        my $config = Koha::UMSConfig->new_from_api($body);

        $config->store;
        $c->res->hears->location( $c->req->url->to_string . '/' . $config->id );
        my $config_id = $c->param('config_id');
        logaction( 'SYSTEMPREFERENCE', 'ADD', $config_id,
            $config, undef, undef );
        return $c->render(
            status  => 201,
            openapi => $c->objects->to_api($config),
        );
    } catch {
        $c->unhandled_exception($_);
    }
}

=head3 update

 Update an existing config

=cut

sub update {

    my $c                 = shift->openapi->valid_input or return;
    my $body = $c->req->json;
    my $config            = $c->objects->find_rs (Koha::UMSConfigs->new, $c->param('config_id') );

    return $c->render_resource_not_found('UMS config entry')
        unless $config;

    my $config_type  = $body->{'config_type'};
    my $config_group = $body->{'config_group'};
    my $branch       = $body->{'branch'};

    if ( $config_type eq "group" ) {
        my $group = Koha::Library::Groups->find($config_group);
        my $config_name = $group->title;
    }
    if ( $config_type eq "library" ) {
        my $branch_name = Koha::Libraries->find($branch);
       my $config_name = $branch_name->branchname;
    }
    return try {
        my $config_before = $config;
        my $config_id = $c->param('config_id');

        $config->store;
        $c->res->headers->location( $c->req->url->to_string . '/' . $config->id );
        logaction( 'SYSTEMPREFERENCE', 'MODIFY', $config_id,
            $config, undef, $config_before ); 
        return try {
            return $c->render(
                status  => 200,
                openapi => $c->objects->to_api( $config )
            );
        } catch {
            $c->unhandled_exception($_);
        }
    }
}

=head3 delete

Delete a configuration

=cut

sub delete {
    my $c             = shift->openapi->valid_input or return;
    my $config_before = Koha::UMSConfigs->find( $c->param('config_id') );

    return $c->render_resource_not_found('UMS config entry')
        unless $config_before;
    try {
        my $config = $config_before;
        my $config_id = $c->param('config_id');
        $config->delete;

        logaction( 'SYSTEMPREFERENCE', 'DELETE', $config_id,
            $config, undef, $config_before ); 
        return $c->render_resource_deleted;
        } catch {
        $c->unhandled_exception($_);
    };

}

1;
