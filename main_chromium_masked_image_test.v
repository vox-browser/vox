module main

import html
import layout
import painting

fn masked_image_test_commands() []layout.PaintCommand {
	radius := layout.CornerRadius{10, 10}
	radii := layout.BoxRadii{radius, radius, radius, radius}
	rect := layout.LayoutRect{124, 323, 20, 20}
	mut data := []f32{len: 5 * layout.compatibility_clip_path_segment_stride}
	for i, point in [painting.Point{124, 323}, painting.Point{144, 323},
		painting.Point{144, 343}, painting.Point{124, 343}] {
		data[i * 12] = if i == 0 { f32(0) } else { f32(1) }
		data[i * 12 + 1] = f32(point.x)
		data[i * 12 + 2] = f32(point.y)
	}
	data[48] = 5
	mask := &layout.PaintClip{
		rect: rect
		corner_radii: radii
		is_svg_content_mask: true
		cache_key: 7
		scope_id: 11
		mask_operations: [layout.PaintMaskOperation{
			kind: .path
			has_fill: true
			path_data: data
			fill_radial_gradient: painting.SVGRadialGradientPaintStyle{
				end_radius: 15
				gradient: painting.SVGGradientPaintStyle{color_stops: [
					painting.ColorStop{color: painting.Color{255, 255, 255, 255}, position: 0},
					painting.ColorStop{color: painting.Color{0, 0, 0, 255}, position: 1},
				]}
			}
		}]
	}
	clipped := &layout.PaintClipList{items: [layout.PaintClip{rect: rect, corner_radii: radii}]}
	return [
		layout.PaintCommand{kind: 'begin_svg_mask_layer', mask_clip_data: mask},
		layout.PaintCommand{kind: 'fill_rect', x: 124, y: 323, width: 20, height: 20,
			radius: 10, color: '#fff', has_clip: true, clip_list: clipped},
		layout.PaintCommand{kind: 'draw_replaced_image', x: 124, y: 323, width: 20, height: 20,
			has_clip: true, clip_list: clipped, image_paintable: &painting.ImagePaintable{
				border_radii: painting.BorderRadiiData{
					top_left: painting.BorderRadiusData{10, 10}
					top_right: painting.BorderRadiusData{10, 10}
					bottom_right: painting.BorderRadiusData{10, 10}
					bottom_left: painting.BorderRadiusData{10, 10}
				}
			}},
		layout.PaintCommand{kind: 'end_svg_mask_layer', mask_clip_data: mask},
	]
}

fn test_masked_image_requires_a_complete_same_owner_scope() {
	commands := masked_image_test_commands()
	assert chromium_masked_image_end(commands, [], 0) == 4
	assert chromium_masked_image_end(commands, [2, 2, 2, 2], 0) == 4
	assert chromium_masked_image_end(commands, [2, 2, 3, 2], 0) == 0
	assert chromium_masked_image_end(commands, [2], 0) == 0
	assert chromium_masked_image_end(commands[..3], [], 0) == 0
	assert chromium_masked_image_end(commands, [], -1) == -1
	for index in 0 .. 4 {
		for changed in [layout.PaintCommand{...commands[index], opacity: .5},
			layout.PaintCommand{...commands[index], group_opacity: .5},
			layout.PaintCommand{...commands[index], transform: [f64(1), 0, 0, 1, 1, 0]!},
			layout.PaintCommand{...commands[index], clip_outs: [f64(0), 0, 1, 1]}] {
			mut copy := commands.clone()
			copy[index] = changed
			assert chromium_masked_image_end(copy, [], 0) == 0
		}
	}
}

fn test_masked_image_rejects_unrepresented_clips_and_content_geometry() {
	commands := masked_image_test_commands()
	for clip in [layout.PaintClip{is_path: true}, layout.PaintClip{is_svg_mask: true},
		layout.PaintClip{rect: layout.LayoutRect{125, 323, 19, 20}},
		layout.PaintClip{rect: layout.LayoutRect{124, 323, 20, 20},
			corner_radii: layout.BoxRadii{top_left: layout.CornerRadius{3, 3}}}] {
		mut copy := commands.clone()
		copy[2] = layout.PaintCommand{...commands[2],
			clip_list: &layout.PaintClipList{items: [clip]}}
		assert chromium_masked_image_end(copy, [], 0) == 0
	}
	for changed in [layout.PaintCommand{...commands[2], x: 125},
		layout.PaintCommand{...commands[2], image_paintable: &painting.ImagePaintable{}},
		layout.PaintCommand{...commands[2], kind: 'draw_video'}] {
		assert chromium_masked_image_end([commands[0], commands[1], changed, commands[3]], [], 0) == 0
	}
	for index in [1, 2] {
		mut copy := commands.clone()
		copy[index] = layout.PaintCommand{...commands[index], local_border_data: &layout.PaintLocalBorderData{
			corner_shapes: [f64(2), 2, 2, 2]!
		}}
		assert chromium_masked_image_end(copy, [], 0) == 0
	}
	for color in ['#fff', '#234567', '#12345680'] {
		background := layout.PaintCommand{...commands[1], color: color}
		assert chromium_masked_image_end([commands[0], background, commands[2], commands[3]], [], 0) == 4
	}
}

