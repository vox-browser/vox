module layout

import html

fn measurement_backoff_pass(mut table RetainedBlockBackoffTable, root &Node, reuse bool) bool {
	table.pass++
	mut pool := &MeasurementUsedValuesChunkPool{ backoff_: table }
	allowed := pool.allows_measurement_recording(root, false)
	if allowed {
		pool.note_measurement(root, false, false)
		if reuse { pool.note_measurement(root, false, true) }
	}
	pool.release()
	return allowed
}

fn test_unused_measurement_recordings_back_off_and_reused_ones_do_not() {
	mut document := html.parse_document('<!doctype html><section id="flex" style="display:flex"><p>text</p></section>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	element := document.get_element_by_id('flex') or { panic('missing flex') }
	root := unsafe { &Node(element.as_node().unsafe_layout_node() or { panic('missing layout') }.real_layout_handle()) }
	mut table := &RetainedBlockBackoffTable{}
	// Recordings that are reused within their pass keep recording.
	for _ in 0 .. 6 { assert measurement_backoff_pass(mut table, root, true) }
	// Unused recordings: the first records again at once, later ones skip passes.
	mut allowed := []bool{}
	for _ in 0 .. 12 { allowed << measurement_backoff_pass(mut table, root, false) }
	assert allowed[0] && allowed[1]
	assert allowed.filter(it).len < allowed.len / 2
	// A reused recording resets the history.
	for !measurement_backoff_pass(mut table, root, true) {}
	assert measurement_backoff_pass(mut table, root, false)
	assert measurement_backoff_pass(mut table, root, false)
	key := retained_measurement_backoff_key(root, false) or { panic('no key') }
	inline_key := retained_measurement_backoff_key(root, true) or { panic('no key') }
	block_key := retained_block_backoff_key(root) or { panic('no key') }
	assert key != inline_key && key != block_key && inline_key != block_key
}
