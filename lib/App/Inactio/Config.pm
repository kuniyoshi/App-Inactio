use strict;
use warnings;
package App::Inactio::Config;
use Carp ( );
use Readonly;

Readonly my %DEFAULT => (
    topic_name       => "close this at you start responding",
    max_call_count   => 30,
    interval_seconds => 60,
);
Readonly my $LAST_STAND_SERVICE_NAME => "last_stand";

sub new {
    my $class    = shift;
    my $filename = shift
        or Carp::croak( "filename required" );

    my $config_ref = do $filename;

    if ( my $e = $@ ) {
        die "Could not parse config[$filename]: $e";
    }
    elsif ( !defined $config_ref ) {
        die "Could not read config[$filename]: $!";
    }

    return bless {
        config => $config_ref,
    }, $class;
}

sub is_api_key_last_stand {
    my $self    = shift;
    my $api_key = shift;
    return $api_key eq $self->{config}{project}{ $LAST_STAND_SERVICE_NAME }{api_key};
}

sub get_api_key {
    my $self         = shift;
    my $project_name = shift;
    my $api_key = $self->{config}{project}{ $project_name }{api_key} || $self->{config}{project}{ $LAST_STAND_SERVICE_NAME }{api_key}
        or die "Could not get api_key of $project_name";
    return $api_key;
}

sub organization { shift->{config}{organization} or die "Could not get organization" }

sub topic_name { shift->{config}{topic_name} || $DEFAULT{topic_name} }

sub max_call_count { shift->{config}{max_call_count} || $DEFAULT{max_call_count} }

sub interval_seconds { shift->{config}{interval_seconds} || $DEFAULT{interval_seconds} }

1;
