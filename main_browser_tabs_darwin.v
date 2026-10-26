module main

$if vox_ui2 ? {
	import ui2
	import platform

	#include "native_browser_tabs_darwin.h"
	fn C.native_browser_tabs_update(toolbar voidptr, owner voidptr, callback fn (voidptr, int, int, int), count int, selected int, first int, end int, width f64)
	fn C.native_browser_tabs_process_mode(i32)
	fn C.native_browser_tabs_remove()
	fn C.native_browser_tabs_first() int
	fn C.native_browser_tabs_end() int
	fn C.native_browser_tab_title(index int, bytes &u8, length int)
	fn C.native_browser_tab_icon(index int, bytes &u8, length int)

	fn (mut app BrowserApp) update_native_browser_tabs(chrome BrowserChromeState) {
		C.native_browser_tabs_process_mode(i32(app.process_tabs()))
		first, end := browser_visible_tabs(chrome.width, chrome.tab_titles.len, chrome.selected_tab)
		C.native_browser_tabs_update(ui2.embedded_browser_control('toolbar'), app,
			native_browser_tab_action, chrome.tab_titles.len,
			chrome.selected_tab, first, end, browser_tab_width(chrome.width, end - first))
		// AppKit copies encoded image bytes before this temporary scope ends.
		scratch := platform.begin_thread_scratch('native tab favicons')
		defer { scratch.finish() }
		// Native tracking keeps its original visible range while selection changes.
		for i in C.native_browser_tabs_first() .. C.native_browser_tabs_end() {
			title := chrome.tab_titles[i]
			C.native_browser_tab_title(i, title.str, title.len)
			if chrome.tab_favicons[i] >= 0 {
				if app.process_tabs() {
					if bytes := app.background_image_bytes(app.tabs.session.state.tabs[i].favicon) {
						C.native_browser_tab_icon(i, bytes.data, bytes.len)
					}
					continue
				}
				tab := if app.tabs != unsafe { nil } {
					app.tabs.pages[i]
				} else {
					unsafe { &BrowserApp(app) }
				}
				cache := tab.browser_text_cache()
				address := if cache.favicon_fallback {
					browser_tab_fallback_favicon_url(tab.document)
				} else {
					cache.favicon_url
				}
				if bytes := tab.background_image_bytes(address) {
					C.native_browser_tab_icon(i, bytes.data, bytes.len)
				}
			}
		}
	}

	fn native_browser_tab_action(owner voidptr, action int, index int, destination int) {
		mut app := unsafe { &BrowserApp(owner) }
		match action {
			0 { app.activate_tab_chrome('tab-select:${index}') }
			1 { app.activate_tab_chrome('tab-close:${index}') }
			2 { app.activate_tab_chrome('tab-new') }
			3 { app.activate_tab_chrome('tab-previous') }
			4 { app.activate_tab_chrome('tab-next') }
			5 { app.activate_tab_chrome('tab-move:${index}:${destination}') }
			6 { app.activate_tab_chrome('tab-detach:${index}') }
			else {}
		}
	}
}
