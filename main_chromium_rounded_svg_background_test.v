module main

import layout
import painting

fn svg_background_test_rectangle() []f32 {
	stride := layout.compatibility_clip_path_segment_stride
	mut data := []f32{len: stride * 5}
	for i, point in [painting.Point{15, 16}, painting.Point{141, 16}, painting.Point{141, 127},
		painting.Point{15, 127}] {
		data[i * stride] = if i == 0 { f32(0) } else { f32(1) }
		data[i * stride + 1] = f32(point.x)
		data[i * stride + 2] = f32(point.y)
	}
	data[stride * 4] = 5
	return data
}

fn test_svg_background_rectangular_masks_use_geometry_instead_of_path_bounds() {
	data := svg_background_test_rectangle()
	assert svg_background_rectangle_path(data)? == painting.Rect{15, 16, 126, 111}
	mut curve := data.clone()
	curve[layout.compatibility_clip_path_segment_stride] = 3
	assert svg_background_rectangle_path(curve) == none
	mut crossed := data.clone()
	crossed[layout.compatibility_clip_path_segment_stride + 1] = 15
	crossed[layout.compatibility_clip_path_segment_stride + 2] = 127
	assert svg_background_rectangle_path(crossed) == none
	part := layout.PaintPath{ path_data: data, transform: [f64(.125), 0, 0, .125, 4, 6]! }
	clip := layout.PaintClip{ is_svg_mask: true, path_components: [part] }
	assert svg_background_rectangular_clip(clip)? == painting.Rect{5.875, 8, 15.75, 13.875}
	assert svg_background_rectangular_clip(layout.PaintClip{
		...clip
		path_components: [
			part,
			part,
		]
	}) == none
	assert svg_background_rectangular_clip(layout.PaintClip{ ...clip, is_svg_content_mask: true }) == none
}

fn test_svg_background_outer_clip_folds_only_matching_rounded_ancestors() {
	radius := layout.CornerRadius{10, 10}
	radii := layout.BoxRadii{ top_left: radius, top_right: radius, bottom_right: radius, bottom_left: radius }
	image := &layout.PaintImageData{
		image_clip_x:      116
		image_clip_y:      295
		image_clip_width:  20
		image_clip_height: 20
		image_clip_radii:  radii
	}
	round := layout.PaintClip{ rect: layout.LayoutRect{116, 295, 20, 20}, corner_radii: radii }
	command := layout.PaintCommand{
		kind:       'draw_background_image'
		image_data: image
		has_clip:   true
		clip_list:  &layout.PaintClipList{
			items: [
				layout.PaintClip{ rect: layout.LayoutRect{0, 0, 1024, 768} },
				round,
				round,
			]
		}
	}
	clip := chromium_svg_background_outer_clip(&command)?
	assert clip[0] == 116 && clip[1] == 295 && clip[4] == 10
	assert chromium_svg_background_has_rounded_ancestor(&command)
	assert !chromium_svg_background_has_rounded_ancestor(&layout.PaintCommand{ ...command, has_clip: false })
	assert !chromium_svg_background_has_rounded_ancestor(&layout.PaintCommand{
		...command
		clip_list: &layout.PaintClipList{ items: [layout.PaintClip{ rect: layout.LayoutRect{0, 0, 1024, 768} }] }
	})
	for invalid in [
		layout.PaintClip{ rect: layout.LayoutRect{117, 295, 19, 20} },
		layout.PaintClip{ ...round, is_path: true },
		layout.PaintClip{ ...round, transform: [f64(1), 0, 0, 1, 1, 0]! },
		layout.PaintClip{ ...round, corner_radii: layout.BoxRadii{ top_left: layout.CornerRadius{9, 9} } },
	] {
		changed := layout.PaintCommand{ ...command, clip_list: &layout.PaintClipList{ items: [invalid] } }
		assert chromium_svg_background_outer_clip(&changed) == none
	}
}

fn test_svg_background_path_clip_is_inverse_mapped_through_the_viewbox() {
	data := svg_background_test_rectangle()
	path := layout.PaintCommand{
		kind:      'draw_svg_path'
		color:     '#f7b259'
		svg_data:  &layout.PaintSVGPathData{
			path_data:      data
			path_transform: [
				f64(.125),
				0,
				0,
				.125,
				0,
				0,
			]!
		}
		has_clip:  true
		clip_list: &layout.PaintClipList{
			items: [layout.PaintClip{
				is_svg_mask:     true
				path_components: [layout.PaintPath{
					path_data: data
					transform: [f64(.125), 0, 0, .125, 0, 0]!
				}]
			}]
		}
	}
	clip := chromium_svg_background_path_clips(&path, [])?
	assert clip.has_clip == 1 && clip.has_ancestor_clip == 0
	assert clip.clip[0] == 15 && clip.clip[1] == 16
	assert clip.clip[2] == 126 && clip.clip[3] == 111
	// Lowered mask layers are absent from the individual path's clip list.
	lowered := layout.PaintCommand{ ...path, has_clip: false, clip_list: unsafe { nil } }
	layer_clip := chromium_svg_background_path_clips(&lowered,
		[painting.Rect{1, 2, 15, 14}, painting.Rect{2, 1, 12, 14}])?
	assert layer_clip.has_clip == 1
	assert layer_clip.clip[0] == 16 && layer_clip.clip[1] == 16
	assert layer_clip.clip[2] == 96 && layer_clip.clip[3] == 104
	for unsupported in [
		layout.PaintCommand{ ...path, opacity: .5 },
		layout.PaintCommand{ ...path, stroke_color: '#000', stroke_width: 1 },
		layout.PaintCommand{ ...path, transform: [f64(1), .5, 0, 1, 0, 0]! },
		layout.PaintCommand{ ...path, clip_outs: [f64(0), 0, 1, 1] },
	] {
		assert chromium_svg_background_path_clips(&unsupported, []) == none
	}
}
