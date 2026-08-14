module html

fn density_of(source ImageSource) f64 {
	return (source.descriptor as PixelDensityDescriptorValue).value
}

fn test_parse_a_srcset_attribute() {
	set := parse_a_srcset_attribute('small.png 0.5x, normal.png 1x, large.png 2x')
	assert set.sources.len == 3
	assert set.sources[0].url == 'small.png'
	assert density_of(set.sources[0]) == 0.5
	assert set.sources[2].url == 'large.png'
	assert density_of(set.sources[2]) == 2.0

	widths := parse_a_srcset_attribute('small.png 320w, large.png 640w')
	assert widths.sources.len == 2
	assert (widths.sources[0].descriptor as WidthDescriptorValue).value == 320.0

	invalid := parse_a_srcset_attribute('bad.png 1x 2x, good.png 2x')
	assert invalid.sources.len == 1
	assert invalid.sources[0].url == 'good.png'
}

fn test_create_and_select_source_set() {
	set := create_source_set('default.png', 'small.png 0.5x, large.png 2x', 100.0)
	assert set.sources.len == 3
	selected := set.select_an_image_source()
	assert selected.source.url == 'default.png'
	assert selected.pixel_density == 1.0

	mut widths := parse_a_srcset_attribute('small.png 100w, large.png 200w')
	widths.normalize_source_densities(100.0)
	assert density_of(widths.sources[0]) == 1.0
	assert density_of(widths.sources[1]) == 2.0
}
