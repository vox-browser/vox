module browserjs

import dom
import html

fn raw_window_handler_fixture() (&Runtime, &html.EnvironmentSettingsObject, &dom.Document, &dom.EventTarget) {
	document := html.parse_document_with_url('<!doctype html><body>raw handlers</body>', dom.URL{value: 'https://raw-handlers.example/'})
	window := html.WindowModel.create_top_level(document, none, 'raw-handler-owner') or { panic(err) }
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut runtime := Runtime.create()
	runtime.bind_scripting_environment(settings) or { panic(err) }
	runtime.install_event_target_binding() or { panic(err) }
	target := unsafe { &dom.EventTarget(window) }
	wrapper := runtime.javascript_event_target(target, none) or { panic(err) }
	runtime.define_value_host_function('__rawWindow', fn [wrapper] (_ voidptr, _ []voidptr) !voidptr {
		return wrapper
	}) or { panic(err) }
	owner := voidptr(runtime)
	runtime.define_value_host_function('__rawContext', fn [owner, settings] (_ voidptr, _ []voidptr) !voidptr {
		runtime := unsafe { &Runtime(owner) }
		return C.vox_jsc_JSValueMakeBoolean(runtime.context, settings.realm().script_execution_depth > 0
			&& settings.realm().callback_execution_depth > 0)
	}) or { panic(err) }
	return runtime, settings, document, target
}

fn test_raw_window_handler_compiles_lazily_to_actual_global_function_and_same_callback() {
	$if !darwin {
		return
	}
	mut runtime, settings, _, target := raw_window_handler_fixture()
	defer { runtime.close() }
	runtime.evaluate_host('globalThis.rawCount=0;globalThis.onload=123;')!
	body := 'globalThis.rawCount++;globalThis.rawValid=this===__rawWindow()&&event===__rawExpectedEvent()&&__rawContext();globalThis.rawNameBinding=onload;return false;'
	target.element_event_handler_attribute_changed('onload', body)
	checkpoint_count := settings.realm().microtask_checkpoint_count
	assert runtime.libjs_vm().execution_context_stack().len == 0
	callback := target.get_current_value_of_event_handler('load') or { panic('actual raw compilation') }
	assert callback.compiled_source_text_ == 'function onload(event) {\n' + body + '\n}'
	assert runtime.libjs_vm().execution_context_stack().len == 0
	assert settings.realm().microtask_checkpoint_count == checkpoint_count
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert voidptr(target.get_current_value_of_event_handler('load') or { panic('cached callback') }) == voidptr(callback)
	actual := runtime.javascript_event_handler(target, 'load')!
	runtime.define_value_host_function('__rawCallback', fn [actual] (_ voidptr, _ []voidptr) !voidptr {
		return actual
	})!
	assert runtime.evaluate_host('__rawCallback().name==="onload"&&__rawCallback().length===1&&rawCount===0&&Function.prototype.toString.call(__rawCallback()).includes("return false;")')! == 'true'
	event := dom.Event.create('load', dom.EventInit{ cancelable: true })
	wrapper := runtime.javascript_event(event)!
	runtime.define_value_host_function('__rawExpectedEvent', fn [wrapper] (_ voidptr, _ []voidptr) !voidptr {
		return wrapper
	})!
	assert !target.dispatch_event(event)
	assert runtime.evaluate_host('rawCount===1&&rawValid&&rawNameBinding===123')! == 'true'
}

fn test_raw_window_syntax_and_early_errors_null_only_value_without_reporting_or_recompile() {
	$if !darwin {
		return
	}
	mut runtime, settings, _, target := raw_window_handler_fixture()
	defer { runtime.close() }
	for body in ['return (', '"use strict";let event;'] {
		target.element_event_handler_attribute_changed('onload', body)
		handler := target.data.event_handler('load') or { panic('handler') }
		listener := handler.listener or { panic('listener') }
		checkpoint_count := settings.realm().microtask_checkpoint_count
		assert target.get_current_value_of_event_handler('load') == none
		assert handler.value.kind == .null_
		assert voidptr(target.data.event_handler('load') or { panic('handler') }) == voidptr(handler)
		assert voidptr(handler.listener or { panic('listener') }) == voidptr(listener)
		assert C.JSValueIsNull(runtime.context, runtime.javascript_event_handler(target, 'load')!)
		assert settings.realm().reported_exceptions.len == 0
		assert settings.realm().microtask_checkpoint_count == checkpoint_count
		assert runtime.libjs_vm().execution_context_stack().len == 0
		target.element_event_handler_attribute_changed('onload', 'return false;')
		assert target.get_current_value_of_event_handler('load') != none
		assert voidptr(handler.listener or { panic('listener') }) == voidptr(listener)
	}
}

