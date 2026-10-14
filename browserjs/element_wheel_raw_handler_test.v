module browserjs

import dom

fn element_raw_wheel_fixture() !&ElementWheelHandlerFixture {
	fixture := element_wheel_handler_fixture(none)!
	mut runtime := fixture.runtime
	runtime.evaluate_host('globalThis.document={scopeKey:"document"};globalThis.scopeKey="global";globalThis.rawRuns=0;0')!
	runtime.install_document_window_event_binding(fixture.document,
		runtime.evaluate_host_value('document')!)!
	return fixture
}

fn test_raw_element_wheel_lazily_caches_owner_scopes_without_helper_or_self_bindings() {
	$if !darwin { return }
	fixture := element_raw_wheel_fixture()!
	mut runtime := fixture.runtime
	defer { runtime.close() }
	mut target := fixture.document.get_element_by_id('handlerDiv')?
	native_target := unsafe { &dom.EventTarget(target) }
	runtime.evaluate_host('handlerDiv.scopeKey="element";handlerDiv.event={sentinel:true};globalThis.rawChecks=[];0')!
	body := r'rawRuns++;rawChecks.push(scopeKey==="element"&&arguments.length===1&&event===arguments[0]&&this===handlerDiv&&window.event===event&&__elementWheelHandlerContext());delete this.scopeKey;rawChecks.push(scopeKey==="document");delete document.scopeKey;rawChecks.push(scopeKey==="global");this.onwheel=null;rawChecks.push(onwheel===null);return false;'
	target.set_attribute_value('onwheel', body)
	slot := native_target.data.event_handler_map['wheel'] or { panic('raw slot') }
	listener := slot.listener or { panic('raw listener') }
	checkpoints := fixture.settings.realm().microtask_checkpoint_count
	callback := native_target.get_current_value_of_event_handler('wheel') or { panic('compiled callback') }
	assert callback.compiled_source_text_ == 'function onwheel(event) {\n${body}\n}'
	assert fixture.settings.realm().microtask_checkpoint_count == checkpoints
	actual := runtime.javascript_event_handler(native_target, 'wheel')!
	runtime.define_value_host_function('__rawElementCallback', fn [actual] (_ voidptr, _ []voidptr) !voidptr { return actual })!
	assert runtime.evaluate_host('__rawElementCallback()===handlerDiv.onwheel&&handlerDiv.onwheel.name==="onwheel"&&handlerDiv.onwheel.length===1&&Object.hasOwn(handlerDiv.onwheel,"prototype")&&Function.prototype.toString.call(handlerDiv.onwheel).includes("rawRuns++")&&rawRuns===0')! == 'true'
	assert voidptr(native_target.get_current_value_of_event_handler('wheel') or { panic('cache') }) == voidptr(callback)
	assert voidptr(slot.listener or { panic('listener identity') }) == voidptr(listener)
	event := element_wheel_handler_event(fixture)
	assert !native_target.dispatch_event(event)
	assert runtime.evaluate_host('rawRuns===1&&rawChecks.length===4&&rawChecks.every(Boolean)&&handlerDiv.onwheel===null&&window.event===undefined')! == 'true'
	assert event.default_prevented() && event.is_trusted()
	assert target.get_attribute_value('onwheel') == body
	element_wheel_handler_assert_contexts(fixture)
}

