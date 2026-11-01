module bookmarkui

$if vox_ui2 ? {
	import ui2
	#include "@DIR/../tools/ui2/embedded_test_darwin.h"
	fn C.ui2_test_window() voidptr
	fn C.ui2_test_parent(window voidptr) voidptr
	fn C.ui2_test_close(window voidptr)
	fn C.ui2_test_flat_hover(control voidptr) int
}

fn test_mounted_ui2_bookmarks_keep_hover_and_remove_stale_controls() {
	$if vox_ui2 ? {
		window := C.ui2_test_window()
		defer {
			ui2.unmount_embedded_browser()
			C.ui2_test_close(window)
		}
		state := State{ width: 800, height: 600, visible: true, items: [Item{ title: 'Saved', url: 'about:blank' }] }
		ui2.mount_embedded_browser(C.ui2_test_parent(window), elements(state), fn (_ string) {})!
		button := ui2.embedded_browser_control('bookmark-open:0')
		assert C.ui2_test_flat_hover(button) != 0
		ui2.update_embedded_browser(elements(State{ ...state, width: 32, overflow: true }))
		assert ui2.embedded_browser_control('bookmarks-overflow') != unsafe { nil }
		assert C.ui2_test_flat_hover(ui2.embedded_browser_control('bookmark-open:0')) != 0
		ui2.update_embedded_browser(elements(State{ ...state, visible: false }))
		for id in ['bookmarks-bar', 'bookmarks-overflow', 'bookmarks-overlay', 'bookmark-open:0'] {
			assert ui2.embedded_browser_control(id) == unsafe { nil }
		}
	}
}
