module layout

import dom
import html
import painting
import platform

$if gcboehm ? {
	fn C.GC_get_total_bytes() uint
}

fn viewport_test_commands(mut document dom.Document) []PaintCommand {
	return display_list_commands(document.record_viewport_display_list() or { panic('missing viewport list') })
}

fn test_viewport_recording_defers_offscreen_entries_and_populates_them_after_scroll() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}div{height:100px}#first{background:red}#last{background:blue}</style><div id="first">first</div><div>middle</div><div id="last">last</div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 100)
	initial_list := document.record_viewport_display_list()?
	initial_scene := retain_display_list_scene(initial_list)
	defer { release_display_list_scene(initial_scene) }
	initial := display_list_commands(initial_list)
	assert initial.any(it.color == 'rgb(255 0 0)')
	assert !initial.any(it.color == 'rgb(0 0 255)')
	mut result := document_layout_result(document)?
	assert result.paint_phase_entry_valid.any(!it)
	storage := result.paint_tree.children.data
	snapshot := initial.map('${it.kind}:${it.color}:${it.text}:${it.transform}')
	document.set_viewport_rect(dom.Rect{0, 200, 320, 100})
	scrolled_list := document.record_viewport_display_list()?
	scrolled_scene := retain_display_list_scene(scrolled_list)
	defer { release_display_list_scene(scrolled_scene) }
	scrolled := display_list_commands(scrolled_list)
	assert scrolled.any(it.color == 'rgb(0 0 255)')
	assert !scrolled.any(it.color == 'rgb(255 0 0)')
	assert result.paint_tree.children.data == storage
	assert initial.map('${it.kind}:${it.color}:${it.text}:${it.transform}') == snapshot
	full_list := document.record_display_list()?
	full := display_list_commands(full_list)
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
	mut ink_probe := PaintCommand{blur: 10, outer_shadow: true}
	assert !viewport_rect_is_outside(LayoutRect{1_000_001, 10, 20, 20}, [f64(1), 0, 0, 1, -1_000_001, 0]!, 320, 100, mut ink_probe)
	assert viewport_rect_is_outside(LayoutRect{10, 1000, 20, 20}, [f64(1), 0, 0, 1, 0, 0]!, 320, 100, mut ink_probe)
	fragment := TextFragment{x: 10, y: 1000, width: 20, height: 20, text: 'text'}
	assert !viewport_fragment_ink_is_outside(&fragment, [f64(1), 0, 0, 1, 0, 0]!, 320, 100, mut ink_probe)
}

fn test_viewport_ink_probes_reuse_storage_for_rectangles_and_glyph_bounds() {
	run := &platform.GlyphRun{
		font_: &platform.Font{font_rendering_policy: .chromium}
		bounding_box_: platform.GlyphRunBounds{-4, -12, 40, 18}
	}
	fragment := TextFragment{
		x: 10, y: 1000, width: 20, height: 20, text: 'text', baseline_set: true
		baseline: 13, decoration: 'none'
		paintable_fragment: painting.PaintableFragment{glyph_run: run}
	}
	mut ink_probe := PaintCommand{}
	identity := [f64(1), 0, 0, 1, 0, 0]!
	mut before := uint(0)
	$if gcboehm ? { before = C.GC_get_total_bytes() }
	mut outside := 0
	for _ in 0 .. 4096 {
		if viewport_rect_is_outside(LayoutRect{10, 1000, 20, 20}, identity, 320, 100, mut ink_probe) { outside++ }
		if viewport_fragment_ink_is_outside(&fragment, identity, 320, 100, mut ink_probe) { outside++ }
	}
	mut allocated := uint(0)
	$if gcboehm ? { allocated = C.GC_get_total_bytes() - before }
	assert outside == 8192
	assert allocated < 8192, 'viewport ink probes allocated ${allocated} bytes'
	// A previous glyph command must not affect a later rectangle, or a changed
	// transform reuse an earlier result.
	assert viewport_rect_is_outside(LayoutRect{10, 1000, 20, 20}, identity, 320, 100, mut ink_probe)
	assert !viewport_fragment_ink_is_outside(&fragment, [f64(1), 0, 0, 1, 0, -1000]!, 320, 100, mut ink_probe)
}
