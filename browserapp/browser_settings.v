module main

import browsersettings
import gg
import platform
import ui2

enum BrowserSettingsSection {
	tabs
	extensions
	proxy
	advanced
}

struct BrowserSettingsUI {
mut:
	open       bool
	section    BrowserSettingsSection
	draft      browsersettings.Proxy
	extensions BrowserExtensionsUI
	error      string
}

const browser_settings_ui = &BrowserSettingsUI{}
const browser_settings_width = 704
const browser_settings_height = 424
const browser_settings_sidebar_width = 156
const browser_settings_content_width = browser_settings_width - browser_settings_sidebar_width
const browser_settings_sidebar_id = 'settings-sidebar-tabs'

fn is_browser_settings_shortcut(key gg.KeyCode, modifier gg.Modifier) bool {
	return key == .comma && modifier == $if macos { gg.Modifier.super } $else { gg.Modifier.ctrl }
}

fn (section BrowserSettingsSection) title() string {
	return match section {
		.tabs { 'Tabs' }
		.extensions { 'Extensions' }
		.proxy { 'Proxy' }
		.advanced { 'Advanced' }
	}
}

fn browser_settings_sidebar(section BrowserSettingsSection) ui2.TabBarConfig {
	return ui2.TabBarConfig{
		id: browser_settings_sidebar_id
		frame: ui2.rect(10, 16, browser_settings_sidebar_width - 20, browser_settings_height - 32)
		items: [
			ui2.TabBarItem{ id: 'tabs', label: 'Tabs', icon: 'square.stack.3d.up' },
			ui2.TabBarItem{ id: 'extensions', label: 'Extensions', icon: 'rectangle.grid.2x2' },
			ui2.TabBarItem{ id: 'proxy', label: 'Proxy', icon: 'globe' },
			ui2.TabBarItem{ id: 'advanced', label: 'Advanced', icon: 'slider.horizontal.3' },
		]
		state: ui2.TabBarState{ selected: section.str() }
		position: .left
		variant: .pill
		animate: false
		theme: ui2.ComponentTheme{
			background: 0xf3f4f6
			muted_foreground: 0x343a44
			primary: 0x2168d6
		}
		accessibility_label: 'Settings sections'
	}
}

fn browser_settings_button(id string, title string, x f64, y f64, width f64) ui2.Element {
	return ui2.with_native_style(ui2.button(id, title, ui2.rect(x, y, width, 28),
		ui2.BoxStyle{}, ui2.TextStyle{ size: 13 }))
}

fn browser_settings_input(id string, value string, hint string, label string, frame ui2.Rect, enabled bool) ui2.Element {
	return ui2.Element{
		...ui2.text_input(
			id:          id
			submit_id:   'settings-apply'
			text:        value
			hint_text:   hint
			multiline:   false
			autocorrect: false
			frame:       frame
			text_style:  ui2.TextStyle{ size: 13 }
		) or { panic(err) }
		enabled:             enabled
		accessibility_label: label
	}
}

fn browser_settings_card(id string, height f64, children []ui2.Element) ui2.Element {
	return ui2.view(id, ui2.rect(24, 64, 500, height), ui2.BoxStyle{ bg: 0xf5f6f8, radius: 10 }, children)
}

fn browser_settings_tabs_elements(draft browsersettings.Proxy) []ui2.Element {
	style := ui2.TextStyle{ size: 13 }
	return [
		browser_settings_card('settings-tabs-card', 90, [
			ui2.checkbox('settings-tab-coloring', 'Enable tab coloring', draft.enable_tab_coloring, ui2.rect(14, 11, 472, 26), style),
			ui2.view('settings-tabs-divider', ui2.rect(14, 44, 472, 1), ui2.BoxStyle{ bg: 0xe1e3e7 }, []),
			ui2.checkbox('settings-custom-tab-titles', 'Enable custom tab titles', draft.enable_custom_tab_titles, ui2.rect(14, 53, 472, 26), style),
		]),
	]
}

