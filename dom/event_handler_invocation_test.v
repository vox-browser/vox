module dom

@[heap]
struct HandlerExceptionObservation {
mut:
	first_reports                int
	replacement_reports          int
	saw_original_listener_window bool
}

fn test_replacing_handler_preserves_original_listener_realm_and_reports_its_abrupt_completion() {
	target := EventTarget.new()
	first_window := &Window{}
	replacement_window := &Window{}
	observation := &HandlerExceptionObservation{}
	first := &CallbackType{
		associated_window: first_window
		report_exception:  fn [observation] (exception IError) {
			assert exception.msg() == 'replacement callback failed'
			mut state := unsafe { &HandlerExceptionObservation(observation) }
			state.first_reports++
		}
		handle_event:      fn (_ &Event, _ ?&EventTarget) JSValue { return js_undefined() }
	}
	target.set_event_handler_attribute('load', first)
	original_listener := target.event_listener_list()[0]
	replacement := &CallbackType{
		associated_window:           replacement_window
		report_exception:            fn [observation] (_ IError) {
			mut state := unsafe { &HandlerExceptionObservation(observation) }
			state.replacement_reports++
		}
		handle_event_with_exception: fn [first_window, replacement_window, observation] (event &Event, _ ?&EventTarget) !JSValue {
			mut state := unsafe { &HandlerExceptionObservation(observation) }
			current := first_window.current_event() or { panic('missing original listener current event') }
			state.saw_original_listener_window = voidptr(current) == voidptr(event) && replacement_window.current_event() == none
			return error('replacement callback failed')
		}
	}
	target.set_event_handler_attribute('load', replacement)
	assert voidptr(target.event_listener_list()[0]) == voidptr(original_listener)
	event := Event.create('load', EventInit{})
	mut did_throw := LegacyListenerExceptionFlag{}
	assert EventDispatcher.dispatch_with_legacy_output(target, event, false, mut did_throw)
	assert did_throw.did_listeners_throw
	assert observation.first_reports == 1
	assert observation.replacement_reports == 0
	assert observation.saw_original_listener_window
	assert first_window.current_event() == none
}
