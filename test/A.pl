use 5.16.0;
use strict;
use warnings;

use lib '.';
use B;
use C;

my $obj = B->new();

$obj->foo();
$obj->fooD();
# foo();