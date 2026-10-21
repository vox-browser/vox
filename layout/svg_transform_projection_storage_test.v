module layout

import html
import platform
import svg

fn test_computed_svg_transform_projection_does_not_copy_descendant_models() {
	mut document := html.parse_document('<!doctype html><svg width="100" height="80"><g id="target" transform="translate(5 7)">' + '<path d="M0 0H10V10Z" fill="green"/>'.repeat(256) + '</g></svg>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 200, 120)
	element := document.get_element_by_id('target')?
	bridge := element.as_node().layout_node()?
	node := unsafe { &Node(bridge.real_layout_handle()) }
	size := CSSPixelSize.from_values(100, 80)
	before := platform.thread_arena_usage().used
	model := svg_transform_element_model(node, element, size)
	$if prealloc { assert platform.thread_arena_usage().used - before < 4096 }
	assert model.children.len == 0
	assert model.attributes.len == 1
	assert svg.element_transform(model) == svg.AffineTransform{e:5, f:7}
}

fn test_computed_svg_use_projection_keeps_css_offsets_and_live_transform_updates() {
	mut document := html.parse_document('<!doctype html><svg width="100" height="80"><defs><path id="shape" d="M0 0H10V10Z"/></defs><use id="target" href="#shape" x="1" y="2" style="x:12px;y:15px" transform="scale(2)"/></svg>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 200, 120)
	mut element := document.get_element_by_id('target')?
	bridge := element.as_node().layout_node()?
	node := unsafe { &Node(bridge.real_layout_handle()) }
	size := CSSPixelSize.from_values(100, 80)
	first := svg.element_transform(svg_transform_element_model(node, element, size))
	assert first == svg.AffineTransform{a:2, d:2, e:24, f:30}
	element.set_attribute_value('style', 'x:7px;y:3px')
	element.set_attribute_value('transform', 'translate(5 9)')
	document.set_needs_full_style_update(true)
	document.set_needs_full_layout_tree_update(true)
	_ = layout_document_typed_in_viewport(document, 200, 120)
	updated := element.as_node().layout_node()?
	updated_node := unsafe { &Node(updated.real_layout_handle()) }
	assert svg.element_transform(svg_transform_element_model(updated_node, element, size)) == svg.AffineTransform{e:12, f:12}
	assert first == svg.AffineTransform{a:2, d:2, e:24, f:30}
}
