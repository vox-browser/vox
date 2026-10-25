module main

$if vox_ui2 ? {
	import browsersettings
	import os
	import time
	import ui2
}

fn test_settings_shortcut_requires_command_comma() {
	assert is_browser_settings_shortcut(.comma, .super)
	assert !is_browser_settings_shortcut(.comma, .ctrl)
	assert !is_browser_settings_shortcut(.comma, .super | .shift)
	assert !is_browser_settings_shortcut(.period, .super)
}

$if vox_ui2 ? {
	#include "native_browser_settings_test_darwin.h"
	fn C.native_test_address_window() voidptr
	fn C.native_test_address_parent(window voidptr) voidptr
	fn C.native_test_address_close(window voidptr)
	fn C.native_test_chrome_click(control voidptr)
	fn C.native_test_chrome_enabled(control voidptr) int
	fn C.native_test_settings_shortcut() int
	fn C.native_test_settings_controls(host voidptr, port voidptr, checkbox voidptr, apply voidptr) int
	fn C.native_test_settings_close_shortcut() int
	fn C.native_test_settings_submit(control voidptr) int
	fn C.native_test_settings_edit(control voidptr, value &char)
	fn C.native_test_settings_capture()

	fn test_native_ui2_settings_apply_cancel_validation_and_toolbar_reconciliation() {
		directory := os.join_path(os.temp_dir(), 'vox-native-settings-${os.getpid()}-${time.sys_mono_now()}')
		path := os.join_path(directory, 'settings.json')
		browsersettings.initialize(path)!
		window := C.native_test_address_window()
		toolbar := ui2.view('toolbar', ui2.rect(0, 0, 800, 42), ui2.BoxStyle{}, [
			ui2.text_input(id: 'address', multiline: false, frame: ui2.rect(100, 8, 600, 24)) or { panic(err) },
		])
		ui2.mount_embedded_browser(C.native_test_address_parent(window), [toolbar], browser_settings_event)!
		defer {
			C.native_browser_settings_hide()
			ui2.remove_embedded_settings()
			C.native_browser_settings_remove()
			ui2.unmount_embedded_browser()
			C.native_test_address_close(window)
			os.rmdir_all(directory) or {}
		}
		// Create an application menu before installing its native key equivalent.
		C.native_test_settings_shortcut()
		C.native_browser_settings_install(show_browser_settings)
		assert C.native_test_settings_shortcut() != 0
		assert C.native_browser_settings_visible() != 0
		host := ui2.embedded_browser_control('settings-host')
		port := ui2.embedded_browser_control('settings-port')
		checkbox := ui2.embedded_browser_control('settings-enabled')
		apply := ui2.embedded_browser_control('settings-apply')
		assert C.native_test_settings_controls(host, port, checkbox, apply) != 0
		assert C.native_test_chrome_enabled(host) == 0
		assert C.native_test_chrome_enabled(port) == 0
		C.native_test_chrome_click(checkbox)
		assert C.native_test_chrome_enabled(host) != 0
		ui2.set_text('settings-host', 'localhost')
		ui2.set_text('settings-port', 'bad')
		C.native_test_chrome_click(apply)
		assert C.native_browser_settings_visible() != 0
		assert ui2.text('settings-error').contains('65535')
		assert !os.exists(path)
		// A live toolbar update must leave the separate settings subtree intact.
		ui2.update_embedded_browser([ui2.Element{ ...toolbar, frame: ui2.rect(0, 0, 900, 42) }])
		assert ui2.embedded_browser_control('settings-host') == host
		show_browser_settings()
		assert ui2.text('settings-port') == 'bad'
		ui2.set_text('settings-port', '9050')
		assert C.native_test_settings_submit(port) != 0
		assert C.native_browser_settings_visible() == 0
		assert browsersettings.current().host == 'localhost'
		assert browsersettings.current().port == '9050'
		browsersettings.initialize(path)!
		show_browser_settings()
		assert ui2.text('settings-port') == '9050'
		C.native_test_settings_capture()
		C.native_test_settings_edit(host, c'discarded.example')
		C.native_test_chrome_click(ui2.embedded_browser_control('settings-cancel'))
		show_browser_settings()
		assert ui2.text('settings-host') == 'localhost'
		assert ui2.text('settings-error') == ''
		C.native_test_settings_edit(host, c'closed.example')
		assert C.native_test_settings_close_shortcut() != 0
		assert C.native_browser_settings_visible() == 0
		show_browser_settings()
		assert ui2.text('settings-host') == 'localhost'
		C.native_test_chrome_click(checkbox)
		assert C.native_test_chrome_enabled(host) == 0
		C.native_test_chrome_click(apply)
		assert browsersettings.proxy_override() or { panic('missing direct override') } == ''
		// Destroying the settings window must clear its root from UI2 as well.
		ui2.remove_embedded_settings()
		C.native_browser_settings_remove()
		ui2.update_embedded_browser([toolbar])
		assert ui2.embedded_browser_control('settings-host') == unsafe { nil }
		show_browser_settings()
		assert C.native_browser_settings_visible() != 0
		assert ui2.text('settings-host') == 'localhost'
	}
}
