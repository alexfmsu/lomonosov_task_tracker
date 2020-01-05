# -----------
use 5.16.0;
use strict;
use warnings;

# -----------
use utf8;
use DDP;

# ---------------------------------
use JSON::XS;

# use Term::ANSIColor qw(:constants);

# ---------------------------------
use lib '.';

use Config::Simple;

# use Config::BipartiteNConfig;

use SSH;
use Job;

# ----------------------
use POSIX ":sys_wait_h";
use Socket;

# -----------------------------------
# use constant SECTION  => 'Bipartite_n_g';
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

# $ssh_runner->cancel_jobs();
# exit(0);
# $ssh_runner->cd('_scratch/MAGMA');
$ssh_runner->cd('_scratch/PyQuantum');

# my ($o, $e) = $ssh_runner->exec('[ -d "dir1" ] && echo "OK"');
# say scalar @$o;
# if(@$o){
#     say $o->[0];
# }
# p $o;
# p $e;
# exit(0);
# my ($o, $e) = $ssh_runner->exec('wc -c ~/_scratch/PyQuantum/test_sc.err');
# p $o;
# p $e;
# $o->[0] =~ /^(?<size>\d+)\s+/;
# p $+{size};

# exit(0);
# for(1..10){
# p $ssh_runner->ls();

# }
# p $ssh_runner->TEST();
# p $ssh_runner->GPUTEST();

# p $ssh_runner->receive_files('_scratch/main.cpp', 'main.cpp');

# exit(0);
my $to_download = 0;

# -------------------------------------------------------------------------------------------------
# job_folder_id
my $job_folder_id = `ls -d job_* 2>/dev/null | wc -l`;

$job_folder_id++;

my $job_folder = 'job_' . $job_folder_id;

mkdir($job_folder);

say "JOB_FOLDER: ", $job_folder;

# -------------------------------------------------------------------------------------------------

my $id = 0;

my @jobs;

my $epoch_size = 100;

for my $epoch ( 0 .. 9 ) {
    for my $w_0_type ( 't0', 's2' ) {
        for my $dt_click ( 50, 100, 250, 500 ) {
            for my $dt (10) {
                my $job = new Job(
                    n          => $epoch_size,
                    queue      => 'test',
                    output     => $id.'.out',
                    error      => $id.'.err',
                    sc_out_dir => 'T_click_1ms',
                    pc_out_dir => '.',
                    mode       => 'impi',
                    x_file     => '~/software/Python/bin/python3.7 -W ignore'
                        . ' '
                        . 'click2_T_mpi.py' . ' '
                        . "job\_$id\_config.py",

          # x_file     => '~/software/Python/bin/python3.7 -c \'print(123)\'',
          # x_file     => 'run_test_sc.sh',

                    # x_file     => 'test.py',
                    path    => "_scratch/PyQuantum",
                    status  => 'None',
                    id      => $id,
                    task_id => -1,
                    config  => qq(
            import PyQuantum.TC_Lindblad.config as config

            T = 1 * config.ms
            dt = $dt * config.ns
            
            # nt_batch = 20
            
            lg = 0.01
            lg_str = 'l001g'
            
            dt_click = $dt_click
            dt_click_str = '${dt_click}ns'
            
            out_path = 'T_click_1ms'
            
            precision = 1e-3
            sink_limit = 1
            thres = 0.001
            
            epoch = $epoch
            epoch_size = $epoch_size
            
            # w_0_type = ['t0', 's2']
            w_0_type = ['$w_0_type']
        ),
                );

                $id++;

                push @jobs, $job;
            }
        }
    }
}

# $job->{config} =~ s/^\s+//gm;
# $ssh_runner->exec( 'echo "'
#                         . $job->{config} . '" > '
#                         . 'job_'.$job->{id}
#                         . '_config.py' );

# exit(0);

# exit(0);
socketpair( my $CHILD, my $PARENT, AF_UNIX, SOCK_STREAM, PF_UNSPEC )
    || die "socketpair: $!";

$PARENT->autoflush(1);
$CHILD->autoflush(1);

$| = 1;

