package Koha::Plugin::Com::ByWaterSolutions::UMSGentleNudge::ConfigController;
use C4::Context;
use C4::Log qw( logaction );
use Modern::Perl;
use Mojo::Base 'Mojolicious::Controller';
use Koha::Plugin::Com::ByWaterSolutions::UMSGentleNudge;
use Koha::UMSConfigs;
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
    #my $patron_categories = $c->req->json->{'patron_categories'};
    my $processing_fee = $c->req->json->{'processing_fee'};
    my $remove_minors = $c->req->json->{'remove_minors'};
    my $restriction = $c->req->json->{'restriction'};
    my $threshold = $c->req->json->{'threshold'};
    my $unique_email = $c->req->json->{'unique_email'};
    return try {
        my $config = Koha::UMSConfig->find({config_id => $config_id });
        
        {
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
            #patron_categories => $patron_categories,
            processing_fee => $processing_fee,
            remove_minors => $remove_minors,
            restriction => $restriction,
            threshold => $threshold,
            unique_email => $unique_email
        };

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
1;