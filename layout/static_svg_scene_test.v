module layout

import css
import dom
import painting
import platform

fn static_svg_scene_test_gradient() painting.SVGGradientPaintStyle {
	return painting.SVGGradientPaintStyle{
		color_stops:        [painting.ColorStop{ color: painting.Color{7, 11, 13, 255}, position: 0.25, transition_hint: 0.4 }]
		repeat_length:      0.75
		gradient_transform: painting.Affine{ e: 17, f: 19 }
		spread_method:      .reflect
		color_space:        .linear_srgb
	}
}

fn static_svg_scene_test_clip() PaintClip {
	return PaintClip{
		rect:            LayoutRect{1, 2, 30, 40}
		corner_radii:    BoxRadii{ top_left: CornerRadius{3, 5} }
		is_path:         true
		is_svg_mask:     true
		path_data:       [f32(23), 29, 31]
		path_even_odd:   true
		path_components: [PaintPath{
			path_data:     [f32(37), 41, 43]
			path_even_odd: true
			transform:     [f64(2), 0, 0, 2, 47, 53]!
		}]
		cache_key:       59
		scope_id:        61
		mask_luminance:  true
		transform:       [f64(3), 0, 0, 3, 67, 71]!
	}
}

fn static_svg_scene_test_commands() []PaintCommand {
	mask := &PaintVisualLayer{
		kind:      .svg_mask
		scope_id:  61
		mask_clip: static_svg_scene_test_clip()
	}
	effect := &PaintVisualLayer{
		kind:      .css_effect
		scope_id:  73
		opacity:   0.65
		clip_rect: LayoutRect{3, 4, 50, 60}
	}
	return [
		PaintCommand{ kind: 'begin_css_effect_layer'.clone(), visual_layer_data: effect },
		PaintCommand{ kind: 'begin_svg_mask_layer'.clone(), visual_layer_data: mask },
		PaintCommand{
			kind:                'draw_svg_path'.clone()
			x:                   79
			y:                   83
			width:               89
			height:              97
			color:               'rgba(7, 11, 13, 1)'.clone()
			srgb_color_data:     &PaintSRGBColor{
				serialized: 'color(srgb .1 .2 .3)'.clone()
				components: [
					f64(0.1),
					0.2,
					0.3,
					1,
				]!
			}
			stroke_color:        '#abcdef'.clone()
			line_style:          'solid'.clone()
			stroke_width:        2.5
			opacity:             0.65
			group_opacity:       0.65
			force_dark_backdrop: painting.Color{101, 103, 107, 255}
			local_border_data:   &PaintLocalBorderData{ origin_x: 109, origin_y: 113, transform_context_index: 127, initial_transform: painting.Affine{ e: 131, f: 137 } }
			clip_outs:           [
				f64(139),
				149,
				151,
				157,
			]
			points:              [
				f64(163),
				167,
			]
			transform:           [
				f64(5),
				0,
				0,
				5,
				173,
				179,
			]!
			svg_data:            &PaintSVGPathData{
				path:                 'M0 0L10 0L10 10Z'.clone()
				path_data:            [
					f32(181),
					191,
					193,
				]
				path_transform:       [
					f64(7),
					0,
					0,
					7,
					197,
					199,
				]!
				path_polygons:        [
					[f64(211), 223],
					[f64(227), 229],
				]
				svg_solid_color_data: &PaintSVGSolidColorData{
					fill_serialized:   'rgba(7, 11, 13, 1)'.clone()
					fill:              css.Color{7, 11, 13, 255}
					has_fill:          true
					stroke_serialized: '#abcdef'.clone()
					stroke:            css.Color{171, 205, 239, 255}
					has_stroke:        true
				}
				svg_gradient_data:    &PaintSVGGradientData{
					fill_linear_gradient:   painting.SVGLinearGradientPaintStyle{ gradient: static_svg_scene_test_gradient(), start_point: painting.Point{2, 3}, end_point: painting.Point{5, 7} }
					stroke_linear_gradient: painting.SVGLinearGradientPaintStyle{ gradient: static_svg_scene_test_gradient(), end_point: painting.Point{11, 13} }
					fill_radial_gradient:   painting.SVGRadialGradientPaintStyle{ gradient: static_svg_scene_test_gradient(), start_center: painting.Point{17, 19}, start_radius: 23, end_center: painting.Point{29, 31}, end_radius: 37 }
					stroke_radial_gradient: painting.SVGRadialGradientPaintStyle{ gradient: static_svg_scene_test_gradient(), end_radius: 41 }
				}
				stroke_dasharray:     [
					f64(3),
					5,
				]
				stroke_dashoffset:    7
				non_scaling_stroke:   true
				stroke_first:         true
				fill_even_odd:        true
				stroke_linecap:       1
				stroke_linejoin:      2
				stroke_miterlimit:    9
				fill_opacity:         0.7
				stroke_opacity:       0.8
			}
			has_clip:            true
			clip_x:              1
			clip_y:              2
			clip_width:          30
			clip_height:         40
			clip_list:           &PaintClipList{ items: [static_svg_scene_test_clip()] }
			recording_clip:      LayoutRect{5, 6, 70, 80}
			visual_layer_list:   &PaintVisualLayerList{
				items: [
					*effect,
					*mask,
				]
			}
			mask_clip_data:      &PaintClip{
				rect:      LayoutRect{7, 8, 90, 100}
				path_data: [
					f32(233),
					239,
				]
			}
			fixed_to_viewport:   true
		},
		PaintCommand{ kind: 'end_svg_mask_layer'.clone(), visual_layer_data: mask },
		PaintCommand{ kind: 'end_css_effect_layer'.clone(), visual_layer_data: effect },
	]
}

