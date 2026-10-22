module dom

@[heap]
struct InlineCompilerProbe {
mut:
	calls            int
	accept           bool
	source           string
	callback         &CallbackType = unsafe { nil }
	reports          int
	reported_message string
}

fn test_raw_handler_activation_retains_owner_reporting_before_compiler_is_installed() {
	mut document := Document.create(url_about_blank())
	document.browsing_context = &BrowsingContext{ active_document_: document }
	element := document.create_element('button')!
	target := unsafe { &EventTarget(element) }
	target.element_event_handler_attribute_changed('onclick', 'throw original;')
	mut probe := inline_compiler_probe(mut document)
	probe.accept = true
	probe.callback = &CallbackType{
		handle_event_with_exception: fn (_ &Event, _ ?&EventTarget) !JSValue {
			return error('original raw exception')
		}
	}
	probe_handle := voidptr(probe)
	document.set_event_callback_exception_reporter(fn [probe_handle] (exception IError) {
		mut probe := unsafe { &InlineCompilerProbe(probe_handle) }
		probe.reports++
		probe.reported_message = exception.msg()
	})
	assert target.dispatch_event(Event.create('click', EventInit{}))
	assert probe.reports == 1 && probe.reported_message == 'original raw exception'
}

fn inline_compiler_probe(mut document Document) &InlineCompilerProbe {
	mut probe := &InlineCompilerProbe{
		callback: &CallbackType{
			handle_event: fn (_ &Event, _ ?&EventTarget) JSValue {
				return js_bool(false)
			}
		}
	}
	probe_handle := voidptr(probe)
	document.set_inline_event_handler_compiler(InlineEventHandlerCompiler{
		can_compile: fn (_ &EventTarget) bool { return true }
		compile:     fn [probe_handle] (_ &EventTarget, _ string, _ string, source string) ?&CallbackType {
			mut probe := unsafe { &InlineCompilerProbe(probe_handle) }
			probe.calls++
			probe.source = source
			if !probe.accept { return none }
			return probe.callback
		}
	})
	return probe
}

fn test_raw_handler_scripting_disabled_preserves_handler_listener_and_source_for_later_compile() {
	mut document := Document.create(url_about_blank())
	mut probe := inline_compiler_probe(mut document)
	probe.accept = true
	element := document.create_element('button')!
	target := unsafe { &EventTarget(element) }
	target.element_event_handler_attribute_changed('onclick', 'return false;')
	handler := target.data.event_handler('click') or { panic('handler') }
	listener := handler.listener or { panic('activated listener') }
	assert target.get_current_value_of_event_handler('click') == none
	assert probe.calls == 0 && handler.value.kind == .string
	assert handler.value.string_data == 'return false;'
	assert voidptr(target.data.event_handler('click') or { panic('handler') }) == voidptr(handler)
	assert voidptr(handler.listener or { panic('listener') }) == voidptr(listener)
	document.browsing_context = &BrowsingContext{ active_document_: document }
	compiled := target.get_current_value_of_event_handler('click') or { panic('compiler') }
	assert voidptr(compiled) == voidptr(probe.callback)
	assert probe.calls == 1 && probe.source == 'function onclick(event) {\nreturn false;\n}'
	assert !target.dispatch_event(Event.create('click', EventInit{ cancelable: true }))
	assert probe.calls == 1
}

fn test_raw_handler_syntax_failure_nulls_value_but_retains_activation_and_retries_only_after_replacement() {
	mut document := Document.create(url_about_blank())
	document.browsing_context = &BrowsingContext{ active_document_: document }
	mut probe := inline_compiler_probe(mut document)
	element := document.create_element('button')!
	target := unsafe { &EventTarget(element) }
	target.element_event_handler_attribute_changed('onclick', 'return (')
	handler := target.data.event_handler('click') or { panic('handler') }
	listener := handler.listener or { panic('activated listener') }
	assert target.get_current_value_of_event_handler('click') == none
	assert probe.calls == 1 && handler.value.kind == .null_
	assert voidptr(target.data.event_handler('click') or { panic('handler') }) == voidptr(handler)
	assert voidptr(handler.listener or { panic('listener') }) == voidptr(listener)
	assert target.get_current_value_of_event_handler('click') == none
	assert probe.calls == 1 && target.event_listener_list().len == 1
	probe.accept = true
	target.element_event_handler_attribute_changed('onclick', 'return false;')
	assert target.get_current_value_of_event_handler('click') != none
	assert probe.calls == 2
	assert voidptr(target.data.event_handler('click') or { panic('handler') }) == voidptr(handler)
	assert voidptr(handler.listener or { panic('listener') }) == voidptr(listener)
}

fn test_raw_handler_csp_attribute_check_precedes_value_replacement_and_compiler() {
	mut document := Document.create(url_about_blank())
	document.browsing_context = &BrowsingContext{ active_document_: document }
	mut probe := inline_compiler_probe(mut document)
	probe.accept = true
	element := document.create_element('button')!
	target := unsafe { &EventTarget(element) }
	target.element_event_handler_attribute_changed('onclick', 'return false;')
	handler := target.data.event_handler('click') or { panic('handler') }
	document.set_csp_hook(DocumentCSPHook{
		inline_check: fn (_ voidptr, _ &Element, type_ string, source string) bool {
			assert type_ == 'script-attribute' && source == 'blocked body'
			return true
		}
	})
	target.element_event_handler_attribute_changed('onclick', 'blocked body')
	assert probe.calls == 0 && handler.value.string_data == 'return false;'
	assert target.get_current_value_of_event_handler('click') != none
	assert probe.calls == 1 && probe.source.contains('return false;')
}

fn test_raw_handler_unavailable_owner_compiler_keeps_raw_value_without_callable() {
	mut document := Document.create(url_about_blank())
	document.browsing_context = &BrowsingContext{ active_document_: document }
	element := document.create_element('button')!
	target := unsafe { &EventTarget(element) }
	target.element_event_handler_attribute_changed('onclick', 'return false;')
	handler := target.data.event_handler('click') or { panic('handler') }
	assert target.get_current_value_of_event_handler('click') == none
	assert handler.value.kind == .string
	document.set_inline_event_handler_compiler(InlineEventHandlerCompiler{
		can_compile: fn (_ &EventTarget) bool { return false }
		compile:     fn (_ &EventTarget, _ string, _ string, _ string) ?&CallbackType {
			panic('unavailable compiler must not run')
		}
	})
	assert target.get_current_value_of_event_handler('click') == none
	assert handler.value.kind == .string
}
