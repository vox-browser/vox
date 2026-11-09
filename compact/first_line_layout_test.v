module main

import css
import dom
import html
import layout
import platform

fn test_first_line_shapes_and_paints_its_font_before_a_forced_break() {
	for policy in [dom.FontRenderingPolicy.libweb, .chromium] {
		mut document := html.parse_document('<!doctype html><style>body{margin:0}#target{font:20px/1 monospace;color:blue}#target::first-line{font-size:40px;color:red}</style><div id="target">W<br>i</div>')
		document.set_font_rendering_policy(policy)
		mut root := layout.layout_document_typed_in_viewport(document, 400, 300)
		target := document.get_element_by_id('target') or { panic('target') }
		assert target.get_bounding_client_rect().height == 60
		commands := root.paint_commands().filter(it.kind == 'draw_text' && it.text.trim_space() != '')
		assert commands.len == 2
		assert commands[0].text == 'W' && commands[0].font_size == 40
		assert commands[1].text == 'i' && commands[1].font_size == 20
		assert commands[0].color != commands[1].color
		assert commands.all(it.glyph_run != none)
		document.finalize()
	}
}

fn test_first_line_soft_wrap_restores_the_ordinary_font_and_source_text() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}#target{font:20px/1 monospace;width:5ch}#target::first-line{font-size:40px}</style><div id="target">XX XX XX</div>')
	defer { document.finalize() }
	mut root := layout.layout_document_typed_in_viewport(document, 400, 300)
	target := document.get_element_by_id('target') or { panic('target') }
	assert target.get_bounding_client_rect().height == 60
	commands := root.paint_commands().filter(it.kind == 'draw_text' && it.text.trim_space() != '')
	assert commands.len >= 2
	assert commands[0].font_size == 40
	assert commands[1..].all(it.font_size == 20)
	mut text := ''
	for command in commands { text += command.text }
	assert text.replace(' ', '') == 'XXXXXX'
	// Changing the available width rebuilds the first-line boundary from the
	// immutable source; no temporary shaping node replaces the DOM text node.
	mut mutable_target := unsafe { &dom.Element(target) }
	mutable_target.set_attribute_value('style', 'width:30ch')
	_ = layout.layout_document_typed_in_viewport(document, 400, 300)
	assert target.get_bounding_client_rect().height == 40
	assert (target.as_node().text_content() or { '' }) == 'XX XX XX'
}

fn test_first_line_from_an_outer_part_rule_sizes_the_shadow_host() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}</style><div id="host"></div>')
	defer { document.finalize() }
	mut host := document.get_element_by_id('host') or { panic('host') }
	shadow := host.attach_shadow(dom.ShadowRootInit{mode:.open})!
	mut part := document.create_element_ns(dom.namespace_html_uri, 'div')!
	part.set_attribute_value('part', 'label')
	mut part_node := part.as_node()
	part_node.append_child(document.create_text_node('X').as_node())!
	part_node.append_child(document.create_element_ns(dom.namespace_html_uri, 'br')!.as_node())!
	part_node.append_child(document.create_text_node('X').as_node())!
	mut shadow_node := shadow.as_node()
	shadow_node.append_child(part_node)!
	css.add_document_author_style_sheet(document, '::part(label){font:20px/1 monospace}::part(label)::first-line{font-size:86px}')
	_ = layout.layout_document_typed_in_viewport(document, 400, 300)
	assert host.get_bounding_client_rect().height == 106
}

fn test_empty_first_line_and_preserved_newlines_restore_ordinary_text() {
	for content in ['<br>X', 'X\nX'] {
		mut document := html.parse_document('<!doctype html><style>body{margin:0}#target{font:20px/1 monospace;white-space:pre}#target::first-line{font-size:40px}</style><div id="target">${content}</div>')
		mut root := layout.layout_document_typed_in_viewport(document, 400, 300)
		target := document.get_element_by_id('target') or { panic('target') }
		assert target.get_bounding_client_rect().height == 60, content
		commands := root.paint_commands().filter(it.kind == 'draw_text' && it.text.trim_space() != '')
		assert commands.len == if content.starts_with('<br>') { 1 } else { 2 }
		assert commands.last().font_size == 20
		document.finalize()
	}
}

fn test_first_line_recomputes_after_an_inherited_font_change() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}#target::first-line{font-size:2em}</style><div id="parent" style="font:20px/1 monospace"><div id="target">X<br>X</div></div>')
	defer { document.finalize() }
	_ = layout.layout_document_typed_in_viewport(document, 400, 300)
	target := document.get_element_by_id('target') or { panic('target') }
	assert target.get_bounding_client_rect().height == 60
	mut parent := document.get_element_by_id('parent') or { panic('parent') }
	parent.set_attribute_value('style', 'font:30px/1 monospace')
	mut root := layout.layout_document_typed_in_viewport(document, 400, 300)
	assert target.get_bounding_client_rect().height == 90
	commands := root.paint_commands().filter(it.kind == 'draw_text' && it.text == 'X')
	assert commands.len == 2
	assert commands[0].font_size == 60 && commands[1].font_size == 30
}

fn test_first_line_style_sources_survive_native_geometry_workspace_retirement() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	defer {
		document.finalize()
		owner.finish()
		document.release_native_storage()
	}
	html.parse_html_from_a_string(document, '<!doctype html><style>body{margin:0}#target{font:20px/1 monospace}#target::first-line{font-size:86px}</style><div id="target">X<br>X</div>')
	_ = layout.layout_document_typed_in_viewport(document, 400, 300)
	target := document.get_element_by_id('target') or { panic('target') }
	node := unsafe { &layout.Node((target.as_node().unsafe_layout_node() or { panic('layout') }).real_layout_handle()) }
	result := layout.document_layout_result(document) or { panic('result') }
	used := result.state.try_get(node.as_node_with_style() or { panic('style') }) or { panic('geometry') }
	source := used.line_boxes[0].fragments()[0].style_source()
	$if prealloc { assert document.native_storage().arena.contains(source) }
	mut churn := platform.begin_thread_scratch('overwrite retired first-line workspace')
	bytes := []u8{len: 1024 * 1024, init: 0xa5}
	assert bytes[bytes.len - 1] == 0xa5
	churn.finish()
	assert source.computed_values().font_size().to_double() == 86
	assert source.parent() != none
	assert target.get_bounding_client_rect().height == 106
}
