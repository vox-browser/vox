module layout

import dom
import html

fn backoff_layout_node(document &dom.Document, id string) &Node {
	element := document.get_element_by_id(id) or { panic('missing element ${id}') }
	return unsafe { &Node(element.as_node().unsafe_layout_node() or { panic('missing layout ${id}') }.real_layout_handle()) }
}

fn backoff_has_snapshot(document &dom.Document, id string) bool {
	result := document_layout_result(document) or { panic('missing layout') }
	return u64(voidptr(backoff_layout_node(document, id))) in result.state.block_layouts_
}

fn backoff_snapshot(document &dom.Document, id string) voidptr {
	result := document_layout_result(document) or { panic('missing layout') }
	return voidptr(result.state.block_layouts_[u64(voidptr(backoff_layout_node(document, id)))] or {
		return unsafe { nil }
	})
}

fn backoff_append_item(mut document dom.Document, index int) {
	host := document.get_element_by_id('host') or { panic('missing host') }
	mut item := document.create_element('p') or { panic(err) }
	mut item_node := unsafe { &dom.Node(item.as_node()) }
	item_node.append_child(document.create_text_node('item ${index}').as_node()) or { panic(err) }
	mut host_node := unsafe { &dom.Node(host.as_node()) }
	host_node.append_child(item.as_node()) or { panic(err) }
	document.update_layout(.debugging)
}

fn backoff_assert_full_layout(mut document dom.Document) {
	before := (document.record_display_list() or { panic('missing paint') }).dump()
	document.set_needs_full_layout_tree_update(true)
	document.update_layout(.debugging)
	assert (document.record_display_list() or { panic('missing rebuilt paint') }).dump() == before
}

fn test_rebuilt_ancestor_stops_recording_snapshots_while_nested_context_is_reused() {
	mut document := html.parse_document('<!doctype html><div id="changed"></div><section id="outer" style="overflow:hidden;width:300px"><div id="inner" style="overflow:hidden">Stable words that never change.</div><div id="host" style="overflow:hidden"></div></section>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	assert backoff_has_snapshot(document, 'outer')
	inner := backoff_snapshot(document, 'inner')
	assert inner != unsafe { nil }
	mut outer_layout_nodes := []voidptr{}
	mut recorded := []bool{}
	for index in 0 .. 8 {
		backoff_append_item(mut document, index)
		outer_layout_nodes << voidptr(backoff_layout_node(document, 'outer'))
		recorded << backoff_has_snapshot(document, 'outer')
		// The unchanged nested context keeps the snapshot it recorded first.
		assert backoff_snapshot(document, 'inner') == inner
	}
	// Each insertion rebuilds the ancestor's layout node, orphaning its snapshot.
	for index in 1 .. outer_layout_nodes.len {
		assert outer_layout_nodes[index] != outer_layout_nodes[index - 1]
	}
	// One orphaned snapshot records again at once; consecutive ones back off.
	assert recorded[0]
	assert recorded.filter(it).len < recorded.len / 2
	assert document.get_element_by_id('host')?.get_bounding_client_rect().height > 0
	backoff_assert_full_layout(mut document)
}

fn test_backed_off_context_records_again_and_is_reused_once_it_stops_changing() {
	mut document := html.parse_document('<!doctype html><div id="changed"></div><section id="outer" style="overflow:hidden;width:300px"><div id="host" style="overflow:hidden"></div></section>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	for index in 0 .. 6 {
		backoff_append_item(mut document, index)
	}
	assert !backoff_has_snapshot(document, 'outer')
	// Changes outside the context relayout it without rebuilding its layout node.
	outer := voidptr(backoff_layout_node(document, 'outer'))
	mut changed := document.get_element_by_id('changed')?
	mut reused := false
	mut previous := unsafe { nil }
	for height in 1 .. 40 {
		changed.set_attribute_value('style', 'height:${height}px')
		document.update_layout(.debugging)
		assert voidptr(backoff_layout_node(document, 'outer')) == outer
		current := backoff_snapshot(document, 'outer')
		if current != unsafe { nil } && current == previous {
			reused = true
			break
		}
		previous = current
	}
	assert reused
	assert document.get_element_by_id('outer')?.get_bounding_client_rect().y > 0
	backoff_assert_full_layout(mut document)
}

fn backoff_record(document &dom.Document, id string, inline bool) RetainedBlockBackoff {
	result := document_layout_result(document) or { panic('missing layout') }
	node := backoff_layout_node(document, id)
	key := if inline { retained_inline_backoff_key(node) or { panic('no key') } } else {
		retained_block_backoff_key(node) or { panic('no key') }
	}
	return result.state.block_layout_backoff_.entries[key] or { RetainedBlockBackoff{} }
}

fn test_rejected_inputs_stop_being_collected_until_the_backoff_expires() {
	mut document := html.parse_document('<!doctype html><style>#para::before{content:"x"}</style><div id="changed"></div><section id="outer" style="overflow:hidden;width:300px"><ul><li>Item</li></ul></section><p id="para">Generated content before plain words.</p>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	mut changed := document.get_element_by_id('changed')?
	for height in 1 .. 6 {
		changed.set_attribute_value('style', 'height:${height}px')
		document.update_layout(.debugging)
	}
	// Both contexts are rejected on every attempt (a list item, a pseudo-element),
	// so later passes skip collecting their inputs.
	block := backoff_record(document, 'outer', false)
	assert block.misses >= 2
	inline := backoff_record(document, 'para', true)
	assert inline.misses >= 2
	assert !backoff_has_snapshot(document, 'outer')
	result := document_layout_result(document) or { panic('missing layout') }
	assert u64(voidptr(backoff_layout_node(document, 'para'))) !in result.state.inline_layouts_
	backoff_assert_full_layout(mut document)
}

fn test_inline_snapshot_misses_do_not_back_off() {
	mut document := html.parse_document('<!doctype html><div id="changed"></div><p id="para" style="width:200px">Plain words that wrap across a couple of lines here.</p>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	mut para := document.get_element_by_id('para')?
	for width in 0 .. 4 {
		// Each width change invalidates the snapshot; the next pass records again.
		para.set_attribute_value('style', 'width:${200 + width * 10}px')
		document.update_layout(.debugging)
		result := document_layout_result(document) or { panic('missing layout') }
		assert u64(voidptr(backoff_layout_node(document, 'para'))) in result.state.inline_layouts_
	}
	assert backoff_record(document, 'para', true).misses == 0
	backoff_assert_full_layout(mut document)
}
