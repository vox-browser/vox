module layout

import html

struct PaintArenaReferenceFrame {
	node &Node
	box &BlockBox
}

// The former per-parent allocator is an independent construction oracle.
fn paint_arena_reference_tree(node &Node, state &LayoutState, transform [6]f64) BlockBox {
	mut root := block_box_from_typed_layout_shallow(node, state, transform)
	mut queue := [PaintArenaReferenceFrame{node: node, box: &root}]
	mut index := 0
	for index < queue.len {
		entry := queue[index]
		mut parent := unsafe { &BlockBox(entry.box) }
		children := typed_paint_child_nodes(entry.node, state)
		mut boxes := []BlockBox{cap: children.len}
		mut nodes := []&Node{cap: children.len}
		for child in children {
			box := block_box_from_typed_layout_shallow(child, state, parent.paint_transform)
			if box.tag_name == '' && !child.is_anonymous() && !child.is_generated_for_pseudo_element() { continue }
			boxes << box
			nodes << child
		}
		parent.children = boxes
		for child_index, child in nodes {
			queue << PaintArenaReferenceFrame{node: child, box: unsafe { &parent.children[child_index] }}
		}
		index++
	}
	return root
}

fn paint_arena_tree_snapshot(root &BlockBox) []string {
	mut snapshot := []string{}
	mut pending := [root]
	for pending.len > 0 {
		node := pending.pop()
		assert snapshot.len < 10000, 'cyclic paint tree'
		mut shallow := *node
		shallow.children = []BlockBox{}
		snapshot << '${node.children.len}:${shallow}'
		for index := node.children.len - 1; index >= 0; index-- {
			pending << unsafe { &node.children[index] }
		}
	}
	return snapshot
}

fn test_paint_arena_matches_separate_child_vectors_for_flow_special_and_generated_boxes() {
	for markup in [
		'<div style="transform:translate(3px,5px)">' + '<section><p>text <strong>bold</strong></p></section>'.repeat(64) + '</div>',
		'<style>p::before{content:"generated"}span{display:contents}</style><p><span>unboxed</span><br>end</p><input value="input"><svg width="20" height="20"><rect width="20" height="20" fill="red"/></svg>',
		'<div style="display:flex"><p>one</p><p>two</p></div><table style="border-collapse:collapse"><tr><td>A</td><td style="visibility:collapse">B</td></tr></table>',
	] {
		mut document := html.parse_document('<!doctype html>' + markup)
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 400, 300)
		result := document_layout_result(document)?
		root := result.root.first_child()?
		actual := build_typed_paint_tree_in_arena(root, result.state, [6]f64{})
		expected := paint_arena_reference_tree(root, result.state, [6]f64{})
		// Ownership and array headers differ by design. Compare all serialized
		// box data and the independently generated paint stream instead.
		assert paint_arena_tree_snapshot(&actual) == paint_arena_tree_snapshot(&expected)
		assert actual.paint_commands().map(it.str()) == expected.paint_commands().map(it.str())
	}
}

fn test_paint_arena_child_slices_survive_collection_and_grow_without_overwriting_neighbors() {
	mut document := html.parse_document('<!doctype html><div id="first"><p>first child</p></div><div id="second"><p>second child</p></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	result := document_layout_result(document)?
	mut tree := build_typed_paint_tree_in_arena(result.root.first_child()?, result.state, [6]f64{})
	mut body := &tree
	for index, child in tree.children {
		if child.tag_name == 'body' {
			body = unsafe { &tree.children[index] }
			break
		}
	}
	assert body.tag_name == 'body'
	assert body.children.len == 2
	neighbor := body.children[1]
	gc_collect()
	assert body.children[1] == neighbor
	mut first := &body.children[0]
	first.children << BlockBox{tag_name: 'added'}
	assert first.children.last().tag_name == 'added'
	assert body.children[1] == neighbor
	assert body.children[1].children[0].tag_name == 'p'
}

fn test_new_paint_arenas_preserve_previous_geometry_and_recordings_after_mutations() {
	mut document := html.parse_document('<!doctype html><div id="parent" style="width:300px"><p>text that wraps after the next layout</p></div>')
	defer { document.finalize() }
	previous := layout_document_typed_in_viewport(document, 400, 300)
	old_list := document.record_display_list()?
	old_dump := old_list.dump()
	old_body := previous.children.filter(it.tag_name == 'body')[0]
	old_width := old_body.children[0].width
	mut parent := document.get_element_by_id('parent')?
	parent.set_attribute_value('style', 'width:80px')
	document.update_layout(.debugging)
	current := document_layout_result(document)?
	current_body := current.paint_tree.children.filter(it.tag_name == 'body')[0]
	assert current_body.children[0].width == 80
	assert old_body.children[0].width == old_width
	assert old_list.dump() == old_dump
	gc_collect()
	assert old_list.dump() == old_dump
}
