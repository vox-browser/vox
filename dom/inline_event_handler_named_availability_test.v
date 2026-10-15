module dom

@[heap]
struct NamedHandlerAvailabilityProbe {
mut:
	environment_ready bool = true
	pause_ready bool
	steps []string
	callback &CallbackType = &CallbackType{}
}

fn named_handler_availability_compiler(probe &NamedHandlerAvailabilityProbe) InlineEventHandlerCompiler {
	handle := voidptr(probe)
	return InlineEventHandlerCompiler{
		supports_handler: fn [handle] (_ &EventTarget, name string) bool {
			mut state := unsafe { &NamedHandlerAvailabilityProbe(handle) }
			state.steps << 'supports:${name}'
			return name in ['play', 'pause']
		}
		can_compile: fn [handle] (_ &EventTarget) bool {
			mut state := unsafe { &NamedHandlerAvailabilityProbe(handle) }
			state.steps << 'environment'
			return state.environment_ready
		}
		can_compile_handler: fn [handle] (_ &EventTarget, name string) bool {
			mut state := unsafe { &NamedHandlerAvailabilityProbe(handle) }
			state.steps << 'available:${name}'
			return name == 'play' || state.pause_ready
		}
		compile: fn [handle] (_ &EventTarget, name string, body string, source string) ?&CallbackType {
			mut state := unsafe { &NamedHandlerAvailabilityProbe(handle) }
			state.steps << 'compile:${name}'
			assert source == 'function on${name}(event) {\n${body}\n}'
			if body == 'return (' { return none }
			return state.callback
		}
	}
}

fn test_named_handler_availability_keeps_unavailable_slot_then_compiles_requested_name_once() {
	mut document := Document.create(url_about_blank())
	document.browsing_context = &BrowsingContext{ active_document_: document }
	element := document.create_element('audio')!
	target := unsafe { &EventTarget(element) }
	mut probe := &NamedHandlerAvailabilityProbe{}
	document.set_inline_event_handler_compiler(named_handler_availability_compiler(probe))
	target.element_event_handler_attribute_changed('onplay', 'return false;')
	target.element_event_handler_attribute_changed('onpause', 'return false;')
	pause_slot := target.data.event_handler('pause') or { panic('missing pause slot') }
	listener := pause_slot.listener or { panic('missing pause listener') }
	assert target.get_current_value_of_event_handler('pause') == none
	assert pause_slot.value.kind == .string && pause_slot.value.string_data == 'return false;'
	assert voidptr(pause_slot.listener or { panic('lost pause listener') }) == voidptr(listener)
	assert target.get_current_value_of_event_handler('play') != none
	assert probe.steps == ['supports:pause', 'environment', 'available:pause',
		'supports:play', 'environment', 'available:play', 'compile:play']
	probe.pause_ready = true
	assert voidptr(target.get_current_value_of_event_handler('pause') or { panic('pause retry') }) == voidptr(probe.callback)
	assert pause_slot.value.kind == .object && target.event_listener_list().len == 2
	assert voidptr(pause_slot.listener or { panic('changed pause listener') }) == voidptr(listener)
	steps := probe.steps.clone()
	assert target.get_current_value_of_event_handler('pause') != none
	assert probe.steps == steps
}

fn test_named_handler_availability_runs_after_environment_and_before_parse_failure() {
	mut document := Document.create(url_about_blank())
	document.browsing_context = &BrowsingContext{ active_document_: document }
	element := document.create_element('video')!
	target := unsafe { &EventTarget(element) }
	mut probe := &NamedHandlerAvailabilityProbe{ environment_ready: false }
	document.set_inline_event_handler_compiler(named_handler_availability_compiler(probe))
	target.element_event_handler_attribute_changed('onpause', 'return (')
	target.element_event_handler_attribute_changed('onplaying', 'return false;')
	slot := target.data.event_handler('pause') or { panic('missing pause slot') }
	listener := slot.listener or { panic('missing pause listener') }
	assert target.get_current_value_of_event_handler('playing') == none
	assert target.get_current_value_of_event_handler('pause') == none
	assert probe.steps == ['supports:playing', 'supports:pause', 'environment']
	assert slot.value.kind == .string
	probe.environment_ready = true
	assert target.get_current_value_of_event_handler('pause') == none
	assert slot.value.kind == .string
	probe.pause_ready = true
	assert target.get_current_value_of_event_handler('pause') == none
	assert slot.value.kind == .null_
	assert voidptr(slot.listener or { panic('parse removed listener') }) == voidptr(listener)
	assert target.event_listener_list().len == 2
	assert (target.data.event_handler('playing') or { panic('unsupported slot') }).value.kind == .string
	assert probe.steps == ['supports:playing', 'supports:pause', 'environment',
		'supports:pause', 'environment', 'available:pause',
		'supports:pause', 'environment', 'available:pause', 'compile:pause']
}
