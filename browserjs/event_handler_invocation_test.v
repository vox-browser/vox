module browserjs

import dom
import html

fn native_handler_fixture() (&Runtime, &html.EnvironmentSettingsObject, &dom.EventTarget) {
	document := html.parse_document_with_url('<!doctype html><body>handlers</body>',
		dom.URL{value: 'https://native-handlers.example/'})
	window := html.WindowModel.create_top_level(document, none, 'native-handlers') or { panic(err) }
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut runtime := Runtime.create()
	runtime.bind_scripting_environment(settings) or { panic(err) }
	runtime.install_event_target_binding() or { panic(err) }
	// The Window wrapper is the actual global. Borrow EventTarget methods below
	// while preserving that receiver's native Window identity.
	target := unsafe { &dom.EventTarget(window) }
	wrapper := runtime.javascript_event_target(target, none) or { panic(err) }
	runtime.define_value_host_function('__handlerWindow', fn [wrapper] (_ voidptr, _ []voidptr) !voidptr {
		return wrapper
	}) or { panic(err) }
	return runtime, settings, target
}

fn test_native_window_error_handler_receives_five_original_values_and_strict_boolean_return() {
	$if !darwin {
		return
	}
	mut runtime, settings, target := native_handler_fixture()
	defer { runtime.close() }
	owner := voidptr(&runtime)
	runtime.define_value_host_function('__handlerContext', fn [owner, settings] (_ voidptr, _ []voidptr) !voidptr {
		runtime := unsafe { &Runtime(owner) }
		return C.vox_jsc_JSValueMakeBoolean(runtime.context,
			settings.realm().script_execution_depth > 0 && settings.realm().callback_execution_depth > 0)
	})!
	runtime.evaluate_host(r'
 globalThis.handlerReason={original:true};globalThis.handlerReturn=true;globalThis.handlerArgumentsValid=false;globalThis.ordinaryErrorListenerValid=false;
 globalThis.errorHandler=function(message,source,line,column,error){
   if(arguments.length===1){globalThis.ordinaryHandlerValid=message instanceof Event&&this===__handlerWindow();return false;}
   handlerArgumentsValid=arguments.length===5&&message==="native failure"&&source==="owner.js"&&line===17&&column===23&&error===handlerReason&&this===__handlerWindow()&&__handlerContext();
   return handlerReturn;
 };
 EventTarget.prototype.addEventListener.call(__handlerWindow(),"error",function(event){ordinaryErrorListenerValid=arguments.length===1&&event===globalThis.expectedErrorEvent&&this===__handlerWindow();});
 ')!
	function := runtime.evaluate_host_value('errorHandler')!
	runtime.set_javascript_event_handler(target, 'error', function)!
	assert runtime.javascript_event_handler(target, 'error')! == function
	error_event := dom.ErrorEvent.create('error', dom.ErrorEventInit{
		EventInit: dom.EventInit{ cancelable: true }
		message:   'native failure'
		filename:  'owner.js'
		lineno:    17
		colno:     23
		error:     dom.js_webidl_value(runtime.webidl_value(runtime.evaluate_host_value('handlerReason')!)!)
	})
	event := unsafe { &dom.Event(error_event) }
	wrapper := runtime.javascript_event(event)!
	runtime.define_value_host_function('__errorEvent', fn [wrapper] (_ voidptr, _ []voidptr) !voidptr {
		return wrapper
	})!
	runtime.evaluate_host('globalThis.expectedErrorEvent=__errorEvent()')!
	assert !target.dispatch_event(event)
	assert event.default_prevented()
	assert runtime.evaluate_host('handlerArgumentsValid&&ordinaryErrorListenerValid')! == 'true'
	for expression in ['false', '1', 'new Boolean(true)'] {
		runtime.evaluate_host('handlerReturn=' + expression)!
		retry := dom.ErrorEvent.create('error', dom.ErrorEventInit{ EventInit: dom.EventInit{ cancelable: true } })
		assert target.dispatch_event(unsafe { &dom.Event(retry) })
	}
	ordinary := dom.Event.create('error', dom.EventInit{ cancelable: true })
	assert !target.dispatch_event(ordinary)
	assert runtime.evaluate_host('ordinaryHandlerValid')! == 'true'
	assert settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0
	assert settings.realm().callback_execution_depth == 0
}

fn test_native_error_handler_requires_actual_error_event_window_and_error_type() {
	$if !darwin {
		return
	}
	mut runtime, _, window_target := native_handler_fixture()
	defer { runtime.close() }
	function := runtime.evaluate_host_value('(function(event){globalThis.singleErrorArgument=arguments.length===1&&event instanceof Event;return false})')!
	ordinary_target := dom.EventTarget.new()
	runtime.set_javascript_event_handler(ordinary_target, 'error', function)!
	error := dom.ErrorEvent.create('error', dom.ErrorEventInit{ EventInit: dom.EventInit{ cancelable: true } })
	assert !ordinary_target.dispatch_event(unsafe { &dom.Event(error) })
	assert runtime.evaluate_host('singleErrorArgument')! == 'true'
	runtime.set_javascript_event_handler(window_target, 'load', function)!
	wrong_type := dom.ErrorEvent.create('load', dom.ErrorEventInit{ EventInit: dom.EventInit{ cancelable: true } })
	assert !window_target.dispatch_event(unsafe { &dom.Event(wrong_type) })
	assert runtime.evaluate_host('singleErrorArgument')! == 'true'
}

fn test_native_beforeunload_converts_after_cancel_and_keeps_script_return_value() {
	$if !darwin {
		return
	}
	mut runtime, settings, target := native_handler_fixture()
	defer { runtime.close() }
	function := runtime.evaluate_host_value(r'(function(event){
   globalThis.beforeUnloadOrder=["callback"];globalThis.beforeUnloadWrapperValid=event instanceof BeforeUnloadEvent&&event instanceof Event&&event.returnValue===""&&this===__handlerWindow();
   return {toString(){beforeUnloadOrder.push(event.defaultPrevented?"cancelled":"uncancelled");return "leave "+42}};
 })')!
	runtime.set_javascript_event_handler(target, 'beforeunload', function)!
	event := dom.BeforeUnloadEvent.create('beforeunload', dom.EventInit{ cancelable: true })
	assert !target.dispatch_event(unsafe { &dom.Event(event) })
	assert event.return_value() == 'leave 42'
	assert runtime.evaluate_host('beforeUnloadWrapperValid&&beforeUnloadOrder.join(",")==="callback,cancelled"')! == 'true'
	setter := runtime.evaluate_host_value(r'(function(event){event.returnValue="author preset";return {toString(){throw "must not convert"}}})')!
	runtime.set_javascript_event_handler(target, 'beforeunload', setter)!
	preset := dom.BeforeUnloadEvent.create('beforeunload', dom.EventInit{ cancelable: true })
	assert !target.dispatch_event(unsafe { &dom.Event(preset) })
	assert preset.return_value() == 'author preset'
	assert settings.realm().reported_exceptions.len == 0
	for expression in ['null', 'undefined'] {
		nullish := runtime.evaluate_host_value('(function(){return ' + expression + '})')!
		runtime.set_javascript_event_handler(target, 'beforeunload', nullish)!
		uncancelled := dom.BeforeUnloadEvent.create('beforeunload', dom.EventInit{ cancelable: true })
		assert target.dispatch_event(unsafe { &dom.Event(uncancelled) })
		assert uncancelled.return_value() == ''
	}
	false_result := runtime.evaluate_host_value('(function(){return false})')!
	runtime.set_javascript_event_handler(target, 'beforeunload', false_result)!
	false_event := dom.BeforeUnloadEvent.create('beforeunload', dom.EventInit{ cancelable: true })
	assert !target.dispatch_event(unsafe { &dom.Event(false_event) })
	assert false_event.return_value() == 'false'
	assert target.dispatch_event(dom.Event.create('beforeunload', dom.EventInit{ cancelable: true }))
}

