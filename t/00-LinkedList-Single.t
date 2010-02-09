
use v5.8;
use strict;

use Test::More;
use Scalar::Util    qw( reftype );

my $class   = 'LinkedList::Single';

use_ok $class;

my $ignore
= qr
{
    \b
    (
        import  |
        qualify |
        gensym  |
        refaddr |
        blessed |
        BEGIN   |
        OVERLOAD|
        push    |
        carp    |
        __ANON__
    )
    \b
}x;

my @expect
= grep
{
    ! /\W/ and ! /$ignore/o 
}
keys %{ $::{'LinkedList::'}{'Single::'} };

ok $class->can( $_ ),   "$class can '$_'" for @expect;

my $node    = $class->new;

ok $node->can( $_ ),    "node can '$_'"   for @expect;


ok $node->isa( $class ),        'node isa $class';
ok 'REF' eq reftype $node,      '$node is a ref';

ok $$node,                      '$$node is true';
ok 'ARRAY' eq reftype $$node,   '$$node is an array';

undef $node;

ok ! $node,                     "Node is false";

done_testing;

# this is not a module

0

__END__
