use 5.16.0;
use strict;
use DDP;

# my $job_folder_id = `ls -n job_* 2>/dev/null | wc -l`;
# # say $job_folder_id;

# $job_folder_id++;

# mkdir('job_'.$job_folder_id);

my $config = qq(
        a = '1'
        b = '2');

$config =~ s/^\s+//gm;

say $config;

`echo `.$config.` > cfg';
