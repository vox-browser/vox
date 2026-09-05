module painting

import css
import platform

fn test_display_list_recording_context_translates_device_and_css_geometry() {
	mut recorder := new_display_list_recorder(new_accumulated_visual_context_tree())
	context := new_display_list_recording_context(&recorder, Palette('test'), 1.5, ChromeMetrics{}) or { panic(err) }

	css_pixels := css.CSSPixels.nearest_value_for(2.4)
	assert context.rounded_device_pixels(css_pixels) == 4
	assert context.floored_device_pixels(css_pixels) == 3
	assert context.enclosing_device_pixels(css_pixels) == 4
	point := css.CSSPixelPoint.from_values(1, 2)
	assert context.rounded_device_point(point) == IntPoint{2, 3}
	assert context.floored_device_point(point) == IntPoint{1, 3}
	rect := css.CSSPixelRect.new(0.2, 1.1, 2.2, 3.1)
	assert context.enclosing_device_rect(rect) == IntRect{0, 1, 4, 5}
	assert context.rounded_device_rect(rect) == IntRect{0, 2, 4, 4}
	size := css.CSSPixelSize.from_values(2.2, 3.1)
	assert context.enclosing_device_size(size) == IntSize{4, 5}
	assert context.rounded_device_size(size) == IntSize{3, 5}

	mut quantized_recorder := new_display_list_recorder(new_accumulated_visual_context_tree())
	mut quantized_context := new_display_list_recording_context(&quantized_recorder, Palette('test'), 3, ChromeMetrics{}) or { panic(err) }
	// Device-to-CSS conversion constructs CSSPixels, so 1/3 is quantized to
	// Ladybird's nearest 1/64 CSS pixel rather than retained as an f64.
	assert quantized_context.scale_to_css_pixels(1).raw_value() == 21
	assert quantized_context.scale_to_css_point(IntPoint{1, 2}).y().raw_value() == 43
	assert quantized_context.scale_to_css_size(IntSize{2, 3}).width().raw_value() == 43
	quantized_rect := quantized_context.scale_to_css_rect(IntRect{1, 2, 3, 4})
	assert quantized_rect.x.raw_value() == 21
	assert quantized_rect.y.raw_value() == 43
	assert quantized_rect.width.raw_value() == 64
	assert quantized_rect.height.raw_value() == 85
	quantized_context.set_device_viewport_rect(IntRect{1, 2, 3, 4})
	viewport := quantized_context.css_viewport_rect()
	assert viewport.x.raw_value() == 21
	assert viewport.y.raw_value() == 43
	assert viewport.width.raw_value() == 64
	assert viewport.height.raw_value() == 85
}

fn test_display_list_recording_context_clone_copies_only_source_state() {
	mut first_recorder := new_display_list_recorder(new_accumulated_visual_context_tree())
	metrics := new_chrome_metrics(2) or { panic(err) }
	mut context := new_display_list_recording_context(&first_recorder, Palette('dark'), 2, metrics) or { panic(err) }
	context.set_device_viewport_rect(IntRect{10, 20, 300, 400})
	context.set_should_show_line_box_borders(true)
	context.set_should_paint_overlay(false)
	context.set_svg_transform(Affine{ e: 12, f: 34 })
	context.set_draw_svg_geometry_for_clip_path(true)

	mut context_recorder := context.display_list_recorder()
	assert context_recorder.fill_rect(IntRect{1, 2, 3, 4}, Color{ r: 1 })
	assert first_recorder.display_list.commands.len == 1
	assert context.palette() == Palette('dark')
	assert context.device_pixel_converter().device_pixels_per_css_pixel() == 2
	assert context.device_pixels_per_css_pixel() == 2
	assert context.chrome_metrics() == metrics

	mut second_recorder := new_display_list_recorder(new_accumulated_visual_context_tree())
	cloned := context.clone(&second_recorder) or { panic(err) }
	assert cloned.paint_generation_id() == context.paint_generation_id() + 1
	assert cloned.palette() == context.palette()
	assert cloned.device_viewport_rect() == context.device_viewport_rect()
	assert cloned.should_show_line_box_borders()
	assert !cloned.should_paint_overlay()
	// Upstream clone() deliberately does not propagate these transient SVG
	// controls into the new recording pass.
	assert !cloned.draw_svg_geometry_for_clip_path()
	assert cloned.svg_transform() == Affine{}
	mut cloned_recorder := cloned.display_list_recorder()
	assert cloned_recorder.fill_rect(IntRect{5, 6, 7, 8}, Color{ g: 1 })
	assert second_recorder.display_list.commands.len == 1
	assert first_recorder.display_list.commands.len == 1
}