fn test_native_beforeunload_conversion_throw_reports_original_once_and_dispatch_continues() {
	$if !darwin {
		return
	}
	mut runtime, settings, target := native_handler_fixture()
	defer { runtime.close() }
	runtime.evaluate_host(r'
 globalThis.beforeUnloadReason={actual:"reason"};globalThis.beforeUnloadLater=0;
 globalThis.throwingReturn=function(event){
   globalThis.retainedBeforeUnload=event;
   return {toString(){globalThis.cancelledBeforeThrow=event.defaultPrevented;throw beforeUnloadReason}};
 };
 ')!
	runtime.set_javascript_event_handler(target, 'beforeunload', runtime.evaluate_host_value('throwingReturn')!)!
	runtime.evaluate_host('EventTarget.prototype.addEventListener.call(__handlerWindow(),"beforeunload",function(event){beforeUnloadLater++;globalThis.laterSawEmpty=event.returnValue===""&&event.defaultPrevented})')!
	event := dom.BeforeUnloadEvent.create('beforeunload', dom.EventInit{ cancelable: true })
	assert !target.dispatch_event(unsafe { &dom.Event(event) })
	assert event.return_value() == ''
	assert runtime.evaluate_host('cancelledBeforeThrow&&laterSawEmpty&&beforeUnloadLater===1&&retainedBeforeUnload.currentTarget===null')! == 'true'
	assert settings.realm().reported_exceptions.len == 1
	marker := runtime.evaluate_host_value('beforeUnloadReason')!
	assert runtime.actual_webidl_value(settings.realm().reported_exceptions[0].value.as_webidl_value()!)! == marker
	thrower := runtime.evaluate_host_value('(function(){throw beforeUnloadReason})')!
	runtime.set_javascript_event_handler(target, 'beforeunload', thrower)!
	second := dom.BeforeUnloadEvent.create('beforeunload', dom.EventInit{ cancelable: true })
	assert target.dispatch_event(unsafe { &dom.Event(second) })
	assert second.return_value() == ''
	assert settings.realm().reported_exceptions.len == 2
	assert runtime.actual_webidl_value(settings.realm().reported_exceptions[1].value.as_webidl_value()!)! == marker
	assert runtime.evaluate_host('beforeUnloadLater===2')! == 'true'
	assert settings.realm().script_execution_depth == 0
	assert settings.realm().callback_execution_depth == 0
	assert runtime.take_document_state_dirty()
}

fn test_native_beforeunload_return_value_brand_conversion_and_original_setter_exception() {
	$if !darwin {
		return
	}
	mut runtime, _, _ := native_handler_fixture()
	defer { runtime.close() }
	event := dom.BeforeUnloadEvent.create('beforeunload', dom.EventInit{})
	wrapper := runtime.javascript_event(unsafe { &dom.Event(event) })!
	runtime.define_value_host_function('__beforeUnload', fn [wrapper] (_ voidptr, _ []voidptr) !voidptr {
		return wrapper
	})!
	assert runtime.evaluate_host(r'
 const event=__beforeUnload(),descriptor=Object.getOwnPropertyDescriptor(BeforeUnloadEvent.prototype,"returnValue"),marker={};
 event.returnValue=42;let constructorError=false,brandError=false,same=false;
 try{new BeforeUnloadEvent()}catch(e){constructorError=e instanceof TypeError}
 try{descriptor.get.call(new Event("beforeunload"))}catch(e){brandError=e instanceof TypeError}
 try{event.returnValue={toString(){throw marker}}}catch(e){same=e===marker}
 constructorError&&brandError&&same&&event.returnValue==="42"&&!event.defaultPrevented&&descriptor.enumerable&&descriptor.configurable&&Object.getPrototypeOf(BeforeUnloadEvent.prototype)===Event.prototype&&Object.prototype.toString.call(event)==="[object BeforeUnloadEvent]";
 ')! == 'true'
	assert event.return_value() == '42'
}
