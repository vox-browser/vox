module dom

@[heap]
struct InlineHandlerAvailabilityProbe {
	target voidptr
mut:
	steps       []string
	name        string
	body        string
	source      string
	invocations int
	callback    &CallbackType = unsafe { nil }
}

fn inline_handler_availability_probe(target &EventTarget) &InlineHandlerAvailabilityProbe {
	probe := &InlineHandlerAvailabilityProbe{ target: voidptr(target) }
	handle := voidptr(probe)
	mut observation := unsafe { &InlineHandlerAvailabilityProbe(handle) }
	observation.callback = &CallbackType{
		handle_event: fn [handle] (event &Event, current_target ?&EventTarget) JSValue {
			mut observation := unsafe { &InlineHandlerAvailabilityProbe(handle) }
			assert voidptr(current_target or { panic('missing callback target') }) == observation.target
			assert event.type_name() == observation.name
			observation.invocations++
			return js_bool(false)
		}
	}
	return probe
}

fn test_optional_inline_handler_filter_preserves_unsupported_raw_slot_before_environment_and_compile() {
	mut document := Document.create(url_about_blank())
	document.browsing_context = &BrowsingContext{ active_document_: document }
	element := document.create_element('button')!
	target := unsafe { &EventTarget(element) }
	probe := inline_handler_availability_probe(target)
	handle := voidptr(probe)
	document.set_inline_event_handler_compiler(InlineEventHandlerCompiler{
		supports_handler: fn [handle] (actual &EventTarget, name string) bool {
			mut observation := unsafe { &InlineHandlerAvailabilityProbe(handle) }
			assert voidptr(actual) == observation.target
			observation.steps << 'supports:${name}'
			return name == 'wheel'
		}
		can_compile: fn [handle] (actual &EventTarget) bool {
			mut observation := unsafe { &InlineHandlerAvailabilityProbe(handle) }
			assert voidptr(actual) == observation.target
			observation.steps << 'can_compile'
			return true
		}
		compile: fn [handle] (actual &EventTarget, name string, body string, source string) ?&CallbackType {
			mut observation := unsafe { &InlineHandlerAvailabilityProbe(handle) }
			assert voidptr(actual) == observation.target && name == 'wheel'
			observation.steps << 'compile'
			observation.name = name
			observation.body = body
			observation.source = source
			return observation.callback
		}
	})
	target.element_event_handler_attribute_changed('onclick', 'unsupported();')
	target.element_event_handler_attribute_changed('onwheel', 'return false;')
	rejected := target.data.event_handler('click') or { panic('missing raw click handler') }
	rejected_listener := rejected.listener or { panic('missing raw click listener') }
	supported := target.data.event_handler('wheel') or { panic('missing raw wheel handler') }
	supported_listener := supported.listener or { panic('missing raw wheel listener') }
	assert target.get_current_value_of_event_handler('click') == none
	assert target.dispatch_event(Event.create('click', EventInit{ cancelable: true }))
	assert probe.steps == ['supports:click', 'supports:click'] && probe.invocations == 0
	assert rejected.value.kind == .string && rejected.value.string_data == 'unsupported();'
	assert voidptr(target.data.event_handler('click') or { panic('missing preserved handler') }) == voidptr(rejected)
	assert voidptr(rejected.listener or { panic('missing preserved listener') }) == voidptr(rejected_listener)
	assert target.event_listener_list().len == 2
	compiled := target.get_current_value_of_event_handler('wheel') or { panic('supported compiler did not run') }
	assert voidptr(compiled) == voidptr(probe.callback)
	assert probe.steps == ['supports:click', 'supports:click', 'supports:wheel', 'can_compile', 'compile']
	assert probe.name == 'wheel' && probe.body == 'return false;'
	assert probe.source == 'function onwheel(event) {
return false;
}'
	assert supported.value.kind == .object && voidptr(supported.value.object_data) == voidptr(probe.callback)
	assert voidptr(target.data.event_handler('wheel') or { panic('missing compiled handler') }) == voidptr(supported)
	assert voidptr(supported.listener or { panic('missing compiled listener') }) == voidptr(supported_listener)
	assert voidptr(target.get_current_value_of_event_handler('wheel') or { panic('missing cached callback') }) == voidptr(compiled)
	assert !target.dispatch_event(Event.create('wheel', EventInit{ cancelable: true }))
	assert probe.invocations == 1 && probe.steps.len == 5
	assert rejected.value.kind == .string && rejected.value.string_data == 'unsupported();'
}

fn test_inline_handler_compiler_without_optional_filter_keeps_existing_lazy_compilation() {
	mut document := Document.create(url_about_blank())
	document.browsing_context = &BrowsingContext{ active_document_: document }
	element := document.create_element('button')!
	target := unsafe { &EventTarget(element) }
	probe := inline_handler_availability_probe(target)
	handle := voidptr(probe)
	document.set_inline_event_handler_compiler(InlineEventHandlerCompiler{
		can_compile: fn [handle] (actual &EventTarget) bool {
			mut observation := unsafe { &InlineHandlerAvailabilityProbe(handle) }
			assert voidptr(actual) == observation.target
			observation.steps << 'can_compile'
			return true
		}
		compile: fn [handle] (actual &EventTarget, name string, body string, source string) ?&CallbackType {
			mut observation := unsafe { &InlineHandlerAvailabilityProbe(handle) }
			assert voidptr(actual) == observation.target && name == 'click'
			observation.steps << 'compile'
			observation.name = name
			observation.body = body
			observation.source = source
			return observation.callback
		}
	})
	target.element_event_handler_attribute_changed('onclick', 'return false;')
	handler := target.data.event_handler('click') or { panic('missing raw handler') }
	listener := handler.listener or { panic('missing activated listener') }
	assert probe.steps.len == 0 && handler.value.kind == .string
	assert !target.dispatch_event(Event.create('click', EventInit{ cancelable: true }))
	assert probe.invocations == 1 && probe.steps == ['can_compile', 'compile']
	assert probe.body == 'return false;' && probe.source == 'function onclick(event) {
return false;
}'
	assert voidptr(target.get_current_value_of_event_handler('click') or { panic('missing cached callback') }) == voidptr(probe.callback)
	assert !target.dispatch_event(Event.create('click', EventInit{ cancelable: true }))
	assert probe.invocations == 2 && probe.steps.len == 2
	assert voidptr(target.data.event_handler('click') or { panic('missing same handler') }) == voidptr(handler)
	assert voidptr(handler.listener or { panic('missing same listener') }) == voidptr(listener)
	assert target.event_listener_list().len == 1
}
