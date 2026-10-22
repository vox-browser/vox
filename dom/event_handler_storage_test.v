module dom

@[heap]
struct HandlerStorageObservation {
mut:
	values                     []string
	target                     &EventTarget  = unsafe { nil }
	replacement                &CallbackType = unsafe { nil }
	nested                     &CallbackType = unsafe { nil }
	hook_calls                 int
	outer_was_unpublished      bool
	nested_was_published_first bool
	compile_calls              int
}

fn assert_missing_handler_storage_stays_absent(mut target EventTarget) {
	assert target.data.event_handler_storage() == none
	kind := target.data.kind
	mut visitor := CellVisitor{}
	before := gc_heap_usage().total_bytes
	mut observed := 0
	for _ in 0 .. 1024 {
		observed += target.data.event_handler_count()
		if target.data.has_event_handler('missing') { observed++ }
		if target.data.event_handler('missing') != none { observed++ }
		if target.get_current_value_of_event_handler('missing') != none { observed++ }
		target.deactivate_event_handler('missing')
		target.visit_edges(mut visitor)
	}
	after := gc_heap_usage().total_bytes
	assert observed == 0 && visitor.visited == 0
	assert target.data.event_handler_storage() == none
	assert target.data.kind == kind
	$if gcboehm ? {
		assert after == before
	}
}

fn test_handler_metadata_reads_removal_and_visiting_leave_ordinary_targets_unallocated() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	element := document.create_element_ns(namespace_html_uri, 'div')!
	text := Text.new(document, 'ordinary text')
	mut element_target := unsafe { &EventTarget(element) }
	mut text_target := unsafe { &EventTarget(text) }
	mut generic := EventTarget.new()
	assert_missing_handler_storage_stays_absent(mut element_target)
	assert_missing_handler_storage_stays_absent(mut text_target)
	assert_missing_handler_storage_stays_absent(mut generic)
}

fn handler_storage_target_from_recording_scope() (&EventTarget, &HandlerStorageObservation) {
	target := EventTarget.new()
	observation := &HandlerStorageObservation{}
	callback := &CallbackType{
		handle_event: fn [observation] (_ &Event, _ ?&EventTarget) JSValue {
			mut state := unsafe { &HandlerStorageObservation(observation) }
			state.values << 'first'
			return js_undefined()
		}
	}
	target.set_event_handler_attribute('load', callback)
	return target, observation
}

fn test_handler_storage_retains_late_callbacks_identity_visitors_and_reinsertion() {
	mut target, observation := handler_storage_target_from_recording_scope()
	storage := target.data.event_handler_storage() or { panic('missing handler storage') }
	handler := target.data.event_handler('load') or { panic('missing late handler') }
	listener := handler.listener or { panic('missing activated listener') }
	for _ in 0 .. 3 {
		gc_collect()
	}
	assert target.data.event_handler_count() == 1
	assert target.data.has_event_handler('load')
	assert !target.data.has_event_handler('missing')
	assert target.dispatch_event(Event.create('load', EventInit{}))
	assert observation.values == ['first']
	replacement := &CallbackType{
		handle_event: fn [observation] (_ &Event, _ ?&EventTarget) JSValue {
			mut state := unsafe { &HandlerStorageObservation(observation) }
			state.values << 'replacement'
			return js_undefined()
		}
	}
	target.set_event_handler_attribute('load', replacement)
	gc_collect()
	assert voidptr(target.data.event_handler('load') or { panic('lost handler') }) == voidptr(handler)
	assert voidptr(handler.listener or { panic('lost listener') }) == voidptr(listener)
	mut visitor := CellVisitor{}
	target.visit_edges(mut visitor)
	assert visitor.visited == 3
	target.dispatch_event(Event.create('load', EventInit{}))
	assert observation.values == ['first', 'replacement']
	target.set_event_handler_attribute('load', none)
	assert target.data.event_handler_count() == 0 && target.data.event_handler('load') == none
	assert voidptr(target.data.event_handler_storage() or { panic('missing handler storage') }) == voidptr(storage)
	assert target.event_listener_list().len == 0
	assert handler.value.kind == .null_ && handler.listener == none
	target.set_event_handler_attribute('load', replacement)
	gc_collect()
	assert voidptr(target.data.event_handler_storage() or { panic('missing handler storage') }) == voidptr(storage)
	assert voidptr(target.data.event_handler('load') or { panic('missing replacement slot') }) != voidptr(handler)
	assert handler.value.kind == .null_
}

