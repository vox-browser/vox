module dom

import math

// A capture or emulated viewport can expose one media-query density while
// retaining the presenting screen's font and paint grid. Ordinary documents
// inherit their display density without an override.
pub fn (d &Document) rendering_device_pixel_ratio() f64 {
	if d.rendering_device_pixel_ratio_ > 0 { return d.rendering_device_pixel_ratio_ }
	return d.display_device_pixel_ratio()
}

pub fn (mut d Document) set_rendering_device_pixel_ratio(value f64) {
	ratio := if value > 0 && !math.is_nan(value) && !math.is_inf(value, 0) { value } else { 0.0 }
	if d.rendering_device_pixel_ratio_ == ratio { return }
	d.rendering_device_pixel_ratio_ = ratio
	d.bump_style_environment_version()
	d.set_needs_full_style_update(true)
	d.request_full_layout_tree_update('rendering-density')
	if paintable := d.unsafe_paintable() { paintable.invalidate_all_paint_caches() }
	d.set_needs_repaint()
}
