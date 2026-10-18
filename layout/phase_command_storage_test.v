module layout

import html

fn test_relayout_reuses_phase_buffers_without_changing_published_command_snapshots() {
	mut document := html.parse_document('<!doctype html><div id="label">before</div>' + '<p>unchanged <b>text</b></p>'.repeat(16))
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	// The published list stays valid while its holder retains its scene.
	initial := record_retained_display_list(mut document)?
	initial_dump := initial.dump()
	initial_commands := display_list_commands(initial)
	initial_snapshot := initial_commands.map(it.str())
	mut previous := document_layout_result(document)?
	headers := previous.paint_phase_commands.data
	buffers := previous.paint_phase_commands.map(it.data)
	mut label := document.get_element_by_id('label')?
	label.set_inner_html('after')!
	document.update_layout(.debugging)
	mut current := document_layout_result(document)?
	assert current.paint_phase_commands.data == headers
	assert previous.paint_phase_commands.len == 0
	assert !previous.paint_phase_cache_valid
	updated := document.record_display_list()?
	assert current.paint_phase_commands.data == headers
	mut reused := 0
	for index, bucket in current.paint_phase_commands {
		if bucket.cap > 0 && bucket.data == buffers[index] { reused++ }
	}
	assert reused >= 16
	assert display_list_commands(updated).any(it.text == 'after')
	assert initial.dump() == initial_dump
	assert initial_commands.map(it.str()) == initial_snapshot
	gc_collect()
	assert initial.dump() == initial_dump
}

fn test_phase_storage_remaps_grown_and_shrunk_trees_and_matches_fresh_recording() {
	mut document := html.parse_document('<!doctype html><div id="target"><p>initial</p></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	_ = document.record_display_list()?
	mut target := document.get_element_by_id('target')?
	for markup in ['<p>first</p><p style="color:red">second</p>'.repeat(16), '<p>small</p>', '<p style="background:lime">last</p>'] {
		target.set_inner_html(markup)!
		document.update_layout(.debugging)
		// Retained: the list is compared after the next recording.
		list := record_retained_display_list(mut document)?
		recording_dump := list.dump()
		commands := display_list_commands(list)
		snapshot := commands.map(it.str())
		mut result := document_layout_result(document)?
		result.paint_phase_commands = [][]PaintCommand{}
		result.paint_phase_cache_valid = false
		result.display_list = unsafe { nil }
		result.needs_repaint = true
		document.invalidate_display_list()
		assert document.record_display_list()?.dump() == recording_dump
		assert commands.map(it.str()) == snapshot
	}
}

fn test_phase_bucket_growth_preserves_prefix_and_drops_oversized_private_capacity() {
	mut recorder := new_paint_phase_command_recorder(1)
	mut commands := [PaintCommand{kind:'fill_rect',color:'red',paint_box_index:0,paint_phase:.background}]
	recorder.publish_commands(mut commands)
	first := recorder.phase_commands[0].data
	commands << PaintCommand{kind:'fill_rect',color:'blue',paint_box_index:0,paint_phase:.background}
	recorder.publish_commands(mut commands)
	assert recorder.phase_commands[0].map(it.color) == ['red','blue']
	assert recorder.phase_commands[0].data != first
	mut oversized := []PaintCommand{cap:256}
	oversized << PaintCommand{kind:'fill_rect',color:'kept'}
	recorder.phase_commands[0] = oversized
	recorder.reserve_phase_bucket(0, 1)
	assert recorder.phase_commands[0].cap == 2
	assert recorder.phase_commands[0][0].color == 'kept'
}
