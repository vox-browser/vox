module main

import dom
import html
import browserui
import platform
import time

fn browser_select_picker_model(node &dom.Node) ?&html.HTMLSelectElementModel {
	mut current := unsafe { node }
	for {
		if element := current.as_element() {
			if element.is_html_element() && element.local_name() == 'select' {
				return html.HTMLSelectElementModel.create(unsafe { &dom.HTMLSelectElement(element) })
			}
		}
		current = current.parent_or_shadow_host() or { return none }
	}
	return none
}

fn (mut app BrowserApp) close_browser_select_picker(node &dom.Node) {
	if mut model := browser_select_picker_model(node) { model.set_is_open(false) }
}

// DOM eligibility remains with the select owner; UI2 only presents its rows.
fn (mut app BrowserApp) show_browser_select_picker(node &dom.Node) {
	mut model := browser_select_picker_model(node) or { return }
	if !model.is_open() { return }
	element := unsafe { &dom.Element(model.element) }
	if !model.is_mutable() || !element.is_connected() || voidptr(element.document()) != voidptr(app.document) {
		model.set_is_open(false)
		return
	}
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	app.dismiss_browser_popup()
	model.set_is_open(true)
	mut rows := []browserui.MenuRow{}
	for item in model.select_items_ {
		match item {
			html.SelectItemOption { rows << browser_select_picker_option(item, false) }
			html.SelectItemOptionGroup {
				rows << browserui.MenuRow{ text: item.label.clone(), group: true }
				for option in item.items { rows << browser_select_picker_option(option, true) }
			}
			html.SelectItemSeparator { rows << browserui.MenuRow{ separator: true } }
		}
	}
	rect := element.get_bounding_client_rect()
	mut state := app.browser_ui()
	state.select_node = unsafe { &dom.Node(element) }
	state.select_document = app.document.unique_id()
	state.version++
	state.popup = browserui.Popup{
		token:  u64(time.sys_mono_now())
		x:      rect.x * app.page_zoom
		y:      (rect.y + rect.height) * app.page_zoom + app.page_top()
		width:  rect.width * app.page_zoom
		active: browser_select_picker_selected(rows)
		rows:   rows
	}
	app.refresh_browser_ui()
}

fn (mut app BrowserApp) complete_browser_select_picker(selected u32) {
	state := app.browser_ui()
	if app.document == unsafe { nil } || state.select_node == unsafe { nil }
		|| state.select_document != app.document.unique_id() {
		return
	}
	mut model := browser_select_picker_model(state.select_node) or { return }
	element := unsafe { &dom.Element(model.element) }
	if !element.is_connected() || !model.is_mutable() { return }
	// Bridge each queued native notification during its dispatch, preserving
	// input/change order across the native and compact script listeners.
	app_handle := voidptr(&app)
	document := app.document
	for event_name in ['input', 'change'] {
		listener := dom.IDLEventListener.create(&dom.CallbackType{
			handle_event: fn [app_handle, document, element, event_name] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
				mut app := unsafe { &BrowserApp(app_handle) }
				if voidptr(app.document) == voidptr(document) {
					_ = app.dispatch_javascript_event(event_name, element)
				}
				return dom.js_undefined()
			}
		})
		unsafe { &dom.EventTarget(element) }.add_event_listener(event_name, listener,
			dom.AddEventListenerOptions{ once: true })
	}
	model.did_select_item(u32(selected))
}

fn browser_select_picker_option(option html.SelectItemOption, grouped bool) browserui.MenuRow {
	return browserui.MenuRow{
		id:      'select-${option.id}'
		text:    option.label.clone()
		enabled: !option.disabled
		checked: option.selected
		indent:  if grouped { 1 } else { 0 }
	}
}

fn browser_select_picker_selected(rows []browserui.MenuRow) int {
	for index, row in rows { if row.checked { return index } }
	return -1
}
