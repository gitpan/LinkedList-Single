
use v5.8;
use strict;

use Test::More;
use Scalar::Util    qw( blessed refaddr reftype weaken );

my $class   = 'LinkedList::Single';

use_ok $class;

ok do
{
    my $node    = $class->new;
    my $head    = $node->head;

    my $sanity
    = refaddr $head == refaddr $node
    and blessed $head eq blessed $node;

}, "head returns node ($class)";

ok do
{
    my $node    = $class->new( 1 );

    my ( $found ) = $node->data;

    1 == $found 

}, 'new inserts data value';

ok do
{
    # without the DESTROY handling things gracefully
    # the cleanup fails with the 100-th level of 
    # recursion.

    my $node    = $class->new( 1 .. 200 );

    my $head    = $node->head_ref;

    weaken $head;

    undef $node;

    not defined $head

}, 'DESTROY cleans up the list';


done_testing;

# this is not a modle

0

__END__
