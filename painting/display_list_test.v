module painting

fn test_display_list_recorder_capture_nesting_and_empty_clip_rejection() {
	mut tree := new_accumulated_visual_context_tree()
	empty_context := tree.append(ClipVisualData{ rect: IntRect{} }, 0)
	mut recorder := new_display_list_recorder(tree)
	assert !recorder.fill_rect(IntRect{}, Color{ r: 1 })
	assert !recorder.fill_rect(IntRect{0, 0, 5, 5}, transparent)
	assert recorder.begin_capture()
	assert !recorder.begin_capture()
	assert recorder.save()
	assert recorder.fill_rect(IntRect{1, 2, 3, 4}, Color{ r: 9 })
	assert recorder.restore()
	captured := recorder.take_capture()
	assert captured.len == 3
	assert command_name(captured[0]) == 'Save'
	assert recorder.save_nesting_level == 0
	assert !recorder.restore()
	recorder.accumulated_context_index = empty_context
	assert !recorder.fill_rect(IntRect{0, 0, 2, 2}, Color{ g: 1 })
	assert recorder.display_list.commands.len == 3
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
	assert recorder.fill_rounded_rect(FillRoundedRect{
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