fn assert_static_svg_scene_test_clip(clip &PaintClip) {
	assert clip.rect == LayoutRect{1, 2, 30, 40}
	assert clip.corner_radii.top_left == CornerRadius{3, 5}
	assert clip.is_path && clip.is_svg_mask && !clip.is_svg_content_mask
	assert clip.path_data == [f32(23), 29, 31]
	assert clip.path_even_odd
	assert clip.path_components[0].path_data == [f32(37), 41, 43]
	assert clip.path_components[0].path_even_odd
	assert clip.path_components[0].transform == [f64(2), 0, 0, 2, 47, 53]!
	assert clip.cache_key == 59 && clip.scope_id == 61 && clip.mask_luminance
	assert clip.transform == [f64(3), 0, 0, 3, 67, 71]!
}

fn assert_static_svg_scene_test_gradient(gradient &painting.SVGGradientPaintStyle) {
	assert gradient.color_stops[0].color == painting.Color{7, 11, 13, 255}
	assert gradient.color_stops[0].position == 0.25
	assert (gradient.color_stops[0].transition_hint or { panic('missing hint') }) == 0.4
	assert (gradient.repeat_length or { panic('missing repeat') }) == 0.75
	assert (gradient.gradient_transform or { panic('missing transform') }) == painting.Affine{ e: 17, f: 19 }
	assert gradient.spread_method == .reflect
	assert gradient.color_space == .linear_srgb
}

