module main

import browserextensions
import platform
import ui2

struct BrowserExtensionRow {
	id      string
	name    string
	version string
	sites   string
	enabled bool
}

struct BrowserExtensionsUI {
mut:
	open    bool
	rows    []BrowserExtensionRow
	message string
	failed  bool
}

const browser_extensions_ui = &BrowserExtensionsUI{}
const browser_extensions_width = 560
const browser_extensions_height = 390

fn browser_extensions_button(id string, title string, x f64, y f64, width f64) ui2.Element {
	return ui2.with_native_style(ui2.button(id, title, ui2.rect(x, y, width, 28),
		ui2.BoxStyle{}, ui2.TextStyle{ size: 13 }))
}

fn browser_extensions_elements(state &BrowserExtensionsUI) ui2.Element {
	mut rows := []ui2.Element{}
	if state.rows.len == 0 {
		rows << ui2.label('extensions-empty', 'No extensions loaded', ui2.rect(8, 8, 480, 22), ui2.TextStyle{ size: 13 })
	}
	for index, extension in state.rows {
		y := f64(index * 58)
		rows << ui2.label('extensions-name:${extension.id}', '${extension.name}  ${extension.version}', ui2.rect(8, y + 4, 312, 21), ui2.TextStyle{ size: 13 })
		rows << ui2.Element{
			...ui2.label('extensions-sites:${extension.id}', extension.sites, ui2.rect(8, y + 27, 312, 18), ui2.TextStyle{ size: 11, color: 0x555555 })
			tooltip: extension.sites
		}
		action := if extension.enabled { 'disable' } else { 'enable' }
		title := if extension.enabled { 'Disable' } else { 'Enable' }
		rows << browser_extensions_button('extensions-${action}:${extension.id}', title, 326, y + 9, 76)
		rows << browser_extensions_button('extensions-remove:${extension.id}', 'Remove', 410, y + 9, 82)
	}
	folder := ui2.text_input(
		id:          'extensions-path'
		submit_id:   'extensions-install'
		hint_text:   'Folder containing manifest.json'
		frame:       ui2.rect(24, 48, 314, 28)
		autocorrect: false
		text_style:  ui2.TextStyle{ size: 13 }
	) or { panic(err) }
	mut elements := [
		ui2.label('extensions-heading', 'Extensions', ui2.rect(24, 16, 490, 25), ui2.TextStyle{ size: 18 }),
		ui2.Element{ ...folder, accessibility_label: 'Unpacked extension folder' },
		browser_extensions_button('extensions-install', 'Load unpacked', 422, 48, 114),
		ui2.label('extensions-help', 'Use a trusted Manifest V3 folder. Changes apply on new page loads.', ui2.rect(24, 82, 512, 20), ui2.TextStyle{ size: 12 }),
		ui2.scroll('extensions-list', ui2.rect(24, 112, 512, 206), 0xf7f7f7, rows),
		ui2.Element{
			...ui2.label('extensions-status', state.message, ui2.rect(24, 336, 416, 26), ui2.TextStyle{ size: 12, color: if state.failed {
				u32(0xb42318)
			} else {
				u32(0x333333)
			} })
			tooltip: state.message
		},
		browser_extensions_button('extensions-close', 'Done', 450, 336, 86),
	]
	if ui2.file_dialog_supported() {
		elements << browser_extensions_button('extensions-browse', 'Browse…', 346, 48, 68)
	}
	return ui2.Element{
		...ui2.view('extensions-root', ui2.rect(0, 0, browser_extensions_width, browser_extensions_height), ui2.BoxStyle{ bg: 0xffffff }, elements)
		accessibility_role:  'dialog'
		accessibility_label: 'Extensions'
	}
}

fn (mut state BrowserExtensionsUI) load_rows() {
	mut scratch := platform.begin_thread_scratch('extension list')
	defer { scratch.finish() }
	installed := browserextensions.installed(browserextensions.profile_path()) or {
		scratch.leave()
		state.rows = []BrowserExtensionRow{}
		state.message = err.msg().clone()
		state.failed = true
		return
	}
	scratch.leave()
	state.rows = installed.map(BrowserExtensionRow{
		id:      it.id.clone()
		name:    it.name.clone()
		version: it.version.clone()
		sites:   it.scripts.map(it.matches.join(', ')).join(', ')
		enabled: it.enabled
	})
}

