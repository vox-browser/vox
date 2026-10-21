module painting

import platform

fn test_background_tile_iterator_matches_repetition_clipping_order_and_limits() {
	for repeat_x in [false, true] {
		for repeat_y in [false, true] {
			for first in [Rect{-31.5, -20.25, 10.5, 8.25}, Rect{8, 9, 12, 10}, Rect{100, 0, 12, 10},
				Rect{0, 100, 12, 10}, Rect{0, 0, 0, 10}] {
				for clip in [Rect{0, 0, 40, 30}, Rect{-40, -30, 50, 45}, Rect{0, 0, 0, 0}] {
					for limit in [0, 1, 3, 4096] {
						plan := BackgroundTilePlan{
							first_tile: first
							repeat_x:   repeat_x
							repeat_y:   repeat_y
							x_step:     13.25
							y_step:     10.5
						}
						mut iterator := background_tile_iterator(plan, clip, limit)
						mut actual := []Rect{}
						for { actual << iterator.next() or { break } }
						assert actual == background_tiles_from_plan_limited(plan, clip, limit)
						assert iterator.next() == none
					}
				}
			}
		}
	}
}

fn test_background_tile_iterator_bounds_working_storage_across_nested_traversals() {
	plan := BackgroundTilePlan{ first_tile: Rect{0, 0, 1, 1}, repeat_x: true, repeat_y: true, x_step: 1, y_step: 1 }
	clip := Rect{0, 0, 16, 16}
	before := platform.thread_arena_usage().used
	mut count := 0
	for _ in 0 .. 64 {
		mut outer := background_tile_iterator(plan, clip, 0)
		for {
			_ = outer.next() or { break }
			mut inner := background_tile_iterator(plan, clip, 1)
			assert inner.next()? == Rect{0, 0, 1, 1}
			assert inner.next() == none
			count++
		}
	}
	$if prealloc {
		assert platform.thread_arena_usage().used - before < 16 * 1024
	}
	assert count == 64 * 256
}
