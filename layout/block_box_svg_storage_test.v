module layout

import css
import dom
import html
import painting
import platform

fn test_ordinary_paint_boxes_do_not_embed_svg_storage() {
	// The prior record occupied 2304 bytes on the current ABI. Preserve the
	// saving in the retained projection vector, including ordinary HTML boxes.
	assert sizeof(BlockBox) <= 1920
	assert sizeof(BlockBoxSVGData) + sizeof(PaintSVGPathData) <= 512
	box := BlockBox{}
	assert sizeof(box.svg_data) == sizeof(voidptr)
	assert box.svg_data == unsafe { nil }
	assert !box.has_svg_path()
	assert box.svg_path().path == ''
	assert box.svg_path().stroke_miterlimit == 4
	assert box.svg_path().fill_opacity == 1
	assert box.svg_path().stroke_opacity == 1
	assert box.own_paint_transform_4x4 == css.FloatMatrix4x4.identity()
}

fn test_svg_box_replacement_keeps_old_path_commands_and_hit_geometry() {
	mut box := BlockBox{
		svg_data: &BlockBoxSVGData{
			has_path:     true
			bounding_box: painting.Rect{1, 2, 10, 20}
			points:       [f64(1), 2, 11, 22]
			fill_color:   'red'
			stroke_color: 'blue'
			stroke_width: 3
			path:         &PaintSVGPathData{
				path:             'M1 2L11 22'
				path_data:        [f32(1), 2, 11, 22]
				path_transform:   [f64(2), 0, 0, 2, 7, 8]!
				stroke_dasharray: [f64(3), 4]
			}
		}
	}
	old := box
	commands := box.paint_commands().filter(it.kind == 'draw_svg_path')
	assert commands.len == 1
	assert voidptr(commands[0].svg_data) == voidptr(old.svg_path())
	assert commands[0].svg_data.path_data.data == old.svg_path().path_data.data
	assert commands[0].svg_data.stroke_dasharray.data == old.svg_path().stroke_dasharray.data
	assert commands[0].points == old.svg_data.points
	assert old.svg_path_bounding_box_contains_hit_test_point(painting.Point{11, 14})
	assert !old.svg_path_bounding_box_contains_hit_test_point(painting.Point{7, 8})
	box.svg_data = &BlockBoxSVGData{
		path:       &PaintSVGPathData{ path: 'M0 0L5 5' }
		fill_color: 'green'
	}
	gc_collect()
	assert old.has_svg_path()
	assert old.svg_data.bounding_box == painting.Rect{1, 2, 10, 20}
	assert commands[0].svg_data.path == 'M1 2L11 22'
	assert commands[0].points == [f64(1), 2, 11, 22]
	assert commands[0].color == 'red'
	assert commands[0].stroke_color == 'blue'
	assert commands[0].stroke_width == 3
	// A manually constructed path without the typed hit flag still paints,
	// while retaining the legacy ordinary-box hit-test fallback.
	assert !box.has_svg_path()
	assert box.svg_path_bounding_box_contains_hit_test_point(painting.Point{-100, -100})
	assert box.paint_commands().any(it.kind == 'draw_svg_path' && it.color == 'green')
}

fn test_inline_paint_matrix_retains_explicit_zero_and_old_value_copies() {
	zero := css.FloatMatrix4x4{ m11: 0, m22: 0, m33: 0, m44: 0 }
	mut box := BlockBox{ own_paint_transform_4x4: zero }
	old := box
	assert box.own_paint_transform_4x4 == zero
	box.own_paint_transform_4x4 = css.FloatMatrix4x4{ m11: 2 }
	assert old.own_paint_transform_4x4 == zero
	assert box.own_paint_transform_4x4.m11 == 2
	box.own_paint_transform_4x4 = css.FloatMatrix4x4.identity()
	assert box.own_paint_transform_4x4 == css.FloatMatrix4x4.identity()
	assert old.own_paint_transform_4x4 == zero
}

fn test_distinct_compositor_transforms_keep_snapshots_and_bounded_retained_storage() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}#target{width:20px;height:20px;transform:translate3d(0px,0px,3px)}</style><div id="target"></div>')
	document.enable_native_storage()
	mut allocations := document.enter_native_storage()
	defer {
		allocations.finish()
		document.finalize()
		document.release_native_storage()
	}
	_ = layout_document_typed_in_viewport(document, 200, 100)
	result := document_layout_result(document) or { panic('missing layout') }
	target := document.get_element_by_id('target') or { panic('missing target') }
	placeholder := target.as_node().layout_node() or { panic('missing target layout') }
	mut box := result.paint_tree.find_box(i64(target.as_node().unique_id())) or { panic('missing target transport') }
	node := unsafe { &Node(placeholder.layout_handle) }
	styled := node.as_node_with_style() or { panic('missing target style') }
	mut computed := unsafe { &css.ComputedProperties(styled.computed_values()) }
	// The sampled values already own their parsed payloads. Parse them and
	// initialize the property map outside the compositor allocation measurement.
	mut samples := []&dom.StyleValue{}
	for index in 0 .. 256 {
		samples << css.parse_css_value(css.ParsingParams{}, 'translate3d(${index + 1}px,0px,3px)', .transform) or { panic('invalid transform') }
	}
	computed.set_animated_property(.transform, samples.last(), .no, .no)
	mut changed := HandleSet{}
	changed.add(u64(placeholder.layout_handle))
	mut scratch := platform.new_arena('distinct compositor transform test')
	defer { scratch.release() }
	mut grown := i64(0)
	initial := box
	// Warm the property map and all resolution paths before measuring. The
	// second pass still changes every matrix, so same-value reuse cannot pass.
	for pass in 0 .. 2 {
		mut before := i64(0)
		$if prealloc {
			before = document.native_storage().arena.usage().used
		}
		entry := scratch.enter()
		for index in 0 .. samples.len {
			previous := box
			previous_matrix := previous.own_paint_transform_4x4
			computed.set_animated_property(.transform, samples[index], .no, .no)
			mut refresh := CompositorPaintStyleRefresh{}
			refresh_compositor_paint_styles_in_box(mut box, result.state, &changed, [6]f64{}, mut refresh)
			assert refresh.changed
			assert refresh.boxes.len == 1
			assert box.uses_own_paint_transform_4x4
			assert box.own_paint_transform_4x4.m14 == f64(index + 1)
			assert box.own_paint_transform_4x4.m34 == 3
			assert previous.own_paint_transform_4x4 == previous_matrix
			assert box.own_paint_transform_4x4 != previous_matrix
		}
		scratch.leave(entry)
		scratch.reset()
		if pass == 1 {
			$if prealloc {
				grown = document.native_storage().arena.usage().used - before
			}
		}
	}
	gc_collect()
	assert initial.own_paint_transform_4x4.m14 == 0
	assert initial.own_paint_transform_4x4.m34 == 3
	assert box.own_paint_transform_4x4.m14 == 256
	assert box.own_paint_transform_4x4.m34 == 3
	$if prealloc {
		assert grown < 4096, '256 distinct transforms retained ${grown} bytes'
	}
}