if ( my $pid = fork() ) {
    close($PARENT);

    $SIG{INT} = sub {
        $ssh_runner->cancel_jobs();
    };

    my $json = JSON::XS->new();

    for my $job (@jobs) {
        while (1) {
            if ( scalar @{ $ssh_runner->MY() } < MAX_JOBS + 1 ) {

                # $ssh_runner->exec('echo ' . $config.);
                # add job to queue
                $job->{config} =~ s/^\s+//gm;

                # say $job->{config};

                $ssh_runner->exec( 'echo "'
                        . $job->{config} . '" > ' . 'job_'
                        . $job->{id}
                        . '_config.py' );

                $job->{task_id} = $ssh_runner->sbatch($job);

                $job->{status} = $ssh_runner->task_status( $job->{task_id} );
                my $job_info = $ssh_runner->task_info( $job->{task_id} );

                # p $job->{status};

                print $CHILD $json->encode(
                    {   id      => $job->{id},
                        task_id => $job->{task_id},
                        status  => $job_info->{status},
                        cpus    => $job_info->{cpus},
                        node    => $job_info->{node},
                        time    => $job_info->{time},
                    }
                ) . "\n";

                last;
            }
        }
    }

    waitpid( -1, 0 );
}
else {
    close($CHILD);

    my $ssh_waiter = SSH->new( host => $host, user => $login, pass => $pass );

    $ssh_waiter->connect();

    $ssh_waiter->cd('_scratch/PyQuantum');

    my $json = JSON::XS->new();

    while (1) {
        $ssh_waiter->{finished} = 1;

        my $size = pack( "L", 0 );
        ioctl( $PARENT, &FIONREAD, $size ) or die "Couldn't call ioctl: $!\n";
        $size = unpack( "L", $size );

        if ( $size != 0 ) {
            sysread( $PARENT, my $data, $size );

            for my $line ( split /\n/, $data ) {
                my $h = $json->decode($line);

                for my $job (@jobs) {
                    if ( $job->{id} == $h->{id} ) {
                        $job->{task_id} = $h->{task_id};
                        $job->{status}  = $h->{status};
                        $job->{cpus}    = $h->{cpus};
                        $job->{node}    = $h->{node};
                        $job->{time}    = $h->{time};

                        # p $job;

                        $ssh_waiter->add_task($job);
                    }
                }
            }
        }

        for my $job (@jobs) {
            if ( $job->{status} ne 'done' && $job->{status} ne 'fail' ) {
                $ssh_waiter->{finished} = 0;
            }

            if ( $job->{task_id} != -1 ) {
                my $task_id = $job->{task_id};

                # my $job_info = $ssh_runner->task_info( $job->{task_id} );
                # my $task_status = $ssh_waiter->task_status($task_id);

                # p $job;
                my $job_info = $ssh_waiter->task_info( $job->{task_id} );

                if ( $job->{status} ne 'done' && $job->{status} ne 'fail' ) {
                    if ( defined $job_info->{status} ) {
                        $job->{status} = $job_info->{status};
                        $job->{time}   = $job_info->{time};
                    }
                    else {
   # -------------------------------------------------------------------------
   # download output
                        $ssh_waiter->receive_files( $job->{output},
                            $job_folder . '/' . $job->{task_id} . '.out' );

                        $ssh_waiter->exec( 'rm ' . $job->{output} );

   # -------------------------------------------------------------------------

   # -------------------------------------------------------------------------
   # download error
                        my ( $o, $e )
                            = $ssh_waiter->cmd(
                            'wc -c ' . $job->{path} . '/' . $job->{error} );

                        $o->[0] =~ /^(?<size>\d+)\s+/;

                        if ( $+{size} == 0 ) {

                            # say "OK";
                            if ($to_download) {
                                $ssh_waiter->receive_files(
                                    $job->{sc_out_dir},
                                    $job_folder . '/' . $job->{pc_out_dir} );
                            }
                            $job->{status} = 'done';
                        }
                        else {
                            $ssh_waiter->receive_files( $job->{error},
                                      $job_folder . '/'
                                    . $job->{task_id}
                                    . '.err' );
                            $job->{status} = 'fail';
                        }

                        $ssh_waiter->exec( 'rm ' . $job->{error} );
                        $ssh_waiter->exec(
                            'rm ' . 'job_' . $job->{id} . '_config.py' );

   # -------------------------------------------------------------------------

                        # p $job->{pc_out_dir};

                        # say '~/_scratch/' . $job->{output};

         # $ssh_waiter->receive_files($job->{sc_out_dir}, $job->{pc_out_dir});
         # $job->{status} = 'done';
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
