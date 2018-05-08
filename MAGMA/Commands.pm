use 5.16.0;
use strict;
use warnings;
use utf8;

sub cmd {
    my ( $self, $cmd ) = @_;

    $self->{ssh}->blocking(1);
    $self->{chan} = $self->{ssh}->channel;

    $self->{chan}->exec($cmd);

    $self->readlines2();

    # $self->{ssh}->blocking(1);
}

sub cd{
	my ($self, $path) = @_;
	
	my ($o, $e) = $self->exec("cd $path && pwd");
	
	return $e->[0] if @$e;
	
	$self->{path} = $o->[0];

	undef
}

sub ls{
	my $self = shift;

	my ($o, $e) = $self->exec('ls');
	
	return $e->[0] if @$e;

	return $o;
}

sub rm{
	my ($self, $file) = @_;
	
	my ($o, $e) = $self->exec("rm $file");
	
	return $e->[0] if @$e;

	undef;
}

1;