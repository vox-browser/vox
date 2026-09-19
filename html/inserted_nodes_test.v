module html

import editing
import dom

fn test_inserted_nodes_tracks_structure_text_and_atomic_tail() {
	document := parse_document('<!doctype html><body><div id="host">leading<span>nested<img></span></div></body>')
	host := document.get_element_by_id('host') or { panic('missing host') }
	nodes := host.as_node().children_as_vector()
	mut inserted := editing.InsertedNodes.new(nodes)

	assert !inserted.is_empty()
	assert inserted.leading_content_kind() == .text_node
	assert inserted.first_node()? == nodes[0]
	assert inserted.last_node()? == nodes[1]
	assert inserted.last_atomic_node()?.as_element()?.local_name() == 'img'
	assert inserted.connected_nodes().len == 2
	assert inserted.connected_text_nodes().len == 2
	first_text := unsafe { &dom.Text(nodes[0]) }
	assert inserted.contains(first_text)

	mut first_node := unsafe { &dom.Node(nodes[0]) }
	first_node.remove(false)
	assert inserted.connected_nodes().len == 1
	assert !inserted.contains(first_text)

	replacement_first := document.create_text_node('replacement first').as_node()
	replacement_last := document.create_text_node('replacement last').as_node()
	inserted.did_replace_node_range(nodes[1], replacement_first, replacement_last)
	assert inserted.first_node()? == nodes[0]
	assert inserted.last_node()? == replacement_last
}

fn test_inserted_nodes_identifies_unwrapped_paragraph_text_and_ignores_br_tail() {
	document := parse_document('<!doctype html><body><div id="host"><p>paragraph</p><br></div></body>')
	host := document.get_element_by_id('host') or { panic('missing host') }
	inserted := editing.InsertedNodes.new(host.as_node().children_as_vector())

	assert inserted.leading_content_kind() == .unwrapped_paragraph_text
	assert inserted.last_atomic_node() == none
}
