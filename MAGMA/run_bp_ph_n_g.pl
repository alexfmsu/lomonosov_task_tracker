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
use constant SECTION  => 'Bipartite_ph_n_g';
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

my $ssh_runner = SSH->new(host => $host, user => $login, pass => $pass);

# p $ssh_runner;
# ---------------------------------------------------------

# -------------------------------------------------------------
sub cancel_jobs {
    $ssh_runner->{break_loop} = 1;

    $ssh_runner->CANCEL();

    print BOLD, GREEN, "\n\nAll tasks are canceled\n\n", RESET;

    $ssh_runner->disconnect();

    exit(0);
}
# -------------------------------------------------------------

# -------------------------
$ssh_runner->connect();

$ssh_runner->CANCEL();

$ssh_runner->cd('_scratch/MAGMA');

# p $ssh_runner->exec('pwd');

# p $ssh_runner->exec('make compile_bp_n_g');
# ---------------------------------------

my @jobs;

my $id = 0;

my $mks = 1e-6;
my $RWA = 1e-2;

# my @n = (10 .. 50);
my @n = grep { $_ % 10 == 0 } 30 .. 30;

my @wc = (21.506);    # MHz
my @wa = (21.506);    # MHz

my @g = map {$_ / 50 } 1..50;    # MHz

my @T = (1);              # mks

my @nt = (20000);

my $out         = 'out';
my $out_pc_root = '/home/alexfmsu/Quant/C++/' . SECTION . '/' . $out;

for my $n (@n) {
    for my $capacity ( grep { $_ % 5 == 0 } 80 .. $n+100 ) {
    # for my $capacity ( grep { $_ % 5 == 0 } $n .. $n+100 ) {
        for my $wc (@wc) {
            for my $wa (@wa) {
                for my $g (@g) {
                    for my $T (@T) {
                        print $g;

                        my $config_path = './config';

                        # my $out_path = "$capacity\_$n\_$g";
                        my $out_path = "$n/$capacity\_$g";

                        my $nt = '20000';

                        my $init_state = '[' . 0 . ', ' . $n . ']';

                        my $config_filename = "$n\_$capacity\_$g";

                        my $conf = Config::BipartiteNConfig->new(
                            capacity => $capacity,
                            n        => $n,
                            wc       => $wc . ' * GHz',
                            wa       => $wa . ' * GHz',
                            g        => ($g * 21.506 * 1e-2) . ' * GHz',
                            T        => $T . ' * mks',
                            # dt       => $dt,
                            nt         => int($T * $nt),
                            dt         => 'T / ' . int($T * $nt),
                            init_state => $init_state,
                            precision  => 50,
                            path => '"' . SECTION . '/' . $out . '/' . $out_path . '/"'
                        );
                        print($config_path . "/" . $config_filename);
                        $conf->write_to_file($config_path . "/" . $config_filename);

                        $ssh_runner->send_files($config_path . "/" . $config_filename, SECTION . '/Config/' . $out_path . '/' . $config_filename);

                        my $job = new Job(
                            N      => 1,
                            queue  => 'gputest',
                            output => 'bp_n_g.out',
                            sc_out_dir => SECTION . '/' . $out . '/' . $out_path . '/',
                            pc_out_dir => $out_pc_root . '/' . $out_path,
                            mode       => 'run',
                            x_file     => 'bin/bp_n_g.x ' . SECTION . '/' . 'Config' . '/' . $out_path . '/' . $config_filename,
                            path       => "_scratch/MAGMA/",
                            status     => 'None',
                            id         => $id++,
                            task_id    => -1
                        );

                        `rm -r $job->{pc_out_dir} 2>/dev/null || true`;

                        push @jobs, $job;
                    }
                }
            }
        }
    }
}

socketpair(my $CHILD, my $PARENT, AF_UNIX, SOCK_STREAM, PF_UNSPEC) || die "socketpair: $!";

$PARENT->autoflush(1);
$CHILD->autoflush(1);

$| = 1;

if (my $pid = fork()) {
    close($PARENT);

    $SIG{INT} = \&cancel_jobs;

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
