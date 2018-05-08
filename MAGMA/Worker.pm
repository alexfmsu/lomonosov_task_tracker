package Worker;

# -----------
use 5.16.0;
use strict;
use warnings;
# -----------
use utf8;
use DDP;
# ----------------------
use POSIX ":sys_wait_h";
use Socket;
# -----------------------------------
use lib '.';

use SSH;

use Term::ANSIColor qw(:constants);

require "sys/ioctl.ph";

sub new{
	my ($self, %params) = @_;

	return bless \%params, $self; 
}

# -------------------------------------------------------------
sub cancel_jobs {
	my $self = shift;

    $self->{ssh_runner}->{break_loop} = 1;

    $self->{ssh_runner}->CANCEL();

    print BOLD, GREEN, "\n\nAll tasks are canceled\n\n", RESET;

    $self->{ssh_runner}->disconnect();

    exit(0);
}
# -------------------------------------------------------------

sub run {
	my $self = shift;

	my $cfg = $self->{cfg};
		
	p $self->{cfg};

	my $login = $cfg->param('name');
	my $pass  = $cfg->param('pass');
	my $host  = $cfg->param('host');
	
	my $ssh_runner = SSH->new(host => $host, user => $login, pass => $pass) or die $!;
	$self->{ssh_runner} = $ssh_runner;

	$ssh_runner->connect() or die $!;

	socketpair(my $CHILD, my $PARENT, AF_UNIX, SOCK_STREAM, PF_UNSPEC) || die "socketpair: $!";

    $PARENT->autoflush(1);
    $CHILD->autoflush(1);

    $| = 1;

    if (my $pid = fork()) {
        close($PARENT);

        $SIG{INT} = $self->\&cancel_jobs;

        my $json = JSON::XS->new();

        for my $job (@{$self->{jobs}}) {
            while (1) {
                if (scalar @{ $ssh_runner->MY() } < $self->{max_jobs} + 1) {
                	p $job;
                    my $task_id = $ssh_runner->sbatch($job);

                    $job->{task_id} = $task_id;
                    $job->{status}  = $ssh_runner->task_status($task_id);

                    print $CHILD $json->encode(
                        {
                            id      => $job->{id},
                            task_id => $job->{task_id},
                            status  => $job->{status}
                        }
                    ) . "\n";

                    last;
                }
            }
            # p $job;
        }

        waitpid(-1, 0);
    }
    else {
        close($CHILD);

		my $ssh_waiter = SSH->new(host => $host, user => $login, pass => $pass);

        $ssh_waiter->connect();

        $ssh_waiter->cd('_scratch/MAGMA');

        my $json = JSON::XS->new();

        while (1) {
            $ssh_waiter->{finished} = 1;

            my $size = pack("L", 0);
            ioctl($PARENT, &FIONREAD, $size) or die "Couldn't call ioctl: $!\n";
            $size = unpack("L", $size);

            if ($size != 0) {
                sysread($PARENT, my $data, $size);

                for my $line (split /\n/, $data) {
                    my $h = $json->decode($line);

                    for my $job (@{$self->{jobs}}) {
                        if ($job->{id} == $h->{id}) {
                            $job->{task_id} = $h->{task_id};
                            $job->{status}  = $h->{status};

                            $ssh_waiter->add_task($job);
                        }
                    }
                }
            }

            for my $job (@{$self->{jobs}}) {
                if ($job->{status} ne 'done') {
                    $ssh_waiter->{finished} = 0;
                }

                if ($job->{task_id} != -1) {
                    my $task_id     = $job->{task_id};
                    my $task_status = $ssh_waiter->task_status($task_id);

                    if ($job->{status} ne 'done') {
                        if (defined $task_status) {
                            $job->{status} = $task_status;
                        }
                        else {

                            p $job->{pc_out_dir};
                            $ssh_waiter->receive_files($job->{sc_out_dir}, $job->{pc_out_dir});
                            $job->{status} = 'done';
                        }
                    }
                }
            }

            $ssh_waiter->print_tasks();

            last if $ssh_waiter->{finished};

            sleep($self->{TIMEOUT});
        }

        exit(0);
    }
}


1;