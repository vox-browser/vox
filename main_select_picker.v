module main

import dom
import html
import x.json2

$if macos {
	import platform
}

fn browser_select_picker_model(node &dom.Node) ?&html.HTMLSelectElementModel {
	mut current := node
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

// Activation has already checked trust, mutability and user activation. Present
// after compact click listeners so their cancellation also suppresses the UI.
fn (mut app BrowserApp) show_browser_select_picker(node &dom.Node) {
	$if macos {
		mut model := browser_select_picker_model(node) or { return }
		if !model.is_open() { return }
		defer { model.set_is_open(false) }
		element := unsafe { &dom.Element(model.element) }
		if !model.is_mutable() || !element.is_connected()
			|| voidptr(element.document()) != voidptr(app.document) {
			return
		}
		// AppKit tracks menus in a nested event loop. Copy all labels to native
		// ownership before tracking, and keep V temporaries outside frame arenas.
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		mut items := []map[string]json2.Any{}
		for item in model.select_items_ {
			match item {
				html.SelectItemOption { items << browser_select_picker_option(item, false) }
				html.SelectItemOptionGroup {
					items << {
						'label': json2.Any(item.label)
						'group': json2.Any(true)
					}
					for option in item.items { items << browser_select_picker_option(option, true) }
				}
				html.SelectItemSeparator {
					items << {
						'separator': json2.Any(true)
					}
				}
			}
		}
		encoded := json2.encode(items)
		rect := element.get_bounding_client_rect()
		selected := C.native_browser_select_picker(C.native_browser_view(), encoded.str, encoded.len,
			rect.x * app.page_zoom, (rect.y + rect.height) * app.page_zoom + app.page_top(),
			rect.width * app.page_zoom)
		if selected < 0 || voidptr(app.document) != voidptr(element.document())
			|| !element.is_connected() || !model.is_mutable() {
			return
		}
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
}

fn browser_select_picker_option(option html.SelectItemOption, grouped bool) map[string]json2.Any {
	return {
		'id':       json2.Any(option.id)
		'label':    json2.Any(option.label)
		'selected': json2.Any(option.selected)
		'disabled': json2.Any(option.disabled)
		'grouped':  json2.Any(grouped)
	}
}

$if macos {
	#include "native_select_picker_darwin.h"
	fn C.native_browser_select_picker(view voidptr, items &u8, length int, x f64, y f64, width f64) i64
}
