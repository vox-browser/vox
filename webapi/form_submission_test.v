module main

import dom
import gg
import html
import page
import time

const form_search_markup = '<form id="search" action="/r/worldnews/search"><input id="query" type="text" name="q" placeholder="search"><input id="submit" type="submit" value=""><input type="checkbox" name="restrict_sr" checked><input type="checkbox" name="include_over_18"><input type="hidden" name="sort" value="new"></form><input form="search" type="hidden" name="source" value="outside"><form><input name="unrelated" value="skip"></form>'

fn form_search_app(markup string) (&BrowserApp, &html.HTMLInputElementModel) {
	mut owner := page.Page.create(1) or { panic(err) }
	document := parse_browser_navigation_document_for_page_with_response_time('<!doctype html><style>input[type=submit]{width:32px;height:28px}button{width:90px;height:30px}</style>' + markup,
		dom.URL{ value: 'https://old.reddit.com/' }, none, none, unsafe { &dom.Page(owner) },
		time.sys_mono_now())
	owner.set_local_root_navigable(document.navigable() or { panic('missing navigable') }) or {
		panic(err)
	}
	mut app := &BrowserApp{
		page_model:      owner
		document:        document
		address:         'https://old.reddit.com/'
		viewport_width:  640
		viewport_height: 480
	}
	app.install_compact_navigation_handler()
	app.relayout(640, 480 + app.chrome_height())
	query := document.get_element_by_id('query') or { panic('missing query') }
	model := html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(query) })
	dom.run_focusing_steps_for_node(query.as_node(), none, .click)
	return app, model
}

fn form_search_type(mut app BrowserApp, text string) {
	for code in text.runes() {
		app.handle_character(u32(code))
	}
}

fn form_search_click(mut app BrowserApp, id string) {
	element := app.document.get_element_by_id(id) or { panic(id) }
	rect := element.get_bounding_client_rect()
	assert rect.width > 0 && rect.height > 0
	x := f32(rect.x + rect.width / 2)
	y := f32(rect.y + rect.height / 2) + app.page_top()
	// Match the window's event/click callbacks, deferring the network request
	// until after input dispatch so the destination can be checked locally.
	app.ctx = &gg.Context{}
	app.handle_event(&gg.Event{
		typ:          .mouse_down
		mouse_x:      x
		mouse_y:      y
		mouse_button: .left
	})
	app.handle_click(x, y)
	app.handle_event(&gg.Event{
		typ:          .mouse_up
		mouse_x:      x
		mouse_y:      y
		mouse_button: .left
	})
}

fn test_native_search_enter_navigates_with_live_unicode_query_and_untouched_controls() {
	mut app, model := form_search_app(form_search_markup)
	defer { app.document.finalize() }
	form_search_type(mut app, 'C++ & café 🌍')
	app.handle_key(.enter, unsafe { gg.Modifier(0) })
	assert model.value() == 'C++ & café 🌍'
	assert app.pending_native_navigation? == 'https://old.reddit.com/r/worldnews/search?q=C%2B%2B+%26+caf%C3%A9+%F0%9F%8C%8D&restrict_sr=on&sort=new&source=outside'
	assert app.document.is_fully_active()
}

fn test_native_search_icon_click_navigates_with_last_typed_character() {
	mut app, model := form_search_app(form_search_markup)
	defer { app.document.finalize() }
	form_search_type(mut app, 'latest news')
	form_search_click(mut app, 'submit')
	assert model.value() == 'latest news'
	assert app.deferred_navigation_input?.address == 'https://old.reddit.com/r/worldnews/search?q=latest+news&restrict_sr=on&sort=new&source=outside'
	assert app.pending_native_navigation == none
}

@[heap]
struct FormSearchSubmitObservation {
mut:
	count     int
	submitter ?&dom.HTMLElement
	cancel    bool
}

