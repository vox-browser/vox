module browserui

$if vox_ui2 ? {
	import ui2
	#include "@DIR/../tools/ui2/embedded_reopen_test_darwin.h"
	fn C.native_test_address_window() voidptr
	fn C.native_test_address_parent(voidptr) voidptr
	fn C.native_test_address_close(voidptr)
	fn C.ui2_test_reopen_begin()
	fn C.ui2_test_reopen_end()
	fn C.ui2_test_reopen(i32) i32
	fn C.ui2_test_reopen_hide(voidptr)
	fn C.ui2_test_reopen_minimize(voidptr) i32
	fn C.ui2_test_reopen_visible(voidptr) i32
}

struct ReopenEvents {
mut:
	count int
}

const reopen_events = &ReopenEvents{}

fn test_appkit_reopen_reaches_ui2_and_show_restores_the_host_window() {
	$if vox_ui2 ? {
		window := C.native_test_address_window()
		C.ui2_test_reopen_begin()
		defer {
			ui2.unmount_embedded_browser()
			C.ui2_test_reopen_end()
			C.native_test_address_close(window)
		}
		mut events := unsafe { reopen_events }
		events.count = 0
		ui2.mount_embedded_browser(C.native_test_address_parent(window), [], fn (event string) {
			assert event == 'host-reopen'
			mut log := unsafe { reopen_events }
			log.count++
		})!
		assert C.ui2_test_reopen(0) == 0
		assert C.ui2_test_reopen(1) == 0
		assert events.count == 2
		C.ui2_test_reopen_hide(window)
		assert C.ui2_test_reopen_visible(window) == 0
		ui2.embedded_host_action('show')
		assert C.ui2_test_reopen_visible(window) == 1
		assert C.ui2_test_reopen_minimize(window) == 1
		ui2.embedded_host_action('show')
		assert C.ui2_test_reopen_visible(window) == 1
		ui2.unmount_embedded_browser()
		assert C.ui2_test_reopen(0) == 1
		assert events.count == 2
	}
}