fn test_static_svg_scene_owns_all_shape_payloads_after_source_arena_retirement() {
	mut source := platform.new_arena('static SVG scene source')
	entry := source.enter()
	commands := static_svg_scene_test_commands()
	source.leave(entry)
	mut owner := platform.new_retained_arena('owned static SVG scene')
	mut scope := owner.enter_nested()
	owned := own_static_svg_commands(commands) or { panic('rejected static scene') }
	scope.finish()
	assert voidptr(owned[2].svg_data) != voidptr(commands[2].svg_data)
	assert voidptr(owned[2].clip_list) != voidptr(commands[2].clip_list)
	assert voidptr(owned[2].visual_layer_list) != voidptr(commands[2].visual_layer_list)
	// With VOX_ARENA_POISON=1 the source becomes overwritten/write-protected.
	// No subsequent assertion may consult commands or another source pointer.
	source.release()
	assert owned.map(it.kind) == ['begin_css_effect_layer', 'begin_svg_mask_layer', 'draw_svg_path',
		'end_svg_mask_layer', 'end_css_effect_layer']
	command := unsafe { &owned[2] }
	assert command.x == 79 && command.y == 83 && command.width == 89 && command.height == 97
	assert command.color == 'rgba(7, 11, 13, 1)' && command.stroke_color == '#abcdef'
	assert command.line_style == 'solid' && command.stroke_width == 2.5
	assert command.opacity == 0.65 && command.group_opacity == 0.65
	assert (command.force_dark_backdrop or { panic('missing backdrop') }) == painting.Color{101, 103, 107, 255}
	assert command.srgb_color_data.serialized == 'color(srgb .1 .2 .3)'
	assert command.srgb_color_data.components == [f64(0.1), 0.2, 0.3, 1]!
	assert command.local_border_data.origin_x == 109 && command.local_border_data.origin_y == 113
	assert command.local_border_data.transform_context_index == 127
	assert command.local_border_data.initial_transform == painting.Affine{ e: 131, f: 137 }
	assert command.clip_outs == [f64(139), 149, 151, 157]
	assert command.points == [f64(163), 167]
	assert command.transform == [f64(5), 0, 0, 5, 173, 179]!
	path := command.svg_data
	assert path.path == 'M0 0L10 0L10 10Z'
	assert path.path_data == [f32(181), 191, 193]
	assert path.path_transform == [f64(7), 0, 0, 7, 197, 199]!
	assert path.path_polygons == [[f64(211), 223], [f64(227), 229]]
	assert path.stroke_dasharray == [f64(3), 5] && path.stroke_dashoffset == 7
	assert path.non_scaling_stroke && path.stroke_first && path.fill_even_odd
	assert path.stroke_linecap == 1 && path.stroke_linejoin == 2 && path.stroke_miterlimit == 9
	assert path.fill_opacity == 0.7 && path.stroke_opacity == 0.8
	assert path.svg_solid_color_data.fill_serialized == command.color
	assert path.svg_solid_color_data.fill == css.Color{7, 11, 13, 255}
	assert path.svg_solid_color_data.has_fill && path.svg_solid_color_data.has_stroke
	assert path.svg_solid_color_data.stroke_serialized == '#abcdef'
	assert path.svg_solid_color_data.stroke == css.Color{171, 205, 239, 255}
	linear := command.fill_linear_gradient() or { panic('missing linear fill') }
	linear_stroke := command.stroke_linear_gradient() or { panic('missing linear stroke') }
	radial := command.fill_radial_gradient() or { panic('missing radial fill') }
	radial_stroke := command.stroke_radial_gradient() or { panic('missing radial stroke') }
	assert_static_svg_scene_test_gradient(&linear.gradient)
	assert_static_svg_scene_test_gradient(&linear_stroke.gradient)
	assert_static_svg_scene_test_gradient(&radial.gradient)
	assert_static_svg_scene_test_gradient(&radial_stroke.gradient)
	assert linear.start_point == painting.Point{2, 3} && linear.end_point == painting.Point{5, 7}
	assert linear_stroke.end_point == painting.Point{11, 13}
	assert radial.start_center == painting.Point{17, 19} && radial.end_center == painting.Point{29, 31}
	assert radial.start_radius == 23 && radial.end_radius == 37 && radial_stroke.end_radius == 41
	assert_static_svg_scene_test_clip(&command.clip_list.items[0])
	assert_static_svg_scene_test_clip(&command.visual_layer_list.items[1].mask_clip)
	mask_layer := owned[1].visual_layer()
	assert_static_svg_scene_test_clip(&mask_layer.mask_clip)
	assert command.has_clip && command.clip_width == 30 && command.clip_height == 40
	assert (command.recording_clip or { panic('missing recording clip') }) == LayoutRect{5, 6, 70, 80}
	assert command.mask_clip().path_data == [f32(233), 239]
	assert command.fixed_to_viewport
	assert owned[0].visual_layer().opacity == 0.65
	assert (owned[4].visual_layer().clip_rect or { panic('missing effect clip') }) == LayoutRect{3, 4, 50, 60}
	$if prealloc {
		assert owner.arena.contains(owned.data)
		for value in [command.kind, command.color, command.stroke_color, command.line_style,
			command.srgb_color_data.serialized, path.path, path.svg_solid_color_data.fill_serialized,
			path.svg_solid_color_data.stroke_serialized] {
			assert owner.arena.contains(value.str)
		}
		assert owner.arena.contains(path)
		assert owner.arena.contains(command.srgb_color_data)
		assert owner.arena.contains(command.local_border_data)
		assert owner.arena.contains(command.points.data)
		assert owner.arena.contains(command.clip_outs.data)
		assert owner.arena.contains(path.path_data.data)
		assert owner.arena.contains(path.path_polygons.data)
		for polygon in path.path_polygons {
			assert owner.arena.contains(polygon.data)
		}
		assert owner.arena.contains(path.stroke_dasharray.data)
		assert owner.arena.contains(path.svg_solid_color_data)
		assert owner.arena.contains(path.svg_gradient_data or { panic('missing gradients') })
		for stops in [linear.gradient.color_stops, linear_stroke.gradient.color_stops,
			radial.gradient.color_stops, radial_stroke.gradient.color_stops] {
			assert owner.arena.contains(stops.data)
		}
		assert owner.arena.contains(command.clip_list)
		assert owner.arena.contains(command.clip_list.items.data)
		assert owner.arena.contains(command.clip_list.items[0].path_data.data)
		assert owner.arena.contains(command.clip_list.items[0].path_components.data)
		assert owner.arena.contains(command.clip_list.items[0].path_components[0].path_data.data)
		assert owner.arena.contains(command.visual_layer_list)
		assert owner.arena.contains(command.visual_layer_list.items.data)
		assert owner.arena.contains(command.visual_layer_list.items[1].mask_clip.path_data.data)
		assert owner.arena.contains(command.visual_layer_list.items[1].mask_clip.path_components[0].path_data.data)
		assert owner.arena.contains(command.mask_clip_data or { panic('missing mask') })
		assert owner.arena.contains(command.mask_clip().path_data.data)
		assert owner.arena.contains(owned[1].visual_layer_data or { panic('missing layer') })
		assert owner.arena.contains(owned[1].visual_layer().mask_clip.path_components[0].path_data.data)
	}
	owner.release()
}

