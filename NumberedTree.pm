package NumberedTree;

use strict;

our $VERSION = '1.00';

my @counters = (); # For getting new serial numbers.

sub getNewSerial {
    my $lucky_number = shift;
    $counters[$lucky_number] = 1 unless (exists $counters[$lucky_number]);
    return ($counters[$lucky_number]++);
}

sub getNewLucky {
    $#counters++;
    return $#counters;
}

# <new> constructs a new tree or node.
# Arguments: $value - the value to be stored in the node.
# Returns: The tree object.

sub new {
    my ($parent, $value) = @_;
    my $parent_serial;
    my $class;
    
    my $properties = { 
	Value => $value,
	Items => [],
	Cursor => -1
	};

    if ($class = ref($parent)) {
	# Give it the same number as its parent, or a new number.
	$properties->{_LuckyNumber} = $parent->{_LuckyNumber};
    } else {
	$class = $parent;
	$properties->{_LuckyNumber} = getNewLucky;
    }
    $properties->{_Serial} = getNewSerial($properties->{_LuckyNumber});

    return bless $properties, $class;
}

# <nextNode> moves the cursor forward by one.
# Arguments: None.
# Returns: Whatever is pointed by the cursor, undef on overflow, first item
#          on subsequent overflow.

sub nextNode {
    my $self = shift;

    my $cursor = $self->{Cursor};
    my $length = $self->childCount;
    $cursor++;

    # return undef when end of iterations. On next call - reset counter.
    if ($cursor > $length) {
	$cursor = ($length) ? 0 : -1;
    }
    $self->{Cursor} = $cursor;

    if (exists $self->{Items}->[$cursor]) {
	return $self->{Items}->[$cursor];
    }
    return undef;
}

# <reset> returns the counter to the beginning of the list.
# Arguments: None.
# Returns: Nothing.

sub reset {
    my $self = shift;
    $self->{Cursor} = -1;
}

# <delete> deletes the item pointed to by the cursor.
# The curser is not changed, which means it effectively moves to the next item.
# However it does change to be just after the end if it is already there,
# so you won't get an overflow.
# Arguments: None.
# Returns: The deleted item or undef if none was deleted.

sub delete {
    my $self = shift;
    my $cursor = $self->{Cursor};
    
    if (exists $self->{Items}->[$cursor]) {
	my $deleted =  splice(@{$self->{Items}}, $cursor, 1);

	# Make sure the cursor doesn't overflow:
	if ($cursor > $self->childCount) {
	    $self->{Cursor} = $self->childCount;
	}
	return $deleted;
    }

    return undef;
}

# <append> adds a node at the end of the list.
# Arguments: parameters for new.
# Returns: The added node or undef on error.

sub append {
    my $self = shift;
    my $newNode = $self->new(shift);
    return undef unless $newNode;

    push @{$self->{Items}}, $newNode;
    return $newNode;
}

# <savePlace> saves the place of the cursor.
# Arguments: None.
# Returns: Nothing.

sub savePlace {
    my $self = shift;
    $self->{Saved} = $self->{Cursor};
}

# <restorePlace> returns the cursor to its saved place if any. The place is 
# still saved untill the save is changed.
# Arguments: None.
# Returns: 1 if restored, undef otherwise.

sub restorePlace {
    my $self = shift;
    if (exists($self->{Saved}) && ($self->{Saved} <= $self->childCount)) {
	$self->{Cursor} = $self->{Saved};
	return 1;
    }
    return undef;
}

# <clone> returns a new tree that is the same as the cloned one except for 
#   its lucky number.
# Arguments: None.
# Returns: None.

sub clone {
    my $self = shift;
    my $lucky_number = shift;

    unless (defined $lucky_number) {
	$lucky_number = getNewLucky;
	$counters[$lucky_number] = $counters[$self->{_LuckyNumber}];
    }

    my $cloned = {};
    $cloned->{$_} = $self->{$_} foreach (keys %$self);
    $cloned->{_LuckyNumber} = $lucky_number;
    $cloned->{Items} = [map {$_->clone($lucky_number)} @{ $self->{Items} }];
    
    return bless $cloned, ref($self);
}

