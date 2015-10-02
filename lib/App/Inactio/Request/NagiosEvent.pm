use strict;
use warnings;
package App::Inactio::Request::NagiosEvent;
use parent "App::Inactio::Request";
use Data::Dumper;

sub hostname { shift->{hostname} }

sub service_desc { shift->{service_desc} }

sub service_state { shift->{service_state} }

sub service_state_type { shift->{service_state_type} }

sub new {
    my $class = shift;
    my %param = @_;

    return bless \%param, $class;
}

sub is_error {
    my $self = shift;
    return $self->service_state eq "critical" && $self->service_state_type eq "hard";
}

sub is_recovery { shift->service_state eq "ok" }

sub project_name { shift->hostname }

sub name { shift->service_desc }

sub description {
    my $self = shift;
    return $self->name . " of " . $self->project_name;
}

sub expand_param {
    my $self = shift;
    my %param;

    $param{description}       = "system";
    $param{scale}             = "whole";
    $param{notification_text} = $self->name;

    return %param;
}

1;