fn test_static_svg_scene_rejects_hidden_resource_owners_and_unsupported_commands() {
	cases := [
		PaintCommand{ kind: 'draw_text' },
		PaintCommand{ kind: 'draw_background_image' },
		PaintCommand{ kind: 'apply_backdrop_filter' },
		PaintCommand{ kind: 'future_command' },
		PaintCommand{ kind: 'fill_rect', text: 'hidden' },
		PaintCommand{ kind: 'fill_rect', glyph_run: &platform.GlyphRun{} },
		PaintCommand{ kind: 'fill_rect', box_shadow_data: &PaintBoxShadowData{} },
		PaintCommand{ kind: 'fill_rect', gradient: &LinearGradient{} },
		PaintCommand{ kind: 'fill_rect', image_data: &PaintImageData{} },
		PaintCommand{ kind: 'fill_rect', image_paintable: &painting.ImagePaintable{} },
		PaintCommand{ kind: 'fill_rect', replaced_image_bitmap: &dom.Bitmap_{} },
		PaintCommand{ kind: 'fill_rect', canvas_bitmap: &dom.Bitmap_{} },
		PaintCommand{ kind: 'fill_rect', canvas_paintable: &painting.CanvasPaintable{} },
		PaintCommand{ kind: 'fill_rect', video_bitmap: &dom.Bitmap_{} },
		PaintCommand{ kind: 'fill_rect', video_frame_source: &painting.VideoFrameSource{} },
		PaintCommand{ kind: 'fill_rect', video_paintable: &painting.VideoPaintable{} },
		PaintCommand{ kind: 'fill_rect', nested_viewport_commands: [PaintCommand{ kind: 'fill_rect' }] },
		PaintCommand{ kind: 'fill_rect', nested_viewport_paintable: &painting.NavigableContainerViewportPaintable{} },
		PaintCommand{ kind: 'fill_rect', text_clip_runs: [PaintTextClipRun{}] },
		PaintCommand{ kind: 'fill_rect', backdrop_filter_data: &painting.GfxFilter{} },
		PaintCommand{ kind: 'fill_rect', svg_data: &PaintSVGPathData{ fill_pattern: &painting.SVGPatternPaintStyle{} } },
		PaintCommand{ kind: 'fill_rect', svg_data: &PaintSVGPathData{ stroke_pattern: &painting.SVGPatternPaintStyle{} } },
		PaintCommand{ kind: 'fill_rect', clip_list: &PaintClipList{ items: [PaintClip{ is_svg_content_mask: true }] } },
		PaintCommand{ kind: 'fill_rect', mask_clip_data: &PaintClip{ mask_operations: [PaintMaskOperation{ kind: .path }] } },
		PaintCommand{ kind: 'fill_rect', visual_layer_data: &PaintVisualLayer{ kind: .css_filter } },
		PaintCommand{ kind: 'fill_rect', visual_layer_list: &PaintVisualLayerList{ items: [PaintVisualLayer{ filter: painting.GfxFilter{} }] } },
	]
	for index in 0 .. cases.len {
		if _ := own_static_svg_commands([cases[index]]) {
			panic('accepted unsupported static SVG case ${index}')
		}
	}
}

