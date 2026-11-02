module browserui

import browsertabs
import ui2

$if vox_ui2 ? {
	import os
	#include "@DIR/tab_color_test_darwin.h"
	fn C.native_test_address_window() voidptr
	fn C.native_test_address_parent(voidptr) voidptr
	fn C.native_test_address_close(voidptr)
	fn C.ui2_test_tabs_capture(voidptr, &u8) int
	fn C.ui2_test_tab_color_pixel(voidptr, f64, f64) u32
	fn C.ui2_test_tab_color_menu(voidptr) int
	fn C.ui2_test_tab_menu_count(voidptr) int
}

struct TabColorEvents {
mut:
	events []string
}

const tab_color_events = &TabColorEvents{}

fn record_tab_color_event(event string) {
	mut state := unsafe { tab_color_events }
	state.events << event
}

fn test_tab_palette_has_named_choices_default_and_one_selected_row() {
	for color in [browsertabs.Color.none, .red, .orange, .yellow, .green, .blue, .purple, .pink] {
		rows := tab_color_rows(color)
		assert rows[0].group && rows[0].text == 'Tab Color'
		assert rows[1].text == 'Default'
		assert rows.filter(it.checked).len == 1
		assert rows.filter(it.checked)[0].id == 'tab-color-${color}'
		assert tab_fill(color, true) != tab_fill(color, false)
	}
}

fn test_tab_color_context_action_is_opt_in_and_coloring_preserves_tab_controls() {
	plain := tab_strip(800, [Tab{ title: 'Plain', width: 184 }], 258).children[3]
	assert plain.menu.len == 0
	assert plain.vector.fill == u32(0xd4d4d4)
	for selected in [true, false] {
		tab := tab_strip(800, [Tab{ index: 2, title: 'Colored', width: 184,
			selected: selected, color: .blue, color_action: 'tab-color-menu:owner' }], 258).children[3]
		assert tab.menu == [ui2.MenuEntry{ id: 'tab-color-menu:owner', title: 'Tab Color…' }]
		assert tab.vector.fill == tab_fill(.blue, selected)
		assert tab.children[2].id == 'tab-close:2'
		assert tab.action_id == 'tabdrag-2' && tab.draggable
		if selected { assert tab.children.last().box.bg == tab.vector.fill }
	}
}

fn test_mounted_color_menu_dispatch_and_reconciliation_paint_the_selected_color() {
	$if vox_ui2 ? {
		window := C.native_test_address_window()
		defer {
			ui2.unmount_embedded_browser()
			C.native_test_address_close(window)
		}
		mut events := unsafe { tab_color_events }
		events.events.clear()
		ui2.mount_embedded_browser(C.native_test_address_parent(window), [tab_strip(800, [
			Tab{ title: 'Colored', x: 62, width: 184, selected: true, color: .blue, color_action: 'tab-color-menu:owner' },
		], 258)], record_tab_color_event)!
		tab := ui2.embedded_browser_control('tab-0')
		assert C.ui2_test_tab_color_menu(tab) == 1
		assert events.events == ['tab-color-menu:owner']
		strip := ui2.embedded_browser_control('tab-strip')
		assert C.ui2_test_tab_color_pixel(strip, 150, 25) == tab_fill(.blue, true)
		assert C.ui2_test_tab_color_pixel(strip, 150, 28) == tab_fill(.blue, true)
		path := os.getenv_opt('VOX_TAB_COLOR_CAPTURE') or { os.join_path(os.temp_dir(), 'vox-ui2-tab-colors.png') }
		assert C.ui2_test_tabs_capture(strip, path.str) == 1
		ui2.update_embedded_browser([tab_strip(800, [Tab{ title: 'Plain', x: 62, width: 184, selected: true }], 258)])
		assert C.ui2_test_tab_menu_count(tab) == 0
		assert C.ui2_test_tab_color_pixel(strip, 150, 25) == tab_fill(.none, true)
	}
}
