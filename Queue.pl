use 5.16.0;

use strict;
use warnings;
use utf8;

sub TEST {
    my $self = shift;

    my ($o, $e) = $self->cmd('squeue -p test');

    return $o;
}

sub GPUTEST {
    my $self = shift;

    my ($o, $e) = $self->cmd('squeue -p gputest');

    return $o;
}

sub REGULAR4 {
    my $self = shift;

    my ($o, $e) = $self->cmd('squeue -p regular4');

    return $o;
}

sub REGULAR6 {
    my $self = shift;

    my ($o, $e) = $self->cmd('squeue -p regular6');

    return $o;
}

sub MY {
    my $self = shift;

    my ($o, $e) = $self->cmd('squeue -u $USER');

    return $o;
}

sub CANCEL {
    my $self = shift;

    my ($o, $e) = $self->cmd('scancel -u $USER');

    return $o;
}

1;
