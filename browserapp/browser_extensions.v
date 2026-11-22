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
	folder  string
	rows    []BrowserExtensionRow
	message string
	failed  bool
}

fn (state &BrowserExtensionsUI) elements() []ui2.Element {
	mut rows := []ui2.Element{}
	if state.rows.len == 0 {
		rows << ui2.label('extensions-empty', 'No extensions loaded', ui2.rect(14, 10, 472, 24), ui2.TextStyle{ size: 13 })
	}
	for index, extension in state.rows {
		y := f64(index * 58)
		action := if extension.enabled { 'disable' } else { 'enable' }
		title := if extension.enabled { 'Disable' } else { 'Enable' }
		rows << ui2.Element{
			...ui2.view('', ui2.rect(0, y, 500, 58), ui2.BoxStyle{ transparent: true }, [
				ui2.label('extensions-name:${extension.id}', '${extension.name}  ${extension.version}', ui2.rect(14, 4, 282, 21), ui2.TextStyle{ size: 13 }),
				ui2.with_tooltip(ui2.label('extensions-sites:${extension.id}', extension.sites, ui2.rect(14, 27, 282, 18), ui2.TextStyle{ size: 11, color: 0x525a66 }), extension.sites),
				ui2.with_action(browser_settings_button('extensions-toggle:${extension.id}', title, 310, 9, 76), 'extensions-${action}:${extension.id}'),
				browser_settings_button('extensions-remove:${extension.id}', 'Remove', 394, 9, 82),
			])
			key: extension.id
		}
	}
	browse := ui2.file_dialog_supported()
	folder := ui2.text_input(
		id:          'extensions-path'
		submit_id:   'extensions-install'
		text:        state.folder
		hint_text:   'Folder containing manifest.json'
		frame:       ui2.rect(24, 64, if browse { 300 } else { 378 }, 28)
		multiline:   false
		autocorrect: false
		text_style:  ui2.TextStyle{ size: 13 }
	) or { panic(err) }
	help := ui2.TextStyle{ size: 12, color: 0x525a66 }
	mut elements := [
		ui2.Element{ ...folder, accessibility_label: 'Unpacked extension folder' },
		browser_settings_button('extensions-install', 'Load unpacked', 410, 64, 114),
		ui2.label('extensions-help', 'Use a trusted Manifest V3 folder.', ui2.rect(24, 101, 500, 20), help),
		ui2.label('extensions-apply-help', 'Extension changes are saved immediately and take effect on new page loads.', ui2.rect(24, 121, 500, 20), help),
		ui2.scroll('extensions-list', ui2.rect(24, 152, 500, 150), 0xf5f6f8, rows),
		ui2.with_tooltip(ui2.label('extensions-status', state.message, ui2.rect(24, 307, 500, 26), ui2.TextStyle{
			size: 12
			color: if state.failed { u32(0xb42318) } else { u32(0x343a44) }
		}), state.message),
	]
	if browse {
		elements << browser_settings_button('extensions-browse', 'Browse…', 332, 64, 70)
	}
	return elements
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

fn (mut state BrowserExtensionsUI) handle_event(event string) {
	if event == 'extensions-browse' {
		directories := ui2.open_folder_dialog(title: 'Choose an unpacked extension')
		if directories.len > 0 { ui2.set_text('extensions-path', directories[0]) }
		return
	}
	state.folder = ui2.text('extensions-path').clone()
	state.message = update_browser_extension(event, state.folder) or {
		state.failed = true
		state.message = err.msg().clone()
		refresh_browser_settings()
		return
	}
	state.failed = false
	state.load_rows()
	if event == 'extensions-install' {
		state.folder = ''
		ui2.set_text('extensions-path', '')
	}
	refresh_browser_settings()
}

fn update_browser_extension(event string, folder string) !string {
	mut scratch := platform.begin_thread_scratch('update extension profile')
	defer { scratch.finish() }
	path := browserextensions.profile_path()
	if event == 'extensions-install' {
		extension := browserextensions.install(path, folder.trim_space()) or {
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
