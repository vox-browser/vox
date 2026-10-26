module main

import painting

fn test_background_bitmap_tiles_and_clips_snap_their_shared_edges_before_source_cropping() {
	tile := pixel_snapped_background_bitmap_rect(painting.Rect{34.72, 14, 900, 55})
	assert tile == painting.Rect{35, 14, 900, 55}
	clip := pixel_snapped_background_bitmap_rect(painting.Rect{83.71875, 105.265625, 70, 50})
	assert clip == painting.Rect{84, 105, 70, 50}
	left := pixel_snapped_background_bitmap_rect(painting.Rect{-20.28125, 10.71875, 50.5, 40})
	right := pixel_snapped_background_bitmap_rect(painting.Rect{30.21875, 10.71875, 49.5, 40})
	assert left.right() == right.x
	assert left.y == 11 && right.y == 11
	sprite := pixel_snapped_background_bitmap_rect(painting.Rect{957, -1585.5, 140, 1751})
	assert sprite == painting.Rect{957, -1585, 140, 1751}
}

fn test_chromium_background_repeat_includes_the_tile_before_a_narrow_clip() {
	plan := painting.BackgroundTilePlan{
		first_tile: painting.Rect{720, 219, 140, 1751}
		repeat_x:   true
		repeat_y:   true
		x_step:     140
		y_step:     1751
	}
	clip := painting.Rect{719, 218, 35, 16}
	corrected := chromium_background_bitmap_plan(plan, clip)
	assert corrected.first_tile == painting.Rect{580, -1532, 140, 1751}
	assert painting.background_tiles_from_plan_limited(corrected, clip, 4096).len == 4
	assert chromium_background_bitmap_tiles_are_bounded(corrected, clip, 4)
	assert !chromium_background_bitmap_tiles_are_bounded(corrected, clip, 3)
	assert chromium_background_bitmap_plan(corrected, clip) == corrected
	assert chromium_background_bitmap_plan(painting.BackgroundTilePlan{
		...plan
		repeat_x_has_gap: true
	}, clip).first_tile == plan.first_tile
}

fn test_tiny_background_tiles_keep_the_unbounded_repeated_bitmap_primitive() {
	plan := painting.BackgroundTilePlan{
		first_tile: painting.Rect{0, 0, 1, 1}
		repeat_x:   true
		repeat_y:   true
		x_step:     1
		y_step:     1
	}
	assert !chromium_background_bitmap_tiles_are_bounded(plan, painting.Rect{0, 0, 1024, 768}, 4096)
}

fn test_background_patterns_crop_single_tiles_and_repeat_across_tile_edges() {
	plan := painting.BackgroundTilePlan{
		first_tile: painting.Rect{20, 30, 140, 1751}
		repeat_x:   true
		repeat_y:   true
		x_step:     140
		y_step:     1751
	}
	assert chromium_background_bitmap_pattern_flags(plan, painting.Rect{20, 30, 35, 16}) == 0
	assert chromium_background_bitmap_pattern_flags(plan, painting.Rect{20, 30, 140, 1751}) == 0
	for clip in [painting.Rect{19, 30, 35, 16}, painting.Rect{20, 29, 35, 16}] {
		assert chromium_background_bitmap_pattern_flags(plan, clip) == chromium_bitmap_repeat_x | chromium_bitmap_repeat_y
	}
	clip := painting.Rect{19, 29, 35, 16}
	corrected := chromium_background_bitmap_plan(plan, clip)
	assert chromium_background_bitmap_pattern_flags(corrected, clip) == chromium_bitmap_repeat_x | chromium_bitmap_repeat_y
	assert chromium_background_bitmap_pattern_flags(painting.BackgroundTilePlan{
		...plan
		repeat_x_has_gap: true
	}, clip) == 0
	assert chromium_background_bitmap_pattern_flags(painting.BackgroundTilePlan{
		...plan
		repeat_x: false
	}, clip) == chromium_bitmap_repeat_y
}
