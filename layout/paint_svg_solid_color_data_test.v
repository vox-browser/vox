module layout

import css
import dom
import html
import painting

$if gcboehm ? {
	fn C.GC_gcollect()
}

fn solid_svg_recording(mut document dom.Document) PaintCommand {
	commands := display_list_commands(document.record_display_list() or {
		panic('missing SVG recording')
	}).filter(it.kind == 'draw_svg_path')
	assert commands.len == 1
	return commands[0]
}

fn test_svg_adapter_retains_solid_colors_across_recordings_and_collection() {
	mut document := html.parse_document('<!doctype html><svg width="40" height="30"><path d="M0 0L30 0L30 20Z" fill="rgb(12 34 56 / .5)" stroke="rgb(78 90 123 / .25)"/></svg>')
	_ = layout_document_typed_in_viewport(document, 80, 60)
	first := solid_svg_recording(mut document)
	data := first.svg().svg_solid_color_data
	assert data != unsafe { nil }
	assert first.retained_svg_fill_color() == css.parse_color_string(first.color)
	assert first.retained_svg_stroke_color() == css.parse_color_string(first.stroke_color)
	document.set_needs_repaint_with_invalidation(.paint_commands)
	second := solid_svg_recording(mut document)
	assert voidptr(second.svg().svg_solid_color_data) == voidptr(data)
	for _ in 0 .. 3 {
		$if gcboehm ? {
			C.GC_gcollect()
		}
		assert (first.retained_svg_fill_color() or { panic('missing retained solid color') }) == css.Color{12, 34, 56, 128}
		assert (second.retained_svg_stroke_color() or { panic('missing retained solid color') }) == css.Color{78, 90, 123, 64}
	}
}

fn test_svg_solid_color_keys_invalidate_each_changed_channel_and_force_dark_copy() {
	fill := css.Color{0, 0, 0, 255}
	stroke := css.Color{255, 255, 255, 128}
	command := PaintCommand{
		kind:                 'draw_svg_path'
		color:                fill.serialize()
		stroke_color:         stroke.serialize()
		force_dark_role:      .svg
		force_dark_role_set:  true
		svg_data: &PaintSVGPathData{
			svg_solid_color_data: retained_svg_solid_color_data(fill.serialize(), fill,
				stroke.serialize(), stroke)
		}
	}
	mut changed := command
	changed.color = 'red'
	assert changed.retained_svg_fill_color() == none
	assert (changed.retained_svg_stroke_color() or { panic('missing retained solid color') }) == stroke
	changed = command
	changed.stroke_color = ''
	assert (changed.retained_svg_fill_color() or { panic('missing retained solid color') }) == fill
	assert changed.retained_svg_stroke_color() == none
	changed.color = 'invalid-color'
	assert changed.retained_svg_fill_color() == none
	dark := resolve_force_dark_paint_commands([command], painting.ForceDarkSettings.default())[0]
	assert dark.color != command.color
	assert dark.retained_svg_fill_color() == none
	if dark.stroke_color != command.stroke_color {
		assert dark.retained_svg_stroke_color() == none
	}
	assert (command.retained_svg_fill_color() or { panic('missing retained solid color') }) == fill
	assert (command.retained_svg_stroke_color() or { panic('missing retained solid color') }) == stroke
}

fn test_svg_solid_color_mutation_replaces_snapshot_and_keeps_old_recording() {
	mut document := html.parse_document('<!doctype html><svg width="40" height="30"><path id="path" d="M0 0L30 0L30 20Z" fill="red" stroke="blue"/></svg>')
	_ = layout_document_typed_in_viewport(document, 80, 60)
	first := solid_svg_recording(mut document)
	mut path := document.get_element_by_id('path') or { panic('missing path') }
	path.set_attribute_value('fill', 'rgb(10 20 30 / .5)')
	path.set_attribute_value('stroke', 'none')
	_ = layout_document_typed_in_viewport(document, 80, 60)
	second := solid_svg_recording(mut document)
	assert voidptr(first.svg().svg_solid_color_data) != voidptr(second.svg().svg_solid_color_data)
	$if gcboehm ? {
		C.GC_gcollect()
	}
	assert (first.retained_svg_fill_color() or { panic('missing retained solid color') }) == css.Color{255, 0, 0, 255}
	assert (first.retained_svg_stroke_color() or { panic('missing retained solid color') }) == css.Color{0, 0, 255, 255}
	assert (second.retained_svg_fill_color() or { panic('missing retained solid color') }) == css.Color{10, 20, 30, 128}
	assert second.retained_svg_stroke_color() == none
}

