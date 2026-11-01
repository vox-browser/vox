module browserui

$if vox_ui2 ? {
	import ui2
	import os
	#include "@DIR/tab_visual_test_darwin.h"
	fn C.native_test_address_window() voidptr
	fn C.native_test_address_parent(voidptr) voidptr
	fn C.native_test_address_close(voidptr)
	fn C.ui2_test_tabs_capture(voidptr, &u8) int
	fn C.ui2_test_tabs_pixel(voidptr, f64, f64) u32
}

fn test_mounted_tabs_keep_the_classic_shoulders_overlap_outline_and_active_seam() {
	$if vox_ui2 ? {
		window := C.native_test_address_window()
		defer {
			ui2.unmount_embedded_browser()
			C.native_test_address_close(window)
		}
		strip := tab_strip(800, [
			Tab{ index: 0, title: 'ChatGPT: Chat, Work, Create', x: 62, width: 184, selected: true },
			Tab{ index: 1, title: 'Second tab', x: 246, width: 184 },
		], 442)
		ui2.mount_embedded_browser(C.native_test_address_parent(window), [ui2.view('toolbar', ui2.rect(0, 0, 800, 60), ui2.BoxStyle{ bg: 0xf7f7f7 }, [strip])], fn (_ string) {})!
		toolbar := ui2.embedded_browser_control('toolbar')
		path := os.getenv_opt('VOX_TAB_STYLE_CAPTURE') or { os.join_path(os.temp_dir(), 'vox-ui2-classic-tabs.png') }
		assert C.ui2_test_tabs_capture(toolbar, path.str) == 1
		// Empty shoulder, filled body and the outline of the old silhouette.
		assert C.ui2_test_tabs_pixel(toolbar, 64, 7) == u32(0xdbdbdb)
		assert C.ui2_test_tabs_pixel(toolbar, 66, 15) == u32(0xdbdbdb)
		assert C.ui2_test_tabs_pixel(toolbar, 251, 27) == u32(0xf7f7f7)
		assert C.ui2_test_tabs_pixel(toolbar, 150, 25) == u32(0xf7f7f7)
		assert C.ui2_test_tabs_pixel(toolbar, 320, 25) == u32(0xd4d4d4)
		// The selected foot merges into the toolbar; an inactive tab keeps its edge.
		assert C.ui2_test_tabs_pixel(toolbar, 150, 28) == u32(0xf7f7f7)
		assert C.ui2_test_tabs_pixel(toolbar, 320, 28) == u32(0xadadad)
		// Reconciliation must move the open seam when selection changes.
		switched := tab_strip(800, [
			Tab{ index: 0, title: 'ChatGPT: Chat, Work, Create', x: 62, width: 184 },
			Tab{ index: 1, title: 'Second tab', x: 246, width: 184, selected: true },
		], 442)
		ui2.update_embedded_browser([ui2.view('toolbar', ui2.rect(0, 0, 800, 60), ui2.BoxStyle{ bg: 0xf7f7f7 }, [switched])])
		assert C.ui2_test_tabs_pixel(toolbar, 150, 28) == u32(0xadadad)
		assert C.ui2_test_tabs_pixel(toolbar, 320, 28) == u32(0xf7f7f7)
	}
}
