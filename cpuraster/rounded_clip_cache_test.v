module cpuraster

fn test_rounded_clip_cache_uses_texture_geometry_and_stays_bounded() {
	width := 60
	height := 34
	shape := RoundedClipGeometry{
		rect: Rect{0, 0, 58, 32}
		radii: [f32(12), 8, 9, 11, 0, 0, 0, 0]!
	}
	mut cache := RoundedClipCache{}
	for index in 0 .. 5 {
		translated := RoundedClipGeometry{...shape, transform: Matrix{e: f32(index) / 4}}
		assert !cache.raster_clip(translated, width, height).reused
		hit := cache.raster_clip(translated, width, height)
		assert hit.reused
		retained := hit.clip or { panic('expected partial coverage') }
		reference := canvas_raster_clip(width, height, [translated.path()])
		mut actual := []u8{len: width * height * 4, init: 177}
		mut expected := actual.clone()
		assert retained.apply_to_straight_rgba(mut actual, width, height)
		assert reference.apply_to_straight_rgba(mut expected, width, height)
		assert actual == expected
	}
	assert !cache.raster_clip(shape, width, height).reused
	assert !cache.raster_clip(shape, width - 1, height).reused
	assert !cache.raster_clip(shape, width, height - 1).reused
}

fn test_rounded_clip_cache_remembers_full_coverage() {
	shape := RoundedClipGeometry{
		rect: Rect{-40, -40, 140, 140}
		radii: [f32(8), 8, 8, 8, 8, 8, 8, 8]!
	}
	mut cache := RoundedClipCache{}
	miss := cache.raster_clip(shape, 100, 100)
	hit := cache.raster_clip(shape, 100, 100)
	assert !miss.reused && miss.clip == none
	assert hit.reused && hit.clip == none
}
