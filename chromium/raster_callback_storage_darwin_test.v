module main

import platform

fn test_deferred_native_raster_callback_reclaims_tile_storage_on_rejection() {
	previous := document_geometry_grid
	defer { document_geometry_grid = previous }
	document_geometry_grid = DocumentGeometryGrid{ width: 128, height: 128, columns: 1, rows: 1 }
	mut pixels := []u8{len: 8 * 8 * 4, init: u8(73)}
	// Unsupported descriptors return before creating a GPU context, but the
	// tile adapter still needs its temporary result and tile allocations.
	shape := C.VoxGraphiteShape{ fill: -1, matrix: [f32(1), 0, 0, 0, 1, 0, 0, 0, 1]! }
	assert draw_document_shape_pixels(pixels.data, 8, 8, 32, 0, 0, 0, &shape) == 0
	before := platform.thread_arena_usage().used
	for _ in 0 .. 512 {
		assert draw_document_shape_pixels(pixels.data, 8, 8, 32, 0, 0, 0, &shape) == 0
	}
	growth := platform.thread_arena_usage().used - before
	assert pixels.all(it == 73)
	$if prealloc {
		assert growth < 4096, 'callback retained ${growth} bytes'
	}
}
