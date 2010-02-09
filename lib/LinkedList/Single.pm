########################################################################
# housekeeping
########################################################################

package LinkedList::Single;

use v5.8;
use strict;

use Carp;

use Scalar::Util    qw( blessed refaddr );
use Symbol;

use overload
(
    q{bool} =>
    sub
    {
        # the list handler is true if the current 
        # node is not empty (i.e., is not at the 
        # final node).

        my $listh   = shift;

        scalar @$$listh
    },
);

########################################################################
# package variables
########################################################################

our $VERSION    = '0.99.1';

# inside-out data for the heads of the lists.

my %headz   = ();

########################################################################
# utility subs
########################################################################

########################################################################
# public interface
########################################################################

# entry with a link-to-empty-next.
#
# the nested arrayref is the first
# node on the list. this is required
# for unshift to add the first node
# after the head.

sub construct
{
    my $proto   = shift;

    my $listh   = bless \[], blessed $proto || $proto;

    $headz{ refaddr $listh } = [ $$listh ];

    $listh
}

sub initialize
{
    my $listh   = shift;

    # data for the list is on the stack.
    # otherwise the caller gets back an 
    # empty list.

    if( @_ )
    {
        # no telling if somone overloaded new and 
        # moved the node. only fix is to re-set the
        # thing to the head before adding the data.
        #
        # or... they know enough to leave it alone
        # if they want to so this should just take
        # the location as-is.

        my $node    = $headz{ refaddr $listh }[0];

        ( $node ) = @$node = ( [], $_ )
        for @_;
    }
    else
    {
        $listh->head;
    }

    return
}

sub new
{
    my $listh   = &construct;

    $listh->initialize( @_ );

    $listh
}

sub clone
{
    # recycle the head node

    my $listh   = shift;

    my $clone   = bless \[ $$listh ], blessed $listh || $listh;

    $headz{ refaddr $clone } = $headz{ refaddr $listh };

    $clone
}

########################################################################
# perl's recursive cleanups croaks after 100 levels, kinda limits the
# list size. fix is converting it to iterateive by replacing the 
# head node.
#
# nasty business: simplest solution gets sig11's 
# in 5.8 & 5.10.1 with lists 2**15 long or more. 
# probelem is that destroy pukes after 
# returning. only fixe so far is keeping the 
# heads alive permenantly (i.e., mem leak is 
# feature)
#
#    $head   = $head->[0]
#    while $head->[0];
#
# fix is expanding the list in place, which 
# takes a bit more work.
#
#   @$head  = @{ $head->[0] }
#   while $head->[0];
#
# wierd thing is that it blows up after DESTROY returns, 
# not when the entry is deleted from $headz{ $key }.
#
# net result: truncate works fine with the fast method,
# DESTROY has to expand out the contents to make it work.
#
# note that doing this without the separate $node
# variable gits the sigfault ( i.e.,
#
#   $head->[0] = @{ $head->[0] }
#
# blows up).
#
# see t/03*.t for example of testing this particular
# issue.

my $cleanup
= sub
{
    my $node    = shift;

    ( $node->[0] ) = @{ $node->[0] }
    while $node->[0];

    return
};

sub DESTROY
{
    my $head    = delete $headz{ refaddr shift };

    my $node    = $head->[0];

    $cleanup->( $node );

    $#$head     = -1;

    return
}

# if $headz{ $key } isn't removed then the
# node = node->next approach works just fine. 
# so, truncate can use the faster aproach.

sub truncate
{
    my $listh   = shift;

    my $node    = $$listh;

    $cleanup->( $node->[0] );

    $node->[0]  = [];

    $listh
}

########################################################################
# basic information: the current node referenced by the list handler
#
# calling node without an argument returns the current one, with one
# sets the node. this allows for tell/reset-style stacking of node
# positions.

sub node
{
    my $listh   = shift;

    @_
    ? $$listh   = shift
    : $$listh
}

########################################################################
# hide extra data in the head node after the first-node ref.
#
# splice with $#$head works since 1 .. end == length - 1 == offset.

sub set_meta
{
    my $listh   = shift;

    my $head    = $headz{ refaddr $listh };

    splice @$head, 1, $#$head, @_;

    $listh
}

