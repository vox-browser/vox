module layout

import os

// Same-binary control: carry every committed retained layout into the
// incremental state, as before.
const retain_relaid_layout_caches = os.getenv('VOX_RETAIN_RELAID_LAYOUT_CACHES') != ''

// The incremental pass starts from the committed retained block and inline
// layouts, as a complete pass carries those of the subtrees it restores. A
// relayout root and its descendants are laid out afresh, so their committed
// entries no longer describe the boxes. The paint projection trusts an entry
// it finds for a container (retained_inline_paint.v checks only the inputs'
// styles before reusing its lines), and a box an in-place tree update
// replaced keeps its old style: the replaced box's text was painted again
// from the committed lines. Carry only the entries of boxes outside the roots
// that are still in the tree; the roots record their own again.
fn relaid_or_detached_box(node &Node, root &Node, roots []&Node, relaid map[u32]bool) bool {
	styled := node.as_node_with_style() or { return true }
	if styled.layout_index() in relaid { return true }
	for relayout_root in roots {
		if voidptr(relayout_root) == voidptr(node) { return true }
	}
	return voidptr(node.root()) != voidptr(root)
}

fn block_layouts_outside_relayout_roots(committed map[u64]&RetainedBlockLayout, root &Node,
	roots []&Node, relaid map[u32]bool) map[u64]&RetainedBlockLayout {
	if retain_relaid_layout_caches { return committed.clone() }
	mut result := map[u64]&RetainedBlockLayout{}
	for key, cache in committed {
		if cache.inputs.len == 0 || relaid_or_detached_box(cache.inputs[0].node, root, roots, relaid) {
			continue
		}
		result[key] = cache
	}
	return result
}

fn inline_layouts_outside_relayout_roots(committed map[u64]&RetainedInlineLayout, root &Node,
	roots []&Node, relaid map[u32]bool) map[u64]&RetainedInlineLayout {
	if retain_relaid_layout_caches { return committed.clone() }
	mut result := map[u64]&RetainedInlineLayout{}
	for key, cache in committed {
		if cache.inputs.len == 0 || relaid_or_detached_box(cache.inputs[0].node, root, roots, relaid) {
			continue
		}
		result[key] = cache
	}
	return result
}
