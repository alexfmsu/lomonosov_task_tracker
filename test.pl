# -----------
use 5.16.0;
use strict;
use warnings;

# -----------
use utf8;
use DDP;

# ---------------------------------
use JSON::XS;
use Term::ANSIColor qw(:constants);

# ---------------------------------
use lib '.';

use Config::Simple;

use Config::BipartiteNConfig;

use SSH;
use Job;

# ----------------------
use POSIX ":sys_wait_h";
use Socket;

# -----------------------------------
use constant SECTION  => 'Bipartite_n_g';
use constant MAX_JOBS => 3;
use constant TIMEOUT  => 3;

# -------------------------
require "sys/ioctl.ph";

# -------------------------
# use IO::Handle;    # thousands of lines just for autoflush :-(
# ----------------------------------

# ---------------------------------------------------------
my $cfg = new Config::Simple('config.ini');

my $login = $cfg->param('name');
my $pass  = $cfg->param('pass');
my $host  = $cfg->param('host');

my $ssh_runner = SSH->new( host => $host, user => $login, pass => $pass );

# ---------------------------------------------------------


# -------------------------
$ssh_runner->connect();

$ssh_runner->CANCEL();

# $ssh_runner->cd('_scratch/MAGMA');

p $ssh_runner->ls();
p $ssh_runner->TEST();
p $ssh_runner->GPUTEST();

p $ssh_runner->receive_files('_scratch/test.py', 'test.py');

exit(0);

my $id = 0;

my @jobs;
my $job = new Job(
    N          => 1,
    queue      => 'test',
    output     => 'test.out',
    sc_out_dir => '_scratch',
    pc_out_dir => '.',
    mode       => 'run',
    x_file     => 'test.py',
    path    => "_scratch",
    status  => 'None',
    id      => $id++,
    task_id => -1
);

push @jobs, $job;

socketpair(my $CHILD, my $PARENT, AF_UNIX, SOCK_STREAM, PF_UNSPEC) || die "socketpair: $!";

$PARENT->autoflush(1);
$CHILD->autoflush(1);

$| = 1;

if (my $pid = fork()) {
    close($PARENT);

    # $SIG{INT} = \&cancel_jobs;
    $SIG{INT} = $ssh_runner->cancel_jobs();

    my $json = JSON::XS->new();

    for my $job (@jobs) {
        while (1) {
            if (scalar @{ $ssh_runner->MY() } < MAX_JOBS + 1) {
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

                for my $job (@jobs) {
                    if ($job->{id} == $h->{id}) {
                        $job->{task_id} = $h->{task_id};
                        $job->{status}  = $h->{status};

                        $ssh_waiter->add_task($job);
                    }
                }
            }
        }

        for my $job (@jobs) {
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

        sleep(TIMEOUT);
    }

    exit(0);
}
