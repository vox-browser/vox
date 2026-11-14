module main

import processmetrics

import gg
import browsertabs
import browserui
import browsersettings
import platform
import ui2

$if macos {
	import browserwindow
}

struct BrowserChromeState {
	width                  int
	height                 int
	address                string
	status                 string
	footer                 string
	back                   bool
	forward                bool
	reload                 bool
	tab_titles             []string
	tab_favicons           []int
	tab_loading            []bool
	tab_hibernated         []bool
	tab_coloring           bool
	custom_tab_titles      bool
	tab_colors             []browsertabs.TabColor
	selected_tab           int
	debug                  bool
	bookmarks_visible      bool
	bookmarks_version      u64
	bookmarks_error        string
	bookmark_favicons      []int
	bookmark_overflow_open bool
	memory                 string
	ui_version             u64
	devtools               u64
}

fn browser_chrome_requires_update(previous BrowserChromeState, next BrowserChromeState) bool {
	// Layout diagnostics change on every scroll. They have no visible control
	// while the debug strip is hidden, and must not rebuild the toolbar/tabs.
	if !previous.debug && !next.debug {
		return previous != BrowserChromeState{ ...next, status: previous.status }
	}
	return previous != next
}

fn browser_toolbar_height(debug bool) f64 {
	return toolbar_height + if debug { debug_status_height } else { 0.0 }
}

fn browser_debug_modifier(modifier gg.Modifier, is_macos bool) bool {
	if !modifier.has(.shift) || modifier.has(.alt) { return false }
	return if is_macos {
		modifier.has(.super) && !modifier.has(.ctrl)
	} else {
		modifier.has(.ctrl) && !modifier.has(.super)
	}
}

fn is_browser_debug_shortcut(key gg.KeyCode, modifier gg.Modifier) bool {
	if key != .d { return false }
	$if macos {
		return browser_debug_modifier(modifier, true)
	} $else {
		return browser_debug_modifier(modifier, false)
	}
}

fn (mut app BrowserApp) toggle_browser_debug() {
	app.chrome_debug = !app.chrome_debug
	// A cached full-window image has the old strip height and visibility.
	$if macos {
		if app.snapshot_visible { C.native_hide_cached_snapshot() }
	}
	app.snapshot_visible = false
	app.snapshot_hold = false
	app.snapshot_hold_until = 0
	app.snapshot_cached = false
	app.update_browser_chrome(app.browser_chrome.width, app.browser_chrome.height)
	// The next frame resolves the document viewport against the new strip height.
	request_browser_frame()
}

fn (app &BrowserApp) browser_chrome_snapshot_path(resource_url string) string {
	// Keep previous chrome layouts and debug-only diagnostics out of normal
	// startup snapshots, while retaining the shared snapshots cache directory.
	settings := browsersettings.current()
	return cached_snapshot_path('${resource_url}\nui2-classic-chrome-v6:build=${browserui.build_timestamp}:custom-titles=${settings.enable_custom_tab_titles}:tab-coloring=${settings.enable_tab_coloring}:${app.chrome_debug}:${app.browser_tab_snapshot_key()}:zoom=${app.page_zoom}:bookmarks=${app.bookmark_bar_visible()}:${if app.bookmarks != unsafe { nil } {
		app.bookmarks.version
	} else {
		u64(0)
	}}')
}

fn (app &BrowserApp) chrome_footer() string {
	if app.hovered_link != '' { return app.hovered_link }
	if app.js_messages.len > 0 {
		// Console stacks must stay on the single-line status surface.
		return app.cached_browser_console_footer()
	}
	return app.source_label
}