fn test_masked_image_requires_an_opaque_alpha_mask_and_matching_boundary() {
	commands := masked_image_test_commands()
	mask := commands[0].mask_clip()
	op := mask.mask_operations[0]
	gradient := op.fill_radial_gradient or { panic('missing radial gradient') }
	for changed in [layout.PaintClip{...mask, mask_luminance: true},
		layout.PaintClip{...mask, corner_radii: layout.BoxRadii{}},
		layout.PaintClip{...mask, mask_operations: [op, op]},
		layout.PaintClip{...mask, mask_operations: [layout.PaintMaskOperation{...op, fill_opacity: .5}]},
		layout.PaintClip{...mask, mask_operations: [layout.PaintMaskOperation{...op,
			fill_radial_gradient: painting.SVGRadialGradientPaintStyle{...gradient,
				gradient: painting.SVGGradientPaintStyle{color_stops: [
					painting.ColorStop{color: painting.Color{255, 255, 255, 255}, position: 0},
					painting.ColorStop{color: painting.Color{0, 0, 0, 0}, position: 1},
				]}}}]}] {
		begin := layout.PaintCommand{...commands[0], mask_clip_data: &changed}
		end := layout.PaintCommand{...commands[3], mask_clip_data: &changed}
		assert chromium_masked_image_end([begin, commands[1], commands[2], end], [], 0) == 0
	}
	changed := layout.PaintClip{...mask, scope_id: 12}
	end := layout.PaintCommand{...commands[3], mask_clip_data: &changed}
	assert chromium_masked_image_end([commands[0], commands[1], commands[2], end], [], 0) == 0
}

fn test_css_mask_radius_reaches_the_real_replaced_image_scope() {
	mut keys := []u64{}
	for radius in [4, 10] {
		mut document := html.parse_document('<!doctype html><style>body{margin:0}.outer{position:absolute;left:124px;top:323px;width:20px;height:20px}.inner{display:inline-block;line-height:0;overflow:hidden;border-radius:${radius}px;width:100%;height:100%;-webkit-mask-image:-webkit-radial-gradient(circle,#fff 100%,#000 100%)}img{width:100%;height:100%;background:white;border-radius:${radius}px}</style><div class="outer"><span class="inner"><img width="72" height="72" src="https://image.test/photo.png"></span></div>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		_ = layout.layout_document_typed_in_viewport(document, 1024, 768)
		list := document.record_display_list() or { panic('missing paint') }
		commands := layout.display_list_commands(list)
		mut checked := 0
		for i, command in commands {
			if command.kind != 'begin_svg_mask_layer' { continue }
			mask := command.mask_clip()
			assert mask.corner_radii.top_left == layout.CornerRadius{f64(radius), f64(radius)}
			keys << mask.cache_key
			assert chromium_masked_image_end(commands, [], i) == i + 4
			checked++
		}
		assert checked == 1
	}
	assert keys.len == 2 && keys[0] != keys[1]
}

fn test_masked_image_keeps_fractional_and_nonround_masks_in_general_replay() {
	for declaration in ['border-radius:4.5px', 'border-radius:10px;corner-shape:bevel',
		'border-radius:10px;corner-shape:squircle'] {
		mut document := html.parse_document('<!doctype html><style>body{margin:0}.inner{position:absolute;left:124px;top:323px;width:20px;height:20px;overflow:hidden;${declaration};mask-image:radial-gradient(white,white)}img{width:20px;height:20px;background:white;${declaration}}</style><div class="inner"><img width="72" height="72" src="https://image.test/photo.png"></div>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		_ = layout.layout_document_typed_in_viewport(document, 1024, 768)
		list := document.record_display_list() or { panic('missing paint') }
		commands := layout.display_list_commands(list)
		mut checked := 0
		for i, command in commands {
			if command.kind != 'begin_svg_mask_layer' { continue }
			assert chromium_masked_image_end(commands, [], i) == i
			checked++
		}
		assert checked == 1
	}
}
