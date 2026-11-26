module main

import dom
import gg
import html
import page
import time

@[heap]
struct PageEscapeKeyObservation {
mut:
	count int
	key   string
	code  string
	shift bool
}

fn test_page_escape_reaches_document_listeners_for_text_and_button_focus() {
	mut owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time('<!doctype html><input id="field" value="ma"><button id="button">button</button>', dom.URL{ value: 'https://github.com/vlang/v' }, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	defer { document.finalize() }
	owner.set_local_root_navigable(document.navigable() or { panic('navigable') })!
	mut app := &BrowserApp{ page_model: owner, document: document, address: 'https://github.com/vlang/v', viewport_width: 640, viewport_height: 480 }
	app.relayout(640, 480 + app.chrome_height())
	mut observed := &PageEscapeKeyObservation{}
	mut target := unsafe { &dom.EventTarget(document) }
	target.add_event_listener_without_options('keydown', dom.IDLEventListener.create(&dom.CallbackType{
		handle_event: fn [mut observed] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			key := unsafe { &dom.KeyboardEvent(event) }
			observed.count++
			observed.key = key.key()
			observed.code = key.code()
			observed.shift = key.shift_key()
			mut mutable_event := unsafe { &dom.Event(event) }
			mutable_event.prevent_default()
			return dom.js_undefined()
		}
	}))
	for id in ['field', 'button'] {
		focused := document.get_element_by_id(id) or { panic(id) }
		dom.run_focusing_steps_for_node(focused.as_node(), none, .click)
		before := observed.count
		app.handle_key(.escape, gg.Modifier.shift)
		assert observed.count == before + 1 && observed.key == 'Escape' && observed.code == 'Escape' && observed.shift
	}
	input := html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(document.get_element_by_id('field') or { panic('field') }) })
	assert input.value() == 'ma'
	before := observed.count
	app.address_active = true
	app.address = 'edited address'
	app.handle_key(.escape, unsafe { gg.Modifier(0) })
	assert !app.address_active && observed.count == before
}