fn (app &BrowserApp) browser_chrome_state(width int, height int) BrowserChromeState {
	settings := browsersettings.current()
	titles := app.cached_browser_tab_titles(settings.enable_custom_tab_titles)
	tab_coloring := settings.enable_tab_coloring
	return BrowserChromeState{
		memory:                 app.browser_ui().memory_label
		ui_version:             app.browser_ui().version
		devtools:               app.devtools_state_version()
		tab_titles:             titles
		tab_favicons:           app.cached_browser_tab_favicons()
		tab_loading:            app.browser_tab_loading_states()
		tab_hibernated:         app.browser_tab_hibernated_states()
		tab_coloring:           tab_coloring
		custom_tab_titles:      settings.enable_custom_tab_titles
		tab_colors:             if tab_coloring { app.browser_tab_colors() } else { []browsertabs.TabColor{} }
		selected_tab:           app.browser_selected_tab()
		width:                  width
		height:                 height
		address:                app.address
		status:                 app.status
		footer:                 app.chrome_footer()
		back:                   app.history_index > 0
		forward:                app.history_index + 1 < app.history.len
		reload:                 app.history_index >= 0
		debug:                  app.chrome_debug
		bookmarks_visible:      app.bookmark_bar_visible()
		bookmarks_version:      if app.bookmarks != unsafe { nil } {
			app.bookmarks.version
		} else {
			u64(0)
		}
		bookmarks_error:        app.bookmarks_error
		bookmark_overflow_open: app.bookmark_overflow_open
		bookmark_favicons:      app.cached_browser_bookmark_favicons()
	}
}

fn chrome_navigation_button(id string, title string, x f64, enabled bool) ui2.Element {
	if id in ['back', 'forward', 'reload'] {
		action := match id { 'back' { browserui.NavigationAction.back } 'forward' { browserui.NavigationAction.forward } else { browserui.NavigationAction.reload } }
		return browserui.navigation_button(action, ui2.rect(x, tab_strip_height + 4, 22, 22), enabled)
	}
	return ui2.Element{
		...ui2.button(id, title, ui2.rect(x, tab_strip_height + 4, 22, 22),
			ui2.BoxStyle{ transparent: true }, ui2.TextStyle{ size: 17, color: 0x7d7d7d })
		enabled:             enabled
		tooltip:             title
		accessibility_label: title
	}
}

// System-font labels measure glyphs the face lacks through CoreText's complete
// fallback cascade, which is built on first use. Keep the toolbar's symbols on
// faces that contain them: the history clock names Menlo, the face that cascade
// selects, and browserui draws the native information mark (see its comment).
fn chrome_history_text_style() ui2.TextStyle {
	$if macos {
		return ui2.TextStyle{ size: 17, color: 0x7d7d7d, font_family: 'Menlo' }
	} $else {
		return ui2.TextStyle{ size: 17, color: 0x7d7d7d }
	}
}

// The address field's toolbar geometry, shared with its suggestion dropdown.
const address_field_left = 98.0
const address_field_top = 5.0
const address_field_height = 20.0

fn browser_address_field_width(window_width int) f64 {
	width := f64(window_width)
	return if width > 162 { width - 138 } else { 24.0 }
}

fn browser_chrome_elements(chrome BrowserChromeState) []ui2.Element {
	width := f64(chrome.width)
	address_width := browser_address_field_width(chrome.width)
	memory := if chrome.memory != '' { chrome.memory } else { ui2.text('memory') }
	return [
		ui2.view('toolbar', ui2.rect(0, 0, width, tab_strip_height + browser_toolbar_height(chrome.debug) + if chrome.bookmarks_visible {
			bookmark_bar_height
		} else {
			0.0
		}), ui2.BoxStyle{ bg: 0xf7f7f7 }, [
			browserui.address_info_mark('address-info', ui2.rect(78, tab_strip_height + 6, 18, 20), 0x888888),
			ui2.Element{ ...chrome_navigation_button('back', '‹', 5, chrome.back), tooltip: 'Back', accessibility_label: 'Back' },
			ui2.Element{ ...chrome_navigation_button('forward', '›', 27, chrome.forward), tooltip: 'Forward', accessibility_label: 'Forward' },
			ui2.Element{ ...chrome_navigation_button('reload', '↻', 49, chrome.reload), tooltip: 'Reload', accessibility_label: 'Reload' },
			browserui.address_field(ui2.rect(address_field_left, tab_strip_height + address_field_top,
				address_width, address_field_height), chrome.address),
			ui2.Element{
				...chrome_navigation_button('history', '◷', width - 32, true)
				text_style:          chrome_history_text_style()
				tooltip:             'History'
				accessibility_label: 'History'
			},
			ui2.Element{
				...ui2.label('load-status', chrome.status, ui2.rect(12, tab_strip_height + toolbar_height, width - 24, debug_status_height), ui2.TextStyle{ color: 0x555555, size: 12 })
				hidden: !chrome.debug
			},
		]),
		browserui.status_bar(ui2.rect(0, f64(chrome.height) - status_bar_height, width,
			status_bar_height), chrome.footer, memory),
	]
}

