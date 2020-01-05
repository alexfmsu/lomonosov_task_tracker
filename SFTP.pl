use 5.16.0;

use strict;
use warnings;
use utf8;

use DDP;

use Net::SFTP::Foreign;

sub receive_files {
    my ( $self, $from_path, $to_path ) = @_;

    my ( $o, $e ) = $self->exec( '[ -d "' . $from_path . '" ] && echo "OK"' );
    my $is_folder = scalar @$o;

    # say "to_path:",   $to_path;
    # say "from_path:", $from_path;
    if ($is_folder) {
        $to_path .= '/' . $from_path;
    }
    # say "to_path:", $to_path;

    $self->{sftp}->rget( $self->{path} . "/" . $from_path, $to_path ) or do {
        print color('bold red');

        p $self->{path} . "/" . $from_path;
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
