module main

import painting

fn test_chromium_cover_image_trims_the_source_before_rasterization() {
	image := replaced_image_replay_rects(painting.IntRect{475, 9131, 330, 192},
		painting.IntRect{475, 9131, 330, 138}, 1191, 690, true) or { panic('missing image') }
	assert image.destination == painting.IntRect{475, 9131, 330, 138}
	assert image.source == [f32(0), 0, 1191, 495.9375]!
}

fn test_chromium_image_crop_keeps_source_precision_far_from_the_origin() {
	for y in [0, 9131, 1000000] {
		image := replaced_image_replay_rects(painting.IntRect{875, y, 331, 268},
			painting.IntRect{875, y, 331, 138}, 1824, 1480, true) or { panic('missing image') }
		assert image.source == [f32(0), 0, 1824, 762.0895385742188]!
	}
}

fn test_chromium_image_crop_maps_offsets_in_both_axes() {
	image := replaced_image_replay_rects(painting.IntRect{-15, -10, 200, 100},
		painting.IntRect{10, 20, 100, 60}, 400, 300, true) or { panic('missing image') }
	assert image.destination == painting.IntRect{10, 20, 100, 60}
	assert image.source == [f32(50), 90, 200, 180]!
}

fn test_image_crop_preserves_contained_and_libweb_draws() {
	destination := painting.IntRect{20, 30, 80, 40}
	for chromium in [false, true] {
		image := replaced_image_replay_rects(destination, painting.IntRect{10, 20, 100, 60},
			1824, 1480, chromium) or { panic('missing image') }
		assert image.destination == destination
		assert image.source == [f32(0), 0, 1824, 1480]!
	}
	image := replaced_image_replay_rects(destination, painting.IntRect{30, 40, 20, 10},
		1824, 1480, false) or { panic('missing image') }
	assert image.destination == destination
	assert image.source == [f32(0), 0, 1824, 1480]!
}

fn test_image_crop_omits_empty_and_disjoint_destinations() {
	assert replaced_image_replay_rects(painting.IntRect{0, 0, 10, 10},
		painting.IntRect{20, 20, 10, 10}, 100, 100, true) == none
	assert replaced_image_replay_rects(painting.IntRect{}, painting.IntRect{}, 100, 100, true) == none
	assert replaced_image_replay_rects(painting.IntRect{0, 0, 10, 10},
		painting.IntRect{0, 0, 10, 10}, 0, 100, true) == none
}
