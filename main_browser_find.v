module main

import browserui
import page
import platform
import time
import ui2

fn (mut app BrowserApp) show_browser_find_bar() {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut state := app.browser_ui()
	if state.find_bar == none {
		app.dismiss_browser_popup()
		state.find_bar = browserui.FindBar{ token: u64(time.sys_mono_now()) }
	}
	state.find_focus_pending = true
	state.version++
	app.refresh_browser_ui()
	app.focus_browser_find_bar()
}

fn (app &BrowserApp) focus_browser_find_bar() {
	mut state := app.browser_ui()
	if !state.find_focus_pending { return }
	bar := state.find_bar or { return }
	ui2.focus(bar.input_id())
	if ui2.focused_id() == bar.input_id() { state.find_focus_pending = false }
}

fn (mut app BrowserApp) close_browser_find_bar() {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut state := app.browser_ui()
	if state.find_bar == none { return }
	state.find_bar = none
	state.find_focus_pending = false
	if app.page_model != unsafe { nil } {
		mut model := app.page_model
		model.find_in_page(page.FindInPageQuery{ string_: '' })
	}
	state.version++
	ui2.blur_embedded_textbox()
	app.refresh_browser_ui()
	request_browser_frame()
}

fn (mut app BrowserApp) apply_find_result(result page.FindInPageResult) {
	mut state := app.browser_ui()
	mut bar := state.find_bar or { return }
	total := result.total_match_count or { 0 }
	bar.total = int(total)
	bar.current = if total > 0 { int(result.current_match_index) + 1 } else { 0 }
	bar.searched = true
	state.find_bar = bar
	state.version++
	app.refresh_browser_ui()
	request_browser_frame()
}

// find_browser_step moves to the next or previous match of the active query.
fn (mut app BrowserApp) find_browser_step(forward bool) {
	if app.page_model == unsafe { nil } { return }
	state := app.browser_ui()
	bar := state.find_bar or { return }
	if bar.query == '' { return }
	mut model := app.page_model
	result := if forward { model.find_in_page_next_match() } else { model.find_in_page_previous_match() }
	app.apply_find_result(result)
}

fn (mut app BrowserApp) browser_find_bar_action(action string) {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut state := app.browser_ui()
	mut bar := state.find_bar or { return }
	parts := action.split(':')
	if parts.len != 3 || parts[0] != 'find-bar' || parts[1].u64() != bar.token { return }
	match parts[2] {
		'close' { app.close_browser_find_bar() }
		'next', 'previous' {
			forward := parts[2] == 'next'
			text := ui2.text(bar.input_id())
			if text != bar.query {
				app.search_browser_find_query(text)
			} else {
				app.find_browser_step(forward)
			}
		}
		'change' {
			app.search_browser_find_query(ui2.text(bar.input_id()))
		}
		else {}
	}
}

fn (mut app BrowserApp) search_browser_find_query(text string) {
	mut state := app.browser_ui()
	mut bar := state.find_bar or { return }
	bar.query = text.clone()
	state.find_bar = bar
	if app.page_model == unsafe { nil } { return }
	mut model := app.page_model
	result := model.find_in_page(page.FindInPageQuery{ string_: bar.query, wrap_around: .yes, clear_selection_on_no_match: .yes })
	if bar.query == '' {
		bar.searched = false
		bar.total = 0
		bar.current = 0
		state.find_bar = bar
		state.version++
		app.refresh_browser_ui()
		return
	}
	app.apply_find_result(result)
}