fn test_raw_element_wheel_function_body_gate_csp_and_unsupported_handlers_keep_native_slots() {
	$if !darwin { return }
	fixture := element_raw_wheel_fixture()!
	mut runtime := fixture.runtime
	defer { runtime.close() }
	mut target := fixture.document.get_element_by_id('handlerDiv')?
	native_target := unsafe { &dom.EventTarget(target) }
	for body in ['return (', '"use strict";let event;',
		'}},globalThis.rawRuns++,{onwheel:function(event){'] {
		target.set_attribute_value('onwheel', body)
		slot := native_target.data.event_handler_map['wheel'] or { panic('invalid slot') }
		listener := slot.listener or { panic('invalid listener') }
		assert runtime.evaluate_host('handlerDiv.onwheel===null&&handlerDiv.onwheel===null&&rawRuns===0')! == 'true'
		assert slot.value.kind == .null_
		assert voidptr(slot.listener or { panic('retained listener') }) == voidptr(listener)
		assert target.get_attribute_value('onwheel') == body
	}
	target.set_attribute_value('onclick', 'globalThis.rawRuns++')
	assert native_target.get_current_value_of_event_handler('click') == none
	assert (native_target.data.event_handler_map['click'] or { panic('unsupported click') }).value.kind == .string
	target.set_attribute_value('onwheel', 'return false;')
	callback := native_target.get_current_value_of_event_handler('wheel') or { panic('valid callback') }
	mut document := fixture.document
	document.set_csp_hook(dom.DocumentCSPHook{
		inline_check: fn (_ voidptr, _ &dom.Element, type_ string, _ string) bool { return type_ == 'script-attribute' }
	})
	target.set_attribute_value('onwheel', 'return (')
	assert voidptr(native_target.get_current_value_of_event_handler('wheel') or { panic('CSP preserved') }) == voidptr(callback)
	assert target.get_attribute_value('onwheel') == 'return ('
	document.set_csp_hook(dom.DocumentCSPHook{
		inline_check: fn (_ voidptr, _ &dom.Element, _ string, _ string) bool { return false }
	})
	// Unknown control models and namespace/media scopes stay raw.
	for tag in ['img', 'object', 'fieldset', 'output'] {
		element := document.create_element(tag)!
		owner := unsafe { &dom.EventTarget(element) }
		owner.element_event_handler_attribute_changed('onwheel', 'return false;')
		assert owner.get_current_value_of_event_handler('wheel') == none
		assert (owner.data.event_handler_map['wheel'] or { panic('unsupported owner') }).value.kind == .string
	}
	assert fixture.settings.realm().reported_exceptions.len == 0
	element_wheel_handler_assert_contexts(fixture)
}

fn test_raw_element_wheel_strict_callbacks_preserve_original_exceptions_page_gates_and_window_compiler() {
	$if !darwin { return }
	fixture := element_raw_wheel_fixture()!
	mut runtime := fixture.runtime
	defer { runtime.close() }
	mut target := fixture.document.get_element_by_id('handlerDiv')?
	native_target := unsafe { &dom.EventTarget(target) }
	runtime.evaluate_host('globalThis.rawThrown={owner:true};globalThis.rawStrict=false;0')!
	target.set_attribute_value('onwheel', r'"use strict";rawRuns++;rawStrict=this===handlerDiv&&event===arguments[0];throw rawThrown;')
	callback := native_target.get_current_value_of_event_handler('wheel') or { panic('strict callback') }
	actual := runtime.javascript_event_handler(native_target, 'wheel')!
	mut page_owner := fixture.owner
	page_owner.set_is_scripting_enabled(false)
	assert native_target.dispatch_event(element_wheel_handler_event(fixture))
	assert runtime.evaluate_host('rawRuns===0')! == 'true'
	page_owner.set_is_scripting_enabled(true)
	assert native_target.dispatch_event(element_wheel_handler_event(fixture))
	assert runtime.evaluate_host('rawRuns===1&&rawStrict&&window.event===undefined')! == 'true'
	assert fixture.settings.realm().reported_exceptions.len == 1
	reasons := runtime.take_reported_javascript_exception_values()
	assert reasons.len == 1 && reasons[0] == runtime.evaluate_host_value('rawThrown')!
	assert voidptr(native_target.get_current_value_of_event_handler('wheel') or { panic('cached throwing callback') }) == voidptr(callback)
	assert runtime.javascript_event_handler(native_target, 'wheel')! == actual
	window_target := fixture.settings.global_object()
	window_target.element_event_handler_attribute_changed('onload', 'globalThis.rawWindowRuns=1;return false;')
	window_callback := window_target.get_current_value_of_event_handler('load') or { panic('preserved Window compiler') }
	assert window_callback.compiled_source_text_.starts_with('function onload(event)')
	assert !window_target.dispatch_event(dom.Event.create('load', dom.EventInit{cancelable:true}))
	assert runtime.evaluate_host('rawWindowRuns===1')! == 'true'
	target.set_attribute_value('onwheel', 'return false;')
	runtime.close()
	assert native_target.get_current_value_of_event_handler('wheel') == none
	assert (native_target.data.event_handler_map['wheel'] or { panic('closed raw') }).value.kind == .string
	element_wheel_handler_assert_contexts(fixture)
}
