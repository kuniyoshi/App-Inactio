use strict;
use warnings;
package App::Inactio::Request::NagiosMail;
use Data::Dumper;
use Path::Class qw( dir );
use MIME::Parser;

sub new {
    my $class        = shift;
    my $data         = shift;
    my $output_under = dir( shift || "/tmp/inactio.request.nagios_mail" );
    $output_under->mkpath;

    my $parser = MIME::Parser->new;
    $parser->output_under( $output_under );

    my $entity = $parser->parse_data( \$data );

    my $body = $entity->body;

    return bless {
        entity => $entity,
    }, $class;
}

sub subject {
    my $self = shift;
    return $self->{subject} ||= $self->{entity}->head->get( "Subject" );
}

sub body {
    my $self = shift;
    return join q{}, @{ $self->{entity}->body };
}

sub is_error {
    my $self = shift;
    return $self->subject !~ m{ \s is \s (?:UP|OK) \s }msx; # fail safe.
}

sub is_recovery { !shift->is_error }

sub project_name {
    my $self = shift;

    if ( $self->subject =~ m{ \s ([^\s/]+) / .+? \s is \s }msx ) {
        my $host = $1;
        return $host;
    }

    die "Could not parse project from: ", $self->subject;
}

sub name {
    my $self = shift;

    if ( $self->subject =~ m{ \s [^\s/]+ / (.+?) \s is \s }msx ) {
        my $service = $1;
        return $service;
    }

    die "Could not parse name from: ", $self->subject;
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