fn test_display_list_recorder_capture_nesting_and_empty_clip_rejection() {
	mut tree := new_accumulated_visual_context_tree()
	empty_context := tree.append(ClipVisualData{ rect: IntRect{} }, 0)
	mut recorder := new_display_list_recorder(tree)
	assert !recorder.fill_rect(IntRect{}, Color{ r: 1 })
	assert !recorder.fill_rect(IntRect{0, 0, 5, 5}, transparent)
	mut capture := recorder.begin_command_capture()
	assert recorder.save()
	assert recorder.fill_rect(IntRect{1, 2, 3, 4}, Color{ r: 9 })
	assert recorder.restore()
	captured_data := recorder.captured_commands.data
	captured := capture.take(mut recorder)
	assert captured.len == 3
	// CommandCapture::take() moves the vector instead of cloning every command.
	assert captured.data == captured_data
	assert command_name(captured[0]) == 'Save'
	assert recorder.save_nesting_level == 0
	recorder.set_accumulated_visual_context(empty_context)
	assert recorder.accumulated_visual_context() == empty_context
	assert !recorder.fill_rect(IntRect{0, 0, 2, 2}, Color{ g: 1 })
	assert recorder.display_list.commands.len == 3
}

fn test_cached_command_replay_bypasses_active_capture() {
	mut recorder := new_display_list_recorder(new_accumulated_visual_context_tree())
	mut capture := recorder.begin_command_capture()
	assert recorder.fill_rect(IntRect{1, 2, 3, 4}, Color{ r: 1 })
	recorder.replay_cached_commands([
		DisplayListCommand(Save{}),
		DisplayListCommand(FillRect{IntRect{5, 6, 7, 8}, Color{ g: 1 }}),
		DisplayListCommand(Restore{}),
	])
	captured := capture.take(mut recorder)
	assert captured.len == 1
	assert recorder.display_list.commands.len == 4
	assert (recorder.display_list.commands[2].command as FillRect).rect == IntRect{5, 6, 7, 8}
	assert recorder.save_nesting_level == 0

	mut abandoned_capture := recorder.begin_command_capture()
	assert recorder.fill_rect(IntRect{9, 10, 11, 12}, Color{ b: 1 })
	abandoned_capture.end(mut recorder)
	assert !recorder.is_capturing
	assert recorder.captured_commands.len == 0
}

fn test_recorder_source_shaped_entry_points_and_nesting_updates() {
	mut recorder := new_display_list_recorder(new_accumulated_visual_context_tree())
	assert !recorder.fill_rect_with_linear_gradient(PaintLinearGradient{})
	assert recorder.fill_rect_with_linear_gradient(PaintLinearGradient{
		rect: IntRect{1, 2, 3, 4}
	})
	assert recorder.fill_rect_with_radial_gradient(PaintRadialGradient{
		rect: IntRect{2, 3, 4, 5}
	})
	assert recorder.fill_rect_with_conic_gradient(PaintConicGradient{
		rect: IntRect{3, 4, 5, 6}
	})
	assert !recorder.draw_scaled_immutable_bitmap(DrawScaledBitmap{})
	assert recorder.draw_scaled_immutable_bitmap(DrawScaledBitmap{
		destination: IntRect{4, 5, 6, 7}
	})
	// The C++ repeated-bitmap entry point deliberately has no empty-rect guard.
	assert recorder.draw_repeated_immutable_bitmap(DrawRepeatedBitmap{})
	font := &platform.Font{ point_size: 16 }
	glyph_run := platform.shape_text(0, 0, 'abc', font, .ltr)
	assert !recorder.draw_glyph_run(Point{}, glyph_run, transparent, IntRect{0, 0, 20, 20}, 1, .horizontal)
	assert recorder.draw_glyph_run(Point{1, 2}, glyph_run, Color{ r: 1 }, IntRect{0, 0, 20, 20}, 1, .horizontal)
	assert !recorder.draw_text(IntRect{}, 'abc', font, .center, Color{ r: 1 })
	assert recorder.draw_text(IntRect{10, 20, 100, 30}, 'abc', font, .center, Color{ r: 1 })
	drawn_text := recorder.display_list.commands.last().command as DrawGlyphRun
	retained_run := drawn_text.glyph_run or { panic('missing retained glyph run') }
	assert retained_run.width() == glyph_run.width()
	expected_x := f32(10) + (f32(100) - glyph_run.width()) / 2.0
	metrics := font.pixel_metrics()
	expected_y := f32(20) + metrics.ascent + (f32(30) - (metrics.ascent + metrics.descent)) / 2.0
	assert drawn_text.translation == Point{f64(expected_x), f64(expected_y)}
	assert recorder.paint_nested_display_list(PaintNestedDisplayList{
		display_list_id: 'nested'
	})

	// APPEND updates the public nesting counter without an invented underflow
	// guard; well-formed callers are responsible for balanced commands.
	assert recorder.restore()
	assert recorder.save_nesting_level == -1
}

