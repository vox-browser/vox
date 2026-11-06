module main

import browserui
import browserupdate
import os
import platform
import sokol.sapp
import ui2

struct BrowserUpdateUI {
mut:
	started bool
	results chan string
	timer   &platform.Timer = unsafe { nil }
	notice  browserui.UpdateNotice
}

const browser_update_ui = &BrowserUpdateUI{}

fn (mut app BrowserApp) start_browser_update_check() {
	// Captures and headless/worker roles do not represent interactive launches.
	// Process-tab children share the launch's notification instead of checking
	// again for every new tab.
	if app.screenshot_path != '' || os.getenv('VOX_TAB_GROUP') != '' { return }
	// Development machines opt out entirely; no timer or worker starts.
	if browserupdate.disabled_on_this_machine() { return }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut state := unsafe { browser_update_ui }
	if state.started { return }
	state.started = true
	state.results = chan string{cap: 1}
	state.timer = platform.Timer.create_repeating(250, poll_browser_update_check)
	state.timer.start()
	spawn browserupdate.check(state.results)
}

fn poll_browser_update_check() {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut state := unsafe { browser_update_ui }
	if state.timer == unsafe { nil } || address_bar_owner.app == unsafe { nil } { return }
	select {
		latest := <-state.results {
			state.timer.stop()
			state.timer = unsafe { nil }
			if latest == '' { return }
			state.notice = browserui.UpdateNotice{ latest: latest, open: true }
			refresh_browser_update_notice()
		}
		else {
		}
	}
}

fn refresh_browser_update_notice() {
	$if vox_ui2 ? {
		ui2.show_embedded_panel('update', 'Vox Update', browserui.update_notice_width, browserui.update_notice_height,
			browser_update_ui.notice.elements(browserupdate.current_version()))
	}
	refresh_browser_update_overlay()
}

fn refresh_browser_update_overlay() {
	if address_bar_owner.app == unsafe { nil } { return }
	mut app := address_bar_owner.app.active_browser_tab()
	mut state := app.browser_ui()
	state.version++
	app.refresh_browser_ui()
}

fn browser_update_event(event string) {
	mut state := unsafe { browser_update_ui }
	if !state.notice.open { return }
	if event in ['update-later', 'panel-close:update'] {
		state.notice.open = false
		$if vox_ui2 ? {
			ui2.hide_embedded_panel('update')
		}
		refresh_browser_update_overlay()
	} else if event == 'update-ok' {
		browserupdate.open_download_and_quit(os.open_uri, sapp.quit) or {
			state.notice.open_failed = true
			refresh_browser_update_notice()
			return
		}
		state.notice.open = false
	}
}

fn stop_browser_update_check() {
	mut state := unsafe { browser_update_ui }
	if state.timer != unsafe { nil } {
		state.timer.stop()
		state.timer = unsafe { nil }
	}
	state.notice.open = false
	$if vox_ui2 ? {
		ui2.remove_embedded_panel('update')
	}
}

fn (app &BrowserApp) browser_update_overlay(width int, height int) []ui2.Element {
	$if vox_ui2 ? {
		return []ui2.Element{}
	}
	if !browser_update_ui.notice.open { return []ui2.Element{} }
	panel := browser_update_ui.notice.elements(browserupdate.current_version())
	return [ui2.view('update-overlay', ui2.rect(0, 0, width, height), ui2.BoxStyle{ transparent: true }, [
		ui2.with_action(ui2.button('update-dismiss', '', ui2.rect(0, 0, width, height), ui2.BoxStyle{ transparent: true }, ui2.TextStyle{}), 'update-later'),
		ui2.Element{
			...panel
			frame: ui2.rect(f64(width - browserui.update_notice_width) / 2,
				f64(height - browserui.update_notice_height) / 2, browserui.update_notice_width, browserui.update_notice_height)
		},
	])]
}
