module layout

import css
import dom

$if gcboehm ? {
	fn C.GC_get_total_bytes() usize
	fn C.GC_gcollect()
}

@[noinline]
fn optional_margin_fresh_context() BlockFormattingContext {
	return BlockFormattingContext{}
}

fn test_empty_block_context_does_not_construct_an_absent_margin_child() {
	mut before := usize(0)
	$if gcboehm ? { before = C.GC_get_total_bytes() }
	mut empty := 0
	for _ in 0 .. 512 {
		context := optional_margin_fresh_context()
		if context.trailing_collapsed_margin == none && context.root == none {
			empty++
		}
	}
	mut allocated := usize(0)
	$if gcboehm ? { allocated = C.GC_get_total_bytes() - before }
	assert empty == 512
	// The real float-band vector still belongs to every context. An absent
	// trailing margin must not allocate a dummy layout node and its styles.
	assert allocated < 512 * 256, 'empty context allocations: ${allocated}'
}

fn test_present_trailing_margin_keeps_its_child_through_copy_and_collection() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut child := NodeWithStyle.new(document, none, css.ComputedProperties.new())
	child.set_layout_index(73)
	mut context := optional_margin_fresh_context()
	context.trailing_collapsed_margin = TrailingCollapsedMargin{
		child: unsafe { &Node(child) }
		margin: CSSPixels.new(19)
	}
	snapshot := context
	context.trailing_collapsed_margin = none
	$if gcboehm ? { C.GC_gcollect() }
	margin := snapshot.trailing_collapsed_margin or { panic('lost trailing margin') }
	assert margin.margin.to_double() == 19
	assert voidptr(margin.child) == voidptr(child)
	retained := margin.child.as_node_with_style() or { panic('lost styled child') }
	assert retained.layout_index() == 73
	assert context.trailing_collapsed_margin == none
}
