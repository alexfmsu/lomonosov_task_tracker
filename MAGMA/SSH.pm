package SSH;

use 5.16.0;
use strict;
use warnings;
use utf8;
use DDP;

use Net::SSH2;
use Net::SFTP::Foreign;
use Term::ANSIColor;

use lib '.';

use Commands;

no warnings "experimental";

our %timeout = (
    regular4 => 10,
    regular6 => 10,
    test     => 3
);

sub new {
    my ( $class, %params ) = @_;

    $params{jobs}       = [];
    $params{break_loop} = 0;

    return bless \%params, $class;
}

sub connect {
    my $self = shift;

    $self->{ssh} = Net::SSH2->new();

    $self->{ssh}->connect( $self->{host} );

    $self->{ssh}->auth_agent( $self->{user} ) or say "Cannot connect: " . $!;

    my ( $o, $e ) = $self->cmd('echo $HOME');
    $self->{path} = $o->[0];

    # ---------------------
    $self->{sftp} = Net::SFTP::Foreign->new(
        host       => $self->{user} . '@' . $self->{host},
        passphrase => $self->{passphrase},
        key_path   => "/home/alexfmsu/lomonosov/lomonosov_1.ppk"
    ) or die $!;
}

sub readlines {
    my ( $self, $chan ) = @_;

    my @poll = {
        handle => $self->{chan},
        events => [qw/in err/],
    };

    my ( $stdout, $stderr ) = ( '', '' );

    my ( @out, @err );

    while (1) {
        $self->{ssh}->poll( 250, \@poll );

        while ( my $stdout = $self->{chan}->readline(0) ) {
            push @out, $stdout;
        }

        while ( $stderr = $self->{chan}->readline(1) ) {
            push @err, $stderr;
        }

        last if $self->{chan}->eof;
    }

    # if (@err) {
    #     p @err;

    #     print color('bold red');
    #     die "Commanf error";
    #     print color('reset');
    # }

    return ( \@out, \@err );
}

sub disconnect {
    my $self = shift;

    $self->{chan}->send_eof();
    $self->{chan}->close;
}

sub readlines2 {
    my $self = shift;

    my ( $stdout, $stderr ) = ( '', '' );
    my @out;
    my @err;

    my @poll = {
        handle => $self->{chan},
        events => [qw/in err/],
    };

    while (1) {
        $self->{ssh}->poll( 250, \@poll );

        while ( $self->{chan}->read( my $chunk, 80 ) ) {
            $stdout .= $chunk;
        }

        while ( $stdout =~ s/^(.*)\n// ) {
            push @out, $1;
        }

        while ( $self->{chan}->read( my $chunk, 80, 1 ) ) {
            $stderr .= $chunk;
        }

        while ( $stderr =~ s/^(.*)\n// ) {
            push @err, $1;

            # print "STDERR: [$1]\n";
        }

        last if $self->{chan}->eof;
    }

    # if (@err) {
    #     print "Error: ", $err[0];

    #     print color('bold red');
    #     die "Commanf error";
    #     print color('reset');
    # }

    return ( \@out, \@err );
}

sub TEST {
    my $self = shift;

    my ($o, $e) = $self->cmd('squeue -p test');

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

sub TASKS {
    my $self = shift;

    my $my = $self->MY();

    my @tasks = ();

    for my $i ( 1 .. scalar @$my - 1 ) {
        my $task = $my->[$i];

        if ($task =~ m{
            ^
            (?<id>\d+)
            \s+
            (?<queue>[\d\w]+)
            \s+
            (?<mode>[\d\w]+)
            \s+
            (?<user>[\d\w]+)
            \s+
            (?<status>[\d\w]+)
            }x
            )
        {
            push @tasks, { id => $+{id}, status => $+{status} };
        }
    }

    return \@tasks;
}

sub sbatch_cmd {
    my ( $self, %args ) = @_;

    $self->{queue} = $args{squeue};

    my $cmd
        = "cd "
        . $self->{path} . " && "
        . 'sbatch -n '
        . $args{n} . ' -p '
        . $args{squeue} . ' '
        . '--output='
        . $args{output} . ' '
        . $args{mode} . ' '
        . $args{x_file};

    return $cmd;
}

sub sbatch {
    my ( $self, $job ) = @_;

    $self->{queue} = $job->{queue};

    # my $cmd
    #     = "cd "
    #     . $self->{path} . " && "
    #     . 'sbatch -n '
    #     . $args{n} . ' -p '
    #     . $args{squeue} . ' '
    #     . '--output='
    #     . $args{output} . ' '
    #     . $args{mode} . ' '
    #     . $args{x_file};

    say $job->cmd() . "\n";

    my ($o, $e) = $self->cmd( $job->cmd() );

    for (@$o) {
        if (/^Submitted\sbatch\sjob\s(\d+)$/) {
            return $1;
        }
    }

    print color('bold red');
    die "Cannot submit task\n";
    print color('reset');
}

sub exec {
    my ( $self, $cmd ) = @_;

    $cmd = "cd " . $self->{path} . " && " . $cmd;

    return $self->cmd($cmd);
}

$SIG{ALRM} = sub { };

sub task_exist {
    my ( $self, $task_id ) = @_;

    for ( @{ $self->TASKS() } ) {
        if ( $task_id == $_->{id} ) {
            return 1;
        }
    }

    return 0;
}

sub task_status {
    my ( $self, $task_id ) = @_;

    for ( @{ $self->TASKS() } ) {
        if ( $task_id == $_->{id} ) {
            return $_->{status};
        }
    }

    # warn "No such task\n";

    undef;
}

sub wait_task {
    my ( $self, $job ) = @_;

    $| = 1;

    my $dots = 0;

    my $task_id = $job->{task_id};

    while ( $self->task_exist($task_id) ) {
        for ( 0 .. $timeout{ $job->{queue} } ) {
            alarm(1);
            sleep(1);

            my $task_status = $self->task_status($task_id);

            unless ( defined $task_status ) {
                say "";

                return;
            }

            print "\r\e[Kwait $task_id "
                . '.' x ( $dots + 1 ) . " "
                . ( $self->task_status($task_id) or "done" );

            $dots = ( $dots + 1 ) % 3;

            alarm(0);
        }

        last if $self->{break_loop};
    }

    say "";
}

sub add_task($$) {
    my ( $self, $job ) = @_;

    push @{ $self->{jobs} }, $job;

    # p $self->{jobs};
}

sub print_tasks($) {
    my $self = shift;

    for my $job ( @{ $self->{jobs} } ) {
        if ( $job->{task_id} != -1 ) {
            say "\t", $job->{id}, ' ', $job->{task_id}, ' ', $job->{status}, $job->{pc_out_dir};
        }
    }

    say '';
}

sub receive_files {
    my ( $self, $from_path, $to_path ) = @_;

    $to_path ||= $from_path;

    $self->{sftp}->rget( $self->{path} . "/" . $from_path, $to_path )
        or do {
        print color('bold red');

        die "Error: NOTHING TO RECEIVE\n";
        print color('reset');
        };
}

sub send_files {
    my ( $self, $from_path, $to_path ) = @_;

    $self->{sftp}->rput( $from_path, $self->{path} . "/" . $to_path )
        or say "File $from_path not found" . $!;
}

1;
