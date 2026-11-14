module main

import browsersettings
import gg
import platform
import ui2

struct BrowserSettingsUI {
mut:
	open  bool
	draft browsersettings.Proxy
	error string
}

const browser_settings_ui = &BrowserSettingsUI{}

const browser_settings_width = 500
const browser_settings_height = 678

fn is_browser_settings_shortcut(key gg.KeyCode, modifier gg.Modifier) bool {
	return key == .comma && modifier == $if macos { gg.Modifier.super } $else { gg.Modifier.ctrl }
}

fn browser_settings_input(id string, value string, hint string, x f64, y f64, width f64) ui2.Element {
	return ui2.Element{
		...ui2.text_input(
			id:          id
			submit_id:   'settings-apply'
			text:        value
			hint_text:   hint
			multiline:   false
			autocorrect: false
			frame:       ui2.rect(x, y, width, 24)
			text_style:  ui2.TextStyle{ size: 13 }
		) or { panic(err) }
		enabled:             browser_settings_ui.draft.enabled
		accessibility_label: if id == 'settings-host' {
			'SOCKS5 proxy host'
		} else if id == 'settings-port' {
			'SOCKS5 proxy port'
		} else {
			'Only use SOCKS5 proxy for these sites; empty means all sites'
		}
	}
}

fn browser_settings_elements(proxy browsersettings.Proxy) ui2.Element {
	return ui2.view('settings-root', ui2.rect(0, 0, browser_settings_width, browser_settings_height), ui2.BoxStyle{}, [
		ui2.label('settings-browsing-heading', 'Browsing', ui2.rect(24, 20, 218, 24), ui2.TextStyle{ size: 18 }),
		ui2.checkbox('settings-tab-coloring', 'Enable tab coloring', proxy.enable_tab_coloring, ui2.rect(24, 56, 218, 24), ui2.TextStyle{ size: 13 }),
		ui2.checkbox('settings-custom-tab-titles', 'Enable custom tab titles', proxy.enable_custom_tab_titles, ui2.rect(24, 86, 218, 24), ui2.TextStyle{ size: 13 }),
		ui2.label('settings-appearance-heading', 'Appearance', ui2.rect(258, 20, 218, 24), ui2.TextStyle{ size: 18 }),
		ui2.checkbox('settings-force-dark', 'Force dark mode', proxy.force_dark_enabled, ui2.rect(258, 56, 218, 24), ui2.TextStyle{ size: 13 }),
		ui2.label('settings-force-dark-help', 'For pages without a dark theme.', ui2.rect(258, 86, 218, 20), ui2.TextStyle{ size: 12 }),
		ui2.label('settings-heading', 'Network', ui2.rect(24, 140, 452, 24), ui2.TextStyle{ size: 18 }),
		ui2.checkbox('settings-enabled', 'Use SOCKS5 proxy', proxy.enabled, ui2.rect(24, 180, 452, 24), ui2.TextStyle{ size: 13 }),
		ui2.label('settings-host-label', 'Host', ui2.rect(24, 219, 320, 20), ui2.TextStyle{ size: 13 }),
		ui2.label('settings-port-label', 'Port', ui2.rect(368, 219, 108, 20), ui2.TextStyle{ size: 13 }),
		browser_settings_input('settings-host', proxy.host, '127.0.0.1', 24, 242, 324),
		browser_settings_input('settings-port', proxy.port, '1080', 368, 242, 108),
		ui2.label('settings-sites-label', 'Only for these sites', ui2.rect(24, 286, 452, 20), ui2.TextStyle{ size: 13 }),
		browser_settings_input('settings-sites', proxy.sites, 'example.com, another.org', 24, 310, 452),
		ui2.label('settings-sites-help', 'Includes subdomains. Separate with commas; leave empty for all.', ui2.rect(24, 344, 452, 20), ui2.TextStyle{ size: 12 }),
		ui2.label('settings-help', 'Other sites connect directly. Proxied DNS uses SOCKS5.', ui2.rect(24, 365, 452, 20), ui2.TextStyle{ size: 12 }),
		ui2.label('settings-request-help', 'Changes apply to new requests.', ui2.rect(24, 386, 452, 20), ui2.TextStyle{ size: 12 }),
		ui2.label('settings-advanced-heading', 'Advanced', ui2.rect(24, 426, 452, 24), ui2.TextStyle{ size: 18 }),
		ui2.checkbox('settings-gpu-canvas', 'GPU-accelerated scrolling', !proxy.disable_gpu_canvas, ui2.rect(24, 462, 452, 24), ui2.TextStyle{ size: 13 }),
		ui2.label('settings-gpu-canvas-help', 'Turn off if scrolled pages show drawing errors.', ui2.rect(24, 492, 452, 20), ui2.TextStyle{ size: 12 }),
		ui2.checkbox('settings-libjs', 'Use LibJS JavaScript engine (experimental)', proxy.javascript_engine == 'libjs', ui2.rect(24, 526, 452, 24), ui2.TextStyle{ size: 13 }),
		ui2.label('settings-libjs-help', 'Restart Vox to apply. JavaScriptCore is the default.', ui2.rect(24, 556, 452, 20), ui2.TextStyle{ size: 12 }),
		ui2.label('settings-error', browser_settings_ui.error, ui2.rect(24, 592, 452, 24), ui2.TextStyle{ size: 12, color: 0xb42318 }),
		ui2.with_native_style(ui2.button('settings-cancel', 'Cancel', ui2.rect(294, 632, 86, 28), ui2.BoxStyle{}, ui2.TextStyle{ size: 13 })),
		ui2.with_native_style(ui2.button('settings-apply', 'Apply', ui2.rect(390, 632, 86, 28), ui2.BoxStyle{}, ui2.TextStyle{ size: 13 })),
	])
}

