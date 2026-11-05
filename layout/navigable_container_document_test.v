module layout

import css
import dom
import html

fn test_navigable_viewport_tracks_the_real_active_document_and_its_size() {
	mut parent := html.parse_document('<!doctype html><iframe id="frame" srcdoc="fallback"></iframe>')
	mut child := html.parse_document('<!doctype html><p>loaded child</p>')
	mut replacement := html.parse_document('<!doctype html><p>replacement</p>')
	frame := parent.get_element_by_id('frame')?
	mut navigable := &dom.Navigable{ container_: frame.as_node(), active_document_: child }
	child.set_navigable(navigable)
	defer {
		navigable.remove_from_all_navigables()
		parent.finalize()
		child.finalize()
		replacement.finalize()
	}
	viewport := NavigableContainerViewport.new(parent, frame, css.ComputedProperties.new())
	assert voidptr(viewport.content_document()?) == voidptr(child)
	viewport.did_set_content_size(css.CSSPixelSize.from_values(302, 76))
	assert child.viewport_rect().width == 302
	assert child.viewport_rect().height == 76
	navigable.set_active_document(replacement)
	assert voidptr(viewport.content_document()?) == voidptr(replacement)
	viewport.did_set_content_size(css.CSSPixelSize.from_values(400, 300))
	assert replacement.viewport_rect().width == 400
	assert replacement.viewport_rect().height == 300
	assert child.viewport_rect().width == 302
	navigable.set_active_document(none)
	assert viewport.content_document() == none
	viewport.did_set_content_size(css.CSSPixelSize.from_values(10, 10))
	assert replacement.viewport_rect().width == 400
}

fn test_object_natural_size_uses_its_hosted_svg_document() {
	mut parent := html.parse_document('<!doctype html><object id="object"></object>')
	mut child := dom.Document.create(dom.url_about_blank())
	mut svg := child.create_element_ns('http://www.w3.org/2000/svg', 'svg')!
	svg.set_attribute_value('width', '640')
	svg.set_attribute_value('height', '360')
	child.append_child(svg)
	object := parent.get_element_by_id('object')?
	mut navigable := &dom.Navigable{ container_: object.as_node(), active_document_: child }
	child.set_navigable(navigable)
	defer {
		navigable.remove_from_all_navigables()
		parent.finalize()
		child.finalize()
	}
	viewport := NavigableContainerViewport.new(parent, object, css.ComputedProperties.new())
	size := viewport.natural_size()
	assert size.width?.to_double() == 640
	assert size.height?.to_double() == 360
}

fn test_standalone_iframe_layout_keeps_the_srcdoc_adapter() {
	mut parent := html.parse_document('<!doctype html><iframe id="frame" srcdoc="<p id=child>srcdoc</p>"></iframe>')
	defer { parent.finalize() }
	frame := parent.get_element_by_id('frame')?
	viewport := NavigableContainerViewport.new(parent, frame, css.ComputedProperties.new())
	assert viewport.content_document()?.get_element_by_id('child') != none
}

fn test_hosted_navigation_replaces_painted_content_and_clears_the_navigation_gap() {
	mut parent := html.parse_document('<!doctype html><style>iframe{width:120px;height:60px}</style><iframe id="frame" srcdoc="stale fallback"></iframe>')
	mut first := html.parse_document('<!doctype html><style>body{background:rgb(17 83 29)}</style><p>first child</p>')
	mut second := html.parse_document('<!doctype html><style>body{background:rgb(91 23 47)}</style><p>second child</p>')
	frame := parent.get_element_by_id('frame')?
	mut navigable := &dom.Navigable{ container_: frame.as_node() }
	navigable.set_active_document(first)
	defer {
		navigable.remove_from_all_navigables()
		parent.finalize()
		first.finalize()
		second.finalize()
	}
	root := layout_document_typed_in_viewport(parent, 240, 140)
	first_commands := root.paint_commands().filter(it.kind == 'paint_nested_display_list')
	assert first_commands.len == 1
	assert first_commands[0].nested_viewport_commands.any(it.kind == 'fill_rect' && it.color == 'rgb(17 83 29)')
	assert first_commands[0].nested_viewport_commands.any(it.kind == 'draw_text' && it.text == 'first child')
	navigable.set_active_document(none)
	gap := layout_document_typed_in_viewport(parent, 240, 140)
	assert gap.paint_commands().all(it.kind != 'paint_nested_display_list')
	navigable.set_active_document(second)
	replacement := layout_document_typed_in_viewport(parent, 240, 140)
	second_commands := replacement.paint_commands().filter(it.kind == 'paint_nested_display_list')
	assert second_commands.len == 1
	assert second_commands[0].nested_viewport_commands.any(it.kind == 'fill_rect' && it.color == 'rgb(91 23 47)')
	assert second_commands[0].nested_viewport_commands.any(it.kind == 'draw_text' && it.text == 'second child')
	assert second_commands[0].nested_viewport_commands.all(it.text != 'first child')
}
