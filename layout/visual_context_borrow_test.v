module layout

import painting
import platform

$if gcboehm ? {
	fn C.GC_get_total_bytes() uint
}

fn test_rectangle_mapping_keeps_all_four_transformed_corners() {
	rotation := painting.Affine{ a: 0, b: 1, c: -1, d: 0, e: 5, f: 7 }
	assert rotation.map_rect(painting.Rect{10, 20, 5, 10}) == painting.Rect{-25, 17, 10, 5}
	shear := painting.Affine{ a: -2, b: 1, c: 0.5, d: 3, e: 5, f: -7 }
	assert shear.map_rect(painting.Rect{-4, 2, 6, 5}) == painting.Rect{2, -5, 14.5, 21}
	singular := painting.Affine{ a: 0, d: 0, e: 5, f: 7 }
	assert singular.map_rect(painting.Rect{-4, 2, 6, 5}) == painting.Rect{5, 7, 0, 0}
}

fn test_coordinate_queries_do_not_retain_visual_tree_copies() {
	mut tree := painting.new_accumulated_visual_context_tree()
	transform := tree.append(painting.TransformVisualData{
		matrix: painting.Affine{ a: 2, d: 2 }
	}, 0)
	scroll := tree.append(painting.ScrollVisualData{ scroll_frame_index: 1 }, transform)
	clip := tree.append(painting.ClipVisualData{
		rect: painting.IntRect{0, 0, 100, 100}
	}, scroll)
	snapshot := painting.ScrollStateSnapshot{
		device_offsets: [painting.Point{}, painting.Point{-4, -6}]
	}
	mut box := BlockBox{}
	// Include the identity fast path: a value parameter used as a receiver can
	// be promoted to the heap even when the function immediately returns.
	for context in [0, clip] {
		box.accumulated_visual_context_index = context
		box.accumulated_visual_context_for_descendants_idx = context
		expected := if context == 0 { painting.Point{40, 40} } else { painting.Point{24, 26} }
		expected_rect := if context == 0 {
			LayoutRect{10, 20, 5, 10}
		} else {
			LayoutRect{12, 28, 10, 20}
		}
		before := platform.thread_arena_usage().used
		mut gc_before := uint(0)
		$if gcboehm ? { gc_before = C.GC_get_total_bytes() }
		for _ in 0 .. 4096 {
			assert paintable_box_transform_point_to_local(&box, painting.Point{40, 40}, 1,
				tree, snapshot)? == expected
			assert paintable_box_transform_point_to_local_for_descendants(&box,
				painting.Point{40, 40}, 1, tree, snapshot)? == expected
			assert paintable_box_transform_to_local_coordinates(&box, painting.Point{40, 40},
				1, tree, snapshot) == expected
			assert paintable_box_transform_rect_to_viewport(&box, LayoutRect{10, 20, 5, 10},
				1, tree, snapshot) == expected_rect
			inverse := paintable_box_inverse_transform_point(&box, painting.Point{40, 40}, 1,
				tree)
			assert inverse == if context == 0 { painting.Point{40, 40} } else { painting.Point{20, 20} }
			assert !compatibility_box_contains_hit_test_point(&box, 500, 500, false, tree,
				snapshot)
		}
		$if prealloc {
			allocated := platform.thread_arena_usage().used - before
			assert allocated < 1024, 'coordinate queries retained ${allocated} bytes'
		}
		$if gcboehm ? {
			allocated := C.GC_get_total_bytes() - gc_before
			assert allocated < 4096, 'coordinate queries allocated ${allocated} bytes'
		}
	}
	box.accumulated_visual_context_index = clip
	box.accumulated_visual_context_for_descendants_idx = clip
	assert paintable_box_transform_point_to_local_for_descendants(&box,
		painting.Point{40, 40}, 2, tree, snapshot)? == painting.Point{22, 23}
	assert paintable_box_transform_point_to_local(&box, painting.Point{500, 500}, 1, tree,
		snapshot) == none
	assert paintable_box_transform_to_local_coordinates(&box, painting.Point{500, 500}, 1,
		tree, snapshot) == painting.Point{500, 500}
	box.accumulated_visual_context_index = 0
	assert paintable_box_transform_point_to_local(&box, painting.Point{0.1, 0.2}, 2, tree,
		snapshot)? == painting.Point{0.1, 0.2}
}