fn test_command_bounds_and_playback_culling_context_switches() {
	mut tree := new_accumulated_visual_context_tree()
	effect := tree.append(EffectsVisualData{ opacity: 0.5 }, 0)
	mut list := DisplayList{
		visual_context_tree: tree
	}
	assert list.append(FillRect{IntRect{0, 0, 20, 20}, Color{ r: 1 }}, effect)
	assert list.append(FillRect{IntRect{500, 500, 20, 20}, Color{ g: 1 }}, effect)
	assert list.append(AddRoundedRectClip{uniform_corner_radii(4), IntRect{500, 500, 10, 10}, .outside}, 0)
	assert list.append(PaintScrollbar{
		scroll_frame_index: 1
		thumb_rect: IntRect{0, 0, 5, 20}
		scroll_size: 2
		vertical: true
	}, 0)
	actions := list.playback_plan(ScrollStateSnapshot{
		device_offsets: [
			Point{},
			Point{0, -3},
		]
	}, IntRect{0, 0, 100, 100})
	assert actions.map(it.kind) == ['ApplyEffects', 'FillRect', 'RestoreContext', 'AddClipRect',
		'PaintScrollBar']
	assert actions[4].delta == IntPoint{0, 6}
	outer := PaintOuterBoxShadow{
		blur_radius: 3
		shadow_rect: IntRect{10, 10, 20, 20}
	}
	assert outer.bounding_rect() == IntRect{4, 4, 32, 32}
	assert command_bounding_rect(outer) or { panic('expected bounds') } == IntRect{4, 4, 32, 32}
	assert outer.dump().contains('shadow_rect=')
	inner := PaintInnerBoxShadow{
		blur_radius: 5
		device_content_rect: IntRect{2, 3, 40, 50}
		outer_shadow_rect: IntRect{-5, -4, 60, 70}
		inner_shadow_rect: IntRect{8, 9, 20, 30}
	}
	assert inner.bounding_rect() == IntRect{2, 3, 40, 50}
	assert inner.dump().contains('inner_shadow_rect=')
	line := DrawLine{
		from: IntPoint{10, 20}
		to: IntPoint{30, 5}
		thickness: 2
	}
	assert command_bounding_rect(line) or { panic('expected bounds') } == IntRect{8, 3, 24, 19}
}

fn test_display_list_commands_own_upstream_bounds_and_diagnostics() {
	glyphs := DrawGlyphRun{
		rect: IntRect{10, 20, 30, 40}
		translation: Point{
			x: 0.6
			y: -0.6
		}
		color: Color{
			r: 1
			g: 2
			b: 3
			a: 4
		}
	}
	assert glyphs.bounding_rect() == IntRect{11, 19, 30, 40}
	assert command_bounding_rect(glyphs) or { panic('expected bounds') } == glyphs.bounding_rect()
	assert command_dump(glyphs).starts_with(' rect=')
	assert command_dump(glyphs).contains(' translation=')
	assert command_dump(glyphs).contains(' color=')

	fill := FillRect{IntRect{1, 2, 3, 4}, Color{ r: 5 }}
	assert fill.bounding_rect() == fill.rect
	assert command_dump(fill).starts_with(' rect=')
	assert command_dump(fill).contains(' color=')

	clip := AddRoundedRectClip{
		border_rect: IntRect{2, 4, 6, 8}
	}
	assert clip.bounding_rect() == clip.border_rect
	assert clip.is_clip()
	assert command_is_clip(clip)
	assert command_dump(clip).starts_with(' rect=')

	assert command_dump(ApplyEffects{ opacity: 0.25 }) == ' opacity=0.25 has_filter=false'
	assert command_dump(Save{}) == ''
	assert command_dump(StrokePath{}) == ''
}

fn test_external_content_source_replaces_and_clears_bitmap() {
	mut source := ExternalContentSource{}
	assert source.bitmap_id == none
	source.update('frame-1')
	assert source.bitmap_id or { panic('expected bitmap') } == 'frame-1'
	source.update('frame-2')
	assert source.bitmap_id or { panic('expected bitmap') } == 'frame-2'
	source.clear()
	assert source.bitmap_id == none
}

fn test_recorder_command_guards_rounded_fallback_and_masks() {
	mut recorder := new_display_list_recorder(new_accumulated_visual_context_tree())
	assert !recorder.fill_path(FillPath{})
	assert !recorder.stroke_path(StrokePath{
		path_bounding_rect: IntRect{0, 0, 10, 10}
		color: Color{
			r: 1
		}
	})
	assert !recorder.draw_line(DrawLine{
		from: IntPoint{0, 0}
		to: IntPoint{2, 2}
		color: transparent
	})
	assert recorder.fill_rect_with_rounded_corners(FillRoundedRect{
		rect: IntRect{0, 0, 5, 5}
		color: Color{
			r: 1
		}
	})
	assert command_name(recorder.display_list.commands[0].command) == 'FillRect'
	masks := [
		MaskInfo{
			display_list_id: 'mask-list'
			rect: IntRect{1, 2, 3, 4}
			kind: .luminance
		},
	]
	recorder.begin_masks(masks)
	recorder.end_masks(masks)
	assert recorder.save_nesting_level == 0
	assert recorder.display_list.commands.len == 9
	assert recorder.display_list.commands[4].command is ApplyEffects
	effects := recorder.display_list.commands[4].command as ApplyEffects
	assert effects.operator == .destination_in
	assert effects.mask_kind or { panic('expected mask kind') } == .luminance
}
