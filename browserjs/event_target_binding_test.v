module browserjs

import dom
import html
import highresolutiontime

fn native_event_binding_fixture() (&Runtime, &html.EnvironmentSettingsObject) {
	document :=
		html.parse_document_with_url('<!doctype html><body>events</body>', dom.URL{value: 'https://native-events.example/'})
	mut owner_document := unsafe { &dom.Document(document) }
	owner_document.load_timing_info.navigation_start_time = highresolutiontime.unsafe_shared_current_time()
	_ = html.WindowModel.create_top_level(document, none, 'native-events') or { panic(err) }
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut runtime := Runtime.create()
	runtime.bind_scripting_environment(settings) or { panic(err) }
	runtime.install_event_target_binding() or { panic(err) }
	return runtime, settings
}

fn test_native_event_target_listener_identity_flags_and_same_platform_wrappers() {
	$if !darwin && !linux { return }
	mut runtime, _ := native_event_binding_fixture()
	defer { runtime.close() }
	constructor := runtime.evaluate_host_value('EventTarget')!
	runtime.install_event_target_binding()!
	assert runtime.evaluate_host_value('EventTarget')! == constructor
	assert runtime.evaluate_host(r'
 globalThis.nativeTarget=new EventTarget();globalThis.nativeEvent=new Event("tick",{bubbles:true,cancelable:true,composed:true});
 const values=[];function first(event){values.push(this===nativeTarget&&event===nativeEvent&&event.target===nativeTarget&&event.currentTarget===nativeTarget&&event.eventPhase===Event.AT_TARGET&&event.composedPath()[0]===nativeTarget);}
 function second(event){values.push("second");event.preventDefault();}
 nativeTarget.addEventListener("tick",first);nativeTarget.addEventListener("tick",first);nativeTarget.addEventListener("tick",second,{once:true,passive:true});
 const firstResult=nativeTarget.dispatchEvent(nativeEvent);nativeTarget.removeEventListener("tick",first);nativeTarget.dispatchEvent(nativeEvent);
 let errors=0;for(const f of [()=>EventTarget(),()=>Event(),()=>new Event(),()=>EventTarget.prototype.dispatchEvent.call({},nativeEvent),()=>nativeTarget.dispatchEvent({}),()=>nativeTarget.addEventListener("tick",1)]){try{f()}catch(e){if(e instanceof TypeError)errors++}}
 values.length===2&&values[0]===true&&values[1]==="second"&&firstResult===true&&!nativeEvent.defaultPrevented&&nativeEvent.currentTarget===null&&nativeEvent.eventPhase===0&&nativeEvent.composedPath().length===0&&errors===6&&!nativeEvent.isTrusted&&Object.getOwnPropertyDescriptor(nativeEvent,"isTrusted").configurable===false&&EventTarget.prototype.addEventListener.length===2&&Event.prototype.initEvent.length===1;
 ')! == 'true'
	target := runtime.native_event_target(runtime.evaluate_host_value('nativeTarget')!)!
	event := runtime.native_event(runtime.evaluate_host_value('nativeEvent')!)!
	assert target.event_listener_list().len == 0
	assert runtime.javascript_event_target(target, none)! == runtime.evaluate_host_value('nativeTarget')!
	assert runtime.javascript_event(event)! == runtime.evaluate_host_value('nativeEvent')!
}

fn test_native_event_listener_object_original_throw_and_owner_callback_context() {
	$if !darwin && !linux { return }
	mut runtime, settings := native_event_binding_fixture()
	defer { runtime.close() }
	owner := voidptr(runtime)
	runtime.define_value_host_function('__eventContext', fn [owner, settings] (_ voidptr, _ []voidptr) !voidptr {
		runtime := unsafe { &Runtime(owner) }
		valid := settings.realm().script_execution_depth > 0
			&& settings.realm().callback_execution_depth > 0
		return C.vox_jsc_JSValueMakeBoolean(runtime.context, valid)
	})!
	assert runtime.evaluate_host(r'
 const target=new EventTarget();const marker={};globalThis.eventMarker=marker;const event=new Event("callback");
 const listener={handleEvent(value){globalThis.listenerReceiver=this===listener&&value===event&&__eventContext();}};
 target.addEventListener("callback",listener);target.addEventListener("callback",{get handleEvent(){throw marker}});target.dispatchEvent(event);
 let same=false;try{target.addEventListener("other",listener,{get capture(){throw marker}})}catch(e){same=e===marker}
 globalThis.recursiveState=false;target.addEventListener("callback",function(value){try{target.dispatchEvent(value)}catch(e){recursiveState=e instanceof DOMException&&e.name==="InvalidStateError"}});target.dispatchEvent(event);
 listenerReceiver&&same&&recursiveState;
 ')! == 'true'
	assert settings.realm().reported_exceptions.len == 2
	marker := runtime.evaluate_host_value('eventMarker')!
	for reported in settings.realm().reported_exceptions {
		assert runtime.actual_webidl_value(reported.value.as_webidl_value()!)! == marker
	}
	assert settings.realm().script_execution_depth == 0
	assert settings.realm().callback_execution_depth == 0
	assert runtime.take_document_state_dirty()
}

fn test_native_handler_attribute_false_cancellation_and_closed_runtime_callbacks() {
	$if !darwin && !linux { return }
	mut runtime, _ := native_event_binding_fixture()
	target := dom.EventTarget.new()
	wrapper := runtime.javascript_event_target(target, none)!
	runtime.define_value_host_function('__target', fn [wrapper] (_ voidptr, _ []voidptr) !voidptr {
		return wrapper
	})!
	function :=
		runtime.evaluate_host_value('(function(event){globalThis.handlerThis=this===__target();return false;})')!
	runtime.set_javascript_event_handler(target, 'load', function)!
	assert runtime.javascript_event_handler(target, 'load')! == function
	event := dom.Event.create('load', dom.EventInit{ cancelable: true })
	assert !target.dispatch_event(event)
	assert event.default_prevented()
	assert runtime.evaluate_host('handlerThis')! == 'true'
	runtime.set_javascript_event_handler(target, 'load', C.vox_jsc_JSValueMakeNumber(runtime.context, 1))!
	assert C.JSValueIsNull(runtime.context, runtime.javascript_event_handler(target, 'load')!)
	runtime.set_javascript_event_handler(target, 'load', function)!
	runtime.close()
	assert target.dispatch_event(dom.Event.create('load', dom.EventInit{}))
}

fn test_native_event_options_convert_in_source_order_and_abort_signal_removes_listener() {
	$if !darwin && !linux { return }
	mut runtime, _ := native_event_binding_fixture()
	defer { runtime.close() }
	signal := dom.AbortSignal.new()
	wrapper := runtime.javascript_event_target(unsafe { &dom.EventTarget(signal) }, none)!
	runtime.define_value_host_function('__signal', fn [wrapper] (_ voidptr, _ []voidptr) !voidptr {
		return wrapper
	})!
	assert runtime.evaluate_host(r'
 const order=[];globalThis.abortListenerCount=0;const target=new EventTarget();globalThis.abortListenerTarget=target;
 target.addEventListener("signal",()=>abortListenerCount++,{get signal(){order.push("signal");return __signal()},get passive(){order.push("passive");return false},get once(){order.push("once");return false},get capture(){order.push("capture");return false}});
 order.join(",")==="capture,once,passive,signal";
 ')! == 'true'
	mut mutable_signal := unsafe { &dom.AbortSignal(signal) }
	mutable_signal.signal_abort(dom.js_string('actual reason'))
	assert runtime.evaluate_host('abortListenerTarget.dispatchEvent(new Event("signal"));abortListenerCount===0')! == 'true'
}

fn test_native_event_callback_respects_owning_script_execution_gate_and_time_origin() {
	$if !darwin && !linux { return }
	mut runtime, settings := native_event_binding_fixture()
	defer { runtime.close() }
	assert runtime.evaluate_host('globalThis.gatedCount=0;globalThis.gatedTarget=new EventTarget();gatedTarget.addEventListener("gate",()=>gatedCount++);globalThis.owningEvent=new Event("gate");owningEvent.timeStamp>=0&&owningEvent.timeStamp<10000')! == 'true'
	target := runtime.native_event_target(runtime.evaluate_host_value('gatedTarget')!)!
	mut realm := unsafe { &html.ScriptingRealm(settings.realm()) }
	realm.can_run = false
	target.dispatch_event(dom.Event.create('gate', dom.EventInit{}))
	realm.can_run = true
	assert runtime.evaluate_host('gatedCount===0')! == 'true'
	target.dispatch_event(dom.Event.create('gate', dom.EventInit{}))
	assert runtime.evaluate_host('gatedCount===1')! == 'true'
}