fn browser_settings_proxy_elements(draft browsersettings.Proxy) []ui2.Element {
	style := ui2.TextStyle{ size: 13 }
	help := ui2.TextStyle{ size: 12, color: 0x525a66 }
	return [
		browser_settings_card('settings-proxy-card', 190, [
			ui2.checkbox('settings-enabled', 'Use SOCKS5 proxy', draft.enabled, ui2.rect(14, 11, 472, 26), style),
			ui2.label('settings-host-label', 'Host', ui2.rect(14, 51, 342, 20), style),
			ui2.label('settings-port-label', 'Port', ui2.rect(370, 51, 116, 20), style),
			browser_settings_input('settings-host', draft.host, '127.0.0.1', 'SOCKS5 proxy host', ui2.rect(14, 73, 342, 26), draft.enabled),
			browser_settings_input('settings-port', draft.port, '1080', 'SOCKS5 proxy port', ui2.rect(370, 73, 116, 26), draft.enabled),
			ui2.label('settings-sites-label', 'Only for these sites', ui2.rect(14, 119, 472, 20), style),
			browser_settings_input('settings-sites', draft.sites, 'example.com, another.org', 'Only use SOCKS5 proxy for these sites. Leave empty for all sites.', ui2.rect(14, 141, 472, 26), draft.enabled),
		]),
		ui2.label('settings-sites-help', 'Includes subdomains. Separate with commas or leave empty for all sites.', ui2.rect(24, 269, 500, 20), help),
		ui2.label('settings-help', 'Other sites connect directly. Proxied DNS uses SOCKS5.', ui2.rect(24, 289, 500, 20), help),
		ui2.label('settings-request-help', 'Changes apply to new requests.', ui2.rect(24, 309, 500, 20), help),
	]
}

fn browser_settings_advanced_elements(draft browsersettings.Proxy) []ui2.Element {
	style := ui2.TextStyle{ size: 13 }
	help := ui2.TextStyle{ size: 12, color: 0x525a66 }
	return [
		browser_settings_card('settings-advanced-card', 132, [
			ui2.checkbox('settings-gpu-canvas', 'GPU-accelerated scrolling', !draft.disable_gpu_canvas, ui2.rect(14, 10, 472, 24), style),
			ui2.label('settings-gpu-canvas-help', 'Turn off if scrolled pages show drawing errors.', ui2.rect(34, 36, 452, 20), help),
			ui2.view('settings-advanced-divider', ui2.rect(14, 65, 472, 1), ui2.BoxStyle{ bg: 0xe1e3e7 }, []),
			ui2.checkbox('settings-libjs', 'Use LibJS after background compilation (experimental)', draft.javascript_engine == 'libjs', ui2.rect(14, 75, 472, 24), style),
			ui2.label('settings-libjs-help', 'Restart Vox to apply. JavaScriptCore is the default.', ui2.rect(34, 101, 452, 20), help),
		]),
	]
}

