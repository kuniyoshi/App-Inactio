use strict;
use warnings;
package App::Inactio;
use Carp ( );
use Data::Dumper;
use Readonly;
use List::Util qw( first );
use JSON;
use URI;
use WebService::Reactio;
use App::Inactio::Config;

Readonly my $CONFIG_FILE => "/etc/sysconfig/inactio.pl";

sub request { shift->{request} }

sub config { shift->{config} }

sub reactio { shift->{reactio} }

sub new {
    my $class = shift;
    my %param = @_;

    my $config_file = delete $param{config} || $CONFIG_FILE;
    my $req = delete $param{request}
        or Carp::croak( "request required" );

    my $config = App::Inactio::Config->new( $config_file );
    my $self = bless {
        config  => $config,
        request => $req,
    }, $class;
    $self->init;

    return $self;
}

sub init {
    my $self = shift;
    my $api_key = $self->config->get_api_key( $self->request->project_name );
    my $reactio = WebService::Reactio->new(
        api_key      => $api_key,
        organization => $self->config->organization,
    );
    $self->{reactio} = $reactio;
    return;
}

sub dump {
    my $self = shift;
    return Data::Dumper->new( [ @_ ] )->Terse( 1 )->Sortkeys( 1 )->Useqq( 1 )->Indent( 0 )->Dump;
}

sub is_last_stand {
    my $self = shift;
    return $self->config->is_api_key_last_stand( $self->reactio->{api_key} );
}

sub create_incident {
    my $self = shift;

    my %param = $self->request->expand_param;
    my $name = $self->request->name
        or die "Could not get name";

    if ( $self->is_last_stand ) {
        $param{notification_text} = $self->request->description;
        $name = $param{notification_text};
    }

    $param{notification_call} = JSON::true;
    $param{topics} ||= [ ];
    push @{ $param{topics} }, $self->config->topic_name;

    my $res_ref = $self->reactio->create_incident( $name, \%param );

    if ( $res_ref->{type} ) { # How can i test wether did request succeed?
        die "Could not create incident: ", $self->dump( $res_ref );
    }

    return $res_ref;
}

sub get_incident_url {
    my $self = shift;
    my $id   = shift;
    my $organization = $self->config->organization;
    return URI->new( "https://$organization.reactio.jp/incident/$id#topic/all" );
}

sub is_topic_open {
    my $self        = shift;
    my $incident_id = shift;

    my $res_ref = eval { $self->reactio->incident( $incident_id ) };

    if ( my $e = $@ ) {
        warn "Could not get incident: $e";
        return 1; # fail safe, i do not want to stop calling on error.
    }

    my $topic = first { $_->{name} eq $self->config->topic_name } @{ $res_ref->{topics} };

    return $topic->{status} ne "close"; # fail safe too, false only when status ne `close`.
}

sub close_topic_if_only_one_incident_exists { die "Reactio API can not close the topic" }

sub keep_calling_while_topic_is_open {
    my $self        = shift;
    my $incident_id = shift;

    my $count;
    my $max_count = $self->config->max_call_count;
    my $interval  = $self->config->interval_seconds;

    while ( $count++ < $max_count && $self->is_topic_open( $incident_id ) ) {
        my $res_ref = eval { $self->reactio->notify_incident( $incident_id, $self->request->name ) };

        if ( my $e = $@ ) {
            warn "Could not notify incident[$incident_id]: $e";
        }

        if ( $res_ref->{type} ) { # Humm, i need is_error field.
            warn $self->dump( $res_ref );
        }

        sleep $interval;
    }

    return;
}

1;
