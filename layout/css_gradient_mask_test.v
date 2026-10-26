module layout

import css
import dom
import math
import painting

fn gradient_mask_test_mask(declaration string, rect painting.Rect) painting.SVGMaskVisualData {
	mut document := dom.Document.create(dom.URL{ value: 'https://mask.test/' })
	defer { document.finalize() }
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic(err) }
	element.set_attribute_value('style', declaration)
	mut computer := css.StyleComputer.new(document)
	computed := computer.compute_style(dom.AbstractElement.new(element, none))
	_ = css.resolve_computed_values_for_document(computed, document)
	node := NodeWithStyle.new(document, element.as_node(), computed)
	return css_mask_image_for_box(element, computed, rect, unsafe { &Node(node) }) or {
		panic('missing generated mask')
	}
}

fn test_generated_mask_preserves_transparent_and_opaque_groups() {
	for alpha in ['transparent', 'white'] {
		mask := gradient_mask_test_mask('mask-image:linear-gradient(${alpha},${alpha})', painting.Rect{7, 9, 120, 60})
		assert mask.mask_type == .alpha
		assert mask.bounding_rect == painting.IntRect{7, 9, 120, 60}
		assert mask.operations.len == 1
		operation := mask.operations[0]
		assert operation.has_fill
		assert operation.path.segments.len == 5
		gradient := operation.fill_linear_gradient or { panic('missing linear mask') }
		assert gradient.gradient.color_stops.len == 2
		expected_alpha := if alpha == 'transparent' { u8(0) } else { u8(255) }
		assert gradient.gradient.color_stops.all(it.color.a == expected_alpha)
	}
}

fn test_linear_mask_resolves_current_color_geometry_and_color_space() {
	mask := gradient_mask_test_mask('color:rgba(10,20,30,.5);mask-image:linear-gradient(90deg in srgb-linear,currentColor,transparent)', painting.Rect{7, 9, 120, 60})
	gradient := mask.operations[0].fill_linear_gradient or { panic('missing linear mask') }
	assert math.abs(gradient.start_point.x - 7) < 1e-9
	assert math.abs(gradient.end_point.x - 127) < 1e-9
	assert math.abs(gradient.start_point.y - 39) < 1e-9
	assert math.abs(gradient.end_point.y - 39) < 1e-9
	assert gradient.gradient.color_space == .linear_srgb
	assert gradient.gradient.color_stops[0].color == painting.Color{10, 20, 30, 128}
}

fn test_radial_mask_keeps_elliptical_radii_and_off_center_origin() {
	mask := gradient_mask_test_mask('mask-image:radial-gradient(ellipse 30px 10px at 25% 75%,white,transparent)', painting.Rect{7, 9, 120, 60})
	gradient := mask.operations[0].fill_radial_gradient or { panic('missing radial mask') }
	transform := gradient.gradient.gradient_transform or { panic('missing ellipse transform') }
	assert transform == painting.Affine{ a: 30, d: 10, e: 37, f: 54 }
	assert gradient.start_center == painting.Point{}
	assert gradient.start_radius == 0
	assert gradient.end_center == painting.Point{}
	assert gradient.end_radius == 1
}

fn test_gradient_mask_cache_identity_tracks_alpha_geometry_and_stops() {
	rect := painting.Rect{7, 9, 120, 60}
	base := gradient_mask_test_mask('mask-image:radial-gradient(circle,white,transparent)', rect)
	repeated := gradient_mask_test_mask('mask-image:radial-gradient(circle,white,transparent)', rect)
	assert base.cache_key == repeated.cache_key
	for declaration in ['mask-image:radial-gradient(circle,white,white)',
		'mask-image:radial-gradient(circle at 25% 50%,white,transparent)',
		'mask-image:radial-gradient(circle,white 25%,transparent)'] {
		changed := gradient_mask_test_mask(declaration, rect)
		assert base.cache_key != changed.cache_key
	}
	translated := gradient_mask_test_mask('mask-image:radial-gradient(circle,white,transparent)', painting.Rect{8, 9, 120, 60})
	assert base.cache_key != translated.cache_key
}
