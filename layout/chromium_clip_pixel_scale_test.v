module layout

import dom
import html
import painting

fn test_clip_adapter_snaps_device_edges_and_radii_in_both_layout_spaces() {
	for policy in [dom.FontRenderingPolicy.libweb, .chromium] {
		mut document := html.parse_document('<!doctype html><div id="box"></div>')
		defer { document.finalize() }
		document.set_font_rendering_policy(policy)
		_ = layout_document_typed_in_viewport(document, 300, 150)
		element := document.get_element_by_id('box') or { panic('box') }
		bridge := element.as_node().layout_node() or { panic('layout') }
		box := BlockBox{layout_handle: bridge.layout_handle}
		for density in [f64(2), 1] {
			document.set_display_device_pixel_ratio(density)
			for coordinate_scale in [f64(1), 2] {
				document.set_layout_coordinate_scale(coordinate_scale)
				rect := LayoutRect{10.25 * coordinate_scale, 20.25 * coordinate_scale,
					100.5 * coordinate_scale, 30.5 * coordinate_scale}
				radius := 3.75 * coordinate_scale
				radii := BoxRadii{CornerRadius{radius, radius}, CornerRadius{radius, radius},
					CornerRadius{radius, radius}, CornerRadius{radius, radius}}
				clip := compatibility_clip_visual_data(&box, rect, radii)
				if policy == .libweb {
					assert clip.device_pixel_scale == 1
					assert clip.rect == compatibility_rounded_int_rect(rect)
					assert clip.corner_radii == compatibility_corner_radii(radii)
					continue
				}
				assert clip.device_pixel_scale == density / coordinate_scale
				assert clip.rect == if density == 2 {
					painting.IntRect{21, 41, 201, 61}
				} else {
					painting.IntRect{10, 20, 101, 31}
				}
				local := compatibility_clip_layout_rect(clip)
				assert local == if density == 2 {
					LayoutRect{10.5 * coordinate_scale, 20.5 * coordinate_scale,
						100.5 * coordinate_scale, 30.5 * coordinate_scale}
				} else {
					LayoutRect{10 * coordinate_scale, 20 * coordinate_scale,
						101 * coordinate_scale, 31 * coordinate_scale}
				}
				assert compatibility_clip_layout_radii(clip).top_left.x ==
					if density == 2 { 3.5 * coordinate_scale } else { 3 * coordinate_scale }
			}
		}
	}
}

fn test_device_clip_replay_keeps_fractional_bounds_under_transforms_and_effects() {
	mut tree := painting.new_accumulated_visual_context_tree()
	transform := tree.append(painting.TransformVisualData{
		matrix: painting.Affine{a: 1, d: 1, e: 3, f: 7}
	}, 0)
	clip := tree.append(painting.ClipVisualData{
		rect: painting.IntRect{21, 41, 201, 61}
		corner_radii: painting.CornerRadii{
			top_left: painting.CornerRadius{11, 11}
		}
		device_pixel_scale: 2
	}, transform)
	effect := tree.append(painting.EffectsVisualData{opacity: 0.5}, clip)
	context := flatten_compatibility_visual_context(tree, effect, painting.ScrollStateSnapshot{})
	assert context.clip == LayoutRect{13.5, 27.5, 100.5, 30.5}
	assert context.clips[0].rect == LayoutRect{10.5, 20.5, 100.5, 30.5}
	assert context.clips[0].corner_radii.top_left == CornerRadius{5.5, 5.5}
	assert context.layers[0].clip_rect or { panic('bounds') } == context.clip
}

fn test_overflow_paint_commands_retain_the_device_snapped_clip() {
	mut document := html.parse_document('<!doctype html><style>
		body{margin:0}#clip{position:absolute;left:10.25px;top:20.25px;
		width:100.5px;height:30.5px;overflow:hidden}#ink{width:200px;height:100px;background:red}
	</style><div id="clip"><div id="ink"></div></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	for density in [f64(2), 1, 2] {
		document.set_display_device_pixel_ratio(density)
		_ = layout_document_typed_in_viewport(document, 300, 150)
		list := document.record_display_list() or { panic('display list') }
		result := viewport_layout_result(list.concrete_handle)
		commands := result.display_list_commands.filter(it.kind == 'fill_rect' && it.color == 'rgb(255 0 0)')
		assert commands.len == 1
		command := commands[0]
		assert command.has_clip
		assert [command.clip_x, command.clip_y, command.clip_width, command.clip_height] ==
			if density == 2 { [10.5, 20.5, 100.5, 30.5] } else { [10.0, 20, 101, 31] }, 'density=${density}, actual=${command.clip_x},${command.clip_y},${command.clip_width},${command.clip_height}'
	}
}
