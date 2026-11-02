module browserjs

import dom
import html
import json2
import page

@[heap]
struct UnsupportedRawHandlerEnumerationProbe {
mut:
	calls int
}

fn test_unsupported_element_raw_handlers_do_not_enumerate_document_providers() {
	$if !darwin { return }
	fixture := element_raw_wheel_fixture()!
	mut runtime := fixture.runtime
	defer { runtime.close() }
	probe := &UnsupportedRawHandlerEnumerationProbe{}
	runtime.add_canvas_element_provider(fn [probe] () map[string]&dom.Element {
		mut counter := unsafe { &UnsupportedRawHandlerEnumerationProbe(probe) }
		counter.calls++
		return map[string]&dom.Element{}
	})
	mut target := fixture.document.get_element_by_id('handlerDiv')?
	native_target := unsafe { &dom.EventTarget(target) }
	for name in ['click', 'mousedown', 'mouseup', 'pointerdown', 'pointerup', 'focus', 'blur', 'keydown'] {
		target.set_attribute_value('on' + name, 'globalThis.rawRuns++')
		assert native_target.get_current_value_of_event_handler(name) == none
		assert native_target.data.event_handler(name)?.value.kind == .string
	}
	assert probe.calls == 0
	assert runtime.evaluate_host('rawRuns')! == '0'
}

@[heap]
struct ElementRawWheelFixture {
	runtime  &Runtime
	host     &ElementWheelHost
	owner    &page.Page
	document &dom.Document
	settings &html.EnvironmentSettingsObject
}

