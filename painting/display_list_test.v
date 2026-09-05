module painting

import platform

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
