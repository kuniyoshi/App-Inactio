#!/usr/bin/perl
use 5.10.0;
use utf8;
use strict;
use warnings;
use open qw( :std :utf8 );
use autodie qw( open close );
use Data::Dumper;
use App::Inactio;
use App::Inactio::Request::NagiosEvent;
use WebService::ChatWork::Message;
use WebService::ChatWorkApi;

$Data::Dumper::Terse    = 1;
$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Indent   = 1;

my( $hostname, $service_desc, $service_state, $service_state_type ) = map { lc } @ARGV;

my $req = App::Inactio::Request::NagiosEvent->new(
    hostname           => $hostname,
    service_desc       => $service_desc,
    service_state      => $service_state,
    service_state_type => $service_state_type,
);

my $app = App::Inactio->new(
    request => $req,
);

if ( $req->is_error ) {
    my $res_ref = $app->create_incident;

    eval {
        post_chatwork(
            url   => $app->get_incident_url( $res_ref->{id} ),
            name  => $req->name,
            body  => $req->body,
            token => $app->config->{config}{chatwork_token},
        );
    };

    if ( my $e = $@ ) {
        warn "Could not post to chatwork: $e";
    }

    $app->keep_calling_while_topic_is_open( $res_ref->{id} );
}
elsif ( $req->is_recovery ) {
    # $app->close_topic_if_only_one_incident_exists;
}
else {
    die "Unknown request: ", Dumper $req;
}

exit;

sub post_chatwork {
    my( $url, $name, $body, $token ) = @{ { @_ } }{ qw( url name body token ) };

    my $chatwork = WebService::ChatWorkApi->new(
        api_token => $token,
    );
    my $me = $chatwork->ds( "me" )->retrieve;
    my( $room ) = $me->rooms( name => "マイチャット" );

    my $message = WebService::ChatWork::Message->new(
        info => (
            title   => "INACTIO ALERT - $name",
            message => "reactio:\n$url\n\n$body",
        ),
    );

    $room->post_message( $message );

    return;
}
