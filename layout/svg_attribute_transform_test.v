module layout

import css
import html
import svg

fn test_attribute_transform_matches_recursive_model_for_transform_and_use_offsets() {
	document := html.parse_document('<!doctype html><svg xmlns="http://www.w3.org/2000/svg"><g id="child"><path d="M0 0H20V10Z"/></g></svg>')
	for tag in ['svg', 'g', 'path', 'use', 'clipPath', 'mask', 'pattern'] {
		mut element := document.create_element_ns('http://www.w3.org/2000/svg', tag) or { panic(err) }
		for transform in ['', 'translate(2 -3)', 'scale(2 .5) rotate(30 4 5)', 'matrix(1 2 3 4 5 6)',
			'translate(4) skewX(17) skewY(-12)', 'invalid(', 'translate(2 3) bad(4)'] {
			element.set_attribute_value('transform', transform)
			for x, y in {
				'':        ''
				'4':       '-7'
				'1e2':     '3.5'
				'invalid': '20%'
				'-2px':    '7px'
			} {
				element.set_attribute_value('x', x)
				element.set_attribute_value('y', y)
				assert svg_element_attribute_transform(element) == svg.element_transform(svg_element_model(element))
			}
		}
	}
}

fn test_attribute_transform_observes_live_attributes_without_retaining_child_state() {
	document := html.parse_document('<!doctype html><svg><use id="target" x="4" y="-2" transform="scale(2)"><g id="child" transform="translate(100 100)"><path d="M0 0H10V10Z"/></g></use></svg>')
	mut target := document.get_element_by_id('target') or { panic('missing use') }
	assert svg_element_attribute_transform(target) == svg.AffineTransform{ a: 2, d: 2, e: 8, f: -4 }
	target.set_attribute_value('x', '7')
	target.set_attribute_value('y', '3')
	target.set_attribute_value('transform', 'translate(5 9)')
	assert svg_element_attribute_transform(target) == svg.AffineTransform{ e: 12, f: 12 }
	mut child := document.get_element_by_id('child') or { panic('missing child') }
	child.set_attribute_value('transform', 'scale(300)')
	assert svg_element_attribute_transform(target) == svg.AffineTransform{ e: 12, f: 12 }
	target.remove_attribute('transform')
	target.remove_attribute('x')
	target.remove_attribute('y')
	assert svg_element_attribute_transform(target) == svg.AffineTransform{}
}

fn test_attribute_transform_leaves_descendant_computed_styles_unmaterialized() {
	document := html.parse_document('<!doctype html><svg id="target" transform="translate(5 7)"><g id="child"><feFlood id="resource" flood-color="red"/></g></svg>')
	target := document.get_element_by_id('target') or { panic('missing SVG root') }
	child := document.get_element_by_id('child') or { panic('missing child') }
	resource := document.get_element_by_id('resource') or { panic('missing resource') }
	assert css.computed_properties_for_element(child) == none
	assert css.computed_properties_for_element(resource) == none
	assert svg_element_attribute_transform(target) == svg.AffineTransform{ e: 5, f: 7 }
	assert css.computed_properties_for_element(child) == none
	assert css.computed_properties_for_element(resource) == none
}

fn test_attribute_transform_keeps_nested_path_geometry_and_live_svg_updates() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}</style><svg width="80" height="40"><g id="group" transform="translate(5 7)"><path d="M0 0H10V10Z" fill="green"/></g></svg>')
	_ = layout_document_typed_in_viewport(document, 100, 80)
	first := display_list_commands(document.record_display_list() or { panic('missing initial list') }).filter(it.kind == 'draw_svg_path')
	assert first.len == 1
	assert first[0].path_transform == [f64(1), 0, 0, 1, 5, 7]!
	mut group := document.get_element_by_id('group') or { panic('missing group') }
	group.set_attribute_value('transform', 'translate(13 17)')
	// This standalone bridge fixture has no browser mutation replay owner.
	// Reconstruct the committed SVG geometry before observing the new transform.
	document.set_needs_full_style_update(true)
	document.set_needs_full_layout_tree_update(true)
	_ = layout_document_typed_in_viewport(document, 100, 80)
	second := display_list_commands(document.record_display_list() or { panic('missing updated list') }).filter(it.kind == 'draw_svg_path')
	assert second.len == 1
	assert second[0].path_transform == [f64(1), 0, 0, 1, 13, 17]!
	assert first[0].path_transform == [f64(1), 0, 0, 1, 5, 7]!
}
