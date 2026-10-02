module dom

fn test_event_listeners_compare_actual_callback_objects_and_native_record_addresses() {
	target := EventTarget.new()
	first := &CallbackType{}
	second := &CallbackType{}
	a := IDLEventListener.create(first)
	b := IDLEventListener.create(second)
	target.add_event_listener_without_options('native', a)
	target.add_event_listener_without_options('native', b)
	assert target.event_listener_list().len == 2
	target.remove_event_listener_without_options('native', a)
	assert target.event_listener_list().len == 1
	assert voidptr(target.event_listener_list()[0].callback or { panic('callback') }.callback()) == voidptr(second)
	identity := &CallbackType{}
	c := IDLEventListener.create(&CallbackType{ callback_identity_: voidptr(identity) })
	d := IDLEventListener.create(&CallbackType{ callback_identity_: voidptr(identity) })
	target.add_event_listener_without_options('actual', c)
	target.add_event_listener_without_options('actual', d)
	assert target.event_listener_list().len == 2
	target.remove_event_listener_without_options('actual', d)
	assert target.event_listener_list().len == 1
}

fn test_throwing_event_callback_sets_source_legacy_exception_flag() {
	target := EventTarget.new()
	callback := IDLEventListener.create(&CallbackType{
		handle_event_with_exception: fn (_ &Event, _ ?&EventTarget) !JSValue {
			return error('author callback exception')
		}
	})
	target.add_event_listener_without_options('native', callback)
	mut event := Event.new('native')
	event.set_current_target(target)
	mut flag := LegacyListenerExceptionFlag{}
	assert EventDispatcher.inner_invoke(event, target.event_listener_list(), .bubbling_phase,
		false, mut flag)
	assert flag.did_listeners_throw
}