fn test_non_solid_svg_and_ordinary_commands_do_not_allocate_solid_color_data() {
	assert (PaintCommand{ kind: 'draw_text' }).svg().svg_solid_color_data == unsafe { nil }
	assert (PaintCommand{ kind: 'fill_rect' }).svg().svg_solid_color_data == unsafe { nil }
	assert retained_svg_solid_color_data('', none, '', none) == unsafe { nil }
	mut document := html.parse_document('<!doctype html><svg width="40" height="30"><defs><linearGradient id="g"><stop stop-color="red"/></linearGradient></defs><path d="M0 0L30 0L30 20Z" fill="url(#g)" stroke="none"/></svg>')
	_ = layout_document_typed_in_viewport(document, 80, 60)
	command := solid_svg_recording(mut document)
	assert command.svg().svg_solid_color_data == unsafe { nil }
	assert command.retained_svg_fill_color() == none
	assert command.retained_svg_stroke_color() == none
	assert command.fill_linear_gradient() != none
}

fn test_chromium_svg_solids_keep_modern_rgb_alpha_before_byte_conversion() {
	for chromium in [true, false] {
		mut document := html.parse_document('<!doctype html><svg width="40" height="30"><path d="M0 0L30 0L30 20Z" fill="rgb(51 91 131 / 59%)" stroke="rgb(190 70 20 / 30%)"/></svg>')
		defer { document.finalize() }
		if chromium { document.set_font_rendering_policy(.chromium) }
		_ = layout_document_typed_in_viewport(document, 80, 60)
		command := solid_svg_recording(mut document)
		assert command.retained_svg_fill_color()? == css.Color{51, 91, 131, 150}
		assert command.retained_svg_stroke_color()? == css.Color{190, 70, 20, 77}
		if chromium {
			assert command.retained_svg_solid_alpha(false)? == 0.59
			assert command.retained_svg_solid_alpha(true)? == 0.3
		} else {
			assert command.retained_svg_solid_alpha(false) == none
			assert command.retained_svg_solid_alpha(true) == none
		}
	}
}

fn test_svg_alpha_snapshots_follow_currentcolor_mutations_and_preserve_old_recordings() {
	mut document := html.parse_document('<!doctype html><svg width="40" height="30" style="color:rgb(51 91 131 / 59%)"><path id="alpha-path" d="M0 0L30 0L30 20Z" fill="currentColor"/></svg>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 80, 60)
	first := solid_svg_recording(mut document)
	assert first.retained_svg_solid_alpha(false)? == 0.59
	mut path := document.get_element_by_id('alpha-path') or { panic('missing alpha path') }
	path.set_attribute_value('fill', 'rgb(51 91 131 / 31%)')
	_ = layout_document_typed_in_viewport(document, 80, 60)
	second := solid_svg_recording(mut document)
	$if gcboehm ? { C.GC_gcollect() }
	assert first.retained_svg_solid_alpha(false)? == 0.59
	assert second.retained_svg_solid_alpha(false)? == 0.31
	path.set_attribute_value('fill', 'rgb(51 91 131 / .3101)')
	_ = layout_document_typed_in_viewport(document, 80, 60)
	third := solid_svg_recording(mut document)
	assert second.color == third.color
	assert second.retained_svg_solid_alpha(false)? == 0.31
	assert third.retained_svg_solid_alpha(false)? == 0.3101
	mut changed := second
	changed.color = 'red'
	assert changed.retained_svg_solid_alpha(false) == none
}

fn test_legacy_svg_alpha_and_exact_byte_values_keep_the_existing_color_path() {
	for color in ['rgba(51,91,131,.59)', 'rgb(51 91 131 / 20%)', 'rgb(51 91 131)'] {
		mut document := html.parse_document('<!doctype html><svg width="40" height="30"><path d="M0 0L30 0L30 20Z" fill="${color}"/></svg>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		_ = layout_document_typed_in_viewport(document, 80, 60)
		command := solid_svg_recording(mut document)
		assert command.retained_svg_solid_alpha(false) == none
	}
}
