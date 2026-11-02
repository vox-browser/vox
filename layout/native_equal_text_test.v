module layout

import dom
import html

fn equal_text_run_id(box &BlockBox, handle voidptr) ?i64 {
	for line in box.lines {
		for fragment in line.fragments {
			if fragment.layout_handle == handle { return fragment.text_run_id }
		}
	}
	for child in box.children {
		if id := equal_text_run_id(child, handle) { return id }
	}
	return none
}

fn equal_text_document(tag string) !&dom.Document {
	u := dom.URL{ value: 'https://equal-text.test/' }
	mut document := html.create_navigation_document(u, u.origin(), none)!
	document.enable_native_storage()
	mut allocation := document.enter_native_storage()
	html.parse_html_from_a_string(document, '<!doctype html><p>Timestamp <${tag} id="stamp">2 days ago</${tag}></p><p id="other">Unchanged text</p>')
	allocation.finish()
	enable_native_paint_tree_storage(document)
	_ = layout_document_typed_in_viewport(document, 400, 300)
	return document
}

fn retire_equal_text_document(mut document dom.Document) {
	handle := document.layout_engine_handle()
	document.destroy_a_document_and_its_descendants()
	document.finalize()
	retire_native_document_layout(handle)
	document.release_native_storage()
}

fn test_equal_text_reuses_geometry_and_preserves_new_text_identity_and_ranges() {
	$if !prealloc {
		return
	}
	mut document := equal_text_document('span')!
	defer { retire_equal_text_document(mut document) }
	mut stamp := document.get_element_by_id('stamp')?.as_node()
	old := stamp.first_child()?
	old_layout := old.unsafe_layout_node()?
	mut range := document.create_range()
	range.set_start(old, 2)!
	range.set_end(old, 5)!
	mut observer := dom.MutationObserver.construct_impl(none)!
	mut options := dom.MutationObserverOptions{ child_list: true }
	observer.observe(stamp, mut options)!
	defer { observer.disconnect() }
	document.mutation_observer_microtask_queued = true
	before := document.layout_engine_handle()
	old_display := document.record_display_list()?
	previous_commands := old_display.dump()
	stamp.set_text_content('')!
	stamp.set_text_content('2 days ago')!
	fresh := stamp.first_child()?
	assert voidptr(fresh) != voidptr(old)
	assert voidptr(range.start_container()) == voidptr(stamp)
	assert voidptr(range.end_container()) == voidptr(stamp)
	assert range.start_offset() == 0
	document.update_layout(.debugging)
	assert document.layout_engine_handle() == before
	assert old.unsafe_layout_node() == none
	assert voidptr(fresh.unsafe_layout_node()?) == voidptr(old_layout)
	assert voidptr(old_layout.dom_node_?) == voidptr(fresh)
	new_display := document.record_display_list()?
	assert new_display.dump() == previous_commands
	current := document_layout_result(document)?
	assert equal_text_run_id(&current.paint_tree, old_layout.real_layout_handle())? == i64(fresh.unique_id())
	records := observer.take_records()
	assert records.len == 2
	assert voidptr(records[0].removed_nodes[0]) == voidptr(old)
	assert voidptr(records[1].added_nodes[0]) == voidptr(fresh)
	for _ in 0 .. 25 {
		stamp.set_text_content('')!
		stamp.set_text_content('2 days ago')!
		document.update_layout(.debugging)
		assert document.layout_engine_handle() == before
	}
}

fn test_equal_text_falls_back_for_real_text_style_structure_and_viewport_changes() {
	$if !prealloc {
		return
	}
	for change in ['text', 'style', 'structure', 'viewport', 'other'] {
		mut document := equal_text_document('span')!
		defer { retire_equal_text_document(mut document) }
		mut stamp := document.get_element_by_id('stamp')?
		mut node := stamp.as_node()
		before := document.layout_engine_handle()
		node.set_text_content('')!
		node.set_text_content(if change == 'text' { '3 days ago' } else { '2 days ago' })!
		if change == 'style' { stamp.set_attribute_value('style', 'font-size:30px') }
		if change == 'structure' { stamp.set_inner_html('<b>2 days ago</b>')! }
		if change == 'other' {
			mut other := document.get_element_by_id('other')?.as_node()
			other.set_text_content('Changed other content')!
		}
		_ = layout_document_typed_in_viewport(document, if change == 'viewport' { 450 } else { 400 }, 300)
		assert document.layout_engine_handle() != before, change
	}
}

