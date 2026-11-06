module main

import painting

fn test_background_subset_records_at_the_local_origin_with_the_snapped_clip() {
	destination := painting.Rect{916, 214, 96, 128}
	source := painting.Rect{16.9814548492432, 0, 168.009750366211, 223.999984741211}
	geometry := chromium_background_local_origin(destination, source, destination,
		[f64(1), 0, 0, 1, 0, 0]!, 202, 224, true)
	assert geometry.destination_x == 0 && geometry.destination_y == 0
	assert geometry.clip_x == 0 && geometry.clip_y == 0
	assert geometry.transform_e == 916 && geometry.transform_f == 214
}

fn test_background_subset_preserves_the_affine_mapping_and_relative_clip() {
	destination := painting.Rect{12, 20, 96, 128}
	source := painting.Rect{1, 0, 168, 224}
	clip := painting.Rect{10, 18, 100, 132}
	geometry := chromium_background_local_origin(destination, source, clip,
		[f64(0.5), 0, 0, 2, 1.25, -3.5]!, 202, 224, true)
	assert geometry.destination_x == 0 && geometry.destination_y == 0
	assert geometry.clip_x == -2 && geometry.clip_y == -2
	assert geometry.transform_e == 7.25 && geometry.transform_f == 36.5
	rotated := chromium_background_local_origin(destination, source, clip,
		[f64(0), 1, -1, 0, 10, 20]!, 202, 224, true)
	assert rotated.transform_e == -10 && rotated.transform_f == 32
}

fn test_complete_background_images_keep_their_original_draw_coordinates() {
	destination := painting.Rect{404, 134, 568, 401}
	geometry := chromium_background_local_origin(destination, painting.Rect{0, 0, 2392, 1690},
		painting.Rect{404, 134, 600, 401}, [f64(1), 0, 0, 1, 2.25, -3.5]!, 2392, 1690, true)
	assert geometry.destination_x == 404 && geometry.destination_y == 134
	assert geometry.clip_x == 404 && geometry.clip_y == 134
	assert geometry.transform_e == 2.25 && geometry.transform_f == -3.5
}

fn test_background_origin_composes_the_local_offset_before_the_existing_translation() {
	destination := painting.Rect{1, 1, 10, 10}
	geometry := chromium_background_local_origin(destination, painting.Rect{1, 0, 10, 10},
		destination, [f64(0.003), 0, 0.003, 1, 100000, 0]!, 20, 20, true)
	// Adding either small term to the large translation first loses it.
	assert geometry.transform_e == f32(100000.0078125)
	assert geometry.transform_f == 1
}

fn test_root_and_legacy_background_subsets_keep_their_document_origin() {
 destination := painting.Rect{916, 214, 96, 128}
 geometry := chromium_background_local_origin(destination, painting.Rect{16.98, 0, 168, 224},
  destination, [f64(1), 0, 0, 1, 2.25, -3.5]!, 202, 224, false)
 assert geometry.destination_x == 916 && geometry.destination_y == 214
 assert geometry.clip_x == 916 && geometry.clip_y == 214
 assert geometry.transform_e == 2.25 && geometry.transform_f == -3.5
}
