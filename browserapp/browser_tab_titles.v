module main

import browsersettings
import browsertabs
import browserui
import platform
import time
import ui2

fn (app &BrowserApp) browser_display_tab_title(index int, custom_titles bool) string {
	if app.process_tabs() {
		tab := app.tabs.session.state.tabs[index]
		return if custom_titles && tab.custom_title != '' { tab.custom_title } else { tab.title }
	}
	tab := if app.tabs == unsafe { nil } { app } else { app.tabs.pages[index] }
	hibernated_title := app.hibernated_browser_tab_title(index)
	if hibernated_title != '' {
		return hibernated_title
	}
	custom := tab.browser_ui().custom_tab_title
	return if custom_titles && custom != '' { custom } else { tab.browser_tab_title() }
}

fn (mut app BrowserApp) show_browser_tab_title_editor(target string) {
	if !browsersettings.current().enable_custom_tab_titles { return }
	index := app.browser_tab_index_for_identity(target)
	if index < 0 { return }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	app.dismiss_browser_popup()
	app.blur_address_bar()
	mut state := app.browser_ui()
	state.tab_title_target = target.clone()
	state.tab_title_editor = browserui.TabTitleEditor{
		token: u64(time.sys_mono_now())
		title: app.browser_display_tab_title(index, true).clone()
	}
	state.tab_title_focus_pending = true
	state.version++
	app.refresh_browser_ui()
	app.focus_browser_tab_title_editor()
}

// The custom renderer mounts on its next draw; the native backend mounts now.
fn (app &BrowserApp) focus_browser_tab_title_editor() {
	mut state := app.browser_ui()
	if !state.tab_title_focus_pending { return }
	editor := state.tab_title_editor or { return }
	ui2.focus(editor.input_id())
	if ui2.focused_id() == editor.input_id() { state.tab_title_focus_pending = false }
}

fn (mut app BrowserApp) browser_tab_title_editor_action(action string) {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut state := app.browser_ui()
	mut editor := state.tab_title_editor or { return }
	parts := action.split(':')
	if parts.len != 3 || parts[0] != 'tab-title-editor' || parts[1].u64() != editor.token { return }
	name := parts[2]
	if name !in ['change', 'cancel', 'save', 'reset'] { return }
	if name == 'cancel' {
		app.dismiss_browser_popup()
		app.refresh_browser_ui()
		return
	}
	index := app.browser_tab_index_for_identity(state.tab_title_target)
	if !browsersettings.current().enable_custom_tab_titles || index < 0 {
		app.dismiss_browser_popup()
		app.refresh_browser_ui()
		return
	}
	editor.title = ui2.text(editor.input_id()).clone()
	state.tab_title_editor = editor
	if name == 'change' { return }
	title := if name == 'reset' { '' } else { browsertabs.normalize_custom_title(editor.title) }
	if app.process_tabs() {
		app.tabs.session.set_custom_title(state.tab_title_target, title) or {
			editor.error = 'Could not rename tab: ${err.msg()}'
			state.tab_title_editor = editor
			state.version++
			app.refresh_browser_ui()
			return
		}
	} else {
		mut tab := if app.tabs == unsafe { nil } { &app } else { app.tabs.pages[index] }
		mut tab_state := tab.browser_ui()
		tab_state.custom_tab_title = title.clone()
	}
	app.invalidate_tab_customization_snapshot()
	app.dismiss_browser_popup()
	app.refresh_browser_ui()
}