fn element_raw_wheel_fixture() !&ElementRawWheelFixture {
	owner := page.Page.create(1)!
	url := dom.URL{ value: 'https://native-element-raw-wheel.example.test/' }
	mut document := html.create_navigation_document_for_page(url, url.origin(), none,
		unsafe { &dom.Page(owner) })!
	document.set_document_type(.html)
	html.parse_html_from_a_string(document, '<div id="handlerDiv"></div>')
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut runtime := Runtime.create()
	mut host := ElementWheelHost.create(document)!
	host.install(mut runtime)!
	runtime.evaluate_host('globalThis.window=globalThis;0')!
	runtime.install_window_event_handler_binding()!
	runtime.install_window_current_event_binding()!
	runtime.evaluate_host(r'
globalThis.elementRawWheelSpecs=Object.create(null);globalThis.elementRawWheelFacades=Object.create(null);
globalThis.elementRawWheelResolve=function(key){
 if(elementRawWheelFacades[key])return elementRawWheelFacades[key];
 const spec=elementRawWheelSpecs[key];if(!spec)return null;
 const wrapper={addEventListener(){},removeEventListener(){}};
 __ladybirdElementWheelBind(wrapper,key,spec.tag,spec.namespace);
 elementRawWheelFacades[key]=wrapper;return wrapper;
};
__ladybirdElementWheelSetResolver(elementRawWheelResolve);0')!
	for key, element in host.elements_for_binding() {
		spec := json2.encode({
			'tag':       element.local_name()
			'namespace': element.namespace_uri() or { '' }
		})
		runtime.evaluate_host('elementRawWheelSpecs[${json2.encode(key)}]=${spec};0')!
		id := element.get_attribute_value('id')
		if id != '' {
			runtime.evaluate_host('globalThis[${json2.encode(id)}]=elementRawWheelResolve(${json2.encode(key)});0')!
		}
	}
	handle := voidptr(runtime)
	runtime.define_value_host_function('__elementRawWheelContext', fn [handle, settings] (_ voidptr, _ []voidptr) !voidptr {
		runtime := unsafe { &Runtime(handle) }
		return C.vox_jsc_JSValueMakeBoolean(runtime.context, settings.realm().script_execution_depth > 0
			&& settings.realm().callback_execution_depth > 0
			&& runtime.libjs_vm().has_running_execution_context()
			&& voidptr(html.current_principal_settings_object()) == voidptr(settings)
			&& voidptr(html.incumbent_settings_object()) == voidptr(settings))
	})!
	runtime.evaluate_host('globalThis.document={scopeKey:"document"};globalThis.scopeKey="global";globalThis.rawRuns=0;0')!
	runtime.install_document_window_event_binding(document,
		runtime.evaluate_host_value('document')!)!
	return &ElementRawWheelFixture{ runtime: runtime, host: host, owner: owner,
		document: document, settings: settings }
}

fn element_raw_wheel_event(fixture &ElementRawWheelFixture) &dom.Event {
	wheel := dom.WheelEvent.create_from_platform_event(voidptr(fixture.document.get_window() or {
		panic('missing raw wheel owner Window')
	}), 'wheel', dom.CSSPixelPoint_{ x_: 30.5, y_: -40.75 },
		dom.CSSPixelPoint_{ x_: 13.75, y_: 24.625 }, dom.CSSPixelPoint_{ x_: 3.75, y_: 4.625 },
		dom.CSSPixelPoint_{ x_: 1.25, y_: 2.5 }, 2.5, -3.5, 2, 5,
		dom.modifier_ctrl | dom.modifier_alt)
	return unsafe { &dom.Event(wheel) }
}

fn element_raw_wheel_assert_contexts(fixture &ElementRawWheelFixture) {
	assert fixture.settings.realm().script_execution_depth == 0
	assert fixture.settings.realm().callback_execution_depth == 0
	assert fixture.runtime.libjs_vm().execution_context_stack().len == 0
	assert fixture.runtime.libjs_vm().interpreter_stack().depth() == 0
}

fn test_raw_element_wheel_lazily_caches_owner_scopes_without_helper_or_self_bindings() {
	$if !darwin { return }
	fixture := element_raw_wheel_fixture()!
	mut runtime := fixture.runtime
	defer { runtime.close() }
	mut target := fixture.document.get_element_by_id('handlerDiv')?
	native_target := unsafe { &dom.EventTarget(target) }
	runtime.evaluate_host('handlerDiv.scopeKey="element";handlerDiv.event={sentinel:true};globalThis.rawChecks=[];0')!
	body := r'rawRuns++;rawChecks.push(scopeKey==="element"&&arguments.length===1&&event===arguments[0]&&this===handlerDiv&&window.event===event&&__elementRawWheelContext());delete this.scopeKey;rawChecks.push(scopeKey==="document");delete document.scopeKey;rawChecks.push(scopeKey==="global");this.onwheel=null;rawChecks.push(onwheel===null);return false;'
	target.set_attribute_value('onwheel', body)
	slot := native_target.data.event_handler('wheel') or { panic('raw slot') }
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
	event := element_raw_wheel_event(fixture)
	assert !native_target.dispatch_event(event)
	assert runtime.evaluate_host('rawRuns===1&&rawChecks.length===4&&rawChecks.every(Boolean)&&handlerDiv.onwheel===null&&window.event===undefined')! == 'true'
	assert event.default_prevented() && event.is_trusted()
	assert target.get_attribute_value('onwheel') == body
	element_raw_wheel_assert_contexts(fixture)
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
		slot := native_target.data.event_handler('wheel') or { panic('invalid slot') }
		listener := slot.listener or { panic('invalid listener') }
		assert runtime.evaluate_host('handlerDiv.onwheel===null&&handlerDiv.onwheel===null&&rawRuns===0')! == 'true'
		assert slot.value.kind == .null_
		assert voidptr(slot.listener or { panic('retained listener') }) == voidptr(listener)
		assert target.get_attribute_value('onwheel') == body
	}
	target.set_attribute_value('onclick', 'globalThis.rawRuns++')
	assert native_target.get_current_value_of_event_handler('click') == none
	assert (native_target.data.event_handler('click') or { panic('unsupported click') }).value.kind == .string
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
		assert (owner.data.event_handler('wheel') or { panic('unsupported owner') }).value.kind == .string
	}
	assert fixture.settings.realm().reported_exceptions.len == 0
	element_raw_wheel_assert_contexts(fixture)
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
	assert native_target.dispatch_event(element_raw_wheel_event(fixture))
	assert runtime.evaluate_host('rawRuns===0')! == 'true'
	page_owner.set_is_scripting_enabled(true)
	assert native_target.dispatch_event(element_raw_wheel_event(fixture))
	assert runtime.evaluate_host('rawRuns===1&&rawStrict&&window.event===undefined')! == 'true'
	assert fixture.settings.realm().reported_exceptions.len == 1
	reported := fixture.settings.realm().reported_exceptions[0].value.as_webidl_value()!
	assert runtime.actual_webidl_value(reported)! == runtime.evaluate_host_value('rawThrown')!
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
	assert (native_target.data.event_handler('wheel') or { panic('closed raw') }).value.kind == .string
	element_raw_wheel_assert_contexts(fixture)
}
