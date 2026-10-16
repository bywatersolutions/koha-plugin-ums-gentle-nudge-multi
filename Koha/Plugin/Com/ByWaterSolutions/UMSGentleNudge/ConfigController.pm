package Koha::Plugin::Com::ByWaterSolutions::UMSGentleNudge::ConfigController;
use C4::Context;
use C4::Log qw( logaction );
use Modern::Perl;
use Mojo::Base 'Mojolicious::Controller';
use Koha::Plugin::Com::ByWaterSolutions::UMSGentleNudge;
use Koha::Libraries;
use Koha::Library::Groups;
use Scalar::Util qw( blessed );
use Try::Tiny;
use UMS::GentleNudge::ConfigValidator;

use JSON;

my $plugin = Koha::Plugin::Com::ByWaterSolutions::UMSGentleNudge->new;

=head1 NAME

Koha::Plugin::Com::ByWaterSolutions::UMSGentleNudge::ConfigController - REST API controller for UMS configurations

=head1 API

=head2 Class Methods

=head3 list

List all configs

=cut

our $json = JSON->new;
$json->pretty(1);
$json->convert_blessed(1);

sub list {
    my $c = shift->openapi->valid_input or return;

    return try {
        return $c->render(
            status  => 200,
            openapi => $c->objects->search( $plugin->configs ),
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

    my $config = $c->objects->find( $plugin->configs, $c->param('config_id') );
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

    # Legacy: accept debit_type as alias for config_debit_type
    $body->{config_debit_type} //= delete $body->{debit_type} if exists $body->{debit_type};

    if ( my @errors = UMS::GentleNudge::ConfigValidator::validate($body) ) {
        return $c->render( status => 400, openapi => { error => join( '; ', @errors ), errors => \@errors } );
    }
    if ( my $conflict = UMS::GentleNudge::ConfigValidator::conflict($body) ) {
        return $c->render( status => 409, openapi => { error => $conflict } );
    }

    return try {
        my $patron_category_codes = delete $body->{patron_category_codes} // delete $body->{patron_categories};
        my $debit_type_codes      = delete $body->{debit_type_codes};

        my $config = $plugin->configs->object_class->new_from_api($body)->store;
        $config->set_debit_types($debit_type_codes);
        $config->set_patron_categories($patron_category_codes);
        my $info= $json->encode($config);
        logaction( 
            'GentleNudge', 'ADD', $config->config_id , $config , undef,undef
            );

        $c->res->headers->location( $c->req->url->to_string . '/' . $config->config_id );

        return $c->render(
            status  => 200,
            openapi => $c->objects->find( $plugin->configs, $config->config_id ),
        );
    } catch {
        return $c->_render_duplicate_or_exception($_);
    };
}

=head3 update

Update an existing config

=cut

sub update {
    my $c = shift->openapi->valid_input or return;

    my $config = $c->objects->find_rs( $plugin->configs, $c->param('config_id') );
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

    # Legacy: accept debit_type as alias for config_debit_type
    $body->{config_debit_type} //= delete $body->{debit_type} if exists $body->{debit_type};

    if ( my @errors = UMS::GentleNudge::ConfigValidator::validate($body) ) {
        return $c->render( status => 400, openapi => { error => join( '; ', @errors ), errors => \@errors } );
    }
    if ( my $conflict = UMS::GentleNudge::ConfigValidator::conflict( $body, $config->config_id ) ) {
        return $c->render( status => 409, openapi => { error => $conflict } );
    }

    return try {
        my $patron_category_codes = delete $body->{patron_category_codes} // delete $body->{patron_categories};
        my $debit_type_codes      = delete $body->{debit_type_codes};

        $config->set_from_api($body)->store;
        $config->set_debit_types($debit_type_codes)       if $debit_type_codes;
        $config->set_patron_categories($patron_category_codes) if $patron_category_codes;

        $c->res->headers->location( $c->req->url->to_string );

        my $info= $json->encode($config);
        logaction( 
            'GentleNudge', 'MODIFY', $c->param('config_id'), $config , undef, $config_before
            );
        return $c->render(
            status  => 200,
            openapi => $c->objects->find( $plugin->configs, $c->param('config_id') ),
        );
    } catch {
        return $c->_render_duplicate_or_exception($_);
    };
}

=head3 delete

Delete a configuration

=cut

sub delete {
    my $c = shift->openapi->valid_input or return;

    my $config_id = $c->param('config_id');
    my $config    = $plugin->configs->find( { config_id => $config_id } );
    return $c->render_resource_not_found("Config") unless $config;

    return try {
        
        logaction( 
            'GentleNudge', 'MODIFY', $config_id, undef , undef, $config
            );
        $config->delete;
        return $c->render( status => 204, openapi => q{} );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 _render_duplicate_or_exception

Renders a 409 when storing a configuration hit the unique keys on branch or
config_group (two saves for the same library or group at the same time),
otherwise hands the exception to unhandled_exception.

=cut

sub _render_duplicate_or_exception {
    my ( $c, $error ) = @_;

    if ( blessed $error && $error->isa('Koha::Exceptions::Object::DuplicateID') ) {
        return $c->render(
            status  => 409,
            openapi => { error => 'A configuration for this library or group already exists.' },
        );
    }
    return $c->unhandled_exception($error);
}

1;
