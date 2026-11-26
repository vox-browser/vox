module layout

import os

// Same-binary control: attempt every relayout root, however large.
const retain_large_relayout_roots = os.getenv('VOX_RETAIN_LARGE_RELAYOUT_ROOTS') != ''

// An incremental attempt restores every committed value and lays out its
// roots again; when a root's automatic size changes, the complete pass lays
// the roots out once more and the attempt's work is lost. For roots that hold
// this fraction (1/n) of the tree's boxes, the complete pass with subtree
// reuse costs about what a successful attempt saves, so it runs directly.
const large_relayout_root_fraction = u32(4)
// Smaller trees always attempt: both passes are cheap there.
const large_relayout_root_minimum_tree = u32(512)

fn incremental_roots_are_too_large(root &Node, roots []&Node) bool {
	if retain_large_relayout_roots { return false }
	order := root.tree_order_
	if order == unsafe { nil } || !order.valid || root.tree_order_owner_ != voidptr(root) {
		return false
	}
	total := root.tree_order_end_ - root.tree_order_start_
	if total < large_relayout_root_minimum_tree { return false }
	mut covered := u32(0)
	for relayout_root in roots {
		if voidptr(relayout_root.tree_order_) != voidptr(order)
			|| relayout_root.tree_order_owner_ != voidptr(relayout_root) {
			return false
		}
		covered += relayout_root.tree_order_end_ - relayout_root.tree_order_start_
	}
	return covered * large_relayout_root_fraction >= total
}
