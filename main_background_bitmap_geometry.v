module main

import painting

fn pixel_snapped_background_bitmap_rect(rect painting.Rect) painting.Rect {
	converter := painting.new_device_pixel_converter(1.0) or { return rect }
	snapped := converter.rounded_device_rect(rect)
	return painting.Rect{f64(snapped.x), f64(snapped.y), f64(snapped.width), f64(snapped.height)}
}
