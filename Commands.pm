use 5.16.0;

use strict;
use warnings;

use utf8;

sub cmd {
    # -------------------------------------
    # NOT DONE
    # -------------------------------------
    # RETURN TYPE:
    # -------------------------------------
    # EXAMPLE:
    # -------------------------------------
    my ($self, $cmd) = @_;

    $self->{ssh}->blocking(1);
    $self->{chan} = $self->{ssh}->channel;

    $self->{chan}->exec($cmd);

    $self->readlines();

    # $self->{ssh}->blocking(1);
}

sub cd {
    # -------------------------------------
    # NOT DONE
    # -------------------------------------
    # RETURN TYPE:
    # -------------------------------------
    # EXAMPLE:
    # -------------------------------------
    my ($self, $path) = @_;

    my ($o, $e) = $self->exec("cd $path && pwd");

    return $e->[0] if @$e;

    $self->{path} = $o->[0];

    undef;
}

sub ls($) {
    # -------------------------------------
    # NOT DONE
    # -------------------------------------
    # RETURN TYPE: \ []
    # -------------------------------------
    # EXAMPLE:
    #
    # my $ls = $ssh_runner->ls();
    # p $ls;
    # say $ls->[0];
    # -------------------------------------
    my $self = shift;

    my ($o, $e) = $self->exec('ls');    # ?

    return join('\n', @$e) if @$e;

    return $o;
}

sub rm {
    my ($self, $file) = @_;

    my ($o, $e) = $self->exec("rm $file");

    return $e->[0] if @$e;

    undef;
}

1;