$if vox_ui2 ? {
	fn (mut app BrowserApp) mount_ui2_chrome(parent voidptr, width int, height int) !voidptr {
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		mut owner := unsafe { address_bar_owner }
		owner.app = app
		$if macos { browserwindow.prepare_chrome_window(parent) }
		chrome := app.browser_chrome_state(width, height)
		ui2.mount_embedded_browser(parent, app.browser_chrome_ui_elements(chrome), address_bar_event)!
		app.browser_chrome = chrome
		app.native_address_bar = true
		ui2.install_embedded_keys(browser_ui_key)
		ui2.install_embedded_wheel(browser_ui_scroll)
		ui2.install_embedded_menus('Vox', [ui2.Menu{
			title: 'Browser'
			items: [
				ui2.menu_item_with_shortcut('settings-open', 'Settings…', 'cmd+,'),
				ui2.menu_item_with_shortcut('history', 'History', 'cmd+y'),
				ui2.menu_item_with_shortcut('devtools-toggle', 'Developer Tools', 'cmd+alt+i'),
				ui2.menu_item_with_shortcut('devtools-inspect', 'Inspect Element', 'cmd+shift+c'),
				ui2.menu_item_with_shortcut('devtools-console', 'JavaScript Console', 'cmd+alt+j'),
			]
		}])
		app.start_browser_memory_chrome()
		app.sync_browser_tab_loading_animation(chrome)
		return ui2.embedded_browser_control('address')
	}
}

fn (mut app BrowserApp) update_browser_chrome(width int, height int) {
	load_instruction_stage := processmetrics.begin_instruction_stage('browser_chrome')
	defer { load_instruction_stage.finish() }
	$if vox_ui2 ? {
		if !app.native_address_bar { return }
		chrome := app.browser_chrome_state(width, height)
		changed := browser_chrome_requires_update(app.browser_chrome, chrome)
		app.browser_chrome = chrome
		app.sync_browser_tab_loading_animation(chrome)
		if !changed { return }
		// UI2 retains action IDs and menu keys after the frame scratch expires.
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		ui2.update_embedded_browser(app.browser_chrome_ui_elements(chrome))
	}
}

fn (mut app BrowserApp) activate_browser_chrome(action string) {
	if action.starts_with('address-suggestion:') {
		app.activate_address_suggestion(action)
		return
	}
	if action.starts_with('tab-rename:') {
		app.show_browser_tab_title_editor(action.all_after(':'))
		return
	}
	if action.starts_with('find-bar:') {
		app.browser_find_bar_action(action)
		return
	}
	if action.starts_with('tab-title-editor:') {
		app.browser_tab_title_editor_action(action)
		return
	}
	if action.starts_with('tab-color-menu:') {
		app.show_tab_color_menu(action.all_after(':'))
		return
	}
	if action.starts_with('browser-menu:') {
		app.browser_popup_action(action)
		return
	}
	if action.starts_with('devtools:') {
		app.devtools_action(action)
		return
	}
	if action.starts_with('bookmark-') || action.starts_with('bookmarks-') {
		app.activate_browser_bookmarks(action)
		return
	}
	if action.starts_with('tab-') {
		app.activate_tab_chrome(action)
		return
	}
	match action {
		'history' { app.open_browser_history() }
		'devtools-toggle' { app.toggle_devtools() }
		'devtools-inspect' { app.start_devtools_picker() }
		'devtools-console' { app.show_devtools_console() }
		'back' {
			app.blur_address_bar()
			app.history_go(-1)
		}
		'forward' {
			app.blur_address_bar()
			app.history_go(1)
		}
		'reload' {
			app.blur_address_bar()
			app.reload()
		}
		'home' {
			app.blur_address_bar()
			app.navigate('about:home', true)
		}
		'address-submit' { app.submit_address_bar() }
		else { return }
	}
	request_browser_frame()
}
