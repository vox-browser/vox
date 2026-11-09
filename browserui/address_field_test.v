module browserui

import ui2

$if macos && vox_ui2 ? {
	import os
	#include "@VMODROOT/browserui/tab_visual_test_darwin.h"
	fn C.native_test_address_window() voidptr
	fn C.native_test_address_parent(voidptr) voidptr
	fn C.native_test_address_close(voidptr)
	fn C.native_test_address_insert(voidptr, &u8, int)
	fn C.native_test_address_submit(voidptr)
	fn C.native_test_address_selection(voidptr) u64
	fn C.ui2_test_tabs_pixel(voidptr, f64, f64) u32
	fn C.ui2_test_tabs_capture(voidptr, &u8) int
}

struct AddressFieldEvents {
mut:
	events []string
}

const address_field_events = &AddressFieldEvents{}

fn record_address_field_event(event string) {
	mut log := unsafe { address_field_events }
	log.events << event
}

fn test_mounted_address_field_has_no_outline_while_idle_or_focused_and_keeps_editing() {
	$if macos && vox_ui2 ? {
		window := C.native_test_address_window()
		defer {
			ui2.unmount_embedded_browser()
			C.native_test_address_close(window)
		}
		mut log := unsafe { address_field_events }
		log.events.clear()
		url := 'https://old.reddit.com/'
		elements := [ui2.view('toolbar', ui2.rect(0, 0, 800, 60), ui2.BoxStyle{ bg: 0xf7f7f7 }, [
			address_field(ui2.rect(98, 34, 664, 20), url),
		])]
		ui2.mount_embedded_browser(C.native_test_address_parent(window), elements, record_address_field_event)!
		toolbar := ui2.embedded_browser_control('toolbar')
		field := ui2.embedded_browser_control('address')
		for focused in [false, true] {
			if focused { ui2.select_embedded_textbox('address') }
			// Sample both long edges and the surrounding toolbar. A focused
			// textbox must not introduce a gray bezel or a blue halo.
			for x in [110.0, 300.0, 600.0, 750.0] {
				for y in [34.5, 35.5, 52.5, 53.5] {
					assert C.ui2_test_tabs_pixel(toolbar, x, y) == 0xffffff
				}
				for y in [31.5, 32.5, 55.5, 56.5] {
					assert C.ui2_test_tabs_pixel(toolbar, x, y) == 0xf7f7f7
				}
			}
		}
		assert ui2.focused_id() == 'address'
		assert C.native_test_address_selection(field) == u64(url.len)
		if capture := os.getenv_opt('VOX_ADDRESS_FIELD_CAPTURE') {
			assert C.ui2_test_tabs_capture(toolbar, capture.str) == 1
		}
		replacement := 'https://example.test/привет'
		C.native_test_address_insert(field, replacement.str, replacement.len)
		assert ui2.text('address') == replacement
		assert log.events.last() == 'address-change'
		C.native_test_address_submit(field)
		assert log.events.last() == 'address-submit'
	}
}
