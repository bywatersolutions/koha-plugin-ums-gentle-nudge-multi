package Koha::Plugin::Com::ByWaterSolutions::UMSGentleNudge::ConfigController;
use C4::Context;
use C4::Log qw( logaction );
use Modern::Perl;
use Mojo::Base 'Mojolicious::Controller';
use Koha::Plugin::Com::ByWaterSolutions::UMSGentleNudge;
use Koha::UMSConfigs;
use Koha::UMSConfig;
use Data::Dumper qw( Dumper );
use Koha::Libraries;
use Koha::Library;
use Koha::Library::Groups;
use JSON qw( encode_json decode_json to_json);

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
            openapi => $config
        )
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 add

Create a new config

=cut

sub add {
    my $c = shift->openapi->valid_input or return;
    my $config_name;
    my $body = $c->req->json;
    if ( $body->{config_type} eq "group" ) {
        warn "is a group";
        my $group = Koha::Library::Groups->find($body->{config_group});
                $body->{config_name} = $group->title;
        my $match_result = 
            Koha::UMSConfigs->check_for_existing_group($group);
            if ( $match_result->{duplicate_found} ) {
                warn 'is group match';
                return $c->render(
                    status => 409,
                    openapi => { error => 'A configuration matching this group already exists.'}
                );
            }
    }
    if ( $body->{config_type} eq "library" ) {
        my $library = Koha::Libraries->find($body->{branch});
        warn Dumper($library->branchname);
        $config_name = ($library->branchname);
        warn $config_name;
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
        $body->{patron_categories} = encode_json($body->{patron_categories});
        my $config = Koha::UMSConfig->new_from_api($body);
        $config->store;
        $c->res->headers->location( $c->req->url->to_string . '/' . $config->id );
        my $config_id = $c->param('config_id');
        #logaction( 'SYSTEMPREFERENCE', 'ADD', $config_id,
         #   $config, undef, undef );
        return $c->render(
            status  => 201,
            openapi => $config,
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
    my $config            = Koha::UMSConfigs->find($c->param('config_id') );
    return $c->render_resource_not_found('UMS config entry')
        unless $config;
    my $config_type  = $body->{'config_type'};
    my $config_group = $body->{'config_group'};
    my $branch       = $body->{'branch'};
    return try {
        my $config_before = $config;
        my $config_id = $c->param('config_id');
        $body->{patron_categories} = encode_json($body->{patron_categories});
        $config->set_from_api($body);
        $config->store;
        $c->res->headers->location( $c->req->url->to_string . '/' . $config->id );
       # logaction( 'SYSTEMPREFERENCE', 'MODIFY', $config_id,
       #     $config, undef, $config_before ); 
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
    my $config_before = Koha::UMSConfigs->find($c->param('config_id') );
    warn "after config_before";
    return $c->render_resource_not_found('UMS config entry')
        unless $config_before;
    
    return try {
        warn "in try";
        my $config = $config_before;
        warn "after config";
        my $config_id = $c->param('config_id');
        warn "config_id";
        $config->delete;
        warn "after_delete";

       # logaction( 'SYSTEMPREFERENCE', 'DELETE', $config_id,
     #       to_json(
        #            $config->TO_JSON,
        #            { utf8 => 1, pretty => 1, canonical => 1, }
         #       ), undef, to_json(
          #          $config_before->TO_JSON,
          #          { utf8 => 1, pretty => 1, canonical => 1, }
           #     ) ); 
         #   warn "after log";
        return $c->render_resource_deleted;
        } catch {
        $c->unhandled_exception($_);
    };

}

1;