fn test_handler_publication_stays_after_reentrant_activation_and_callback_changes() {
	mut target := EventTarget.new()
	mut observation := &HandlerStorageObservation{
		target: target
	}
	observation.replacement = &CallbackType{
		handle_event: fn [observation] (_ &Event, _ ?&EventTarget) JSValue {
			mut state := unsafe { &HandlerStorageObservation(observation) }
			state.values << 'replacement'
			return js_undefined()
		}
	}
	observation.nested = &CallbackType{
		handle_event: fn [observation] (_ &Event, _ ?&EventTarget) JSValue {
			mut state := unsafe { &HandlerStorageObservation(observation) }
			state.values << 'nested'
			return js_undefined()
		}
	}
	target.data.set_listener_list_changed_hook(voidptr(observation), fn (context voidptr) {
		mut state := unsafe { &HandlerStorageObservation(context) }
		state.hook_calls++
		if state.hook_calls == 1 {
			state.outer_was_unpublished = state.target.data.event_handler('load') == none
			gc_collect()
			state.target.set_event_handler_attribute('error', state.nested)
			state.nested_was_published_first = state.target.data.has_event_handler('error')
				&& !state.target.data.has_event_handler('load')
		}
	})
	outer := &CallbackType{
		handle_event: fn [observation] (_ &Event, _ ?&EventTarget) JSValue {
			mut state := unsafe { &HandlerStorageObservation(observation) }
			state.values << 'outer'
			state.target.set_event_handler_attribute('load', state.replacement)
			state.target.set_event_handler_attribute('error', none)
			return js_undefined()
		}
	}

	target.set_event_handler_attribute('load', outer)
	assert observation.outer_was_unpublished && observation.nested_was_published_first
	assert observation.hook_calls == 2
	assert target.data.event_handler_count() == 2 && target.event_listener_list().len == 2
	storage := target.data.event_handler_storage() or { panic('missing handler storage') }
	handler := target.data.event_handler('load') or { panic('missing outer slot') }
	listener := handler.listener or { panic('missing outer listener') }
	gc_collect()
	target.dispatch_event(Event.create('load', EventInit{}))
	assert observation.values == ['outer']
	assert target.data.event_handler_count() == 1 && !target.data.has_event_handler('error')
	assert voidptr(target.data.event_handler_storage() or { panic('missing handler storage') }) == voidptr(storage)
	assert voidptr(target.data.event_handler('load') or { panic('lost replaced slot') }) == voidptr(handler)
	assert voidptr(handler.listener or { panic('lost retained listener') }) == voidptr(listener)
	target.dispatch_event(Event.create('load', EventInit{}))
	assert observation.values == ['outer', 'replacement']
	target.set_event_handler_attribute('load', none)
	assert target.data.event_handler_count() == 0 && target.event_listener_list().len == 0
	assert observation.hook_calls == 4
}

fn test_raw_handler_storage_stays_absent_when_blocked_and_compiles_without_replacing_its_slot() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	document.browsing_context = &BrowsingContext{
		active_document_: document
	}
	element := document.create_element_ns(namespace_html_uri, 'button')!
	target := unsafe { &EventTarget(element) }
	document.set_csp_hook(DocumentCSPHook{
		inline_check: fn (_ voidptr, _ &Element, _ string, source string) bool {
			return source == 'blocked'
		}
	})
	target.element_event_handler_attribute_changed('onclick', 'blocked')
	assert target.data.event_handler_storage() == none
	assert target.event_listener_list().len == 0
	observation := &HandlerStorageObservation{}
	callback := &CallbackType{
		handle_event: fn [observation] (_ &Event, _ ?&EventTarget) JSValue {
			mut state := unsafe { &HandlerStorageObservation(observation) }
			state.values << 'compiled'
			return js_undefined()
		}
	}
	document.set_inline_event_handler_compiler(InlineEventHandlerCompiler{
		can_compile: fn (_ &EventTarget) bool {
			return true
		}
		compile:     fn [observation, callback] (_ &EventTarget, _ string, _ string, _ string) ?&CallbackType {
			mut state := unsafe { &HandlerStorageObservation(observation) }
			state.compile_calls++
			return callback
		}
	})
	target.element_event_handler_attribute_changed('onclick', 'allowed')
	storage := target.data.event_handler_storage() or { panic('missing handler storage') }
	handler := target.data.event_handler('click') or { panic('missing raw slot') }
	listener := handler.listener or { panic('missing raw listener') }
	assert handler.value.kind == .string
	gc_collect()
	assert voidptr(target.get_current_value_of_event_handler('click') or {
		panic('missing compiled handler')
	}) == voidptr(callback)
	assert observation.compile_calls == 1
	assert voidptr(target.data.event_handler('click') or { panic('lost compiled slot') }) == voidptr(handler)
	assert voidptr(handler.listener or { panic('lost activated listener') }) == voidptr(listener)
	target.dispatch_event(Event.create('click', EventInit{}))
	assert observation.values == ['compiled']
	target.element_event_handler_attribute_changed('onclick', none)
	assert voidptr(target.data.event_handler_storage() or { panic('missing handler storage') }) == voidptr(storage) && target.data.event_handler_count() == 0
	assert target.event_listener_list().len == 0
}