fn test_static_svg_scene_rejects_unbalanced_or_mismatched_layers() {
	effect := &PaintVisualLayer{ kind: .css_effect, scope_id: 1 }
	other := &PaintVisualLayer{ kind: .css_effect, scope_id: 2 }
	mask := &PaintVisualLayer{ kind: .svg_mask, scope_id: 1 }
	cases := [
		[PaintCommand{ kind: 'begin_css_effect_layer' }],
		[PaintCommand{ kind: 'begin_css_effect_layer', visual_layer_data: effect }],
		[PaintCommand{ kind: 'end_css_effect_layer', visual_layer_data: effect }],
		[PaintCommand{ kind: 'begin_css_effect_layer', visual_layer_data: effect },
			PaintCommand{ kind: 'end_css_effect_layer', visual_layer_data: other }],
		[PaintCommand{ kind: 'begin_css_effect_layer', visual_layer_data: effect },
			PaintCommand{ kind: 'end_svg_mask_layer', visual_layer_data: mask }],
	]
	for index in 0 .. cases.len {
		if _ := own_static_svg_commands(cases[index]) {
			panic('accepted unbalanced static SVG case ${index}')
		}
	}
	assert (own_static_svg_commands([]PaintCommand{}) or { panic('rejected empty scene') }).len == 0
	for kind in ['fill_rect', 'fill_rounded_rect', 'stroke_rounded_rect', 'fill_ellipse',
		'stroke_ellipse', 'fill_polygon', 'draw_line', 'draw_svg_path'] {
		assert (own_static_svg_commands([PaintCommand{ kind: kind }]) or { panic('rejected ${kind}') }).len == 1
	}
}
