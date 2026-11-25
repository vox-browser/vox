module browserui

$if vox_ui2 ?&& !ui2_custom_rendering ? {
	import macos
	import ui2

	#include "@DIR/../native/include/native_address_bar_test_darwin.h"
	#include "@DIR/../native/include/native_popup_test_darwin.h"
	fn C.native_test_address_window() voidptr
	fn C.native_test_address_parent(window voidptr) voidptr
	fn C.native_test_address_close(window voidptr)
	fn C.native_test_popup_keys(window voidptr, choose bool) voidptr
	fn C.native_test_popup_keys_cleanup(timer voidptr)
}

fn test_native_popup_preserves_row_state_and_uses_appkit_keyboard_tracking() {
	$if vox_ui2 ?&& !ui2_custom_rendering ? {
		window := C.native_test_address_window()
		defer { C.native_test_address_close(window) }
		parent := C.native_test_address_parent(window)
		ui2.mount_embedded_browser(parent, [ui2.view('anchor', ui2.rect(0, 0, 800, 30),
			ui2.BoxStyle{}, [])], fn (_ string) {})!
		defer { ui2.unmount_embedded_browser() }
		host := native_popup_host('anchor')
		assert host == parent
		popup := Popup{
			token: 1
			x:     20
			y:     70
			width: 160
			rows:  [
				MenuRow{ id: 'one', text: 'Same title', checked: true },
				MenuRow{ text: 'Group', group: true },
				MenuRow{ id: 'disabled', text: 'Disabled', enabled: false, indent: 1 },
				MenuRow{ separator: true },
				MenuRow{ id: 'two', text: 'Same title', indent: 1 },
			]
		}
		target := native_popup_target()
		menu := native_popup_menu(popup, target)
		defer {
			macos.release(menu)
			macos.release(target)
		}
		assert macos.msg_i64(menu, 'numberOfItems') == 5
		assert macos.msg_f64(menu, 'minimumWidth') == 160
		first := macos.msg_id_u64(menu, 'itemAtIndex:', 0)
		group := macos.msg_id_u64(menu, 'itemAtIndex:', 1)
		disabled := macos.msg_id_u64(menu, 'itemAtIndex:', 2)
		separator := macos.msg_id_u64(menu, 'itemAtIndex:', 3)
		last := macos.msg_id_u64(menu, 'itemAtIndex:', 4)
		assert macos.msg_i64(first, 'state') == 1
		assert !macos.msg_bool(group, 'isEnabled')
		assert !macos.msg_bool(disabled, 'isEnabled')
		assert macos.msg_bool(separator, 'isSeparatorItem')
		assert macos.msg_i64(last, 'indentationLevel') == 1
		assert macos.msg_id(first, 'title') != unsafe { nil }
		assert macos.utf8_string(macos.msg_id(first, 'title')) == macos.utf8_string(macos.msg_id(last, 'title'))

		keys := C.native_test_popup_keys(window, true)
		choice := show_native_popup(host, popup)
		C.native_test_popup_keys_cleanup(keys)
		assert popup.action(choice) == 'browser-menu:1:two'

		escape := C.native_test_popup_keys(window, false)
		cancelled := show_native_popup(host, popup)
		C.native_test_popup_keys_cleanup(escape)
		assert cancelled == -1
	}
}
