module browserui

$if vox_ui2 ? {
	import ui2
	#include "@DIR/../native_browser_tabs_test_darwin.h"
	fn C.native_test_address_window() voidptr
	fn C.native_test_address_parent(window voidptr) voidptr
	fn C.native_test_address_close(window voidptr)
	fn C.native_test_tabs_drag(control voidptr, x f64, y f64)
	fn C.native_test_address_selection(field voidptr) u64
	fn C.native_test_tabs_accessibility(control voidptr) int
	fn C.native_test_tabs_middle(control voidptr)
	fn C.native_test_tabs_click(control voidptr)
	fn C.native_test_address_shortcut(field voidptr, owner voidptr, callback fn (voidptr, int), key u16, shift int) int
}

struct MountedUIEvents {
mut:
	events []string
}

const mounted_ui_events = &MountedUIEvents{}

fn record_mounted_ui_event(event string) {
	mut state := unsafe { mounted_ui_events }
	state.events << event
}

fn test_mounted_tabs_deliver_normalized_pointer_actions_and_typed_shortcuts() {
	$if vox_ui2 ? {
		window := C.native_test_address_window()
		defer {
			ui2.unmount_embedded_browser()
			C.native_test_address_close(window)
		}
		mut log := unsafe { mounted_ui_events }
		log.events.clear()
		elements := [
			tab_strip(800, [Tab{ index: 0, title: 'Saved', x: 62, width: 184 }], 258),
			ui2.text_input(
				multiline: false
				id:        'address'
				text:      'https://example.com'
				frame:     ui2.rect(98, 34, 600, 20)
			)!,
		]
		ui2.mount_embedded_browser(C.native_test_address_parent(window), elements, record_mounted_ui_event)!
		assert C.native_test_tabs_accessibility(ui2.embedded_browser_control('tab-0')) == 1
		C.native_test_tabs_drag(ui2.embedded_browser_control('tab-0'), 200, 0)
		assert log.events.len == 3
		assert log.events[0].starts_with('pointer:down:tabdrag-0:97.0:15.0'), log.events.str()
		assert log.events[1].starts_with('pointer:drag:tabdrag-0:297.0:15.0')
		assert log.events[2].starts_with('pointer:up:tabdrag-0:297.0:15.0')
		C.native_test_tabs_click(ui2.embedded_browser_control('tab-close:0'))
		assert log.events.last() == 'tab-close:0'
		C.native_test_tabs_middle(ui2.embedded_browser_control('tab-0'))
		assert log.events.last().starts_with('pointer:middle:tabdrag-0:97.0:15.0'), log.events.str()
		ui2.install_embedded_keys(fn (event ui2.KeyEvent) {
			action := shortcut(event, false, true)
			if action != '' {
				record_mounted_ui_event(action)
				ui2.consume_key()
			}
		})
		assert C.native_test_address_shortcut(ui2.embedded_browser_control('address'), unsafe { nil }, fn (_ voidptr, _ int) {}, 2, 0) != 0
		assert log.events.last() == 'bookmark-add'
		ui2.select_embedded_textbox()
		assert C.native_test_address_shortcut(ui2.embedded_browser_control('address'), unsafe { nil }, fn (_ voidptr, _ int) {}, 0, 0) != 0
		assert C.native_test_address_selection(ui2.embedded_browser_control('address')) == u64('https://example.com'.len)
		ui2.update_embedded_browser([tab_strip(800, [Tab{ index: 3, title: 'Other', x: 62, width: 80 }], 154)])
		assert ui2.embedded_browser_control('tab-0') == unsafe { nil }
		assert ui2.embedded_browser_control('tab-3') != unsafe { nil }
        popup := Popup{token: 77, x: 100, y: 100, rows: [MenuRow{id: 'off', text: 'Disabled', enabled: false}, MenuRow{id: 'choice', text: 'Choose'}]}
        ui2.update_embedded_browser(popup.elements(800,600))
        before_disabled := log.events.len
        C.native_test_tabs_click(ui2.embedded_browser_control('menu-row-0'))
        assert log.events.len == before_disabled
        C.native_test_tabs_click(ui2.embedded_browser_control('menu-row-1'))
        assert log.events.last() == 'browser-menu:77:choice'
        C.native_test_tabs_click(ui2.embedded_browser_control('browser-menu-dismiss'))
        assert log.events.last() == 'browser-menu:77:dismiss'
		ui2.update_embedded_browser([ui2.button('former-id', 'Former', ui2.rect(0, 0, 50, 24), ui2.BoxStyle{}, ui2.TextStyle{})])
		ui2.update_embedded_browser([ui2.button('current-id', 'Current', ui2.rect(0, 0, 50, 24), ui2.BoxStyle{}, ui2.TextStyle{})])
		assert ui2.embedded_browser_control('former-id') == unsafe { nil }
		assert ui2.embedded_browser_control('current-id') != unsafe { nil }
		ui2.update_embedded_browser([]ui2.Element{})
		assert ui2.embedded_browser_control('tab-0') == unsafe { nil }
	}
}