fn refresh_browser_extensions() {
	$if vox_ui2 ? {
		if browser_extensions_ui.open {
			ui2.show_embedded_panel('extensions', 'Extensions', browser_extensions_width, browser_extensions_height,
				browser_extensions_elements(browser_extensions_ui))
		} else {
			ui2.hide_embedded_panel('extensions')
		}
	}
	if address_bar_owner.app != unsafe { nil } {
		mut app := address_bar_owner.app.active_browser_tab()
		mut state := app.browser_ui()
		state.version++
		app.refresh_browser_ui()
	}
}

fn browser_extensions_event(event string) {
	mut state := unsafe { browser_extensions_ui }
	if event == 'extensions-open' {
		if !state.open {
			if browser_settings_visible() { close_browser_settings() }
			state.open = true
			state.message = ''
			state.failed = false
			state.load_rows()
		}
		refresh_browser_extensions()
		return
	}
	if !state.open { return }
	if event in ['extensions-close', 'panel-close:extensions'] {
		state.open = false
		state.rows = []BrowserExtensionRow{}
		refresh_browser_extensions()
		return
	}
	if event == 'extensions-browse' {
		directories := ui2.open_folder_dialog(title: 'Choose an unpacked extension')
		if directories.len > 0 { ui2.set_text('extensions-path', directories[0]) }
		return
	}
	state.message = update_browser_extension(event) or {
		state.failed = true
		state.message = err.msg().clone()
		refresh_browser_extensions()
		return
	}
	state.failed = false
	state.load_rows()
	refresh_browser_extensions()
	if event == 'extensions-install' { ui2.set_text('extensions-path', '') }
}

fn update_browser_extension(event string) !string {
	mut scratch := platform.begin_thread_scratch('update extension profile')
	defer { scratch.finish() }
	path := browserextensions.profile_path()
	if event == 'extensions-install' {
		extension := browserextensions.install(path, ui2.text('extensions-path').trim_space()) or {
			scratch.leave()
			return error(err.msg().clone())
		}
		scratch.leave()
		return '${extension.name} loaded.'
	}
	action, id := event.split_once(':') or { return '' }
	match action {
		'extensions-enable', 'extensions-disable' {
			browserextensions.set_enabled(path, id, action == 'extensions-enable') or {
				scratch.leave()
				return error(err.msg().clone())
			}
			return if action == 'extensions-enable' {
				'Extension enabled.'
			} else {
				'Extension disabled.'
			}
		}
		'extensions-remove' {
			browserextensions.remove(path, id) or {
				scratch.leave()
				return error(err.msg().clone())
			}
			return 'Extension removed.'
		}
		else { return '' }
	}
}

fn browser_extensions_overlay(width int, height int) []ui2.Element {
	$if vox_ui2 ? {
		return []ui2.Element{}
	}
	if !browser_extensions_ui.open { return []ui2.Element{} }
	x := if width > browser_extensions_width {
		f64(width - browser_extensions_width) / 2
	} else {
		0.0
	}
	return [ui2.view('extensions-overlay', ui2.rect(0, 0, width, height), ui2.BoxStyle{ transparent: true }, [
		ui2.with_action(ui2.button('extensions-dismiss', '', ui2.rect(0, 0, width, height),
			ui2.BoxStyle{ transparent: true }, ui2.TextStyle{}), 'extensions-close'),
		ui2.Element{
			...ui2.scroll('extensions-panel', ui2.rect(x, 0, if width > browser_extensions_width {
				browser_extensions_width
			} else {
				width
			},
				if height > browser_extensions_height { browser_extensions_height } else { height }), 0xffffff,
				[browser_extensions_elements(browser_extensions_ui)])
			scroll_mode: .both
		},
	])]
}
