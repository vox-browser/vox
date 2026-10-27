module layout

import html
import svg

fn nested_clip_node(root &Node, id string) ?&Node {
	if dom_node := root.dom_node() {
		if element := dom_node.as_element() {
			if element.get_attribute_value('id') == id {
				return root
			}
		}
	}
	for child in root.children() {
		if found := nested_clip_node(child, id) {
			return found
		}
	}
	return none
}

fn nested_clip_transform(result DocumentLayoutResult, id string) (f64, f64, f64) {
	node := nested_clip_node(result.root, id) or { panic('missing #${id}') }
	used := result.used_values_for(node.as_node_with_style() or { panic('style') }) or {
		panic('used')
	}
	clip := svg_url_clip_path_for_box(node, result.state, used) or { panic('no clip on #${id}') }
	transform := clip.components[0].transform
	return transform.a, transform.e, transform.f
}

// Wikipedia's sprite places each icon in a nested <svg x y viewBox>. Clip
// geometry in userSpaceOnUse units must map through that viewport exactly once,
// like the clipped shapes themselves.
fn test_user_space_clip_maps_through_nested_viewports_once() {
	document := html.parse_document('<!doctype html><body style="margin:0"><svg width="200" height="200">
		<svg width="42" height="42" viewBox="-1 -1 1026 1026" x="60" y="100">
			<clipPath id="c1"><path d="M0 0h1024v1024H0z"/></clipPath>
			<g id="plain" clip-path="url(#c1)"><path id="shape" d="M0 0h10v10z"/></g>
			<clipPath id="c2" transform="translate(100 0)"><path transform="translate(0 50)" d="M0 0h10v10z"/></clipPath>
			<g id="moved" transform="translate(200 0)" clip-path="url(#c2)"><path d="M0 0h10v10z"/></g>
		</svg></svg>')
	result := run_document_layout(document, 400, 400) or { panic('layout failed') }
	shape := nested_clip_node(result.root, 'shape') or { panic('missing shape') }
	shape_to_page := svg_path_transform_to_page(shape, result.state)
	scale, x, y := nested_clip_transform(result, 'plain')
	assert scale == shape_to_page.a
	assert x == shape_to_page.e && y == shape_to_page.f
	assert int(x) == 60 && int(y) == 100
	// The clipPath and clip child transforms follow the referencing group's.
	_, moved_x, moved_y := nested_clip_transform(result, 'moved')
	assert f32(moved_x) == f32(shape_to_page.e + (200 + 100) * scale)
	assert f32(moved_y) == f32(shape_to_page.f + 50 * scale)
}

fn test_user_space_clip_keeps_local_translation_before_entering_page_space() {
	document := html.parse_document('<!doctype html><body style="margin:0"><svg width="20" height="20" viewBox="0 0 21 20">
		<clipPath id="clip" transform="translate(.5 0)"><path d="M0 0h20v20H0z"/></clipPath>
		<g id="target" clip-path="url(#clip)"><path d="M.5 0h20v20H.5z"/></g></svg>')
	result := run_document_layout(document, 1024, 768) or { panic('layout failed') }
	clip_box := nested_clip_node(result.root, 'clip') or { panic('missing clip') }
	clip_child := clip_box.children()[0]
	scale := f64(f32(20.0 / 21.0))
	for x in [f64(107), 407, 807, 1000007] {
		transform := svg_clip_child_transform_to_page(clip_child, clip_box,
			svg.AffineTransform{a: scale, d: scale, e: x, f: 162.4761962890625})
		assert transform.a == scale && transform.d == scale
		assert f32((transform.e - x) / scale) == f32(.5)
		assert transform.f == 162.4761962890625
	}
}