sub get_meta
{
    my $head    = $headz{ refaddr $_[0] };

    wantarray
    ?   @{ $head }[ 1 .. $#$head ]
    : [ @{ $head }[ 1 .. $#$head ] ]
}

########################################################################
# node/list status

sub has_links
{
    # i.e., is the list populated?

    my $head    = $headz{ refaddr $_[0] };

    !! @{ $head->[0] }
}

sub has_next
{
    # i.e., while( $node->has_next ){ ... }

    my $listh   = shift;

    scalar @{ $$listh->[0] }
}

sub is_empty
{
    # Q: does the current node have data?
    # A: it will if there is more than one element.

    my $listh   = shift;

    @{ $$listh } > 1
}

sub data
{
    my $listh   = shift;
    my $node    = $$listh;

    # any data to replace the current data is 
    # left on the stack.

    # return the existing data.

    if( defined wantarray )
    {
        my @valz    = @{ $node }[ 1 .. $#$node ];

        @_ and splice @$node, 1, $#$node, @_;

        wantarray
        ?  @valz
        : \@valz
    }
    elsif( @_ )
    {
        splice @$node, 1, $#$node, @_;

        return
    }
    else
    {
        # no good reason to call this without @_ or 
        # wantarray, but returning seems the right 
        # thing to do.

        return
    }
}

sub head_ref
{
    # mainly for testing.
    # also useful for using external code to walk the list.

    $headz{ refaddr $_[0] }
}

########################################################################
# basic list manipulation

sub head
{
    my $listh   = shift;

    $$listh     = $headz{ refaddr $listh }[0];

    $listh
}

sub next
{
    my $listh   = shift;
    my $node    = $$listh;

    @$node
    and 
    $$listh     = $node->[0];

    $listh
}

sub each
{
    my $listh   = shift;
    my $node    = $$listh || $listh->head_ref;

    if( @$node )
    {
        # not at the end-of-list.

        my @valz    = $node ? @$node : ();

        $$listh     = shift @valz;

        wantarray
        ?  @valz
        : \@valz
    }
    else
    {
        # this returns false for the scalar
        # case, where an empty node returns
        # an empty arrayref.

        return
    }
}

sub add
{
    my $listh   = shift;
    my $node    = $$listh;

    # insert after the current node.

    $node->[0]  = [ $node->[0], @_ ];

    $listh
}

# aside: this can be very expensive.
# but, then, so is maintaining a separate
# node-before-the-tail entry.
#
# successive pushes are quite fast, due to
# leaving $$listh on the newly added node,
# which leaves the while loop running only
# once per push.

sub push
{
    my $listh   = shift;
    my $node    = $$listh;

    $node       = $node->[0]
    while @$node;

    # at this point we're at the list tail: the
    # empty placeholder arrayref. populate it in
    # place with a new tail.

    @$node      = ( [], @_ );

    $$listh     = $node;

    $listh
}

sub unshift
{
    my $listh   = shift;
    my $head    = $headz{ refaddr $listh };

    $head->[0]  = [ $head->[0], @_ ];

    $listh
}


# shift and cut do the same basic thing, question
# is whether it's done mid-list or at the head.
# pop could work this way if it weren't so bloody
# expensive to find/maintain the end of a list.
#
# note that shift has one bit of extra work in that
# it has to replace $$listh when it currently references
# the first node.

sub cut
{
    # no need to modify $$listh here since the
    # node after the current one is always removed.

    my $listh   = shift;
    my $node    = $$listh;

    # nothing to cut if we are at the end-of-list.
    # or the node prior to it.

    @$node
    or return;

    if( defined wantarray )
    {
        my @valz    = @{ $node->[0] }
        or return;

        $node->[0] = shift @valz;

        wantarray
        ? @valz
        : \@valz
    }
    else
    {
        # once again: discard the data if the 
        # user doesn't want it.

        $node->[0][0]
        and $node->[0] = $node->[0][0];

        return
    }
}

########################################################################
# put these last to avoid having to use CORE::shift
# and CORE::splice everythwere.

sub splice
{
    my $listh   = shift;
    my $count   = shift || 1;

    looks_like_number $count
    or croak "Bogus splice: non-numeric '$count'";

    $count > 0
    or croak "Bogus splice: negative count '$count'";

    my $node    = $$listh   
    or confess "Bogus splice: empty list handler";

    my $next    = $node;

    for( 1 .. $count )
    {
        @$next
        or last;

        $next   = $next->[0];
    }

    my $dead    = $node->[0];

    $node->[0]  = $next->[0];

    if( defined wantarray )
    {
        $next->[0]  = [];

        $dead;
    }
    else
    {
        $cleanup->( $dead );
    }
}


sub shift
{
    my $listh   = shift;
    my $head    = $headz{ refaddr $listh };

    # need to replace $listh contents if it
    # referrs to the head we are removing!

    $$listh     = ''
    if $$listh == $head->[0];

    if( defined wantarray )
    {
        my @valz    = @{ $head->[0] };

        $head->[0]  = shift @valz;

        $$listh     ||= $head->[0];

        wantarray
        ? @valz
        : \@valz
    }
    else
    {
        # get this over with for cases where
        # the user doesn't want the data.

        $head->[0][0]
        and $head->[0]  = $head->[0][0];

        $$listh     ||= $head->[0];

        return
    }
}
# keep require happy

1

__END__

=head1 NAME

LinkedList::Single - singly linked list manager.

=head1 SYNOPSIS

    # generate the list with one value from @_ per node
    # in a single pass.

    my $listh   = LinkedList::Single->new( @one_datum_per_node );

    # generate an empty list.

    my $listh   = LinkedList::Single->new;

    # each node can have multiple data values.

    $listh->push( @multiple_data_in_a_single_node );

    # extract the data from the current node.

    my @data    = $listh->data;

    # save and restore a node position

    my $curr    = $listh->node;

    # do something and restore the node.

    $list->node( $curr );

    # note the lack of "pop", it is simply too
    # expensive with singly linked lists. for 
    # a stack use unsift and shift; for a que
    # use push and shift (or seriously consider
    # using arrays, which are a helluva lot more
    # effective for the purpose).


    $list->push( @node_data );

    my @node_data   = $list->shift; # array of values
    my $node_data   = $list->shift; # arrayref

    # these manipulate the head node directly
    # and to not modify the current list.

    $listh->unshift( @new_head_node_data );

    my @data    = $listh->shift;

    # sequences of pushes are effecient for adding
    # longer lists.

    my $wcurve  = LinkedList::Single->new;

    while( my $base = substr $dna, 0, 1, '' )
    {
        ...

        $wcurve->push( $r, $a, ++$z );
    }

    # reset to the start-of-list.

    $wcurve->head;

    # hide extra data in the head node.

    $wcurve->set_meta( $z, $species );

    # extra data can come back as a list
    # or arrayref.

    my ( $size )    = $wcurve->get_meta;


    # walk down the list examining each item until 
    # the tail is reached.
    #
    # unlike Perl's each there is no internal
    # mechanism for re-setting the current node,
    # if you don't call head $listh->each returns
    # immediatley. 

    $listh->head;

    while( my @data = $listh->each )
    {
        # play with the data
    }

    # duplicate a list handler, reset it to the 
    # start-of-list.

    if( $some_test )
    {
        # $altlist starts out with the same node 
        # as $listh, call to next does not affect
        # $listh.

        my $altlist = $listh->clone;

        my @data    = $altlist->next->data;

        ...
    }


    # for those do-it-yourselfers in the crowd:

    my $node    = $listh->head_ref;

    while( @$node )
    {
        # advance the node and extract the data
        # in one step.

        ( $node, @data )    = @$node;

        # process @data...
    }

    # if you prefer OO...
    # $listh->each returns each value in order then
    # returns false. one catch: in a list context
    # this will return equally false for an empty
    # node as the end-of-list.
    #
    # in a scalar context each returns false for the
    # end-of-list and an empty arrayref for a node.

    $listh->head;

    while( my $data = $listh->each )
    {
        # deal with @$data
    }

    # if you *know* the nodes are never empty

    while( my @data = $listh->each )
    {
        # deal with @data
    }

    # note that $listh->next->data may be empty
    # even if there are mode nodes due to a node
    # having no data.

    $listh->add( @new_data );

    my @old_data    = $listh->cut;

    # $listh->head->cut is slower version of shift.


=head1 DESCRIPTION

Singly-linked list managed via ref-to-scalar. 

Nodes on the list are ref-to-next followed by 
arbitrary -- and possibly empty -- user data:

    my $node    = [ $next, @user_data ].

The list handler can reference the list contents
via double-dollar. For example, walking the list
uses:

    $$listh = $$list->[0]

this allows $listh to be blessed and use inside-
out data structures while the nodes are un-blessed.

=head1 AUTHOR

Steven Lembark <lembark@wrkhors.com>

=head1 COPYRIGHT

Copyright (C) 2009, 2010 Steven Lembark.

=head1 LICENSE

This code can be used under the same terms as Perl-5.10.1 itself.
