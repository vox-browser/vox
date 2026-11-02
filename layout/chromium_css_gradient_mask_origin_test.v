module layout

import dom
import html
import math

fn test_css_gradient_masks_snap_the_chromium_image_origin_without_moving_layout() {
	for policy in [dom.FontRenderingPolicy.libweb, .chromium] {
		for origin in [f64(10.25), 10.5, 10.75, -1.5] {
			for image in ['linear-gradient(180deg,#000 70%,transparent)',
				'radial-gradient(ellipse at 50% 50%,#000,transparent)'] {
				mut document := html.parse_document('<!doctype html><style>html,body{margin:0}#target{position:absolute;left:${origin}px;top:${origin}px;width:120.25px;height:60.75px;background:red;mask-image:${image}}</style><div id="target"></div>')
				defer { document.finalize() }
				document.set_font_rendering_policy(policy)
				root := layout_document_typed_in_viewport(document, 200, 150)
				element := document.get_element_by_id('target') or { panic('missing target') }
				box := root.find_box(i64(element.as_node().unique_id())) or { panic('missing box') }
				mask := box.clips().svg_mask or { panic('missing mask') }
				assert mask.operations.len == 1
				operation := mask.operations[0]
				expected := if policy == .chromium { math.floor(origin + .5) } else { origin }
				assert operation.path.segments[0].point.x == expected
				assert operation.path.segments[0].point.y == expected
				assert operation.path.segments[2].point.x == expected + 120.25
				assert operation.path.segments[2].point.y == expected + 60.75
				if gradient := operation.fill_linear_gradient {
					assert math.abs(gradient.start_point.y - expected) < 1e-9
					assert math.abs(gradient.end_point.y - expected - 60.75) < 1e-9
				} else if gradient := operation.fill_radial_gradient {
					transform := gradient.gradient.gradient_transform or { panic('missing transform') }
					assert transform.e == expected + 120.25 / 2
					assert transform.f == expected + 60.75 / 2
				} else { panic('missing gradient') }
				assert element.get_bounding_client_rect().x == origin
				assert element.get_bounding_client_rect().y == origin
			}
		}
	}
}
