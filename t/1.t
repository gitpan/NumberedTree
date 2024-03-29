
use Test::More tests => 9;
BEGIN { use_ok('NumberedTree') };

my $tree = NumberedTree->new('Root');
ok($tree, "constructor");

my $child = $tree->append("First");
ok ($child, "append");

$tree->append("Second");
ok($child->append("First child"), "deep append");

my $cloned = $tree->clone;
isa_ok($cloned, "NumberedTree", "cloning");

@ch1 = sort $cloned->listChildNumbers;
@ch2 = sort $tree->listChildNumbers;
ok(eq_set(\@ch1, \@ch2), "cloning and descendants");
isnt ($cloned->getLuckyNumber, $tree->getLuckyNumber, "lucky numbers are different");

$tree->allProcess(sub {my $self = shift; $self->{hidden} = "visible";});
ok ($child->{hidden} eq "visible", "allProcess works");

while ($cloned->nextNode) {}
ok ($cloned->nextNode, "cursor resets");