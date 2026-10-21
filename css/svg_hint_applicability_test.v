module css

import dom
import platform

fn test_svg_hint_applicability_preserves_geometry_and_sizing_element_sets() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	expected_attributes := {
		'circle':        ['cx', 'cy', 'r']
		'ellipse':       ['cx', 'cy', 'rx', 'ry']
		'path':          ['d']
		'rect':          ['rx', 'ry', 'x', 'y', 'width', 'height']
		'foreignObject': ['x', 'y', 'width', 'height']
		'image':         ['x', 'y', 'width', 'height']
		'svg':           ['x', 'y', 'width', 'height']
		'symbol':        ['x', 'y', 'width', 'height']
		'use':           ['x', 'y', 'width', 'height']
		'g':             []string{}
	}
	for tag, allowed in expected_attributes {
		for name in ['cx', 'cy', 'd', 'r', 'rx', 'ry', 'x', 'y', 'width', 'height'] {
			mut element := document.create_element_ns('http://www.w3.org/2000/svg', tag)!
			element.set_attribute_value(name, if name == 'd' { 'M0 0L1 1' } else { '1' })
			mut hints := []StyleProperty{}
			collect_svg_presentational_hints(mut hints, element, [])
			expected := name in allowed
			assert hints.len == if expected { 1 } else { 0 }
			if expected {
				assert hints[0].property_id == property_id_from_string(name)?
			}
		}
	}
}

fn test_svg_logical_probe_does_not_allocate_geometry_applicability_tables() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut element := document.create_element_ns('http://www.w3.org/2000/svg', 'rect')!
	element.set_attribute_value('x', '12')
	element.set_attribute_value('fill', 'red')
	element.set_attribute_value('d', 'ignored on rect')
	mut hints := []StyleProperty{}
	requested := [PropertyID.direction, .writing_mode]
	before := platform.thread_arena_usage().used
	for _ in 0 .. 256 { collect_svg_presentational_hints(mut hints, element, requested) }
	assert hints.len == 0
	$if prealloc {
		assert platform.thread_arena_usage().used == before
	}
}
