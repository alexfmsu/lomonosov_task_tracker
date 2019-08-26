package C;

use 5.16.0;
use strict;
use warnings;

use B;

use Exporter 'import';

# use Exporter 'import';
# our (@ISA, @EXPORT_OK);
# @ISA = qw(Exporter);

our @EXPORT = qw(foo2);

# our @EXPORT_OK = qw(foo);

sub foo2 {
	my $self = shift;

    print(123);
}

1;
