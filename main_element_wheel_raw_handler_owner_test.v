module main

import browserjs
import dom
import gg
import html
import page
import time

const element_wheel_raw_handler_owner_markup = '<!doctype html><style>
html,body{margin:0}body{height:1500px}
#eh-scroller{width:240px;height:100px;overflow:auto}
#eh-target{width:180px;height:60px}
#eh-content{height:500px}
#eh-result{position:absolute;top:170px;left:0}
</style><div id="eh-scroller"><div id="eh-target">wheel target</div><div id="eh-content"></div></div><div id="eh-result">waiting</div>'

@[heap]
struct ElementWheelRawHandlerOwnerObservation {
mut:
	events []&dom.Event
	targets []voidptr
	trusted []bool
	inner_before []f64
}

fn element_wheel_raw_handler_owner_fixture(markup string, source string) !(&BrowserApp, &dom.Document, &browserjs.Runtime) {
	mut owner := page.Page.create(1)!
	owner.set_enable_autoscroll(false)
	document := parse_browser_navigation_document_for_page_with_response_time(markup, dom.URL{
		value: 'https://element-wheel-handler-owner.example.test/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	runtime := browserjs.Runtime.create()
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [source], runtime, mut messages)
	assert messages == []
	mut app := &BrowserApp{
		page_model: owner
		document: document
		js_runtime: runtime
		viewport_width: 320
		viewport_height: 240
	}
	app.relayout(320, 240 + app.chrome_height())
	assert document.layout_is_up_to_date() && document.paintable_box() != none
	return app, document, runtime
}

fn element_wheel_raw_handler_owner_probe(mut runtime browserjs.Runtime, document &dom.Document) ! {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	handle := voidptr(&runtime)
	actual_true := runtime.evaluate_host_value('true')!
	runtime.define_value_host_function('__elementWheelRawHandlerOwnerContext', fn [settings, handle, actual_true] (_ voidptr, args []voidptr) !voidptr {
		owner := unsafe { &browserjs.Runtime(handle) }
		assert args.len == 0
		assert settings.realm().script_execution_depth > 0 && settings.realm().callback_execution_depth > 0
		assert owner.libjs_vm().has_running_execution_context()
		assert voidptr(html.current_principal_settings_object()) == voidptr(settings)
		assert voidptr(html.incumbent_settings_object()) == voidptr(settings)
		return actual_true
	})!
}

fn element_wheel_raw_handler_owner_observe(element &dom.Element, scroller &dom.Element, observation &ElementWheelRawHandlerOwnerObservation) {
	handle := voidptr(observation)
	callback := &dom.CallbackType{
		handle_event: fn [handle, scroller] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut saved := unsafe { &ElementWheelRawHandlerOwnerObservation(handle) }
			assert event.interface_ == .wheel_event
			saved.events << event
			saved.targets << voidptr(event.target() or { panic('Native wheel needs its DOM target') })
			saved.trusted << event.is_trusted()
			saved.inner_before << scroller.el_scroll_offset().y()
			return dom.js_undefined()
		}
	}
	unsafe { &dom.EventTarget(element) }.add_event_listener_without_options('wheel', dom.IDLEventListener.create(callback))
}

fn element_wheel_raw_handler_owner_event(mut runtime browserjs.Runtime, event &dom.Event, expression string, trusted bool) ! {
	wrapper := runtime.evaluate_host_value(expression)!
	assert voidptr(runtime.native_event(wrapper)!) == voidptr(event)
	assert runtime.javascript_event(event)! == wrapper
	assert event.is_trusted() == trusted && event.current_target() == none && event.event_phase() == 0
	assert runtime.evaluate_host('${expression}.currentTarget===null&&${expression}.eventPhase===Event.NONE&&window.event===undefined')! == 'true'
}

fn element_wheel_raw_handler_owner_balance(runtime &browserjs.Runtime, document &dom.Document, exceptions int) {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == exceptions
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
	assert runtime.libjs_vm().execution_context_stack().len == 0
	assert runtime.libjs_vm().interpreter_stack().depth() == 0
}