fn (state &BrowserSettingsUI) elements() ui2.Element {
	sidebar := ui2.tab_bar(browser_settings_sidebar(state.section)) or { panic(err) }
	pane := match state.section {
		.tabs { browser_settings_tabs_elements(state.draft) }
		.extensions { state.extensions.elements() }
		.proxy { browser_settings_proxy_elements(state.draft) }
		.advanced { browser_settings_advanced_elements(state.draft) }
	}
	content := [
		ui2.Element{
			...ui2.label('settings-heading', state.section.title(), ui2.rect(24, 18, 500, 30), ui2.TextStyle{ size: 20, bold: true })
			accessibility_role: 'heading'
		},
		// Pane controls at the same positions have distinct native identities.
		ui2.Element{
			...ui2.view('settings-pane', ui2.rect(0, 0, browser_settings_content_width, 338), ui2.BoxStyle{ transparent: true }, pane)
			key: state.section.str()
		},
		ui2.with_tooltip(ui2.label('settings-error', state.error, ui2.rect(24, 339, 500, 24), ui2.TextStyle{ size: 12, color: 0xb42318 }), state.error),
		ui2.view('settings-footer-divider', ui2.rect(0, 366, browser_settings_content_width, 1), ui2.BoxStyle{ bg: 0xe1e3e7 }, []),
		browser_settings_button('settings-cancel', 'Cancel', 342, 381, 86),
		browser_settings_button('settings-apply', 'Apply', 438, 381, 86),
	]
	return ui2.view('settings-root', ui2.rect(0, 0, browser_settings_width, browser_settings_height), ui2.BoxStyle{}, [
		ui2.view('settings-sidebar', ui2.rect(0, 0, browser_settings_sidebar_width, browser_settings_height), ui2.BoxStyle{
			bg: 0xf3f4f6
			border_right: 1
			border_color: 0xe1e3e7
		}, [sidebar]),
		ui2.view('settings-content', ui2.rect(browser_settings_sidebar_width, 0, browser_settings_content_width, browser_settings_height), ui2.BoxStyle{}, content),
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
		refresh_browser_settings()
		return
	}
	show_browser_settings_section(.tabs)
}

fn show_browser_settings_section(section BrowserSettingsSection) {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut state := unsafe { browser_settings_ui }
	if browser_settings_visible() {
		state.select_section(section)
		refresh_browser_settings()
		return
	}
	if address_bar_owner.app != unsafe { nil } {
		mut app := address_bar_owner.app.active_browser_tab()
		app.dismiss_browser_popup()
	}
	state.open = true
	state.section = section
	state.draft = browsersettings.current()
	state.error = ''
	state.extensions = BrowserExtensionsUI{}
	if section == .extensions {
		state.extensions.load_rows()
	}
	refresh_browser_settings()
	// The native panel is reused across openings, even after Cancel.
	if section == .tabs {
		ui2.set_control_checked('settings-tab-coloring', state.draft.enable_tab_coloring)
		ui2.set_control_checked('settings-custom-tab-titles', state.draft.enable_custom_tab_titles)
	} else if section == .extensions {
		ui2.set_text('extensions-path', '')
	}
}

fn refresh_browser_settings() {
	$if vox_ui2 ? {
		ui2.show_embedded_panel('settings', 'Vox Settings', browser_settings_width, browser_settings_height, browser_settings_ui.elements())
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

fn (mut state BrowserSettingsUI) capture_draft() {
	match state.section {
		.tabs {
			state.draft = browsersettings.Proxy{
				...state.draft
				enable_tab_coloring: ui2.control_checked('settings-tab-coloring')
				enable_custom_tab_titles: ui2.control_checked('settings-custom-tab-titles')
			}
		}
		.extensions {
			state.extensions.folder = ui2.text('extensions-path').clone()
		}
		.proxy {
			state.draft = browsersettings.Proxy{
				...state.draft
				enabled: ui2.control_checked('settings-enabled')
				host: ui2.text('settings-host').clone()
				port: ui2.text('settings-port').clone()
				sites: ui2.text('settings-sites').clone()
			}
		}
		.advanced {
			state.draft = browsersettings.Proxy{
				...state.draft
				disable_gpu_canvas: !ui2.control_checked('settings-gpu-canvas')
				javascript_engine: if ui2.control_checked('settings-libjs') { 'libjs' } else { 'javascriptcore' }
			}
		}
	}
}

fn (mut state BrowserSettingsUI) select_section(section BrowserSettingsSection) {
	if state.section == section { return }
	state.capture_draft()
	state.section = section
	state.error = ''
	if section == .extensions {
		state.extensions.load_rows()
	}
}

fn browser_settings_event(event string) {
	match event {
		'settings-open' { show_browser_settings(); return }
		'extensions-open' { show_browser_settings_section(.extensions); return }
		'settings-cancel', 'panel-close:settings' { close_browser_settings(); return }
		else {}
	}
	if !browser_settings_visible() { return }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut state := unsafe { browser_settings_ui }
	if next := ui2.tab_bar_update(browser_settings_sidebar(state.section), event) {
		section := BrowserSettingsSection.from(next.state.selected) or { return }
		state.select_section(section)
		refresh_browser_settings()
		return
	}
	if state.section == .extensions && event.starts_with('extensions-') {
		state.extensions.handle_event(event)
		return
	}
	if event == 'settings-enabled' {
		state.capture_draft()
		state.error = ''
		refresh_browser_settings()
		return
	}
	if event != 'settings-apply' { return }
	state.capture_draft()
	previous := browsersettings.current()
	browsersettings.save(state.draft) or {
		message := err.msg()
		// A proxy validation error can be corrected in Proxy even when Apply
		// was pressed in another section. Persistence errors stay in place.
		_ = state.draft.normalized() or {
			state.section = .proxy
			state.draft
		}
		state.error = message
		refresh_browser_settings()
		return
	}
	if (previous.enable_tab_coloring != state.draft.enable_tab_coloring
		|| previous.enable_custom_tab_titles != state.draft.enable_custom_tab_titles) && address_bar_owner.app != unsafe { nil } {
		mut app := address_bar_owner.app.active_browser_tab()
		if !state.draft.enable_custom_tab_titles && app.browser_ui().tab_title_editor != none { app.dismiss_browser_popup() }
		app.invalidate_tab_customization_snapshot()
	}
	close_browser_settings()
}

fn (app &BrowserApp) browser_settings_overlay(width int, height int) []ui2.Element {
	$if vox_ui2 ? {
		return []ui2.Element{}
	}
	if !browser_settings_ui.open { return []ui2.Element{} }
	return [ui2.view('settings-overlay', ui2.rect(0, 0, width, height), ui2.BoxStyle{ transparent: true }, [
		ui2.with_action(ui2.button('settings-dismiss', '', ui2.rect(0, 0, width, height), ui2.BoxStyle{ transparent: true }, ui2.TextStyle{}), 'settings-cancel'),
		ui2.scroll_with_mode('settings-panel', ui2.rect(if width > browser_settings_width {
			f64(width - browser_settings_width) / 2
		} else {
			0
		}, 0, if width > browser_settings_width { browser_settings_width } else { width },
			if height > browser_settings_height { browser_settings_height } else { height }), 0xffffff,
			.both, [browser_settings_ui.elements()]),
	])]
}
