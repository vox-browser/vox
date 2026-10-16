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
}
