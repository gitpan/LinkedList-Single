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
        #
        # this allows for:
        #
        # $listh->head; while( $listh->next ){ ... }

        my $listh   = shift;

        !! $$listh->[0]
    },
);

########################################################################
# package variables
########################################################################

our $VERSION    = v0.99.4;

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

        my $node    = $listh->head_node;

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

    my $head    = $listh->root;

    splice @$head, 1, $#$head, @_;

    $listh
}

sub add_meta
{
    my $listh   = shift;

    my $head    = $listh->root;

    push @$head, @_;

    $listh
}

sub get_meta
{
    my $head    = $_[0]->root;

    wantarray
    ?   @{ $head }[ 1 .. $#$head ]
    : [ @{ $head }[ 1 .. $#$head ] ]
}

########################################################################
# node/list status

sub has_nodes
{
    # i.e., is the list populated?

    my $head    = $_[0]->root;

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

    ! @{ $$listh }
}

sub data
{
    my $listh   = shift;
    my $node    = $$listh;

    # return the existing data, sans the next ref.

    my @valz    = @{ $node }[ 1 .. $#$node ];

    wantarray
    ?  @valz
    : \@valz
}

sub set_data
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
    else
    {
        splice @$node, 1, $#$node, @_;

        return
    }
}

sub clear_data
{
    my $listh   = shift;
    my $node    = $$listh;

    splice @$node, 1;

    $listh
}

########################################################################
# access the list head.
#
# root is mainly useful for testing, 
# head_node for externally walking the 
# list (i.e., when OO calls are too expensive).

sub root
{
    $headz{ refaddr $_[0] }
}

# get rid of this once W-curve no longer uses it.

*head_ref   = \&root;

sub head_node
{
    my $listh   = shift;

    $listh->root->[0]
}

sub head
{
    my $listh   = shift;

    $$listh     = $listh->head_node;

    $listh
}

########################################################################
# walk the list.

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
    my $node    = $$listh || $listh->root;

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

########################################################################
# modify the list
#
# add uses a relative position (e.g., for insertion sort), others
# use the head (or last) node.

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

    @{ $node->[0] }
    or return;

    if( defined wantarray )
    {
        my @valz   =  @{ $node->[0] };
        $node->[0] = shift @valz;

        wantarray
        ? @valz
        : \@valz
    }
    else
    {
        # once again: discard the data if the 
        # user doesn't want it.

        $node->[0] = $node->[0][0];
    }
}

########################################################################
# put these last to avoid having to use CORE::blah everythwere else.

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

    # this is the start of the chain that gets removed.
    # keep it alive for a few steps to see if the caller
    # wants it back or we should clean it up.
    #
    # after that, splice the node out of the list.

    my $dead    = $node->[0];
    $node->[0]  = delete $next->[0];

    # at this point $dead is a runt linked
    # list without a terminating node.
    #
    # insert anything on the stack after the 
    # current node.

    for( @_ )
    {
       $node    = $node->[0] = [ $node->[0], shift ];
    }

    # if the caller wants anything back then
    # clean up the dead chain and hand it back.
    #
    # node: maybe this should return an array of
    # arrayrefs?

    if( defined wantarray )
    {
        my @valz    = ();

        $node       = $dead;

        while( $node->[0] )
        {
            push @valz, @{ $node }[ 1 .. $#$node ];
        }

        $cleanup->( $dead );

        wantarray
        ? @valz
        : \@valz
    }
    else
    {
        $cleanup->( $dead );
    }
}

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
    my $head    = $_[0]->root;

    $head->[0]  = [ $head->[0], @_ ];

    $_[0]
}


sub shift
{
    my $listh   = shift;
    my $head    = $listh->root;

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

    my $node    = $listh->root;

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

this allows $listh to be blessed without having
to bless every node on the list.

=head2 Methods

=over 4

=item new construct initialize 

New is the constructor, which simply calls construct,
passes the remaining stack to initialize, and returns
the constructed object.

initialize is fodder for overloading, the default simply 
adds each item on the stack to one node as data.

construct should not be replaced since it installs
local data for the list (its head). 

=item clone

Produce a new $listh that shares a head with the 
existing one. This is useful to walk a list when
the existing node's state has to be kept.

    my $clone   = $listh->clone->head;

    while( my @valz = $clone->each )
    {
        # play with the data
    }

    # note that $listh is unaffected by the 
    # head or walking via each.

=item set_meta add_meta get_meta 

These allow storing list-wide data in the head.
get_meta returns whatever set_meta has stored
there, add_meta simply pushes more onto the list.
These can be helpful for keeping track of separate
lists or in derived classes can use these to provide
data for overloading.

=item has_nodes has_next is_empty 'bool'

has_nodes is true if the list has any nodes
at all; has_next is true if the current node
has a next link.

The boolean overload is true if the current
node has a next link (i.e., if calling $listh->next
will go anywhere).

    sub walk_the_list
    {
        my $listh   = shift;

        $listh->has_nodes
        or return;

        $listh->head;

        while( $listh )
        {
            # deal with the data in this node
        }
        continue
        {
            $listh->next;
        }
    }

=item data set_data clear_data

These return or set the data. They cannot be combined
into a single method because there isn't any clean way
to determine if the node needs to be emptied or left
unmodified due to an empty stack. The option of using

    $listh->data( undef )

for cleaning the node leaves no way to store an explicit
undef in the node. 

=item node

Set/get the current node on the list.

This can be used for tell/seek positioning on the list.

    my $old = $listh->node;

    $listh->head;

    ...


    $listh->node( $old );

Note that setting a new position returns the new
position, not the old one. This simplifies re-set
logic which can simply return the result of setting
the new node.

This is also the place to get nodes for processing
by functional code or derived classes.

=item root head_node

These return the internal data (root) or first
data node (head_node).

head_node is useful for anyone whthat wants to walk the
list using functional code:

    my $node    = $listh->head_node;
    my @data    = ();

    for(;;)
    {
        @$node  or last;

        ( $node, @data ) = @$node;

        # play with @data.
    }

moves the least amount of data to walk the entire list.

root is mainly useful for intenal code or derived
classes. This is used by all methods other than 
construct, DESTROY, clone, and root to access the
list's head. Derived classes can override these methods
to use another form of storage for the list root.

=item head next each

head and next start the list at the top and walk the list.

each is kinda like Perl's each: it returns data until 
the end-of-list is reached. It makes no attempt, however,
to initialize or reset the list, only walk it. 

Called in a scalar context this returns an arrayref
with copies of the data (i.e., modifying the returned
data will not modify the node's data). This is a feature.

When the data is exhausted an empty list or undef are
returned. If your list has empty nodes then you want 
to get the data back in a scalar context:

    # if the list has valid empty nodes, use
    # a scalar return to check for end-of-list.

    $listh->head;

    my $data    = '';

    while( $data = $listh->each )
    {
        # play with @$data
    }

or

    # otherwise simply checking for an empty list
    # is sufficient has has lower overhead on long
    # lists.

    $listh->head;

    my @data    = ();

    while( @data = $listh->each )
    {
        # play with @data
    }

=item unshift shift push 

Notice the lack of "pop": it is quite expensive to 
maitain a node-before-the-last-data-node entry in
order to guarantee removing the last node.

shift and unshift are cheap since they can 
access the root node in one step.

push can be quite inexpensive if the current
node is at the end-of-list when it is called:

This is the cheap way to do it: leaving $$listh
at the end-of-list after each push:

    my $listh   = LinkedList::Single->new;

    for(;;)
    {
        my @data    = generate_some_data
        or last;

        $listh->push( @data );
    }

If $listh is not already at the end-of-list
then push gets expensive since the list has 
to be traversed in order to find the end and
perform the push.

Note that walking the list can still be done
between pushes by cloning the list handler 
and moving the clone or saving the final node
and re-setting the list before each push.

For an insertion sort, each will leave the
list handler on the last node:

    my $listh   = LinkedList::Single->new;

    my $new     = '';
    my $old     = '';

    DATA:
    while( my $new = next_data_to_insert )
    {
        $listh->head;

        while( $old = $listh->each ) 
        {
            # decide if the new data is a duplicate
            # or not. this requires examining
            # the entire list.

            is_duplicate_data $new, $old
            and next DATA;
        }

        # at this point $listh is at the end-of-list.

        $listh->push( @$new );
    }

=item add cut splice

add appends a node after the current one, cut removes
the next node, returning its data if not called in a 
void context.

splice is like Perl's splice: it takes a number of items
to remove, optionally replacing them with the rest of the
stack, one value per node:

    my @new_nodz    = ( 1 .. 5 );

    my $old_count   = 5;

    my $old_list    = $listh->splice( $old_count, @new_nodz );

If called in a non-void context, the old nodes have 
a terminator added and are returned to the caller as
an array of arrayrefs with the old data. This can be 
used to re-order portions of the list.


=item truncate

Chops the list off after the current node. 

Note that doing this to the head node will not 
empty the list: it leaves the top node dangling.



=back


=head1 AUTHOR

Steven Lembark <lembark@wrkhors.com>

=head1 COPYRIGHT

Copyright (C) 2009, 2010 Steven Lembark.

=head1 LICENSE

This code can be used under the same terms as Perl-5.10.1 itself.
