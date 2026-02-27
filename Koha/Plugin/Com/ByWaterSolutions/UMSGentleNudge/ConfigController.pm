package Koha::Plugin::Com::ByWaterSolutions::UMSGentleNudge::ConfigController;
use C4::Context;
use C4::Log qw( logaction );
use Modern::Perl;
use Mojo::Base 'Mojolicious::Controller';
use Koha::Plugin::Com::ByWaterSolutions::UMSGentleNudge;
use Koha::UMSConfigs;
use Koha::UMSConfig;
use Data::Dumper qw( Dumper );


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
}
catch {
    $c->unhandled_exception;
};
}

=head3 get

Get a specific config

=cut

sub get {
    my $c = shift->openapi->valid_input or return;
    my $config_id = $c->param('config_id');

    return try {
        my $config = Koha::UMSConfigs->find({ config_id => $config_id });
        return $c->render(
            status =>200,
            openapi => $config,
        );
    }
    catch {
        $c->unhandled_exception($_);
    };
}

=head3 add

Create a new config

=cut

sub add {
    my $c = shift->openapi->valid_input or return;

    my $additional_email = $c->req->json->{'additional_email'};
    my $branch = $c->req->json->{'branch'};
    my $clear_below = $c->req->json->{'clear_below'};
    my $clear_threshold = $c->req->json->{'clear_threshold'};
    my $collections_flag = $c->req->json->{'collections_flag'};
    my $config_group = $c->req->json->{'config_group'};
    my $config_id = $c->req->json->{'config_id'};
    my $config_name = $c->req->json->{'config_name'};
    my $config_type = $c->req->json->{'config_type'};
    my $day_of_week = $c->req->json->{'day_of_week'};
    my $debit_type = $c->req->json->{'debit_type'};
    my $enabled = $c->req->json->{'enabled'};
    my $exemptions_flag = $c->req->json->{'exemptions_flag'};
    my $fees_newer = $c->req->json->{'fees_newer'};
    my $fees_older = $c->req->json->{'fees_older'};
    my $ignore_before = $c->req->json->{'ignore_before'};
    my $patron_categories = $c->req->json->{'day_of_week'};
    my $processing_fee = $c->req->json->{'processing_fee'};
    my $remove_minors = $c->req->json->{'remove_minors'};
    my $restriction = $c->req->json->{'restriction'};
    my $threshold = $c->req->json->{'threshold'};
    my $unique_email = $c->req->json->{'unique_email'};
    return try {
        my $config = Koha::UMSConfig->new({
            additional_email => $additional_email,
            branch    => $branch,
            clear_below => $clear_below,
            clear_threshold => $clear_threshold,
            collections_flag => $collections_flag,
            config_group => $config_group,
            config_id => $config_id,
            config_name => $config_name,
            config_type => $config_type,
            day_of_week => $day_of_week,
            debit_type => $debit_type,
            enabled => $enabled,
            exemptions_flag => $exemptions_flag,
            fees_newer => $fees_newer,
            fees_older => $fees_older,
            ignore_before => $ignore_before,
            patron_categories => $patron_categories,
            processing_fee => $processing_fee,
            remove_minors => $remove_minors,
            restriction => $restriction,
            threshold => $threshold,
            unique_email => $unique_email
        });

        $config->store;

        return $c->render(
            status => 200,
            openapi => $config
        );
    }
    catch {
        $c->unhandled_exception($_);
    }
};
=head3 update

 Update an existing config

=cut

 sub update {

    my $c = shift->openapi->valid_input or return;
    my $config_id = $c->param('config_id');
    my $config = Koha::UMSConfigs->find({ config_id => $config_id });
            warn "LISETTE: " . ($c);
     warn "LISETTE " . $config_id;
    my $additional_email = $c->req->json->{'additional_email'};
    #warn "Lisette" . $additional_email;
    my $branch = $c->req->json->{'branch'};
    my $clear_below = $c->req->json->{'clear_below'};
    my $clear_threshold = $c->req->json->{'clear_threshold'};
    my $collections_flag = $c->req->json->{'collections_flag'};
    my $config_group = $c->req->json->{'config_group'};
    my $config_name = $c->req->json->{'config_name'};
    my $config_type = $c->req->json->{'config_type'};
    my $day_of_week = $c->req->json->{'day_of_week'};
    my $debit_type = $c->req->json->{'debit_type'};
    my $enabled = $c->req->json->{'enabled'};
    my $exemptions_flag = $c->req->json->{'exemptions_flag'};
    my $fees_newer = $c->req->json->{'fees_newer'};
    my $fees_older = $c->req->json->{'fees_older'};
    my $ignore_before = $c->req->json->{'ignore_before'};
    #my $patron_categories = $c->req->json->{'patron_categories'};
    my $processing_fee = $c->req->json->{'processing_fee'};
    my $remove_minors = $c->req->json->{'remove_minors'};
    my $restriction = $c->req->json->{'restriction'};
    my $threshold = $c->req->json->{'threshold'};
    my $unique_email = $c->req->json->{'unique_email'};

    
            #my $config = Koha::UMSConfig->find({ config_id => $config_id });
            #warn "LISETTE: " . ($config);
    return try {
        my $old_config = $config;
        {
            $config->additional_email ( $additional_email ) if $additional_email;
            $config->branch ( $branch ) if $branch;
            $config->clear_below ( $clear_below ) if $clear_below;
            $config->clear_threshold ( $clear_threshold ) if $clear_threshold;
            $config->collections_flag ( $collections_flag ) if $collections_flag;
            $config->config_group ( $config_group ) if $config_group;
            $config->config_id ( $config_id ) if $config_id;
            $config->config_name ( $config_name ) if $config_name;
            $config->config_type ( $config_type ) if $config_type;
            $config->day_of_week ( $day_of_week ) if $day_of_week;
            $config->debit_type ( $debit_type ) if $debit_type;
            $config->enabled  ( $enabled ) if $enabled;
            $config->exemptions_flag ( $exemptions_flag ) if $exemptions_flag;
            $config->fees_newer ( $fees_newer ) if $fees_newer;
            $config->fees_older ( $fees_older ) if $fees_older;
            $config->ignore_before ( $ignore_before ) if $ignore_before ;
            #$config->patron_categories ( $patron_categories ) if $patron_categories;
            $config->processing_fee ( $processing_fee ) if $processing_fee ;
            $config->remove_minors ( $remove_minors ) if $remove_minors;
            $config->restriction ( $restriction ) if $restriction;
            $config->threshold ( $threshold ) if $threshold;
            $config->unique_email ( $unique_email ) if  $unique_email;
        };

        $config->store;

    return try {
        return $c->render(
            status => 200,
            openapi => $config
        );
    }
    catch {
        $c->unhandled_exception($_);
    }
    }
};



=head3 Enable
 Enable a configuration
=cut
my $config_id='';
sub Enable {
    my $c = shift->openapi->valid_input or return;
    my $enabled = $c->req->json->{'enabled'};

        return try {
        my $config = Koha::UMSConfig->find({config_id => $config_id });
};};

=head3 Disable
 Disable a configuration
=cut

sub Disable {
    my $c = shift->openapi->valid_input or return;
    my $enabled = $c->req->json->{'enabled'};

        return try {
        my $config = Koha::UMSConfig->find({config_id => $config_id });
};
};
1;