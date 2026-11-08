module main

import browserui
import os
import platform
import ui2

$if vox_ui2 ? {
	#include "@VMODROOT/native/include/native_browser_settings_test_darwin.h"
	fn C.native_test_address_window() voidptr
	fn C.native_test_address_parent(window voidptr) voidptr
	fn C.native_test_address_close(window voidptr)
	fn C.native_test_chrome_click(control voidptr)
}

fn test_ui2_update_notification_receives_background_result_and_dismisses_without_quitting() {
	$if vox_ui2 ? {
		window := C.native_test_address_window()
		mut app := &BrowserApp{}
		app.mount_ui2_chrome(C.native_test_address_parent(window), 800, 600)!
		defer {
			app.unmount_address_bar()
			C.native_test_address_close(window)
		}
		mut state := unsafe { browser_update_ui }
		state.started = true
		state.results = chan string{cap: 1}
		state.timer = platform.Timer.create()
		// A failure produces no notification and stops polling.
		state.results <- ''
		poll_browser_update_check()
		assert state.timer == unsafe { nil }
		assert !state.notice.open
		assert !ui2.embedded_panel_visible('update')
		// Re-entering startup never queues another request in this process.
		app.start_browser_update_check()
		assert state.timer == unsafe { nil }
		state.timer = platform.Timer.create()
		state.results <- '0.2.0'
		poll_browser_update_check()
		assert state.timer == unsafe { nil }
		assert state.notice.open
		assert ui2.embedded_panel_visible('update')
		assert ui2.text('update-version').contains('0.2.0')
		// Toolbar reconciliation retains the independent UI2 panel controls.
		app.update_browser_chrome(900, 600)
		assert ui2.embedded_control_attached('update-ok')
		// An opener failure keeps the old browser and the retry action alive.
		previous_opener := os.getenv_opt('VOPEN_URI_CMD')
		os.setenv('VOPEN_URI_CMD', '/usr/bin/false', true)
		C.native_test_chrome_click(ui2.embedded_browser_control('update-ok'))
		if previous := previous_opener {
			os.setenv('VOPEN_URI_CMD', previous, true)
		} else {
			os.unsetenv('VOPEN_URI_CMD')
		}
		assert state.notice.open
		assert state.notice.open_failed
		assert ui2.text('update-error').contains('Try OK again')
		C.native_test_chrome_click(ui2.embedded_browser_control('update-later'))
		assert !state.notice.open
		assert !ui2.embedded_panel_visible('update')
		state.notice = browserui.UpdateNotice{ latest: '0.2.0', open: true }
		refresh_browser_update_notice()
		browser_update_event('panel-close:update')
		assert !state.notice.open
		assert !ui2.embedded_panel_visible('update')
	}
}