fn browser_settings_visible() bool {
	$if vox_ui2 ? {
		return ui2.embedded_panel_visible('settings')
	}
	return browser_settings_ui.open
}

fn show_browser_settings() {
	if browser_settings_visible() {
		$if vox_ui2 ? {
			ui2.show_embedded_panel('settings', 'Vox Settings', browser_settings_width, browser_settings_height, browser_settings_elements(browser_settings_ui.draft))
		}
		return
	}
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	if address_bar_owner.app != unsafe { nil } {
		mut app := address_bar_owner.app.active_browser_tab()
		app.dismiss_browser_popup()
	}
	mut state := unsafe { browser_settings_ui }
	state.open = true
	state.draft = browsersettings.current()
	state.error = ''
	refresh_browser_settings()
	// A canceled edit can differ from the last declared string.
	ui2.set_control_checked('settings-enabled', state.draft.enabled)
	ui2.set_control_checked('settings-tab-coloring', state.draft.enable_tab_coloring)
	ui2.set_control_checked('settings-custom-tab-titles', state.draft.enable_custom_tab_titles)
	ui2.set_control_checked('settings-force-dark', state.draft.force_dark_enabled)
	ui2.set_control_checked('settings-gpu-canvas', !state.draft.disable_gpu_canvas)
	ui2.set_control_checked('settings-libjs', state.draft.javascript_engine == 'libjs')
	ui2.set_text('settings-host', state.draft.host)
	ui2.set_text('settings-port', state.draft.port)
	ui2.set_text('settings-sites', state.draft.sites)
}

fn refresh_browser_settings() {
	$if vox_ui2 ? {
		ui2.show_embedded_panel('settings', 'Vox Settings', browser_settings_width, browser_settings_height, browser_settings_elements(browser_settings_ui.draft))
	}
	if address_bar_owner.app != unsafe { nil } {
		mut app := address_bar_owner.app.active_browser_tab()
		mut state := app.browser_ui()
		state.version++
		app.refresh_browser_ui()
	}
}

fn close_browser_settings() {
	mut state := unsafe { browser_settings_ui }
	state.open = false
	$if vox_ui2 ? {
		ui2.hide_embedded_panel('settings')
	}
	if address_bar_owner.app != unsafe { nil } {
		mut app := address_bar_owner.app.active_browser_tab()
		mut ui_state := app.browser_ui()
		ui_state.version++
		app.refresh_browser_ui()
	}
}

fn browser_settings_event(event string) {
	if event == 'settings-open' {
		show_browser_settings()
		return
	}
	if event in ['settings-cancel', 'panel-close:settings'] {
		close_browser_settings()
		return
	}
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut state := unsafe { browser_settings_ui }
	state.draft = browsersettings.Proxy{
		javascript_engine: if ui2.control_checked('settings-libjs') { 'libjs' } else { 'javascriptcore' }
		enable_custom_tab_titles: ui2.control_checked('settings-custom-tab-titles')
		force_dark_enabled: ui2.control_checked('settings-force-dark')
		enable_tab_coloring: ui2.control_checked('settings-tab-coloring')
		disable_gpu_canvas: !ui2.control_checked('settings-gpu-canvas')
		enabled:        ui2.control_checked('settings-enabled')
		host:           ui2.text('settings-host')
		port:           ui2.text('settings-port')
		sites:          ui2.text('settings-sites')
	}
	if event == 'settings-apply' {
		previous := browsersettings.current()
		browsersettings.save(state.draft) or {
			state.error = err.msg()
			refresh_browser_settings()
			return
		}
		if previous.force_dark_enabled != state.draft.force_dark_enabled {
			apply_browser_appearance_to_open_tabs(state.draft.force_dark_enabled)
		}
		if (previous.enable_tab_coloring != state.draft.enable_tab_coloring
			|| previous.enable_custom_tab_titles != state.draft.enable_custom_tab_titles) && address_bar_owner.app != unsafe { nil } {
			mut app := address_bar_owner.app.active_browser_tab()
			if !state.draft.enable_custom_tab_titles && app.browser_ui().tab_title_editor != none { app.dismiss_browser_popup() }
			app.invalidate_tab_customization_snapshot()
		}
		close_browser_settings()
	} else if event == 'settings-enabled' {
		refresh_browser_settings()
	}
}

fn (app &BrowserApp) browser_settings_overlay(width int, height int) []ui2.Element {
	$if vox_ui2 ? {
		return []ui2.Element{}
	}
	if !browser_settings_ui.open { return []ui2.Element{} }
	return [ui2.view('settings-overlay', ui2.rect(0, 0, width, height), ui2.BoxStyle{ transparent: true }, [
		ui2.with_action(ui2.button('settings-dismiss', '', ui2.rect(0, 0, width, height), ui2.BoxStyle{ transparent: true }, ui2.TextStyle{}), 'settings-cancel'),
		ui2.Element{ ...ui2.scroll('settings-panel', ui2.rect(if width > browser_settings_width {
			f64(width - browser_settings_width) / 2
		} else {
			0
		}, 0, if width > browser_settings_width { browser_settings_width } else { width }, height), 0xffffff, [browser_settings_elements(browser_settings_ui.draft)]), scroll_mode: .both },
	])]
}
