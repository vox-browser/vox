module layout

import dom
import html

fn interest_test_document(extra string) &dom.Document {
	return html.parse_document('<!doctype html><style>html,body{margin:0}section{overflow:hidden;width:200px}#spacer{height:1000px}</style><div id="changed"></div><div id="spacer"></div>' + extra)
}

fn interest_test_project(mut document dom.Document) &DocumentLayoutResult {
	_ = document.record_viewport_display_list() or { panic('missing native recording') }
	mut changed := document.get_element_by_id('changed') or { panic('missing trigger') }
	changed.set_inner_html('<p>Changed preceding flow</p>') or { panic(err) }
	document.update_layout(.debugging)
	return document_layout_result(document) or { panic('missing projection') }
}

fn interest_test_id(document &dom.Document, id string) i64 {
	return i64((document.get_element_by_id(id) or { panic('missing ' + id) }).as_node().unique_id())
}

fn test_viewport_projection_keeps_geometry_and_restores_full_document_recording() {
	mut document := interest_test_document('<section id="clip"><p id="text">Offscreen comment</p></section>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 100)
	clip_id := interest_test_id(document, 'clip')
	text_id := interest_test_id(document, 'text')
	initial := document_layout_result(document)?
	assert initial.paint_tree.find_box(text_id) != none
	assert !initial.paint_projection_incomplete
	old := document.record_viewport_display_list()?
	old_scene := retain_display_list_scene(old)
	defer { release_display_list_scene(old_scene) }
	old_vector := display_list_commands(old)
	old_commands := old_vector.clone()
	mut result := interest_test_project(mut document)
	assert result.paint_projection_incomplete
	stub := result.paint_tree.find_box(clip_id)?
	assert !stub.visible && stub.children.len == 0 && stub.lines.len == 0
	assert result.paint_tree.find_box(text_id) == none
	root := document.get_element_by_id('clip')?.as_node().layout_node()?
	assert root.has_geometry_ && root.content_height_ > 0
	_ = document.record_display_list()?
	assert !result.paint_projection_incomplete
	complete := result.paint_tree.find_box(clip_id)?
	assert complete.visible && complete.border_box() == stub.border_box()
	assert result.paint_tree.find_box(text_id) != none
	assert old_vector == old_commands
}

fn test_viewport_projection_restores_offscreen_content_before_scroll_and_hit_testing() {
	mut document := interest_test_document('<section id="clip" style="background:blue"><p id="text">Offscreen comment</p></section>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 100)
	mut result := interest_test_project(mut document)
	assert result.paint_projection_incomplete
	clip_id := interest_test_id(document, 'clip')
	stub := result.paint_tree.find_box(clip_id)?
	document.set_viewport_rect(dom.Rect{0, stub.border_box().y, 320, 100})
	document.update_paint_and_hit_testing_properties_if_needed()
	assert !result.paint_projection_incomplete
	commands := display_list_commands(document.record_viewport_display_list()?)
	assert commands.any(it.color == 'rgb(0 0 255)')
	assert result.paint_tree.find_box(interest_test_id(document, 'text')) != none
	assert viewport_hit_test(voidptr(result), 10, 20, .exact) != none
}

fn test_viewport_projection_restores_text_ranges_and_element_client_geometry() {
	for text_range in [false, true] {
		mut document := interest_test_document('<section id="clip"><p id="text">Offscreen comment</p></section>')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 320, 100)
		mut result := interest_test_project(mut document)
		assert result.paint_projection_incomplete
		element := document.get_element_by_id('text')?
		if text_range {
			text := element.as_node().first_child()?
			rects := viewport_text_range_rects(voidptr(result), text, .start_and_end, 0, 4)
			assert rects.len > 0 && rects[0].width > 0
		} else {
			rects := viewport_transform_client_rects(voidptr(result), element.as_node(), [dom.CSSPixelRect_{x_:0,y_:1000,width_:20,height_:20}])
			assert rects.len == 1 && rects[0].height_ == 20
		}
		assert !result.paint_projection_incomplete
	}
}

fn test_viewport_projection_restores_before_paint_only_ancestor_transforms() {
	mut document := interest_test_document('<div id="ancestor"><section id="clip" style="background:blue"><p>Offscreen comment</p></section></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 100)
	mut result := interest_test_project(mut document)
	assert result.paint_projection_incomplete
	mut ancestor := document.get_element_by_id('ancestor')?
	ancestor.set_attribute_value('style', 'transform:translateY(-1000px)')
	document.update_layout(.debugging)
	_ = document.record_viewport_display_list()?
	result = document_layout_result(document)?
	assert !result.paint_projection_incomplete
	assert result.paint_tree.find_box(interest_test_id(document, 'clip'))?.visible
}

fn test_viewport_projection_retains_escaping_effects_scrollers_and_snap_targets() {
	for extra in [
		'<section style="overflow:visible"><p>Visible overflow</p></section>',
		'<section style="box-shadow:0 -1000px 0 red"><p>Shadow</p></section>',
		'<section style="outline:2px solid red"><p>Outline</p></section>',
		'<section style="filter:drop-shadow(0 -1000px 0 red)"><p>Effect</p></section>',
		'<section style="transform:translateY(-1000px)"><p>Transform</p></section>',
		'<section><p style="position:absolute;top:0">Escaping child</p></section>',
		'<section><p style="scroll-snap-align:start">Snap target</p></section>',
		'<section><p style="background-image:linear-gradient(red,blue)">Paint resource</p></section>',
		'<section><p style="transform:translateX(2px)">Transformed geometry</p></section>',
		'<div style="overflow:auto;height:100px"><section><p>Nested scroller</p></section></div>',
		'<div style="position:fixed;top:1000px"><section><p>Fixed ancestor</p></section></div>',
	] {
		mut document := interest_test_document(extra)
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 320, 100)
		result := interest_test_project(mut document)
		assert !result.paint_projection_incomplete, extra
	}
}
