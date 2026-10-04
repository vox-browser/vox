module browserjs

import dom
import html
import json2
import page

fn public_window_handler_fixture() !(&Runtime, &page.Page, &dom.EventTarget, &html.EnvironmentSettingsObject) {
	owner := page.Page.create(1)!
	url := dom.URL{'https://window-handlers.example/'}
	document := html.create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) })!
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut runtime := Runtime.create()
	runtime.bind_scripting_environment(settings)!
	runtime.evaluate_host('globalThis.window=globalThis')!
	runtime.install_window_event_handler_binding()!
	document_wrapper := runtime.javascript_event_target(unsafe { &dom.EventTarget(document) }, none)!
	runtime.define_value_host_function('__actualWindowDocument', fn [document_wrapper] (_ voidptr, _ []voidptr) !voidptr {
		return document_wrapper
	})!
	runtime.evaluate_host('globalThis.actualWindowDocument=__actualWindowDocument()')!
	return runtime, owner, settings.global_object(), settings
}

fn test_public_window_handler_accessors_bind_the_actual_global_and_source_enumerations() {
	$if !darwin {
		return
	}
	mut runtime, _, target, _ := public_window_handler_fixture()!
	defer { runtime.close() }
	global := runtime.evaluate_host_value('globalThis')!
	assert runtime.native_event_target(global)! == target
	assert runtime.javascript_event_target(target, none)! == global
	for name in window_event_handler_names() {
		assert runtime.evaluate_host('(()=>{const d=Object.getOwnPropertyDescriptor(window,${json2.encode(name.attribute)});return d.enumerable&&d.configurable&&d.get.length===0&&d.set.length===1&&d.get.name===${json2.encode('get ' + name.attribute)}&&d.set.name===${json2.encode('set ' + name.attribute)}&&window[${json2.encode(name.attribute)}]===null})()')! == 'true'
	}
	assert window_event_handler_names().len == 118
	getter := runtime.evaluate_host_value('Object.getOwnPropertyDescriptor(window,"onload").get')!
	runtime.install_window_event_handler_binding()!
	assert runtime.evaluate_host_value('Object.getOwnPropertyDescriptor(window,"onload").get')! == getter
	assert runtime.evaluate_host('(()=>{let threw=false;try{Object.getOwnPropertyDescriptor(window,"onload").get.call({})}catch(e){threw=e instanceof TypeError}return threw})()')! == 'true'
}

fn test_public_window_handler_setter_preserves_callback_identity_and_native_dispatch_receiver() {
	$if !darwin {
		return
	}
	mut runtime, _, target, _ := public_window_handler_fixture()!
	defer { runtime.close() }
	runtime.evaluate_host('globalThis.windowCalls=[];globalThis.loadHandler=function(event){windowCalls.push(this===window&&event.target===actualWindowDocument&&event.currentTarget===window&&event.type==="load");return false};window.onload=loadHandler;')!
	function := runtime.evaluate_host_value('loadHandler')!
	assert runtime.javascript_event_handler(target, 'load')! == function
	assert runtime.evaluate_host_value('window.onload')! == function
	assert !target.dispatch_event(dom.Event.create('load', dom.EventInit{ cancelable: true }))
	assert runtime.evaluate_host('windowCalls.length===1&&windowCalls[0]')! == 'true'
	assert target.event_listener_list().len == 1
	runtime.evaluate_host('window.onload=42;')!
	assert runtime.evaluate_host('window.onload===null')! == 'true'
	assert target.event_listener_list().len == 0
	runtime.evaluate_host('window.onload=loadHandler;')!
	assert runtime.evaluate_host('(()=>{let threw=false;try{window.onload={}}catch(e){threw=e instanceof TypeError}return threw&&window.onload===loadHandler})()')! == 'true'
}

fn test_public_window_raw_getter_compiles_lazily_in_actual_global_and_preserves_source_gate() {
	$if !darwin {
		return
	}
	mut runtime, mut owner, target, _ := public_window_handler_fixture()!
	defer { runtime.close() }
	runtime.evaluate_host('globalThis.rawEntries=[];')!
	target.element_event_handler_attribute_changed('load', 'rawEntries.push(this===window&&onload===window.onload&&event.target===actualWindowDocument);return false;')
	owner.set_is_scripting_enabled(false)
	assert runtime.evaluate_host('window.onload===null')! == 'true'
	assert target.data.event_handler_map['load'].value.kind == .string
	owner.set_is_scripting_enabled(true)
	assert runtime.evaluate_host('typeof window.onload==="function"&&window.onload.name==="onload"&&window.onload.length===1&&window.onload===window.onload')! == 'true'
	assert !target.dispatch_event(dom.Event.create('load', dom.EventInit{ cancelable: true }))
	assert runtime.evaluate_host('rawEntries.length===1&&rawEntries[0]')! == 'true'
	target.element_event_handler_attribute_changed('load', 'let broken;let broken;')
	assert runtime.evaluate_host('window.onload===null')! == 'true'
	assert target.data.event_handler_map['load'].value.kind == .null_
	assert target.event_listener_list().len == 1
}

