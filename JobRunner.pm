package JobRunner;

use 5.16.0;
use strict;
use warnings;

use JSON::XS;
use Socket;
use Exporter;

use constant MAX_JOBS => 3;
use constant TIMEOUT  => 3;


our @ISA = qw(Exporter);

our @EXPORT_OK = qw(run_jobs);

require "sys/ioctl.ph";

sub run_jobs {
    my ( $ssh_runner, $jobs, $job_folder, $to_download ) = @_;

    say scalar @$jobs;

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

        for my $job (@$jobs) {
            while (1) {
                if ( scalar @{ $ssh_runner->MY() } < MAX_JOBS + 1 ) {

                    # add job to queue
                    $job->{config} =~ s/^\s+//gm;

                    $ssh_runner->exec( 'echo "'
                            . $job->{config} . '" > ' . 'job_'
                            . $job->{id}
                            . '_config.py' );

                    $job->{task_id} = $ssh_runner->sbatch($job);

                    # $job->{status}
                    #     = $ssh_runner->task_status( $job->{task_id} );
                    my $job_info = $ssh_runner->task_info( $job->{task_id} );

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

        my $ssh_waiter
            = SSH->new( host => $ssh_runner->{host}, user => $ssh_runner->{user}, pass => $ssh_runner->{pass} );

        $ssh_waiter->connect();

        $ssh_waiter->cd('_scratch/PyQuantum');

        my $json = JSON::XS->new();

        while (1) {
            $ssh_waiter->{finished} = 1;

            my $size = pack( "L", 0 );
            
            ioctl( $PARENT, &FIONREAD, $size )
                or die "Couldn't call ioctl: $!\n";
            
            $size = unpack( "L", $size );

            if ( $size != 0 ) {
                sysread( $PARENT, my $data, $size );

                for my $line ( split /\n/, $data ) {
                    my $h = $json->decode($line);

                    for my $job (@$jobs) {
                        if ( $job->{id} == $h->{id} ) {
                            $job->{task_id} = $h->{task_id};
                            $job->{status}  = $h->{status};
                            $job->{cpus}    = $h->{cpus};
                            $job->{node}    = $h->{node};
                            $job->{time}    = $h->{time};

                            $ssh_waiter->add_task($job);
                        }
                    }
                }
            }

            for my $job (@$jobs) {
                if ( $job->{status} ne 'done' && $job->{status} ne 'fail' ) {
                    $ssh_waiter->{finished} = 0;
                }

                if ( $job->{task_id} != -1 ) {
                    my $task_id = $job->{task_id};

                   # my $job_info = $ssh_runner->task_info( $job->{task_id} );
                   # my $task_status = $ssh_waiter->task_status($task_id);

                    my $job_info = $ssh_waiter->task_info( $job->{task_id} );

                    if (   $job->{status} ne 'done'
                        && $job->{status} ne 'fail' )
                    {
                        if ( defined $job_info->{status} ) {
                            $job->{status} = $job_info->{status};
                            $job->{time}   = $job_info->{time};
                        }
                        else {
   # -------------------------------------------------------------------------
   # download output
                            $ssh_waiter->receive_files( $job->{output},
                                      $job_folder . '/'
                                    . $job->{task_id}
                                    . '.out' );

                            $ssh_waiter->exec( 'rm ' . $job->{output} );

   # -------------------------------------------------------------------------

   # -------------------------------------------------------------------------
   # download error
                            my ( $o, $e )
                                = $ssh_waiter->cmd( 'wc -c '
                                    . $job->{path} . '/'
                                    . $job->{error} );

                            $o->[0] =~ /^(?<size>\d+)\s+/;

                            if ( $+{size} == 0 ) {

                                # say "OK";
                                if ($to_download) {
                                    $ssh_waiter->receive_files(
                                        $job->{sc_out_dir},
                                        $job_folder . '/' . $job->{pc_out_dir}
                                    );
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
}


1;