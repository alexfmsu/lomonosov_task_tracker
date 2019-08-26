package B;

use 5.16.0;
use strict;
use warnings;

use Exporter 'import';

# use Exporter 'import';
# our (@ISA, @EXPORT_OK);
# @ISA = qw(Exporter);

our @EXPORT = qw(foo);

require 'Queue.pl';

# our @EXPORT_OK = qw(foo);

sub new{
	my ($class, %params) = @_;

	return bless \%params, $class;
};

sub foo {
	my $self = shift;

    print(123);
}

1;