fn test_public_window_error_and_beforeunload_handlers_use_source_arguments_and_return_rules() {
	$if !darwin {
		return
	}
	mut runtime, _, target, _ := public_window_handler_fixture()!
	defer { runtime.close() }
	runtime.evaluate_host('globalThis.errorArguments=null;window.onerror=function(){errorArguments=Array.from(arguments);return true};window.onbeforeunload=function(event){globalThis.unloadThis=this===window&&event.target===actualWindowDocument;return "leave message"};')!
	error_event := dom.ErrorEvent.construct_impl('error', dom.ErrorEventInit{ EventInit: dom.EventInit{ cancelable: true }, message: 'original message', filename: 'origin.js', lineno: 12, colno: 34, error: dom.js_number(42) })!
	assert !target.dispatch_event(unsafe { &dom.Event(error_event) })
	assert runtime.evaluate_host('errorArguments.length===5&&errorArguments[0]==="original message"&&errorArguments[1]==="origin.js"&&errorArguments[2]===12&&errorArguments[3]===34&&errorArguments[4]===42')! == 'true'
	unload := dom.BeforeUnloadEvent.create('beforeunload', dom.EventInit{ cancelable: true })
	assert !target.dispatch_event(unsafe { &dom.Event(unload) })
	assert unload.return_value() == 'leave message'
	assert runtime.evaluate_host('unloadThis')! == 'true'
}

fn test_public_window_vendor_event_attribute_preserves_source_event_name_case() {
	$if !darwin {
		return
	}
	mut runtime, _, target, _ := public_window_handler_fixture()!
	defer { runtime.close() }
	runtime.evaluate_host('globalThis.vendorType="";window.onwebkitanimationend=function(event){vendorType=event.type}')!
	target.dispatch_event(dom.Event.create('webkitAnimationEnd', dom.EventInit{}))
	assert runtime.evaluate_host('vendorType')! == 'webkitAnimationEnd'
	assert target.data.event_handler_map['webkitAnimationEnd'].value.kind == .object
}

fn test_public_window_handler_callback_honors_actual_page_and_reports_original_exception() {
	$if !darwin {
		return
	}
	mut runtime, mut owner, target, settings := public_window_handler_fixture()!
	defer { runtime.close() }
	runtime.evaluate_host('globalThis.windowGateCount=0;globalThis.windowMarker={};window.onload=function(){windowGateCount++;throw windowMarker}')!
	owner.set_is_scripting_enabled(false)
	target.dispatch_event(dom.Event.create('load', dom.EventInit{}))
	assert runtime.evaluate_host('windowGateCount')! == '0'
	assert settings.realm().reported_exceptions.len == 0
	owner.set_is_scripting_enabled(true)
	target.dispatch_event(dom.Event.create('load', dom.EventInit{}))
	assert runtime.evaluate_host('windowGateCount')! == '1'
	assert settings.realm().reported_exceptions.len == 1
	assert runtime.actual_webidl_value(settings.realm().reported_exceptions[0].value.as_webidl_value()!)! == runtime.evaluate_host_value('windowMarker')!
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
}

fn test_public_window_handler_registration_uses_engine_global_when_author_global_this_is_replaced() {
	$if !darwin {
		return
	}
	owner := page.Page.create(1)!
	url := dom.URL{'https://window-handlers.example/'}
	document := html.create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) })!
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	runtime.bind_scripting_environment(settings)!
	// The owning realm's Event/EventTarget interfaces already exist before any
	// author assignment. Test the Window registration's engine-global lookup.
	runtime.install_event_target_binding()!
	runtime.evaluate_host('this.window=this;this.replacedGlobal={};this.globalThis=replacedGlobal;')!
	runtime.install_window_event_handler_binding()!
	assert runtime.native_event_target(runtime.evaluate_host_value('window')!)! == settings.global_object()
	assert runtime.evaluate_host('window.onload===null&&!Object.prototype.hasOwnProperty.call(replacedGlobal,"onload")')! == 'true'
}
