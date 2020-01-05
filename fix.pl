# -----------
use 5.16.0;

use strict;
use warnings;
# -----------
use utf8;
use DDP;
# -------

# ---------------------------------
use lib '.';

use JobRunner qw(run_jobs);
use Config::Simple;

use SSH;
use Job;
use POSIX ":sys_wait_h";
use Socket;
# ----------------------

# --------------------------------------------------------------
# use IO::Handle;    # thousands of lines just for autoflush :-(
# --------------------------------------------------------------

# ----------------------------------------------------------------------
my $cfg = new Config::Simple('config.ini');

my $login = $cfg->param('name');
my $pass  = $cfg->param('pass');
my $host  = $cfg->param('host');

my $ssh_runner = SSH->new(host => $host, user => $login, pass => $pass);
# ----------------------------------------------------------------------

# -------------------------
$ssh_runner->connect();

$ssh_runner->cd('_scratch/PyQuantum');

my $ls = $ssh_runner->ls();
p $ls;

# say $ls->[0];
exit(0);
my $to_download = 0;

# ---------------------------------------------------------------------------------------------------------------------
# job_folder_id
my $job_folder_id = `ls -d job_* 2>/dev/null | wc -l`;

$job_folder_id++;

my $job_folder = 'job_' . $job_folder_id;

mkdir($job_folder);

say "JOB_FOLDER: ", $job_folder;
# ---------------------------------------------------------------------------------------------------------------------
my $id = 0;

my @jobs;

my $epoch_size = 100;

for my $epoch (0 .. 9) {
    for my $w_0_type ('t0', 's2') {
        for my $dt_click (50, 100, 250, 500) {
            for my $dt (10) {
                my $job = new Job(
                    n          => $epoch_size,
                    queue      => 'test',
                    sc_out_dir => 'T_click_1ms',
                    pc_out_dir => '.',
                    mode       => 'impi',
                    x_file     => '~/software/Python/bin/python3.7 -W ignore' . ' '
                        . 'click2_T_mpi.py' . ' '
                        . "job\_$id\_config.py",

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

run_jobs($ssh_runner, \@jobs, $job_folder, $to_download);

# =====================================================================================================================
# $job->{config} =~ s/^\s+//gm;
# $ssh_runner->exec( 'echo "'
#                         . $job->{config} . '" > '
#                         . 'job_'.$job->{id}
#                         . '_config.py' );

# exit(0);
# =====================================================================================================================
# x_file => '~/software/Python/bin/python3.7 -c \'print(123)\''
# x_file => 'run_test_sc.sh',
# =====================================================================================================================
# EXAMPLE
# my $ls = $ssh_runner->ls();
# p $ls;
# p $ls->[0];
# =====================================================================================================================
# EXAMPLE
# my $rm = $ssh_runner->rm('z_csv');
# =====================================================================================================================
# EXAMPLE
# p $ssh_runner->TEST();
# p $ssh_runner->GPUTEST();
# =====================================================================================================================
# EXAMPLE
# p $ssh_runner->receive_files( '_scratch/main.cpp', 'main.cpp' );
# =====================================================================================================================
# EXAMPLE
# $ssh_runner->cancel_jobs();
# =====================================================================================================================
# STUFF
# my ( $o, $e ) = $ssh_runner->exec('[ -d "dir1" ] && echo "OK"');
# say scalar @$o;
# if (@$o) {
#     say $o->[0];
# }
# p $o;
# p $e;

# my ( $o, $e ) = $ssh_runner->exec('wc -c ~/_scratch/PyQuantum/test_sc.err');
# p $o;
# p $e;
# $o->[0] =~ /^(?<size>\d+)\s+/;
# p $+{size};
# =====================================================================================================================