fn equal_text_allocation_trial(disable_reuse bool) !i64 {
	mut document := equal_text_document('span')!
	defer { retire_equal_text_document(mut document) }
	element := document.get_element_by_id('stamp') or { return error('missing stamp') }
	mut stamp := element.as_node()
	owner := document.native_storage()
	before := owner.arena.usage().used
	for _ in 0 .. 50 {
		stamp.set_text_content('')!
		stamp.set_text_content('2 days ago')!
		if disable_reuse {
			mut previous := document_layout_result(document) or { return error('missing layout') }
			previous.equal_text_cache = unsafe { nil }
		}
		document.update_layout(.debugging)
		_ = document.record_display_list() or { return error('missing display list') }
	}
	return owner.arena.usage().used - before
}

fn test_equal_text_avoids_retaining_a_new_layout_graph_for_each_refresh() {
	$if !prealloc {
		return
	}
	control := equal_text_allocation_trial(true)!
	candidate := equal_text_allocation_trial(false)!
	println('Native equal text: candidate=${candidate} control=${control} retained bytes')
	assert candidate * 2 < control, '${candidate} candidate bytes versus ${control} control bytes'
}

fn test_equal_text_time_nodes_reuse_geometry_beside_generated_content() {
	$if !prealloc {
		return
	}
	mut document := equal_text_document('time')!
	defer { retire_equal_text_document(mut document) }
	mut other := document.get_element_by_id('other')?
	other.set_inner_html('<style>#other::before{content:"Generated"}</style>Unchanged text')!
	document.update_layout(.debugging)
	mut stamp := document.get_element_by_id('stamp')?.as_node()
	before := document.layout_engine_handle()
	stamp.set_text_content('')!
	stamp.set_text_content('2 days ago')!
	document.update_layout(.debugging)
	assert document.layout_engine_handle() == before
}

fn test_equal_text_keeps_dom_styles_separate_from_viewport_overflow_overrides() {
	$if !prealloc {
		return
	}
	mut document := equal_text_document('time')!
	defer { retire_equal_text_document(mut document) }
	mut root := document.document_element()?
	root.set_attribute_value('style', 'overflow-x:hidden;overflow-y:scroll')
	document.update_layout(.debugging)
	mut stamp := document.get_element_by_id('stamp')?.as_node()
	before := document.layout_engine_handle()
	stamp.set_text_content('')!
	stamp.set_text_content('2 days ago')!
	document.update_layout(.debugging)
	assert document.layout_engine_handle() == before
}

fn test_equal_text_preserves_synthetic_control_owners_and_unrelated_split_text() {
	$if !prealloc {
		return
	}
	mut document := equal_text_document('time')!
	defer { retire_equal_text_document(mut document) }
	mut other := document.get_element_by_id('other')?
	other.set_inner_html('<style>#letter::first-letter{font-size:24px}</style><p id="letter">Initial letter</p><input id="editor" placeholder="Search"><textarea>Existing value</textarea>')!
	document.update_layout(.debugging)
	mut stamp := document.get_element_by_id('stamp')?.as_node()
	before := document.layout_engine_handle()
	commands := document.record_display_list()?.dump()
	stamp.set_text_content('')!
	stamp.set_text_content('2 days ago')!
	document.update_layout(.debugging)
	assert document.layout_engine_handle() == before
	assert document.record_display_list()?.dump() == commands
	// A real removal still invalidates the snapshot even though some of its
	// unchanged control owners were already disconnected synthetic nodes.
	stamp.set_text_content('')!
	stamp.set_text_content('2 days ago')!
	mut editor := document.get_element_by_id('editor')?.as_node()
	editor.remove(false)
	document.update_layout(.debugging)
	assert document.layout_engine_handle() != before
}
