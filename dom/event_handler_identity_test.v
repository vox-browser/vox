module dom

@[heap]
struct EventHandlerIdentityObservation {
mut:
	values []string
}

fn test_handler_activation_retains_the_passed_handler_and_removes_its_exact_listener() {
	target := EventTarget.construct_impl()!
	state := &EventHandlerIdentityObservation{}
	callback := &CallbackType{ handle_event: fn [state] (_ &Event, _ ?&EventTarget) JSValue {
		mut observation := unsafe { &EventHandlerIdentityObservation(state) }
		observation.values << 'callback'
		return js_undefined()
	} }
	target.set_event_handler_attribute('load', callback)
	handler := target.data.event_handler('load') or { panic('handler not installed') }
	listener := handler.listener or { panic('handler lost its activated listener identity') }
	assert target.event_listener_list() == [listener]
	installed := target.event_handler_attribute('load') or { panic('handler value not installed') }
	assert voidptr(installed) == voidptr(callback)
	target.dispatch_event(Event.create('load', EventInit{}))
	assert state.values == ['callback']
	target.set_event_handler_attribute('load', none)
	assert target.event_listener_list().len == 0
	assert target.event_handler_attribute('load') == none
	target.dispatch_event(Event.create('load', EventInit{}))
	assert state.values == ['callback']
}

fn test_replacing_a_handler_keeps_its_existing_listener_and_calls_the_replacement() {
	target := EventTarget.construct_impl()!
	state := &EventHandlerIdentityObservation{}
	first := &CallbackType{ handle_event: fn [state] (_ &Event, _ ?&EventTarget) JSValue {
		mut observation := unsafe { &EventHandlerIdentityObservation(state) }
		observation.values << 'first'
		return js_undefined()
	} }
	second := &CallbackType{ handle_event: fn [state] (_ &Event, _ ?&EventTarget) JSValue {
		mut observation := unsafe { &EventHandlerIdentityObservation(state) }
		observation.values << 'second'
		return js_undefined()
	} }
	target.set_event_handler_attribute('load', first)
	listener := target.event_listener_list()[0]
	target.set_event_handler_attribute('load', second)
	assert target.event_listener_list() == [listener]
	assert (target.data.event_handler('load') or { panic('missing event handler') }).listener? == listener
	target.dispatch_event(Event.create('load', EventInit{}))
	assert state.values == ['second']
}
