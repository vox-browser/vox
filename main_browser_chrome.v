module main

$if vox_ui2 ? {
	import ui2

	#include "native_browser_chrome_darwin.h"
	fn C.native_browser_chrome_start_memory(control voidptr)
	fn C.native_browser_chrome_stop_memory()
}

struct BrowserChromeState {
	width   int
	height  int
	address string
	status  string
	footer  string
	back    bool
	forward bool
	reload  bool
}

fn (app &BrowserApp) chrome_footer() string {
	if app.hovered_link != '' { return app.hovered_link }
	if app.js_messages.len > 0 {
		// Console stacks must stay on the single-line status surface.
		return 'Console: ${app.js_messages.last().split_into_lines()[0]}'
	}
	return app.source_label
}

fn (app &BrowserApp) browser_chrome_state(width int, height int) BrowserChromeState {
	return BrowserChromeState{
		width:   width
		height:  height
		address: app.address
		status:  app.status
		footer:  app.chrome_footer()
		back:    app.history_index > 0
		forward: app.history_index + 1 < app.history.len
		reload:  app.history_index >= 0
	}
}

$if vox_ui2 ? {
	fn chrome_navigation_button(id string, title string, x f64, enabled bool) ui2.Element {
		return ui2.Element{
			...ui2.with_native_style(ui2.button(id, title, ui2.rect(x, 12, 36, 34),
				ui2.BoxStyle{}, ui2.TextStyle{}))
			enabled:             enabled
			tooltip:             title
			accessibility_label: title
		}
	}

	fn browser_chrome_elements(chrome BrowserChromeState) []ui2.Element {
		width := f64(chrome.width)
		address_width := if width > 276 { width - 252 } else { 24.0 }
		footer_width := if width > 224 { width - 224 } else { 0.0 }
		memory := ui2.text('memory')
		return [
			ui2.view('toolbar', ui2.rect(0, 0, width, toolbar_height), ui2.BoxStyle{ bg: 0xececec }, [
				ui2.Element{ ...chrome_navigation_button('back', '‹', 12, chrome.back), tooltip: 'Back', accessibility_label: 'Back' },
				ui2.Element{ ...chrome_navigation_button('forward', '›', 54, chrome.forward), tooltip: 'Forward', accessibility_label: 'Forward' },
				ui2.Element{ ...chrome_navigation_button('reload', '↻', 96, chrome.reload), tooltip: 'Reload', accessibility_label: 'Reload' },
				ui2.Element{ ...chrome_navigation_button('home', '⌂', 138, true), tooltip: 'Home', accessibility_label: 'Home' },
				ui2.text_input(
					id:          'address'
					action_id:   'address-change'
					submit_id:   'address-submit'
					text:        chrome.address
					hint_text:   'Enter a URL'
					multiline:   false
					autocorrect: false
					frame:       ui2.rect(184, 12, address_width, 34)
					text_style:  ui2.TextStyle{ size: 14 }
				) or { panic(err) },
				ui2.with_native_style(ui2.button('go', 'Go', ui2.rect(width - 60, 12, 48, 34), ui2.BoxStyle{}, ui2.TextStyle{})),
				ui2.label('load-status', chrome.status, ui2.rect(12, 52, width - 24, 28), ui2.TextStyle{ color: 0x555555, size: 12 }),
			]),
			ui2.view('status-bar', ui2.rect(0, f64(chrome.height) - status_bar_height, width, status_bar_height), ui2.BoxStyle{ bg: 0xececec }, [
				ui2.label('footer', chrome.footer, ui2.rect(12, 0, footer_width, status_bar_height), ui2.TextStyle{ color: 0x555555, size: 12 }),
				ui2.label('memory', memory, ui2.rect(width - 200, 0, 188, status_bar_height), ui2.TextStyle{ color: 0x555555, size: 12, align: .right }),
			]),
		]
	}

	fn (mut app BrowserApp) mount_ui2_chrome(parent voidptr, width int, height int) !voidptr {
		chrome := app.browser_chrome_state(width, height)
		ui2.mount_embedded_browser(parent, browser_chrome_elements(chrome), address_bar_event)!
		app.browser_chrome = chrome
		app.native_address_bar = true
		C.native_browser_chrome_start_memory(ui2.embedded_browser_control('memory'))
		return ui2.embedded_browser_control('address')
	}
}

fn (mut app BrowserApp) update_browser_chrome(width int, height int) {
	$if vox_ui2 ? {
		if !app.native_address_bar { return }
		chrome := app.browser_chrome_state(width, height)
		if app.browser_chrome == chrome { return }
		ui2.update_embedded_browser(browser_chrome_elements(chrome))
		app.browser_chrome = chrome
	}
}

fn (mut app BrowserApp) activate_browser_chrome(action string) {
	match action {
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
		'go', 'address-submit' { app.submit_address_bar() }
		else { return }
	}
	request_browser_frame()
}
