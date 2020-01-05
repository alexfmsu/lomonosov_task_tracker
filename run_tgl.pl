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
my $SC_ROOTDIR = $cfg->param('rootdir');

my $ssh_runner = SSH->new(host => $host, user => $login, pass => $pass);
# ----------------------------------------------------------------------

# -------------------------
$ssh_runner->connect();

$ssh_runner->cd($SC_ROOTDIR);

my $ls = $ssh_runner->ls();
# p $ls;

# say $ls->[0];
# exit(0);
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

# my $epoch_size = 100;

for my $dt (0.1, 0.01) {
    for my $sink_limit (0.9, 0.95, 0.99) {
        for my $g ([ 0.01, 0.51 ], [ 0.51, 1.01 ]) {
            # for my $dt_click (50, 100, 250, 500) {
            # for my $dt (10) {
            # print($g->[0], $g->[1]);
            my $job = new Job(
                n          => 100,
                queue      => 'test',
                sc_out_dir => 'out/mix',
                pc_out_dir => '.',
                mode       => 'impi',
                x_file     => '~/software/Python/bin/python3.7 -W ignore' . ' '
                    . 'mix_g_l_partial.py' . ' '
                    . "job\_$id\_config.py",

                path    => $SC_ROOTDIR,
                status  => 'None',
                id      => $id,
                task_id => -1,
                config  => qq(
                        # ---------------------------------------------------------------------------------------------------------------------
                        # PyQuantum.Constants
                        import PyQuantum.Constants as Constants
                        # ---------------------------------------------------------------------------------------------------------------------

                        capacity = 2

                        n_atoms = 2

                        wc = Constants.wc
                        wa = Constants.wc

                        g_0 = $g->[0]
                        g_step = 0.01
                        g_1 = $g->[1]

                        l_0 = 0.01
                        l_1 = 1.0
                        l_step = 0.01

                        dt = $dt * Constants.ns

                        sink_limit = $sink_limit

                        sink_precision = 1e-4
                        ampl_precision = 1e-3
                        path = 'out/mix'
                    )
            );

            $id++;

            push @jobs, $job;
            # }
        }
    }
}

for (@jobs){
    $_->print();
}
# print(@jobs);
# run_jobs($ssh_runner, \@jobs, $job_folder, $to_download);
