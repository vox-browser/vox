module layout

import dom
import html
import platform

fn storage_text_lines(document &dom.Document, id string) []TextLine {
	element := document.get_element_by_id(id) or { panic('missing paint owner') }
	node := unsafe { &Node(element.as_node().unsafe_layout_node() or { panic('missing layout') }.real_layout_handle()) }
	result := document_layout_result(document) or { panic('missing layout result') }
	styled := node.as_node_with_style() or { panic('missing styled node') }
	used := result.state.try_get(styled) or { panic('missing geometry') }
	return uncached_text_lines_from_typed_layout(node, used, result.state,
		paint_cumulative_offset(node, result.state, used))
}

fn test_single_text_run_keeps_one_paint_fragment() {
	mut document := html.parse_document('<!doctype html><p id="text">alpha</p>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 200)
	lines := storage_text_lines(document, 'text')
	assert lines.len == 1
	assert lines.cap == 1
	assert lines[0].fragments.len == 1
	assert lines[0].fragments.cap == 1
	assert lines[0].fragments[0].text == 'alpha'
	assert lines[0].fragments[0].width > 0
	assert lines[0].box_decorations.cap == 0
}

fn test_atomic_inline_line_does_not_allocate_text_fragments() {
	mut document := html.parse_document('<!doctype html><p id="text"><span style="display:inline-block;width:20px;height:10px"></span></p>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 200)
	lines := storage_text_lines(document, 'text')
	assert lines.len == 1
	assert lines[0].width == 20
	assert lines[0].fragments.len == 0
	assert lines[0].fragments.cap == 0
	assert lines[0].box_decorations.cap == 0
}

fn test_multiple_text_runs_and_wrapped_lines_preserve_transport() {
	mut document := html.parse_document('<!doctype html><p id="runs">alpha<span style="color:red">beta</span>gamma</p><p id="wrapped" style="width:70px">one two three four five six seven eight</p>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 300)
	runs := storage_text_lines(document, 'runs')
	assert runs.len == 1
	assert runs[0].fragments.len == 3
	assert runs[0].fragments.cap == 3
	assert runs[0].fragments.map(it.text).join('') == 'alphabetagamma'
	assert runs[0].fragments[0].x < runs[0].fragments[1].x
	assert runs[0].fragments[1].x < runs[0].fragments[2].x
	assert runs[0].fragments[1].color.r == 255
	assert runs[0].fragments[1].color.g == 0
	wrapped := storage_text_lines(document, 'wrapped')
	assert wrapped.len > 1
	assert wrapped.cap == wrapped.len
	for index, line in wrapped {
		assert line.fragments.len > 0
		assert line.fragments.cap >= line.fragments.len
		assert line.height > 0
		if index > 0 {
			assert line.y > wrapped[index - 1].y
		}
	}
}

fn test_many_styled_runs_reserve_one_exact_transport_buffer() {
	mut markup := '<!doctype html><p id="text" style="white-space:nowrap">'
	for index in 0 .. 37 { markup += '<span style="color:rgb(${index},0,0)">x</span>' }
	markup += '</p>'
	mut document := html.parse_document(markup)
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 1000, 200)
	// Warm lazy style/font projections, then measure only the paint projection.
	_ = storage_text_lines(document, 'text')
	mut arena := platform.new_arena('exact fragment transport')
	entry := arena.enter()
	lines := storage_text_lines(document, 'text')
	arena.leave(entry)
	assert lines.len == 1
	assert lines[0].fragments.len == 37
	assert lines[0].fragments.cap == 37
	assert lines[0].fragments.map(it.text).join('') == 'x'.repeat(37)
	for index, fragment in lines[0].fragments { assert fragment.color.r == u8(index) }
	$if prealloc {
		// The final wide fragment buffer dominates this projection. A geometric
		// growth chain alone exceeds twice its size, before any paint metadata.
		assert arena.usage().used < i64(37 * sizeof(TextFragment) * 2)
	}
	arena.release()
}

fn test_atomic_inline_projection_does_not_copy_committed_line_fragments() {
	markup := '<!doctype html><p id="text" style="white-space:nowrap">'
		+ '<span style="display:inline-block;width:1px;height:10px"></span>'.repeat(64)
		+ '</p>'
	mut document := html.parse_document(markup)
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 1000, 200)
	_ = storage_text_lines(document, 'text')
	mut arena := platform.new_arena('atomic fragment projection')
	entry := arena.enter()
	lines := storage_text_lines(document, 'text')
	arena.leave(entry)
	assert lines.len == 1
	assert lines[0].width == 64
	assert lines[0].fragments.len == 0
	$if prealloc {
		// Only line metadata is needed. Copying each committed fragment into
		// the arena just to query it consumes tens of kilobytes here.
		assert arena.usage().used < 4096, '${arena.usage().used} bytes for an atomic-only line'
	}
	arena.release()
}
