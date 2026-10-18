module main

$if vox_ui2 ? {
	import ui2

	#include "native_browser_tabs_darwin.h"
	fn C.native_browser_tabs_update(toolbar voidptr, owner voidptr, callback fn (voidptr, int, int), count int, selected int, first int, end int, width f64)
	fn C.native_browser_tabs_remove()
	fn C.native_browser_tab_title(index int, bytes &u8, length int)

	fn (mut app BrowserApp) update_native_browser_tabs(chrome BrowserChromeState) {
		first, end := browser_visible_tabs(chrome.width, chrome.tab_titles.len, chrome.selected_tab)
		C.native_browser_tabs_update(ui2.embedded_browser_control('toolbar'), app,
			native_browser_tab_action, chrome.tab_titles.len,
			chrome.selected_tab, first, end, browser_tab_width(chrome.width, end - first))
		for i in first .. end {
			title := chrome.tab_titles[i]
			C.native_browser_tab_title(i, title.str, title.len)
		}
	}

	fn native_browser_tab_action(owner voidptr, action int, index int) {
		mut app := unsafe { &BrowserApp(owner) }
		match action {
			0 { app.activate_tab_chrome('tab-select:${index}') }
			1 { app.activate_tab_chrome('tab-close:${index}') }
			2 { app.activate_tab_chrome('tab-new') }
			3 { app.activate_tab_chrome('tab-previous') }
			4 { app.activate_tab_chrome('tab-next') }
			else {}
		}
	}
}
