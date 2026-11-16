module yuv

import math

fn test_webp_subset_preserves_crop_scale_and_origin() {
	assert webp_atlas_subset_destination(320, 179, [f32(1.3445379), 0, 317.31094, 179]!,
		[f32(772), 251, 236, 133]!)? == [f32(771), 251, 238, 133]!
	assert webp_atlas_subset_destination(320, 180, [f32(0), 4, 320, 176]!,
		[f32(20), 30, 240, 132]!)? == [f32(20), 27, 240, 135]!
	assert webp_atlas_subset_destination(320, 180, [f32(0), 2, 320, 176]!,
		[f32(20), 30, 240, 132]!) == none
}

fn test_webp_subset_rejects_unsupported_geometry() {
	for source in [
		[f32(-1), 0, 320, 179]!,
		[f32(1), 0, 320, 179]!,
		[f32(0), 0, 320, 180]!,
		[f32(0), 0, 0, 179]!,
		[f32(math.inf(1)), 0, 320, 179]!,
		[f32(math.nan()), 0, 320, 179]!,
	] {
		assert webp_atlas_subset_destination(320, 179, source, [f32(20), 30, 240, 133]!) == none
	}
	for destination in [
		[f32(20), 30, 0, 133]!,
		[f32(20), 30, 160, 89]!,
		[f32(20), 30, 320, 179]!,
		[f32(20.5), 30, 240, 133]!,
		[f32(20), 30, 240.1, 133]!,
		[f32(20), f32(math.inf(1)), 240, 133]!,
	] {
		assert webp_atlas_subset_destination(320, 179, [f32(0), 0, 320, 179]!, destination) == none
	}
}
