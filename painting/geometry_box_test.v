module painting

fn test_device_pixel_converter_preserves_enclosing_and_rounding_contracts() {
	converter := new_device_pixel_converter(1.5) or { panic(err) }
	assert converter.rounded_device_pixels(2.4) == 4
	assert converter.floored_device_pixels(2.4) == 3
	assert converter.enclosing_device_pixels(2.4) == 4
	assert converter.enclosing_device_rect(Rect{0.2, 1.1, 2.2, 3.1}) == IntRect{0, 1, 4, 5}
	assert converter.rounded_device_point(Point{1, 2}) == IntPoint{2, 3}
	assert converter.scale_to_css_pixels(3) == 2
	if _ := new_device_pixel_converter(0) {
		assert false
	}
}

fn test_rect_geometry_and_affine_inverse() {
	rect := Rect{10, 10, 20, 30}
	assert rect.contains(Point{10, 10})
	assert !rect.contains(Point{30, 40})
	assert rect.intersection(Rect{20, 20, 30, 10}) == Rect{20, 20, 10, 10}
	assert rect.united(Rect{0, 5, 5, 5}) == Rect{0, 5, 30, 35}
	transform := Affine{
		a: 2
		d: 3
		e: 5
		f: -2
	}
	mapped := transform.map_point(Point{4, 6})
	assert mapped == Point{13, 16}
	inverse := transform.inverse() or { panic('expected invertible transform') }
	assert inverse.map_point(mapped) == Point{4, 6}
	assert Affine{
		a: 0
		d: 0
	}.inverse() == none
}

fn test_box_model_metrics_are_layer_sums() {
	metrics := BoxModelMetrics{
		margin:  PixelBox{1, 2, 3, 4}
		border:  PixelBox{5, 6, 7, 8}
		padding: PixelBox{9, 10, 11, 12}
	}
	assert metrics.margin_box() == PixelBox{15, 18, 21, 24}
	assert metrics.border_box() == PixelBox{14, 16, 18, 20}
	assert metrics.padding_box() == PixelBox{9, 10, 11, 12}
}

fn test_corner_radii_clip_and_spread_adjustment() {
	mut radii := uniform_corner_radii(10)
	rect := IntRect{0, 0, 100, 50}
	assert !radii.contains(IntPoint{0, 0}, rect)
	assert radii.contains(IntPoint{10, 0}, rect)
	assert radii.contains(IntPoint{50, 25}, rect)
	assert !radii.contains(IntPoint{100, 25}, rect)
	radii.adjust_for_spread_distance(5)
	assert radii.top_left == CornerRadius{15, 15}
	mut small := CornerRadii{
		top_left: CornerRadius{2, 2}
	}
	small.adjust_for_spread_distance(10)
	assert small.top_left.horizontal > 2
	mut css_radii := BorderRadiiData{
		top_left: BorderRadiusData{12, 8}
	}
	css_radii.shrink(3, 0, 0, 4)
	assert css_radii.top_left == BorderRadiusData{8, 5}
	css_radii.inflate(1, 0, 0, 2)
	assert css_radii.top_left == BorderRadiusData{10, 6}
}

fn test_borders_and_chrome_metrics_scale_to_device_and_inverse_zoom() {
	converter := new_device_pixel_converter(2) or { panic(err) }
	borders := BordersData{
		top:    BorderData{Color{
			r: 1
		}, .solid, 1.1}
		right:  BorderData{Color{
			g: 2
		}, .dashed, 2}
		bottom: BorderData{Color{
			b: 3
		}, .dotted, 0.1}
		left:   BorderData{transparent, .none, 0}
	}
	device := borders.to_device_pixels(converter)
	assert device.top.width == 3
	assert device.for_edge(.right).line_style == .dashed
	assert device.bottom.width == 1
	metrics := new_chrome_metrics(2) or { panic(err) }
	assert metrics.scroll_thumb_min_length == 12
	assert metrics.scroll_gutter_thickness == 6
	assert metrics.resize_gripper_size == 6
}