fn test_element_raw_onwheel_parsed_cache_real_gg_cancellation_and_equal_attribute_idl_order() {
	$if !darwin { return }
	body := r'globalThis.erRuns++;erOrder.push("raw");erSaved.push(event);erChecks.push(arguments.length===1&&this===erTarget&&event===arguments[0]&&event.target===erTarget&&event.currentTarget===erTarget&&event instanceof WheelEvent&&event.isTrusted&&event.view===window&&window.event===event&&__elementWheelRawHandlerOwnerContext());document.getElementById("eh-result").textContent="raw wheel painted";this.style.color="rgb(0,128,0)";return false;'
	markup := element_wheel_raw_handler_owner_markup.replace('<div id="eh-target">',
		'<div id="eh-target" onwheel="${body.replace('"', '&quot;')}">')
	mut app, mut document, mut runtime := element_wheel_raw_handler_owner_fixture(markup, r'
globalThis.erTarget=document.getElementById("eh-target");globalThis.erRuns=0;globalThis.erOrder=[];globalThis.erSaved=[];globalThis.erChecks=[];globalThis.erAfterStates=[];
globalThis.erFirst=erTarget.onwheel;globalThis.erSource=erTarget.getAttribute("onwheel");
globalThis.erGetterValid=typeof erFirst==="function"&&erFirst.name==="onwheel"&&erFirst.length===1&&erTarget.onwheel===erFirst&&erRuns===0;
erTarget.addEventListener("wheel",function(event){erOrder.push("after");erAfterStates.push(event.defaultPrevented);erChecks.push(this===erTarget&&event.currentTarget===erTarget)});0
')!
	defer {
		runtime.close()
		document.finalize()
	}
	element_wheel_raw_handler_owner_probe(mut runtime, document)!
	target := document.get_element_by_id('eh-target')?
	scroller := document.get_element_by_id('eh-scroller')?
	native_target := unsafe { &dom.EventTarget(target) }
	slot := native_target.data.event_handler('wheel') or { panic('Parsed raw wheel slot missing') }
	listener := slot.listener or { panic('Parsed raw wheel listener missing') }
	callback := native_target.get_current_value_of_event_handler('wheel') or { panic('Raw wheel callback missing') }
	assert slot.value.kind == .object
	assert callback.compiled_source_text_ == 'function onwheel(event) {\n${body}\n}'
	assert target.get_attribute_value('onwheel') == body
	assert runtime.evaluate_host('erGetterValid&&erRuns===0')! == 'true'
	observation := &ElementWheelRawHandlerOwnerObservation{}
	element_wheel_raw_handler_owner_observe(target, scroller, observation)
	app.handle_event(&gg.Event{
		typ: .mouse_scroll
		mouse_x: 12.5
		mouse_y: 12.25 + app.page_top()
		scroll_y: -1
		window_height: 240 + app.chrome_height()
	})
	assert observation.events.len == 1 && observation.targets[0] == voidptr(target)
	assert scroller.el_scroll_offset().y() == 0 && app.scroll_y == 0
	assert runtime.evaluate_host('erRuns===1&&erOrder.join(",")==="raw,after"&&erAfterStates[0]&&erSaved[0].deltaY===42&&erSaved[0].defaultPrevented&&erChecks.every(Boolean)')! == 'true'
	assert document.get_element_by_id('eh-result')?.text_content()? == 'raw wheel painted'
	assert target.get_attribute_value('style').contains('color')
	assert app.paint_commands.filter(it.kind == 'draw_text' && it.text == 'raw wheel painted').len > 0
	element_wheel_raw_handler_owner_event(mut runtime, observation.events[0], 'erSaved[0]', true)!
	// Repeating identical attribute bytes after an IDL write must replace the
	// callback lazily while preserving this native handler's listener position.
	assert runtime.evaluate_host(r'
globalThis.erIDL=function(event){erOrder.push("idl");erSaved.push(event);return false};
erTarget.onwheel=erIDL;erTarget.setAttribute("onwheel",erSource);
globalThis.erSecond=erTarget.onwheel;
erOrder=[];typeof erSecond==="function"&&erSecond!==erFirst&&erSecond!==erIDL&&erSecond.name==="onwheel"&&erSecond.length===1&&erTarget.onwheel===erSecond&&erRuns===1
')! == 'true'
	assert voidptr(native_target.data.event_handler('wheel') or { panic('Recompiled slot missing') }) == voidptr(slot)
	assert voidptr(slot.listener or { panic('Recompiled listener missing') }) == voidptr(listener)
	second := native_target.get_current_value_of_event_handler('wheel') or { panic('Recompiled callback missing') }
	assert voidptr(second) != voidptr(callback) && second.compiled_source_text_ == callback.compiled_source_text_
	assert app.handle_wheel_at_viewport_point(page.PixelPoint{12.5, 12.25}, page.PixelPoint{},
		0, 0, 0, 0, 2.5, false) == .cancelled
	assert runtime.evaluate_host('erRuns===2&&erOrder.join(",")==="raw,after"&&erAfterStates[1]&&erChecks.every(Boolean)')! == 'true'
	assert scroller.el_scroll_offset().y() == 0 && app.scroll_y == 0
	element_wheel_raw_handler_owner_event(mut runtime, observation.events[1], 'erSaved[1]', true)!
	// Removing an existing attribute deactivates a later IDL assignment. An
	// absent-attribute removal leaves a subsequently installed callback intact.
	assert runtime.evaluate_host('erTarget.onwheel=erIDL;erTarget.removeAttribute("onwheel");erTarget.onwheel===null')! == 'true'
	assert !native_target.data.has_event_handler('wheel')
	assert target.get_attribute('onwheel') == none
	assert runtime.evaluate_host('erTarget.onwheel=erIDL;erTarget.removeAttribute("onwheel");erOrder=[];erTarget.onwheel===erIDL')! == 'true'
	assert app.handle_wheel_at_viewport_point(page.PixelPoint{12.5, 12.25}, page.PixelPoint{},
		0, 0, 0, 0, 3.75, false) == .cancelled
	assert runtime.evaluate_host('erRuns===2&&erOrder.join(",")==="after,idl"&&!erAfterStates[2]&&erSaved[2].defaultPrevented&&erChecks.every(Boolean)')! == 'true'
	assert scroller.el_scroll_offset().y() == 0 && app.scroll_y == 0
	element_wheel_raw_handler_owner_event(mut runtime, observation.events[2], 'erSaved[2]', true)!
	assert app.js_messages == []
	element_wheel_raw_handler_owner_balance(runtime, document, 0)
}

fn test_element_raw_onwheel_function_body_gate_strictness_parameter_and_live_handler_name_lookup() {
	$if !darwin { return }
	mut app, mut document, mut runtime := element_wheel_raw_handler_owner_fixture(element_wheel_raw_handler_owner_markup,
		r'globalThis.erTarget=document.getElementById("eh-target");globalThis.erInjectionRuns=0;globalThis.erStrictRuns=0;globalThis.erChecks=[];globalThis.erSaved=[];erTarget.event={elementSentinel:true};document.event={documentSentinel:true};0')!
	defer {
		runtime.close()
		document.finalize()
	}
	element_wheel_raw_handler_owner_probe(mut runtime, document)!
	mut target := document.get_element_by_id('eh-target')?
	native_target := unsafe { &dom.EventTarget(target) }
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	for body in ['return (', '"use strict";let event;', '"use strict";with({}){};',
		'}},globalThis.erInjectionRuns++,{onwheel:function(event){'] {
		// The last body can escape the generated anonymous function/object text.
		// It is not a FunctionBody and must be rejected before any factory runs.
		target.set_attribute_value('onwheel', body)
		slot := native_target.data.event_handler('wheel') or { panic('Invalid raw slot missing') }
		listener := slot.listener or { panic('Invalid raw listener missing') }
		assert slot.value.kind == .string && slot.value.string_data == body
		assert runtime.evaluate_host('erTarget.onwheel===null&&erTarget.onwheel===null&&erInjectionRuns===0&&erStrictRuns===0')! == 'true'
		assert slot.value.kind == .null_
		assert voidptr(native_target.data.event_handler('wheel') or { panic('Invalid slot removed') }) == voidptr(slot)
		assert voidptr(slot.listener or { panic('Invalid listener removed') }) == voidptr(listener)
		assert settings.realm().reported_exceptions.len == 0
		element_wheel_raw_handler_owner_balance(runtime, document, 0)
	}
	body := r'"use strict";globalThis.erStrictRuns++;erSaved.push(event);erChecks.push(arguments.length===1&&arguments[0]===event&&this===erTarget&&event.target===erTarget&&event.currentTarget===erTarget&&event instanceof WheelEvent&&event.isTrusted&&window.event===event&&__elementWheelRawHandlerOwnerContext());try{void arguments.callee;erChecks.push(false)}catch(error){erChecks.push(error instanceof TypeError)}this.onwheel=null;globalThis.erLiveName=onwheel;return false;'
	target.set_attribute_value('onwheel', body)
	slot := native_target.data.event_handler('wheel') or { panic('Strict raw slot missing') }
	mut owner := app.page_model
	owner.set_is_scripting_enabled(false)
	assert runtime.evaluate_host('erTarget.onwheel===null&&erStrictRuns===0')! == 'true'
	assert slot.value.kind == .string && slot.value.string_data == body
	owner.set_is_scripting_enabled(true)
	assert runtime.evaluate_host('globalThis.erStrict=erTarget.onwheel;typeof erStrict==="function"&&erStrict.name==="onwheel"&&erStrict.length===1&&erTarget.onwheel===erStrict&&erStrictRuns===0')! == 'true'
	callback := native_target.get_current_value_of_event_handler('wheel') or { panic('Strict callback missing') }
	assert callback.compiled_source_text_ == 'function onwheel(event) {\n${body}\n}'
	app.handle_event(&gg.Event{
		typ: .mouse_scroll
		mouse_x: 12.5
		mouse_y: 12.25 + app.page_top()
		scroll_y: -1
		window_height: 240 + app.chrome_height()
	})
	assert runtime.evaluate_host('erStrictRuns===1&&erChecks.every(Boolean)&&erLiveName===null&&erTarget.onwheel===null&&erSaved[0].defaultPrevented&&erInjectionRuns===0')! == 'true'
	assert !native_target.data.has_event_handler('wheel')
	assert target.get_attribute_value('onwheel') == body
	assert document.get_element_by_id('eh-scroller')?.el_scroll_offset().y() == 0 && app.scroll_y == 0
	event := runtime.native_event(runtime.evaluate_host_value('erSaved[0]')!)!
	element_wheel_raw_handler_owner_event(mut runtime, event, 'erSaved[0]', true)!
	assert app.js_messages == []
	element_wheel_raw_handler_owner_balance(runtime, document, 0)
}

fn test_element_raw_onwheel_captures_actual_form_owner_and_live_object_environments() {
	$if !darwin { return }
	body := r'erScopeValues.push(scopeKey);delete this.scopeKey;erScopeValues.push(scopeKey);delete erActualOwner.scopeKey;erScopeValues.push(scopeKey);delete document.scopeKey;erScopeValues.push(scopeKey);erChecks.push(this===erControl&&arguments.length===1&&event===arguments[0]&&event.target===erControl&&event.currentTarget===erControl&&event instanceof WheelEvent&&event.isTrusted&&window.event===event&&document===erDocument&&getElementById("er-owner")===erActualOwner&&__elementWheelRawHandlerOwnerContext());return false;'
	markup := '<!doctype html><style>html,body{margin:0}body{height:1500px}button{display:block;width:180px;height:60px}#er-near{margin:0}#er-plain{width:180px;height:60px}#er-owner{position:absolute;left:200px;top:0}</style><form id="er-near"><button id="er-control" form="er-owner" onwheel="${body.replace('"', '&quot;')}">control</button><div id="er-plain" onwheel="globalThis.erPlainScope=scopeKey;return false;">plain</div></form><form id="er-owner"></form>'
	mut app, mut document, mut runtime := element_wheel_raw_handler_owner_fixture(markup, r'
globalThis.erControl=document.getElementById("er-control");globalThis.erPlain=document.getElementById("er-plain");globalThis.erNear=document.getElementById("er-near");globalThis.erActualOwner=document.getElementById("er-owner");globalThis.erDocument=document;
globalThis.erScopeValues=[];globalThis.erChecks=[];globalThis.scopeKey="global";
document.scopeKey="document";erActualOwner.scopeKey="owner";erNear.scopeKey="nearest";erControl.scopeKey="element";erControl.event={sentinel:true};0
')!
	defer {
		runtime.close()
		document.finalize()
	}
	element_wheel_raw_handler_owner_probe(mut runtime, document)!
	control_element := document.get_element_by_id('er-control')?
	actual_owner := document.get_element_by_id('er-owner')?
	nearest := document.get_element_by_id('er-near')?
	// Reuse the native control model, including its authoritative form= owner.
	// No separate FormAssociatedElement is constructed for compilation.
	model := html.HTMLButtonElementModel.create(unsafe { &dom.HTMLButtonElement(control_element) })
	mut control := model.control
	assert voidptr(control.form() or { panic('Control actual form owner missing') }) == voidptr(actual_owner)
	native_target := unsafe { &dom.EventTarget(control_element) }
	assert runtime.evaluate_host('globalThis.erScoped=erControl.onwheel;typeof erScoped==="function"&&erScoped.name==="onwheel"&&erScoped.length===1&&erControl.onwheel===erScoped&&erScopeValues.length===0')! == 'true'
	callback := native_target.get_current_value_of_event_handler('wheel') or { panic('Scoped callback missing') }
	assert callback.compiled_source_text_ == 'function onwheel(event) {\n${body}\n}'
	// Compilation captures that form object. A later real form-owner transition
	// must not replace the existing function's lexical environment.
	control.set_form(unsafe { &dom.HTMLFormElement(nearest) })
	assert voidptr(control.form() or { panic('Changed form owner missing') }) == voidptr(nearest)
	assert app.handle_wheel_at_viewport_point(page.PixelPoint{12.5, 12.25}, page.PixelPoint{},
		0, 0, 0, 0, 3.25, false) == .cancelled
	assert runtime.evaluate_host('erScopeValues.join(",")==="element,owner,document,global"&&erChecks.every(Boolean)&&erControl.onwheel===erScoped&&erNear.scopeKey==="nearest"')! == 'true'
	assert app.scroll_y == 0
	// A plain div inside a form has no form owner. Its Document environment
	// therefore wins over the nearest ancestor form's identically named field.
	assert runtime.evaluate_host('document.scopeKey="plain document";typeof erPlain.onwheel==="function"&&erPlain.dispatchEvent(new WheelEvent("wheel",{cancelable:true}))===false&&erPlainScope==="plain document"')! == 'true'
	assert app.js_messages == []
	element_wheel_raw_handler_owner_balance(runtime, document, 0)
}
