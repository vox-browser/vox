module main

import css
import math
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

fn chromium_cover_layer(position_x f64, position_y f64) css.BackgroundLayerData {
	return css.BackgroundLayerData{
		position_x: css.LengthPercentage.from_percentage(css.Percentage.new(position_x))
		position_y: css.LengthPercentage.from_percentage(css.Percentage.new(position_y))
		repeat_x: .no_repeat
		repeat_y: .no_repeat
		size_type: .cover
	}
}

fn test_chromium_cover_samples_the_unsnapped_tile_into_the_snapped_destination() {
	// Discord's page background: a 131x768 bitmap covering 1024x6030.828125.
	// Blink fits the snapped 1024x6031 area (tile 1028.71875 wide), positions
	// it at -2.359375 and samples the unsnapped tile's subset.
	area := painting.Rect{0, 0, 1024, 6030.828125}
	tile := chromium_single_tile_background(chromium_cover_layer(50, 0), css.LengthResolutionContext{},
		area, area, 131, 768) or { panic('single tile expected') }
	assert tile.destination == painting.Rect{0, 0, 1024, 6031}
	assert f32(tile.source.x) == f32(0.3004496097564697)
	assert tile.source.y == 0
	assert f32(tile.source.width) == f32(130.39910888671875)
	assert f32(tile.source.height) == f32(767.9780883789062)
}

fn test_chromium_single_tile_positions_inside_the_area_and_snaps_integral_subsets() {
	// A positive no-repeat offset moves the destination to the tile; an exact
	// natural-size subset rounds to whole source pixels.
	layer := css.BackgroundLayerData{
		position_x: css.LengthPercentage.from_percentage(css.Percentage.new(100))
		position_y: css.LengthPercentage.from_percentage(css.Percentage.new(100))
		repeat_x: .no_repeat
		repeat_y: .no_repeat
		size_type: .length_percentage
	}
	area := painting.Rect{10.25, 20, 300, 200}
	tile := chromium_single_tile_background(layer, css.LengthResolutionContext{}, area, area, 40, 30) or {
		panic('single tile expected')
	}
	assert tile.destination == painting.Rect{270, 190, 40, 30}
	assert tile.source == painting.Rect{0, 0, 40, 30}
}

fn test_chromium_single_tile_rejects_tiles_that_repeat_inside_the_destination() {
	layer := css.BackgroundLayerData{
		repeat_x: .repeat
		repeat_y: .no_repeat
		size_type: .length_percentage
	}
	area := painting.Rect{0, 0, 300, 200}
	assert chromium_single_tile_background(layer, css.LengthResolutionContext{}, area, area, 40, 30) == none
	// A repeating tile that already covers its destination is one draw.
	assert chromium_single_tile_background(layer, css.LengthResolutionContext{}, area,
		painting.Rect{0, 0, 300, 200}, 400, 30) != none
}

fn test_chromium_cover_downscales_from_a_fractional_snapped_area() {
	// Discord's floating trophy: 202x224 natural pixels covering 96x128 at a
	// fractional x. The tile fits the snapped area; the subset starts at the
	// truncated 50% offset of the 1/64-pixel tile.
	area := painting.Rect{915.734375, 214, 96, 128}
	tile := chromium_single_tile_background(chromium_cover_layer(50, 50), css.LengthResolutionContext{},
		area, area, 202, 224) or { panic('single tile expected') }
	assert tile.destination == painting.Rect{916, 214, 96, 128}
	assert math.abs(tile.source.x - 621.0 / 64 / (7387.0 / 64 / 202)) < 0.0001
	assert tile.source.y == 0
	assert math.abs(tile.source.width - 96 / (7387.0 / 64 / 202)) < 0.001
	assert math.abs(tile.source.height - 224) < 0.0001
}
