use 5.16.0;

use strict;
use warnings;
use utf8;

use Net::SFTP::Foreign;

sub receive_files {
    my ( $self, $from_path, $to_path ) = @_;

    $to_path ||= $from_path;

    $self->{sftp}->rget( $self->{path} . "/" . $from_path, $to_path ) or do {
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
