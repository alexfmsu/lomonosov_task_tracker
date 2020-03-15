package Job;

use 5.16.0;
use strict;
use warnings;

use DDP;

use Moose;

has [
    'N',    'n',      'queue', 'output', 'error',
    'mode', 'x_file', 'path',  'sc_out_dir',
    'pc_out_dir'
] => (
    is  => 'ro',
    isa => 'Str'
);

has [ 'id', 'task_id' ] => (
    is  => 'ro',
    isa => 'Int'
);

has ['status', 'config'] => (
    is  => 'ro',
    isa => 'Str',
);

sub sbatch {
    my $self = shift;

    unless(defined $self->{output}){
        $self->{output} = $self->{id} . '.out';
    }

    unless(defined $self->{error}){
        $self->{error} = $self->{id} . '.err';
    }

    my $cmd = 'cd ' . $self->{path} . ' && sbatch ';
    $cmd .= '-N ' . $self->{N} . ' '            if defined $self->{N};
    $cmd .= '-n ' . $self->{n} . ' '            if defined $self->{n};
    $cmd .= '-p ' . $self->{queue} . ' '        if defined $self->{queue};
    $cmd .= '--output=' . $self->{output} . ' ';
    $cmd .= '--error=' . $self->{error} . ' ';
    $cmd .= $self->{mode} . ' '                 if defined $self->{mode};
    $cmd .= $self->{x_file} . ' '        if defined $self->{x_file};

    say $cmd;

    return $cmd;
}

sub print{
    my $self = shift;
    
    p $self;
}

1;
