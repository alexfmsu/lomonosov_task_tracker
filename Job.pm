package Job;

use strict;
use warnings;

use Moose;

has [ 'np', 'queue', 'N', 'mode', 'output', 'path', 'x_file', 'sc_out_dir', 'pc_out_dir'] => (
    is  => 'ro',
    isa => 'Str'
);

has [ 'id', 'task_id'] => (
    is  => 'ro',
    isa => 'Int'
);

has [ 'status'] => (
    is  => 'ro',
    isa => 'Str'
);

sub cmd {
    my $self = shift;

    my $cmd = 'cd ' . $self->{path} . ' && sbatch ';
    $cmd .= '-N ' . $self->{N} . ' ' if defined $self->{N};
    $cmd .= '-n ' . $self->{np} . ' ' if defined $self->{np};
    $cmd .= '-p ' . $self->{queue} . ' ' if defined $self->{queue};
    $cmd .= '--output=' . $self->{output} . ' ' if defined $self->{output};
    $cmd .= $self->{mode} . ' ' if defined $self->{mode};
    $cmd .= $self->{x_file} . ' ' if defined $self->{x_file};

    return $cmd;
}

1;
