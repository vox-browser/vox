module layout

import css

// 4chan-style thumbnails: a block-level 151x97 image keeps its natural height
// when its height is transferred through the natural aspect ratio.
fn test_natural_aspect_ratio_is_exact_when_both_dimensions_exist() {
	size := natural_size_with_aspect_ratio(151, 97, 151.0 / 97.0)
	ratio := size.aspect_ratio or { panic('missing ratio') }
	assert CSSPixels.new(151).divided_by_fraction(ratio).to_double() == 97
	assert CSSPixels.new(250).divided_by_fraction(natural_size_with_aspect_ratio(250, 177,
		250.0 / 177.0).aspect_ratio or { panic('missing ratio') }).to_double() == 177
	// A ratio-only image, such as an SVG without natural dimensions, keeps the ratio.
	only := natural_size_with_aspect_ratio(none, none, 2.0)
	assert only.width == none && only.height == none
	assert only.aspect_ratio or { panic('missing ratio') } == css.CSSPixelFraction.new(CSSPixels.new(2),
		CSSPixels.new(1))
	assert natural_size_with_aspect_ratio(10, 10, none).aspect_ratio == none
}
