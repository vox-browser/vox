module webvtt

import math

fn test_defaults() {
	region := VTTRegion.construct_impl()
	direct := VTTRegion.create()
	assert region.id() == ''
	assert region.width() == 100.0
	assert region.lines() == u32(3)
	assert region.region_anchor_x() == 0.0
	assert region.region_anchor_y() == 100.0
	assert region.viewport_anchor_x() == 0.0
	assert region.viewport_anchor_y() == 100.0
	assert region.scroll() == .empty
	assert direct.width() == region.width()
}

fn test_unvalidated_setters() {
	mut region := VTTRegion.construct_impl()
	region.set_id('caption-region')
	region.set_lines(5)
	region.set_scroll(.up)
	assert region.id() == 'caption-region'
	assert region.lines() == u32(5)
	assert region.scroll() == .up
}

fn test_percentage_setters_accept_in_range() {
	mut region := VTTRegion.construct_impl()
	region.set_width(50)!
	region.set_region_anchor_x(10)!
	region.set_region_anchor_y(20)!
	region.set_viewport_anchor_x(30)!
	region.set_viewport_anchor_y(40)!
	assert region.width() == 50.0
	assert region.region_anchor_x() == 10.0
	assert region.region_anchor_y() == 20.0
	assert region.viewport_anchor_x() == 30.0
	assert region.viewport_anchor_y() == 40.0
	// Boundaries are inclusive.
	region.set_width(0)!
	region.set_width(100)!
}

fn test_percentage_setters_reject_out_of_range() {
	mut region := VTTRegion.construct_impl()
	if _ := set_width_result(mut region, -1) {
		assert false, 'expected IndexSizeError for width < 0'
	} else {
		assert err.msg().starts_with('IndexSizeError:')
	}
	if _ := set_width_result(mut region, 101) {
		assert false, 'expected IndexSizeError for width > 100'
	}
	// The value is unchanged after a rejected set.
	assert region.width() == 100.0

	if _ := region.set_region_anchor_x(200) {
		assert false, 'expected IndexSizeError'
	}
	if _ := region.set_viewport_anchor_y(-5) {
		assert false, 'expected IndexSizeError'
	}
}

fn test_percentage_setters_preserve_unrestricted_nan() {
	mut region := VTTRegion.construct_impl()
	region.set_width(math.nan())!
	region.set_region_anchor_x(math.nan())!
	assert math.is_nan(region.width())
	assert math.is_nan(region.region_anchor_x())
}

fn set_width_result(mut region VTTRegion, width f64) !bool {
	region.set_width(width)!
	return true
}