# <deepProcess> runs a given subroutine on all descendants of a node.
# Arguments: $subref - the sub to be run.
#       all remaining arguments will be passed to the subroutine,
#       prepended by a ref to the node being processed.
# Returns: Nothing.

sub deepProcess {
    my $self = shift;
    my ($subref, @args) = @_;

    # I do not use the savePlace + reset metods, because the subroutine 
    # passed by the user may mess it up.
    foreach my $child (@{ $self->{Items} }) {
	$subref->($child, @args);
	$child->deepProcess($subref, @args);
    }
}

# <allProcess> does the same as deepProcess except that it also processes the 
#   root element.
# Arguments: see <deepProcess>.
# Returns: Nothing.

sub allProcess {
    my $self = shift;
    my ($subref, @args) = @_;
    
    $subref->($self, @args);
    $self->deepProcess($subref, @args);
}

#*******************************************************************
#   Accessors:

sub childCount {
    my $self = shift;
    return scalar @{$self->{Items}};
}

# There is no setNumber because numbers are handled only by the object.
sub getNumber {
    my $self = shift;
    return $self->{_Serial};
}

# same for LuckyNumber.
sub getLuckyNumber {
    my $self = shift;
    return $self->{_LuckyNumber};
}

sub getValue {
    my $self = shift;
    return $self->{Value};
}

sub setValue {
    my $self = shift;
    $self->{Value} = shift;
}

#***************************************************************************
#   Service methods.

# <getSubTree returns the sub tree whose  root element's serial number
# is requested.
# Arguments: $serial - the requested serial number.
# Returns - the matching object if it's there, undef otherwise.

sub getSubTree {
    my ($self, $serial) = @_;
    
    $self->savePlace;
    $self->reset;

    while (my $branch = $self->nextNode) {
	if ($branch->{_Serial} == $serial) {
	    $self->restorePlace;
	    return $branch;
	} elsif (my $subtree = getSubTree($branch, $serial)) {
	    $self->restorePlace;
	    return $subtree;
	}
    }
    $self->restorePlace;
    return undef;
}

# <listChildNumbers> returns a list of serial numbers of all items under
# an item whose serial number is given as an argument.
# Arguments: $serial - denoting the item requested.

sub listChildNumbers {
    my $self = shift;
    my $serial = shift;

    my @subSerials = ();
    my $subtree = ($serial) ? getSubTree($self, $serial) : $self;

    $subtree->savePlace;
    $subtree->reset;
    
    while (my $branch = $subtree->nextNode) {
	push @subSerials, $branch->{_Serial};
	
	if ($branch->childCount > 0) {
	    push @subSerials, $branch->listChildNumbers;
	}
    }

    $subtree->restorePlace;
    return @subSerials;
}

# <follow> Will find an item in a tree by its serial number 
# and return a list of all values up to and including the requested one. 
# Arguments: $serial - number of target node.

sub follow {
    my $self = shift;
    my $serial = shift;

    $self->savePlace;
    $self->reset;
        
    while (my $branch = $self->nextNode) {
	my @patharray = ();
	if ($branch->{_Serial} == $serial) {
	    $self->restorePlace;
	    return ($branch->{Value});
	} elsif ($branch->childCount) {
	    @patharray = follow($branch, $serial);
	}
	
	if ($#patharray >= 0) {
	    # Parent nodes go first:
	    unshift @patharray, $branch->{Value};
	    $self->restorePlace;
	    return @patharray;
	}
    }

    $self->restorePlace;
    return ();
}

1;

=head1 NAME

NumberedTree - a thin N-ary tree structure with a number for each item.

=head1 SYNOPSYS

 use NumberedTree;
 my $tree = new('I am the root of the tree');
 $tree->append('I am a child');
 $tree->append('Me too');

 while (my $branch = $tree->nextNode) {
    $branch->delete if ($branch->getValue eq 'Stuff I dont want');
 }
 
 my $itemId = what_the_DB_says;
 print join ' --- ', $tree->follow($itemId); # a list of items up to itemId.

 etc. 

