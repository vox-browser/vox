module main

import encoding.base64
import dom
import html
import layout
import math
import painting

fn svg_image_group_test_image(svg string) (layout.PaintCommand, &dom.Document) {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}img{position:absolute;left:12px;top:8.5px;width:163px;height:33px}</style><img src="data:image/svg+xml;base64,${base64.encode_str(svg)}">')
	document.set_font_rendering_policy(.chromium)
	_ = layout.layout_document_typed_in_viewport(document, 1024, 768)
	commands := layout.display_list_commands(document.record_display_list() or { panic('missing image paint') })
	for command in commands {
		if command.kind == 'paint_nested_display_list' { return command, document }
	}
	panic('missing vector image')
}

fn test_vector_image_rectangular_clip_scopes_keep_local_viewbox_precision() {
	svg := '<svg xmlns="http://www.w3.org/2000/svg" width="178" height="34" viewBox="0 0 178 34"><defs><clipPath id="c"><rect width="178" height="34"/></clipPath></defs><g clip-path="url(#c)"><path d="M48.733 20.6883L178 0V34Z" fill="white"/></g></svg>'
	image, mut document := svg_image_group_test_image(svg)
	defer { document.finalize() }
	assert chromium_svg_image_can_share_recording(image)
	assert !chromium_svg_image_can_share_recording(layout.PaintCommand{
		...image
		transform: [f64(1.25), 0, 0, 1.25, 0, 0]!
	})
	mut masks := []painting.Rect{}
	mut found := false
	for command in image.nested_viewport_commands {
		if command.kind == 'begin_svg_mask_layer' {
			masks << svg_background_rectangular_clip(command.mask_clip()) or { panic('missing rectangle') }
		}
		if command.kind != 'draw_svg_path' { continue }
		found = true
		descriptor := chromium_svg_image_path_clip(&command, masks) or { panic('missing clipped path') }
		assert descriptor.has_clip == 1
		matrix := multiply_paint_transforms(command.transform, command.svg_data.path_transform)
		// The 12px page translation is applied by the parent after the local
		// matrix has been retained; it must not contaminate its float offset.
		assert descriptor.matrix[2] == f32(matrix[4])
		assert math.abs(f64(descriptor.matrix[0]) - f64(163) / 178) < 1e-6
		assert descriptor.clip[2] > 0 && descriptor.clip[2] <= 178
	}
	assert found && masks.len == 1
}

fn test_vector_image_masks_require_balanced_identity_and_rectangular_geometry() {
	data := [f32(0), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
	mut rectangle := []f32{}
	for point in [[f32(0), 0, 0]!, [f32(1), 10, 0]!, [f32(1), 10, 10]!, [f32(1), 0, 10]!,
		[f32(5), 0, 0]!] {
		rectangle << [point[0], point[1], point[2], f32(0), 0, 0, 0, 0, 0, 0, 0, 0]
	}
	clip := &layout.PaintClip{
		is_svg_mask:     true
		cache_key:       7
		scope_id:        11
		path_components: [layout.PaintPath{ path_data: rectangle }]
	}
	begin := layout.PaintCommand{ kind: 'begin_svg_mask_layer', mask_clip_data: clip }
	end := layout.PaintCommand{ kind: 'end_svg_mask_layer', mask_clip_data: clip }
	path := layout.PaintCommand{ kind: 'draw_svg_path', color: 'white', svg_data: &layout.PaintSVGPathData{ path_data: data } }
	image := layout.PaintCommand{
		kind:                     'paint_nested_display_list'
		nested_viewport_commands: [
			begin,
			path,
			end,
		]
	}
	assert chromium_svg_image_can_share_recording(image)
	assert chromium_svg_image_can_share_recording(layout.PaintCommand{
		...image
		nested_viewport_commands: [
			begin,
			begin,
			path,
			end,
			end,
		]
	})
	for children in [[begin, path], [path, end], [begin, path, end, end], [begin, end],
		[begin, layout.PaintCommand{ ...path, group_opacity: .5 }, end], [begin, path,
			layout.PaintCommand{ ...end, mask_clip_data: &layout.PaintClip{ ...*clip, scope_id: 12 } }],
		[layout.PaintCommand{ ...begin, mask_clip_data: &layout.PaintClip{ ...*clip, is_svg_content_mask: true } },
			path, end], [begin, layout.PaintCommand{ ...path, stroke_color: 'black', stroke_width: 1 },
			end]] {
		assert !chromium_svg_image_can_share_recording(layout.PaintCommand{ ...image, nested_viewport_commands: children })
	}
	triangle := rectangle[..rectangle.len - 12]
	translucent := layout.PaintCommand{
		...path
		svg_data: &layout.PaintSVGPathData{
			...*path.svg_data
			fill_opacity: .5
		}
	}
	assert !chromium_svg_image_can_share_recording(layout.PaintCommand{
		...image
		nested_viewport_commands: [begin, translucent, end]
	})
	assert !chromium_svg_image_can_share_recording(layout.PaintCommand{
		...image
		nested_viewport_commands: [layout.PaintCommand{
			...begin
			mask_clip_data: &layout.PaintClip{
				...*clip
				path_components: [layout.PaintPath{ path_data: triangle }]
			}
		}, path, end]
	})
}
