module browserui

import math
import ui2

$if vox_ui2 ? {
	#include "@DIR/tab_visual_test_darwin.h"
	fn C.native_test_address_window() voidptr
	fn C.native_test_address_parent(voidptr) voidptr
	fn C.native_test_address_close(voidptr)
	fn C.ui2_test_tabs_pixel(voidptr, f64, f64) u32
}

fn test_loading_replaces_favicons_and_fallbacks_in_selected_and_background_tabs() {
	for selected in [false, true] {
		for title in ['Site', 'Apps'] {
			for path in ['', '/favicon.png'] {
				loading := tab_strip(800, [Tab{
					index:    2
					title:    title
					icon:     path
					width:    184
					selected: selected
					loading:  true
				}], 258).children[3]
				icon := loading.children[0]
				assert icon.id == 'tab-icon-2' && icon.image_path == ''
				assert icon.frame == ui2.rect(12, 4, 16, 16)
				assert !icon.vector.closed && !icon.vector.fill_enabled
				assert icon.vector.stroke_width == 2 && icon.accessibility_label == 'Loading'
				assert loading.action_id == 'tabdrag-2' && loading.children[2].id == 'tab-close:2'
				complete := tab_strip(800, [Tab{
					index:    2
					title:    title
					icon:     path
					width:    184
					selected: selected
				}], 258).children[3].children[0]
				assert complete.accessibility_label != 'Loading'
				assert complete.image_path == path
			}
		}
	}
}

fn test_loading_arc_rotates_clockwise_with_a_fixed_radius_and_wraps_seamlessly() {
	first := tab_loading_icon(0, 0)
	quarter := tab_loading_icon(0, 15)
	assert first.vector.points != quarter.vector.points
	assert math.abs(first.vector.points[0].x - 8) < 0.00001
	assert math.abs(first.vector.points[0].y - 2) < 0.00001
	assert math.abs(quarter.vector.points[0].x - 14) < 0.00001
	assert math.abs(quarter.vector.points[0].y - 8) < 0.00001
	assert tab_loading_icon(0, 60).vector == first.vector
	for frame in 0 .. 60 {
		for point in tab_loading_icon(0, frame).vector.points {
			assert math.abs(math.hypot(point.x - 8, point.y - 8) - 6) < 0.00001
			assert point.x >= 2 && point.x <= 14 && point.y >= 2 && point.y <= 14
		}
	}
}

fn test_mounted_loading_arc_changes_pixels_and_restores_the_fallback_on_completion() {
	$if vox_ui2 ? {
		window := C.native_test_address_window()
		defer {
			ui2.unmount_embedded_browser()
			C.native_test_address_close(window)
		}
		ui2.mount_embedded_browser(C.native_test_address_parent(window), [tab_strip(800, [
			Tab{ x: 62, width: 184, selected: true, loading: true },
		], 258)], fn (_ string) {})!
		icon := ui2.embedded_browser_control('tab-icon-0')
		// Frame zero has a gap in the upper-left quadrant; a quarter turn fills it.
		before := C.ui2_test_tabs_pixel(icon, 4, 4)
		ui2.refresh_element('tab-icon-0', tab_loading_icon(0, 15))
		assert C.ui2_test_tabs_pixel(icon, 4, 4) != before
		ui2.update_embedded_browser([tab_strip(800, [Tab{ x: 62, width: 184, selected: true }], 258)])
		assert C.ui2_test_tabs_pixel(ui2.embedded_browser_control('tab-icon-0'), 4, 4) != u32(0x1a73e8)
	}
}
