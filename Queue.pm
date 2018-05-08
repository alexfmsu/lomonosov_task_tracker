package Queue;

use 5.16.0;
use strict;
use warnings;
use utf8;
use DDP;

# use QtCore4;
# use QtGui4;
# use QtCore4::isa qw(Qt::Widget);

use Moose;

has 'name'=> (
    is=>'ro',
    isa=>'Str'
);
has 'list'=> (
    is=>'rw'
);

has 'model'=> (
    is=>'rw',
    isa=>'Qt::StandardItemModel'
);



sub show{
    my $self = shift;
    my $ssh = shift;
    
    my $out = $ssh->cmd('squeue -p '.$self->name);
# p $out;
    my @header = split /\s+/, $out->[0];
    
    my $M = scalar @$out - 1;
    my $N = scalar @header;

    $self->model(Qt::StandardItemModel($M, $N));

    for(my $j=0; $j<$N; $j++){
        $self->model->setHorizontalHeaderItem($j, Qt::StandardItem(Qt::String($header[$j])));
    }
    
    for my $i(1..$M){
        my @list = split /\s+/, $out->[$i];
        
        for my $j(0..$N){
            my $str = Qt::String($list[$j]);
            my $item = Qt::StandardItem($str);
            $self->model->setItem($i-1, $j, $item);
        }
    }

    $self->list->setModel($self->model);
}

1;