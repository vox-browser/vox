module layout

import css
import dom

fn test_intrinsic_seed_retains_external_blocks_with_shared_ancestor_chains() {
	document := dom.Document.create(dom.url_about_blank())
	style := css.ComputedProperties.new()
	mut outer := Box.new(document, none, style)
	mut external := Box.new(document, none, style)
	mut measured := Box.new(document, none, style)
	outer.set_layout_index(0)
	external.set_layout_index(1)
	measured.set_layout_index(2)
	external.containing_block_ = outer
	measured.containing_block_ = outer
	mut outer_node := unsafe { &Node(outer) }
	mut measured_node := unsafe { &Node(measured) }
	outer_node.append_child(unsafe { &Node(external) })
	outer_node.append_child(measured_node)
	for i in 0 .. 256 {
		mut child := Box.new(document, none, style)
		child.set_layout_index(u32(i + 3))
		// Hoisted positioned descendants can refer to a block outside this
		// subtree and outside the measured root's own containing-block chain.
		child.containing_block_ = if i % 2 == 0 { external } else { measured }
		measured_node.append_child(unsafe { &Node(child) })
	}
	mut source := LayoutState.new()
	mut outer_values := source.get_mutable(unsafe { &NodeWithStyle(outer) })
	outer_values.set_content_width(CSSPixels.new(100))
	mut external_values := source.get_mutable(unsafe { &NodeWithStyle(external) })
	external_values.set_content_width(CSSPixels.new(80))
	mut probe := LayoutState.new_for_subtree(unsafe { &NodeWithStyle(measured) })
	defer { probe.release_measurement() }
	populate_intrinsic_containing_block_chain(mut probe, mut source, measured_node)
	mut visited := map[u32]bool{}
	populate_intrinsic_external_containing_blocks_once(mut probe, mut source, measured_node, measured_node, mut visited)
	assert visited.len == 3
	assert probe.get(unsafe { &NodeWithStyle(outer) }).content_width().to_double() == 100
	assert probe.get(unsafe { &NodeWithStyle(external) }).content_width().to_double() == 80
	assert probe.try_get(unsafe { &NodeWithStyle(measured) }) == none
	assert source.get(unsafe { &NodeWithStyle(external) }).content_width().to_double() == 80
}
