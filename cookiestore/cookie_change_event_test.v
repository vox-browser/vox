module cookiestore

import dom
import html
import url

fn cookie_event_test_url(path string) url.URL {
	return url.URL{
		scheme: 'https'
		host:   url.Host.from_string('www.example.com')
		paths:  path.trim_left('/').split('/')
	}
}

fn cookie_event_test_store(mut event_loop html.EventLoop, backend &CookieStoreBackend) &CookieStore {
	creation := cookie_event_test_url('/')
	return CookieStore.create(backend, CookieStoreEnvironment{
		creation_url: creation
		api_base_url: creation
	}, event_loop)
}

fn drain_cookie_event_test_loop(mut event_loop html.EventLoop) {
	mut iterations := 0
	for event_loop.task_queue().has_runnable_tasks() {
		event_loop.process()
		iterations++
		assert iterations < 100
	}
}

@[heap]
struct CookieChangeObservation {
mut:
	called     int
	changed    []CookieListItem
	deleted    []CookieListItem
	bubbles    bool
	cancelable bool
	interface_ dom.EventInterface
}

fn test_cookie_change_event_constructor_defaults_and_copies_lists() {
	mut changed := [CookieListItem{ name: 'a', value: '1' }]
	event := CookieChangeEvent.construct_impl('change', CookieChangeEventInit{
		EventInit: dom.EventInit{
			bubbles:    true
			cancelable: true
		}
		changed:   changed
	}) or { panic(err) }
	changed[0] = CookieListItem{
		name: 'mutated'
	}
	assert event.interface_ == .cookie_change_event
	assert event.type_ == 'change'
	assert event.bubbles()
	assert event.cancelable()
	assert event.changed().len == 1
	assert event.changed()[0].name or { panic('missing name') } == 'a'
	assert event.deleted().len == 0
	mut returned := event.changed()
	returned.clear()
	assert event.changed().len == 1
}

fn test_process_cookie_changes_queues_trusted_changed_and_deleted_lists() {
	mut event_loop := html.EventLoop.create(.window)
	mut backend := CookieStoreBackend.create()
	backend.set_now_override(f64(1000))
	store := cookie_event_test_store(mut event_loop, backend)
	observation := &CookieChangeObservation{}
	handler := &dom.CallbackType{
		handle_event: fn [observation] (base &dom.Event, current_target ?&dom.EventTarget) dom.JSValue {
			_ = current_target
			mut seen := unsafe { &CookieChangeObservation(observation) }
			seen.called++
			seen.interface_ = base.interface_
			seen.bubbles = base.bubbles()
			seen.cancelable = base.cancelable()
			event := unsafe { &CookieChangeEvent(base) }
			seen.changed = event.changed()
			seen.deleted = event.deleted()
			return dom.js_undefined()
		}
	}
	store.set_onchange(handler)
	installed_handler := store.onchange() or { panic('handler missing') }
	assert installed_handler == handler
	store.process_cookie_changes([
		Cookie{ name: 'fresh', value: 'new', domain: 'www.example.com', expires: f64(2000) },
		Cookie{ name: 'gone', value: 'old', domain: 'www.example.com', expires: f64(999) },
		Cookie{ name: 'session', value: 'live', domain: 'www.example.com' },
	])
	assert observation.called == 0
	drain_cookie_event_test_loop(mut event_loop)
	assert observation.called == 1
	assert observation.interface_ == .cookie_change_event
	assert !observation.bubbles
	assert !observation.cancelable
	assert observation.changed.len == 2
	assert observation.changed[0].name or { panic('missing name') } == 'fresh'
	assert observation.changed[0].value or { panic('missing value') } == 'new'
	assert observation.changed[1].name or { panic('missing name') } == 'session'
	assert observation.deleted.len == 1
	assert observation.deleted[0].name or { panic('missing name') } == 'gone'
	assert observation.deleted[0].value == none

	store.set_onchange(none)
	assert store.onchange() == none
}
