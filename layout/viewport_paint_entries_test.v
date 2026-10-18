module layout

import dom
import html

fn viewport_test_commands(mut document dom.Document) []PaintCommand {
	return display_list_commands(document.record_viewport_display_list() or { panic('missing viewport list') })
}

fn test_viewport_recording_defers_offscreen_entries_and_populates_them_after_scroll() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}div{height:100px}#first{background:red}#last{background:blue}</style><div id="first">first</div><div>middle</div><div id="last">last</div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 100)
	initial := viewport_test_commands(mut document)
	assert initial.any(it.color == 'rgb(255 0 0)')
	assert !initial.any(it.color == 'rgb(0 0 255)')
	mut result := document_layout_result(document)?
	assert result.paint_phase_entry_valid.any(!it)
	storage := result.paint_tree.children.data
	snapshot := initial.map('${it.kind}:${it.color}:${it.text}:${it.transform}')
	document.set_viewport_rect(dom.Rect{0, 200, 320, 100})
	scrolled := viewport_test_commands(mut document)
	assert scrolled.any(it.color == 'rgb(0 0 255)')
	assert !scrolled.any(it.color == 'rgb(255 0 0)')
	assert result.paint_tree.children.data == storage
	assert initial.map('${it.kind}:${it.color}:${it.text}:${it.transform}') == snapshot
	full := display_list_commands(document.record_display_list()?)
	assert full.any(it.color == 'rgb(255 0 0)') && full.any(it.color == 'rgb(0 0 255)')
	assert result.paint_phase_entry_valid.all(it)
	again := viewport_test_commands(mut document)
	assert again.map('${it.kind}:${it.color}:${it.text}:${it.transform}') == scrolled.map('${it.kind}:${it.color}:${it.text}:${it.transform}')
}

fn test_viewport_recording_keeps_overflowing_transformed_and_fixed_descendants() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}#parent{position:absolute;top:1000px;width:20px;height:20px;background:red}#child{position:absolute;top:-1000px;width:20px;height:20px;background:green}#transformed{position:absolute;top:1200px;transform:translateY(-1200px);width:20px;height:20px;background:blue}#fixed{position:fixed;top:30px;width:20px;height:20px;background:purple}</style><div id="parent"><div id="child"></div></div><div id="transformed"></div><div id="fixed"></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 100)
	commands := viewport_test_commands(mut document)
	assert !commands.any(it.color == 'rgb(255 0 0)')
	for color in ['rgb(0 128 0)', 'rgb(0 0 255)', 'rgb(128 0 128)'] {
		assert commands.any(it.color == color)
	}
}

fn test_viewport_recording_preserves_complete_effect_inputs_and_svg_resources() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}#effect{position:absolute;top:1000px;filter:drop-shadow(0 -1000px 0 red)}#child{width:20px;height:20px;background:green}</style><div id="effect"><div id="child"></div></div><svg style="position:absolute;top:1200px" width="20" height="20"><rect width="20" height="20" fill="blue"/></svg>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 100)
	full := (document.record_display_list()?).dump()
	assert (document.record_viewport_display_list()?).dump() == full
}

fn test_viewport_ink_guards_keep_native_precision_and_unbounded_text_inputs() {
	assert !viewport_rect_is_outside(LayoutRect{1_000_001, 10, 20, 20}, [f64(1), 0, 0, 1, -1_000_001, 0]!, 320, 100)
	assert viewport_rect_is_outside(LayoutRect{10, 1000, 20, 20}, [f64(1), 0, 0, 1, 0, 0]!, 320, 100)
	fragment := TextFragment{x: 10, y: 1000, width: 20, height: 20, text: 'text'}
	assert !viewport_fragment_ink_is_outside(&fragment, [f64(1), 0, 0, 1, 0, 0]!, 320, 100)
}