fn test_raw_window_script_gate_and_unsupported_element_preserve_raw_source() {
	$if !darwin {
		return
	}
	mut runtime, settings, document, target := raw_window_handler_fixture()
	defer { runtime.close() }
	target.element_event_handler_attribute_changed('onload', 'return false;')
	handler := target.data.event_handler('load') or { panic('handler') }
	mut realm := unsafe { &html.ScriptingRealm(settings.realm()) }
	realm.scripting_enabled = false
	assert target.get_current_value_of_event_handler('load') == none
	assert handler.value.kind == .string
	realm.scripting_enabled = true
	assert target.get_current_value_of_event_handler('load') != none
	element := document.create_element('button')!
	element_target := unsafe { &dom.EventTarget(element) }
	element_target.element_event_handler_attribute_changed('onclick', 'return false;')
	assert element_target.get_current_value_of_event_handler('click') == none
	assert (element_target.data.event_handler('click') or { panic('element handler') }).value.kind == .string
}

fn test_raw_window_error_handler_uses_source_five_arguments_and_original_reason() {
	$if !darwin {
		return
	}
	mut runtime, _, _, target := raw_window_handler_fixture()
	defer { runtime.close() }
	runtime.evaluate_host('globalThis.rawReason={identity:true};')!
	target.element_event_handler_attribute_changed('onerror', 'globalThis.rawErrorValid=arguments.length===5&&event==="failure"&&source==="owner.js"&&lineno===17&&colno===23&&error===rawReason&&this===__rawWindow()&&__rawContext();return true;')
	callback := target.get_current_value_of_event_handler('error') or { panic('onerror') }
	assert callback.compiled_source_text_.starts_with('function onerror(event, source, lineno, colno, error)')
	event := dom.ErrorEvent.create('error', dom.ErrorEventInit{
		EventInit: dom.EventInit{ cancelable: true }
		message:   'failure'
		filename:  'owner.js'
		lineno:    17
		colno:     23
		error:     dom.js_webidl_value(runtime.webidl_value(runtime.evaluate_host_value('rawReason')!)!)
	})
	assert !target.dispatch_event(unsafe { &dom.Event(event) })
	assert runtime.evaluate_host('rawErrorValid')! == 'true'
}

fn test_raw_body_handler_csp_precedes_window_value_replacement_and_syntax_compilation() {
	$if !darwin {
		return
	}
	mut runtime, _, mut document, target := raw_window_handler_fixture()
	defer { runtime.close() }
	body := document.body() or { panic('body') }
	body_target := unsafe { &dom.EventTarget(body) }
	body_target.element_event_handler_attribute_changed('onload', 'return false;')
	callback := target.get_current_value_of_event_handler('load') or { panic('Window-reflecting handler') }
	assert voidptr(body_target.event_handler_attribute('load') or { panic('body handler') }) == voidptr(callback)
	document.set_csp_hook(dom.DocumentCSPHook{
		inline_check: fn (_ voidptr, element &dom.Element, type_ string, source string) bool {
			assert element.local_name() == 'body' && type_ == 'script-attribute' && source == 'return ('
			return true
		}
	})
	body_target.element_event_handler_attribute_changed('onload', 'return (')
	assert voidptr(target.get_current_value_of_event_handler('load') or { panic('existing callback') }) == voidptr(callback)
	document.set_csp_hook(dom.DocumentCSPHook{
		inline_check: fn (_ voidptr, _ &dom.Element, _ string, _ string) bool { return false }
	})
	body_target.element_event_handler_attribute_changed('onload', 'return (')
	assert target.get_current_value_of_event_handler('load') == none
	assert (target.data.event_handler('load') or { panic('handler') }).value.kind == .null_
}

fn test_raw_window_exceptions_use_original_activation_owner_and_beforeunload_conversion() {
	$if !darwin {
		return
	}
	mut runtime, settings, _, target := raw_window_handler_fixture()
	defer { runtime.close() }
	runtime.evaluate_host('globalThis.rawThrown={identity:true};')!
	target.element_event_handler_attribute_changed('onload', 'throw globalThis.rawThrown;')
	assert target.dispatch_event(dom.Event.create('load', dom.EventInit{}))
	assert settings.realm().reported_exceptions.len == 1
	reported := settings.realm().reported_exceptions[0].value.as_webidl_value()!
	assert runtime.actual_webidl_value(reported)! == runtime.evaluate_host_value('rawThrown')!
	target.element_event_handler_attribute_changed('onbeforeunload', 'return {toString(){throw globalThis.rawThrown}};')
	event := dom.BeforeUnloadEvent.create('beforeunload', dom.EventInit{ cancelable: true })
	assert !target.dispatch_event(unsafe { &dom.Event(event) })
	assert event.return_value() == ''
	assert settings.realm().reported_exceptions.len == 2
	assert runtime.actual_webidl_value(settings.realm().reported_exceptions[1].value.as_webidl_value()!)! == runtime.evaluate_host_value('rawThrown')!
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
}