fn form_search_observe_submit(app &BrowserApp, cancel bool) &FormSearchSubmitObservation {
	form := app.document.get_element_by_id('search') or { panic('missing form') }
	observation := &FormSearchSubmitObservation{ cancel: cancel }
	mut target := unsafe { &dom.EventTarget(form) }
	target.add_event_listener_without_options('submit',
		dom.IDLEventListener.create(&dom.CallbackType{
			handle_event: fn [observation] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
				mut result := unsafe { &FormSearchSubmitObservation(observation) }
				result.count++
				result.submitter = unsafe { &dom.SubmitEvent(event) }.submitter()
				if result.cancel {
					mut mutable_event := unsafe { &dom.Event(event) }
					mutable_event.prevent_default()
				}
				return dom.js_undefined()
			}
		}))
	return observation
}

fn test_native_button_descendant_click_submits_once_with_actual_submitter_and_overrides() {
	mut app, _ := form_search_app('<form id="search" action="/wrong"><input id="query" name="q"><button id="submit" type="submit" name="go" value="yes" formaction="/search?discard=old" formmethod="get"><span id="label">Search</span></button></form>')
	defer { app.document.finalize() }
	observation := form_search_observe_submit(app, false)
	form_search_type(mut app, 'button')
	form_search_click(mut app, 'label')
	assert observation.count == 1
	assert voidptr(observation.submitter?) == voidptr(app.document.get_element_by_id('submit')?)
	assert app.deferred_navigation_input?.address == 'https://old.reddit.com/search?q=button&go=yes'
}

fn test_native_search_submit_cancellation_stops_enter_and_icon_navigation() {
	mut app, _ := form_search_app(form_search_markup)
	defer { app.document.finalize() }
	observation := form_search_observe_submit(app, true)
	form_search_type(mut app, 'canceled')
	app.handle_key(.enter, unsafe { gg.Modifier(0) })
	assert observation.count == 1
	assert app.pending_native_navigation == none
	form_search_click(mut app, 'submit')
	assert observation.count == 2
	assert app.pending_native_navigation == none
	assert app.deferred_navigation_input == none
}

fn test_native_search_enter_respects_disabled_default_and_multiple_blocking_fields() {
	for markup in [
		'<form id="search" action="/search"><input id="query" name="q"><input type="submit" disabled><input type="submit"></form>',
		'<form id="search" action="/search"><input id="query" name="q"><input name="other"></form>',
	] {
		mut app, _ := form_search_app(markup)
		defer { app.document.finalize() }
		observation := form_search_observe_submit(app, false)
		form_search_type(mut app, 'blocked')
		app.handle_key(.enter, unsafe { gg.Modifier(0) })
		assert observation.count == 0
		assert app.pending_native_navigation == none
	}
}

fn test_native_search_enter_without_button_submits_and_uses_formdata_listener_changes() {
	mut app, _ := form_search_app('<form id="search" action="/search"><input id="query" name="q"></form>')
	defer { app.document.finalize() }
	observation := form_search_observe_submit(app, false)
	form := app.document.get_element_by_id('search')?
	mut target := unsafe { &dom.EventTarget(form) }
	target.add_event_listener_without_options('formdata',
		dom.IDLEventListener.create(&dom.CallbackType{
			handle_event: fn (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
				mut data := unsafe { &html.FormDataEvent(event) }.form_data() or { panic('missing form data') }
				data.set(html.create_form_data_string_entry('q', 'changed & encoded'))
				return dom.js_undefined()
			}
		}))
	form_search_type(mut app, 'original')
	app.handle_key(.enter, unsafe { gg.Modifier(0) })
	assert observation.count == 1
	assert observation.submitter == none
	assert app.pending_native_navigation? == 'https://old.reddit.com/search?q=changed+%26+encoded'
}

fn test_native_search_enter_validates_required_fields_before_navigation() {
	mut app, _ := form_search_app('<form id="search" action="/search"><input id="query" name="q" required><input type="submit"></form>')
	defer { app.document.finalize() }
	observation := form_search_observe_submit(app, false)
	app.handle_key(.enter, unsafe { gg.Modifier(0) })
	assert observation.count == 0
	assert app.pending_native_navigation == none
	form_search_type(mut app, 'valid')
	app.handle_key(.enter, unsafe { gg.Modifier(0) })
	assert observation.count == 1
	assert app.pending_native_navigation? == 'https://old.reddit.com/search?q=valid'
}
