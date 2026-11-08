module browserui

import ui2

$if macos && vox_ui2 ? {
	import os
	#include "@VMODROOT/browserui/tab_visual_test_darwin.h"
	fn C.native_test_address_window() voidptr
	fn C.native_test_address_parent(voidptr) voidptr
	fn C.native_test_address_close(voidptr)
	fn C.ui2_test_tabs_capture(voidptr, &u8) int
}

fn test_build_time_uses_utc_with_unpadded_day_and_padded_clock() {
	assert format_build_time(1_794_142_920) == 'Nov 8 13:02 UTC'
	assert format_build_time(0) == 'Jan 1 00:00 UTC'
	assert format_build_time(1_798_761_599) == 'Dec 31 23:59 UTC'
	assert format_build_time(1_798_761_600) == 'Jan 1 00:00 UTC'
}

fn test_status_bar_keeps_build_time_before_ram_and_clear_of_footer_on_resize() {
	for width in [320.0, 800.0, 1000.0] {
		frame := ui2.rect(0, 600, width, 24)
		bar := status_bar(frame, 'https://example.test/a/long/hovered/link', 'RAM: unavailable')
		assert bar.id == 'status-bar' && bar.frame == frame
		footer := bar.children[0]
		build := bar.children[1]
		memory := bar.children[2]
		assert footer.id == 'footer' && footer.text.starts_with('https://example.test/')
		assert build.id == 'build-time'
		assert build.text == format_build_time(@BUILD_TIMESTAMP.i64())
		assert build.tooltip == 'Build time (UTC)'
		assert build.accessibility_label == 'Build time (UTC)'
		assert footer.frame.x + footer.frame.width + 12 <= build.frame.x
		assert build.frame.x + build.frame.width + 12 <= memory.frame.x
		assert memory.id == 'memory' && memory.text == 'RAM: unavailable'
		assert memory.frame.x + memory.frame.width == width - 12
		assert build.text_style.align == .right && memory.text_style.align == .right
	}
}

fn test_mounted_status_bar_keeps_build_time_during_memory_refresh() {
	$if macos && vox_ui2 ? {
		window := C.native_test_address_window()
		defer {
			ui2.unmount_embedded_browser()
			C.native_test_address_close(window)
		}
		bar := status_bar(ui2.rect(0, 576, 800, 24), 'https://example.test/', 'RAM: 123.5 MB')
		ui2.mount_embedded_browser(C.native_test_address_parent(window), [bar], fn (_ string) {})!
		assert ui2.text('build-time') == build_time_label
		assert ui2.embedded_browser_control('build-time') != unsafe { nil }
		ui2.set_text('memory', 'RAM: 1.5 GB')
		assert ui2.text('memory') == 'RAM: 1.5 GB'
		assert ui2.text('build-time') == build_time_label
		if capture := os.getenv_opt('VOX_STATUS_BAR_CAPTURE') {
			assert C.ui2_test_tabs_capture(ui2.embedded_browser_control('status-bar'), capture.str) == 1
		}
	}
}
