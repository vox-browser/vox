module main

import browserui
import browsertabs
import math
import ui2

fn (app &BrowserApp) browser_tab_strip(chrome BrowserChromeState) ui2.Element {
	mut first, mut end := browser_visible_tabs(chrome.width, chrome.tab_titles.len, chrome.selected_tab)
	mut width := browser_tab_width(chrome.width, end - first)
	if app.tabs != unsafe { nil } {
		if drag := app.tabs.drag {
			first = drag.first
			end = drag.end
			width = drag.width
		}
	}
	mut tabs := []browserui.Tab{}
	mut dragged := []browserui.Tab{}
	for index in first .. end {
		mut slot := index
		mut x := tab_strip_leading_width + f64(slot - first) * width
		mut moving := false
		if app.tabs != unsafe { nil } {
			if drag := app.tabs.drag {
				if drag.moving {
					from := app.browser_drag_tab_index(drag)
					moving = from == index
					if from < index && index <= drag.target { slot-- }
					if drag.target <= index && index < from { slot++ }
					x = if moving {
						math.clamp(drag.x - drag.offset, tab_strip_leading_width, tab_strip_leading_width + f64(end - first - 1) * width)
					} else {
						tab_strip_leading_width + f64(slot - first) * width
					}
				}
			}
		}
		item := browserui.Tab{
			index: index
			title: chrome.tab_titles[index]
			icon: app.browser_tab_icon_path(index, chrome)
			x: x
			width: width
			selected: index == chrome.selected_tab
			dragging: moving
			color: if chrome.tab_coloring && index < chrome.tab_colors.len { chrome.tab_colors[index] } else { browsertabs.TabColor.none }
			color_action: if chrome.tab_coloring { 'tab-color-menu:${app.browser_tab_identity(index)}' } else { '' }
			rename_action: if chrome.custom_tab_titles { 'tab-rename:${app.browser_tab_identity(index)}' } else { '' }
		}
		if moving { dragged << item } else { tabs << item }
	}
	tabs << dragged
	return browserui.tab_strip(f64(chrome.width), tabs, tab_strip_leading_width + 12 + f64(end - first) * width)
}

fn (app &BrowserApp) browser_tab_icon_path(index int, chrome BrowserChromeState) string {
	if index >= chrome.tab_favicons.len || chrome.tab_favicons[index] < 0 { return '' }
	if app.process_tabs() {
		address := app.tabs.session.state.tabs[index].favicon
		bytes := app.background_image_bytes(address) or { return '' }
		return app.browser_ui_icon_path(chrome.tab_favicons[index], bytes)
	}
	tab := if app.tabs != unsafe { nil } {
		app.tabs.pages[index]
	} else {
		unsafe { &BrowserApp(app) }
	}
	cache := tab.browser_text_cache()
	address := if cache.favicon_fallback {
		browser_tab_fallback_favicon_url(tab.document)
	} else {
		cache.favicon_url
	}
	bytes := tab.background_image_bytes(address) or { return '' }
	return tab.browser_ui_icon_path(chrome.tab_favicons[index], bytes)
}
