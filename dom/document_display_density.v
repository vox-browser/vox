module dom

import math

// Display density describes media queries independently of the coordinate
// space used for layout and native input events.
pub fn (mut d Document) set_display_device_pixel_ratio(value f64) {
	ratio := if value <= 0 || math.is_nan(value) || math.is_inf(value, 0) { 1.0 } else { value }
	if d.display_device_pixel_ratio_ == ratio { return }
	d.display_device_pixel_ratio_ = ratio
	d.bump_style_environment_version()
	d.set_needs_media_query_evaluation()
	d.set_needs_full_style_update(true)
	d.request_frame()
}

// The compact paint bridge still uses Page's coordinate conversion ratio.
// Media queries read the presenting display independently of that bridge.
pub fn (d &Document) display_device_pixel_ratio() f64 {
	if d.display_device_pixel_ratio_ > 0 { return d.display_device_pixel_ratio_ }
	return d.device_pixels_per_css_pixel()
}