=head1 DESCRIPTION

 NumberedTree is a special N-ary tree with a number for each node. This is  
 useful on many occasions. The first use I  found for that (and wrote this for) 
 was to store information about the selected item as a number instead of storing
 the whole value which is space-expensive.
 Every tree also has a lucky number of his own that distinguishes it from other
 trees created by the same module.
 This module is thin on purpose and is meant to be a base class for stuff that 
 can make use of this behaveiour. For example, I wrote NumberedTree::DBTree
 which ties a tree to a table in a database, and Javascript::Menu which uses 
 this tree to build a Menu.

=head1 BUILDING AND DESTROYING A TREE

=over 4

=item NumberedTree->new(VALUE)

There is only one correct way to start an independent tree with its own lucky number from scratch: calling the class function I<new>. Using new as a method is wrong because it will create a node for the same tree but the tree won't know of its existence. See below.

=item $tree->clone(LUCKY_NUMBER)

Another way to obtain a new tree object is to clone an existing one. The clone method does that. The original object remains untouched. You have the option of supplying a lucky number instead of letting the module decide, but use this with caution, since there is no guarantee that you give a good number. Best to not use it.

=item $tree->append(VALUE)

This is the correct way to add an item to a tree or a branch thereof. Internally uses $tree->new but does other stuff.

=item $tree->delete

Deletes the child pointed to by the cursor (see below) and returns the deleted item. Note that it becomes risky to use this item since its parent tree knows nothing about it from the moment it is deleted and you can cause collisions so use with caution.

=back

=head1 ITERATING OVER CHILD ITEMS

=head2 The cursor

Every node in the tree has its own cursor that points to the current item. When you start iterating, the cursor is placed just B<before> the first child. When you are at the last item, trying to move beyond the last item will put the 
cursor B<after> the last item (which will result in an undef value, signalling the end) but the next attempt will cause the cursor to B<start over> from the first child.

=head2 Methods for iteration

=over 4

=item nextNode

Moves the cursor one child forward and returns the pointed child.

=item reset

Resets the cursor to point before the first child.

=item savePlace

Allows you to save the cursor's place, do stuff, then go back. There is only one save, though, so don't try to nest saves.

=item restorePlace

Tries to set the cursor to the item at the same place as it was when its place was saved and returns true on success. If the saved place doesn't exist anymore returns undef. Note: If you deleted items from the tree you might not get to the right place.

=head1 ACCESSORS

The following are available:

=over 4

=item get/setValue

Gets or sets the Value property of a node.

=item getNumber

Gets the number of the node within its NumberedTree. There is no setter since this number is special.

=item getLuckyNumber

Gets the number of the main tree that the node is a member of. Again, there is no setter since this is special.

=item childCount

Gets the number of childs for this node.

=back

=head1 THINGS YOU CAN DO WITH NODE NUMBERS

Well, I didn't include the node numbers just for fun, this is actually very needed sometimes. There are three basic service methods that use this (subclasses may add to this):

=over 4

=item getSubTree(NUMBER)

If a node who's number is given is a member of the subtree that the method was invoked on, that node will be  returned, undef otherwise.

=item listChildNumbers(NUMBER)

returns a list of all numbers of nodes that are decendants (any level) of the subtree whose number is given. Number is optional, the node's own number is used if no number is specifically requested.

=item follow(NUMBER)

returns a list of all values starting from the decendant node with the requested number, through every parent of the node and up to the node the method was invoked on. If no such node exists, returns an empty list.

=back

=head1 OTHER METHODS

There are two methods that apply a certain subroutine to whole trees:

=over 4

=item deepProcess (SUBREF, ARG, ARG, ...)

For each child of the node, runs the subroutine referenced by SUBREF with an argument list that starts with a reference to the child being processed and continues with the rest of the arguments passed to deepProcess.

=item allProcess (SUBREF, ARG, ARG, ...)

does the same as deepProcess but runs on the root node first.

=back

=head1 BUGS AND PROBLEMS

Works pretty well for me. If you found anything, please send a bug report:
E<lt>http://rt.cpan.org/NoAuth/Bugs.html?Dist=NumberedTreeE<gt>
or send mail to E<lt>bug-NumberedTree#rt.cpan.orgE<gt> 

=head1 AUTHOR

Yosef Meller, E<lt> mellerf@netvision.net.il E<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2003 by Yosef Meller

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
