module browserjs

import dom
import html
import json2
import page

@[heap]
struct ElementWheelHandlerFixture {
	runtime  &Runtime
	host     &ElementWheelHost
	owner    &page.Page
	document &dom.Document
	settings &html.EnvironmentSettingsObject
}

@[heap]
struct ElementWheelHandlerReplayState {
mut:
	calls       int
	pending_raw bool
	target      &dom.Element = unsafe { nil }
}

fn element_wheel_handler_fixture(replay ?ElementWheelReplayHook) !&ElementWheelHandlerFixture {
	owner := page.Page.create(1)!
	url := dom.URL{ value: 'https://native-element-wheel-handler.example.test/' }
	mut document := html.create_navigation_document_for_page(url, url.origin(), none,
		unsafe { &dom.Page(owner) })!
	document.set_document_type(.html)
	html.parse_html_from_a_string(document,
		'<div id="handlerDiv"></div><button id="handlerButton"></button><svg id="handlerSVG"></svg><math id="handlerMath"></math><div id="handlerRaw" onwheel="globalThis.elementWheelHandlerRawCalls++"></div>')
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut runtime := Runtime.create()
	mut host := ElementWheelHost.create_with_replay(document, replay)!
	host.install(mut runtime)!
	runtime.evaluate_host('globalThis.window=globalThis;0')!
	runtime.install_window_event_handler_binding()!
	runtime.install_window_current_event_binding()!
	runtime.evaluate_host(r'
globalThis.elementWheelHandlerSpecs=Object.create(null);globalThis.elementWheelHandlerFacades=Object.create(null);
globalThis.elementWheelHandlerRawCalls=0;
globalThis.elementWheelHandlerFacade=function(){return {addEventListener(){},removeEventListener(){}}};
globalThis.elementWheelHandlerResolve=function(key){
 if(elementWheelHandlerFacades[key])return elementWheelHandlerFacades[key];
 const spec=elementWheelHandlerSpecs[key];if(!spec)return null;
 const wrapper=elementWheelHandlerFacade();__ladybirdElementWheelBind(wrapper,key,spec.tag,spec.namespace);
 elementWheelHandlerFacades[key]=wrapper;return wrapper;
};
__ladybirdElementWheelSetResolver(elementWheelHandlerResolve);0')!
	for key, element in host.elements_for_binding() {
		spec := json2.encode({
			'tag':       element.local_name()
			'namespace': element.namespace_uri() or { '' }
		})
		runtime.evaluate_host('elementWheelHandlerSpecs[${json2.encode(key)}]=${spec};0')!
		id := element.get_attribute_value('id')
		if id != '' {
			runtime.evaluate_host('globalThis[${json2.encode(id)}]=elementWheelHandlerResolve(${json2.encode(key)});0')!
		} else if element.local_name() == 'body' {
			runtime.evaluate_host('globalThis.handlerBody=elementWheelHandlerResolve(${json2.encode(key)});0')!
		}
	}
	handle := voidptr(runtime)
	runtime.define_value_host_function('__elementWheelHandlerContext', fn [handle, settings] (_ voidptr, _ []voidptr) !voidptr {
		runtime := unsafe { &Runtime(handle) }
		return C.vox_jsc_JSValueMakeBoolean(runtime.context, settings.realm().script_execution_depth > 0
			&& settings.realm().callback_execution_depth > 0
			&& runtime.libjs_vm().has_running_execution_context()
			&& voidptr(html.current_principal_settings_object()) == voidptr(settings)
			&& voidptr(html.incumbent_settings_object()) == voidptr(settings))
	})!
	return &ElementWheelHandlerFixture{ runtime: runtime, host: host, owner: owner,
		document: document, settings: settings }
}

fn element_wheel_handler_guard(runtime &Runtime) !bool {
	return runtime.evaluate_host('!!Object.getOwnPropertyDescriptor(handlerDiv,"onwheel")')! == 'true'
}

fn element_wheel_handler_target(fixture &ElementWheelHandlerFixture, id string) &dom.EventTarget {
	element := fixture.document.get_element_by_id(id) or { panic('missing wheel-handler element') }
	return unsafe { &dom.EventTarget(element) }
}

fn element_wheel_handler_event(fixture &ElementWheelHandlerFixture) &dom.Event {
	wheel := dom.WheelEvent.create_from_platform_event(voidptr(fixture.document.get_window() or {
		panic('missing handler Window')
	}), 'wheel', dom.CSSPixelPoint_{ x_: 30.5, y_: -40.75 },
		dom.CSSPixelPoint_{ x_: 13.75, y_: 24.625 }, dom.CSSPixelPoint_{ x_: 3.75, y_: 4.625 },
		dom.CSSPixelPoint_{ x_: 1.25, y_: 2.5 }, 2.5, -3.5, 2, 5,
		dom.modifier_ctrl | dom.modifier_alt)
	return unsafe { &dom.Event(wheel) }
}

fn element_wheel_handler_assert_contexts(fixture &ElementWheelHandlerFixture) {
	assert fixture.settings.realm().script_execution_depth == 0
	assert fixture.settings.realm().callback_execution_depth == 0
	assert fixture.runtime.libjs_vm().execution_context_stack().len == 0
	assert fixture.runtime.libjs_vm().interpreter_stack().depth() == 0
}

fn test_native_element_onwheel_descriptors_brand_before_replay_and_retain_legacy_values() {
	$if !darwin { return }
	state := &ElementWheelHandlerReplayState{}
	fixture := element_wheel_handler_fixture(fn [state] (_ &Runtime) ! {
		mut observed := unsafe { &ElementWheelHandlerReplayState(state) }
		observed.calls++
		if observed.pending_raw {
			observed.pending_raw = false
			mut target := observed.target
			target.set_attribute_value('onwheel', 'globalThis.elementWheelHandlerRawCalls++')
		}
	})!
	mut runtime := fixture.runtime
	defer { runtime.close() }
	assert element_wheel_handler_guard(runtime)!
	assert runtime.evaluate_host(r'(()=>{
 globalThis.handlerCreated=elementWheelHandlerFacade();__ladybirdElementWheelBind(handlerCreated,"__created_handler_div","div","http://www.w3.org/1999/xhtml");
 globalThis.handlerNull=elementWheelHandlerFacade();__ladybirdElementWheelBind(handlerNull,"__created_handler_null","widget",null);
 globalThis.handlerForeign=elementWheelHandlerFacade();__ladybirdElementWheelBind(handlerForeign,"__created_handler_foreign","widget","urn:handler-test");
 const d=Object.getOwnPropertyDescriptor(handlerDiv,"onwheel");let reads=0;
 for(const target of [handlerDiv,handlerButton,handlerSVG,handlerMath,handlerCreated]){
  const own=Object.getOwnPropertyDescriptor(target,"onwheel");
  if(!own||!own.enumerable||!own.configurable||own.get.name!=="get onwheel"||own.set.name!=="set onwheel"||own.get.length!==0||own.set.length!==1||own.get.prototype!==undefined||own.set.prototype!==undefined||![own.get,own.set].every(fn=>Function.prototype.toString.call(fn).includes("[native code]")))return false;
 }
 if(Object.hasOwn(handlerNull,"onwheel")||Object.hasOwn(handlerForeign,"onwheel"))return false;
 const value=new Proxy({},{get(){reads++;throw "value"},getPrototypeOf(){reads++;throw "value"}});
 const proxy=new Proxy(handlerDiv,{get(){reads++;throw "receiver"},getPrototypeOf(){reads++;throw "receiver"}});
 for(const receiver of [globalThis,new EventTarget(),{},Object.create(handlerDiv),handlerNull,handlerForeign,proxy,null,undefined,0])for(const invoke of [
  ()=>d.get.call(receiver),()=>d.set.call(receiver,value),()=>Reflect.get(handlerDiv,"onwheel",receiver),()=>Reflect.set(handlerDiv,"onwheel",value,receiver)
 ]){let rejected=false;try{invoke()}catch(error){rejected=error instanceof TypeError}if(!rejected)return false}
 return reads===0;
})()')! == 'true'
	assert state.calls == 0
	assert runtime.evaluate_host('handlerDiv.onwheel===null&&handlerButton.onwheel===null')! == 'true'
	assert state.calls == 2
	mut observed := unsafe { &ElementWheelHandlerReplayState(state) }
	observed.target = fixture.document.get_element_by_id('handlerDiv') or { panic('missing replay target') }
	observed.pending_raw = true
	assert runtime.evaluate_host('globalThis.handlerAfterReplay=function(){return false};handlerDiv.onwheel=handlerAfterReplay;handlerDiv.onwheel===handlerAfterReplay')! == 'true'
	assert !state.pending_raw && state.calls == 4
	assert runtime.javascript_event_handler(element_wheel_handler_target(fixture, 'handlerDiv'), 'wheel')! == runtime.evaluate_host_value('handlerAfterReplay')!
	mut changed := state.target
	changed.set_attribute_value('onwheel', 'globalThis.elementWheelHandlerRawCalls++')
	assert runtime.evaluate_host(r'(()=>{
 if(handlerDiv.onwheel!==null||handlerRaw.onwheel!==null||handlerRaw.dispatchEvent(new WheelEvent("wheel",{cancelable:true}))!==true||elementWheelHandlerRawCalls!==0)return false;
 let reads=0;const object={get handleEvent(){reads++;throw "handleEvent"},[Symbol.toPrimitive](){reads++;throw "primitive"}},proxy=new Proxy({},{get(){reads++;throw "get"},getPrototypeOf(){reads++;throw "prototype"}});
 for(const value of [object,proxy]){handlerButton.onwheel=value;const event=new WheelEvent("wheel",{cancelable:true});if(handlerButton.onwheel!==value||!handlerButton.dispatchEvent(event)||event.defaultPrevented)return false}
 const d=Object.getOwnPropertyDescriptor(handlerDiv,"onwheel");
 for(const value of [null,undefined,false,0,"return false",Symbol("handler"),1n]){handlerDiv.onwheel=value;if(handlerDiv.onwheel!==null)return false}
 d.set.call(handlerButton);return reads===0&&d.get.call(handlerButton)===null&&elementWheelHandlerRawCalls===0;
})()')! == 'true'
	assert fixture.settings.realm().reported_exceptions.len == 0
	element_wheel_handler_assert_contexts(fixture)
}

fn test_native_element_onwheel_live_slots_preserve_native_event_identity_order_and_cancellation() {
	$if !darwin { return }
	fixture := element_wheel_handler_fixture(none)!
	mut runtime := fixture.runtime
	defer { runtime.close() }
	assert element_wheel_handler_guard(runtime)!
	assert runtime.evaluate_host(r'(()=>{
 globalThis.elementWheelHandlerChecks=[];
 for(const player of [handlerDiv,handlerButton,handlerSVG,handlerMath]){
  const order=[];let expected;
  const before=()=>order.push("before"),after=()=>order.push("after");
  const replacement=function(event){order.push("replacement");elementWheelHandlerChecks.push(this===player&&arguments.length===1&&event===expected&&event.target===player&&event.currentTarget===player&&window.event===event&&__elementWheelHandlerContext());return false};
  player.addEventListener("wheel",before);player.onwheel=()=>order.push("old");player.addEventListener("wheel",after);player.onwheel=replacement;player.onwheel=replacement;
  player.addEventListener("wheel",replacement);player.removeEventListener("wheel",replacement);
  expected=new WheelEvent("wheel",{cancelable:true});
  if(player.onwheel!==replacement||player.dispatchEvent(expected)!==false||!expected.defaultPrevented||order.join(",")!=="before,replacement,after")return false;
  for(const value of [0,new Boolean(false)]){
   order.length=0;player.onwheel=function(){order.push("value");return value};expected=new WheelEvent("wheel",{cancelable:true});
   if(!player.dispatchEvent(expected)||expected.defaultPrevented||order.join(",")!=="before,value,after")return false;
  }
  order.length=0;player.onwheel=null;
  if(player.onwheel!==null||!player.dispatchEvent(new WheelEvent("wheel"))||order.join(",")!=="before,after")return false;
  order.length=0;player.onwheel=function(event){order.push("prevent");event.preventDefault()};expected=new WheelEvent("wheel",{cancelable:false});
  if(!player.dispatchEvent(expected)||expected.defaultPrevented||order.join(",")!=="before,after,prevent")return false;
  order.length=0;player.onwheel=function(){order.push("false");return false};expected=new WheelEvent("wheel",{cancelable:false});
  if(player.dispatchEvent(expected)!==false||!expected.defaultPrevented||order.join(",")!=="before,after,false")return false;
 }
 // A passive-default body handler ignores preventDefault, while exact false sets the canceled flag directly.
 handlerBody.onwheel=event=>event.preventDefault();const passive=new WheelEvent("wheel",{cancelable:true});
 if(!handlerBody.dispatchEvent(passive)||passive.defaultPrevented)return false;
 handlerBody.onwheel=()=>false;const exactFalse=new WheelEvent("wheel",{cancelable:true});
 if(handlerBody.dispatchEvent(exactFalse)!==false||!exactFalse.defaultPrevented)return false;handlerBody.onwheel=null;
 globalThis.elementWheelHandlerNativeCalls=0;
 globalThis.elementWheelHandlerNative=function(event){elementWheelHandlerNativeCalls++;elementWheelHandlerChecks.push(this===handlerDiv&&arguments.length===1&&event===elementWheelHandlerNativeExpected&&event instanceof WheelEvent&&event instanceof MouseEvent&&event.view===globalThis&&window.event===event&&event.target===handlerDiv&&event.currentTarget===handlerDiv&&event.isTrusted&&event.bubbles&&event.composed&&event.deltaMode===0&&event.deltaX===2.5&&event.deltaY===-3.5&&event.clientX===3.75&&event.pageY===24.625&&event.offsetY===2.5&&event.ctrlKey&&event.altKey&&__elementWheelHandlerContext());handlerDiv.onwheel=function(){elementWheelHandlerNativeCalls+=10;return 0};return false};
 handlerDiv.onwheel=elementWheelHandlerNative;
 return elementWheelHandlerChecks.length===4&&elementWheelHandlerChecks.every(Boolean);
})()')! == 'true'
	target := element_wheel_handler_target(fixture, 'handlerDiv')
	assert runtime.javascript_event_handler(target, 'wheel')! == runtime.evaluate_host_value('elementWheelHandlerNative')!
	event := element_wheel_handler_event(fixture)
	wrapper := runtime.javascript_event(event)!
	assert runtime.javascript_event(event)! == wrapper
	assert voidptr(runtime.native_event(wrapper)!) == voidptr(event)
	runtime.define_value_host_function('__elementWheelHandlerNativeEvent', fn [wrapper] (_ voidptr, _ []voidptr) !voidptr { return wrapper })!
	assert runtime.evaluate_host('globalThis.elementWheelHandlerNativeExpected=__elementWheelHandlerNativeEvent();0')! == '0'
	assert !dom.event_target_dispatch_event(target, event)
	assert event.is_trusted() && event.default_prevented() && event.current_target() == none
	assert dom.event_target_dispatch_event(target, element_wheel_handler_event(fixture))
	assert runtime.evaluate_host('elementWheelHandlerNativeCalls===11&&elementWheelHandlerChecks.length===5&&elementWheelHandlerChecks.every(Boolean)&&elementWheelHandlerNativeExpected.currentTarget===null&&window.event===undefined')! == 'true'
	assert fixture.settings.realm().reported_exceptions.len == 0
	element_wheel_handler_assert_contexts(fixture)
}

fn test_native_element_onwheel_callable_proxy_reports_original_throw_gates_owner_and_closes() {
	$if !darwin { return }
	fixture := element_wheel_handler_fixture(none)!
	mut runtime := fixture.runtime
	mut owner := fixture.owner
	defer { runtime.close() }
	assert element_wheel_handler_guard(runtime)!
	signal := dom.AbortSignal.new()
	signal_wrapper := runtime.javascript_event_target(unsafe { &dom.EventTarget(signal) }, none)!
	runtime.define_value_host_function('__elementWheelHandlerSignal', fn [signal_wrapper] (_ voidptr, _ []voidptr) !voidptr { return signal_wrapper })!
	assert runtime.evaluate_host(r'
globalThis.elementWheelHandlerThrown={actual:true};globalThis.elementWheelHandlerProxyReads=0;globalThis.elementWheelHandlerApplyCalls=0;globalThis.elementWheelHandlerBodyCalls=0;globalThis.elementWheelHandlerLaterCalls=0;globalThis.elementWheelHandlerProxyChecks=[];
globalThis.elementWheelHandlerCallable=new Proxy(function(event){elementWheelHandlerBodyCalls++;elementWheelHandlerProxyChecks.push(this===handlerDiv&&arguments.length===1&&event.target===handlerDiv&&event.currentTarget===handlerDiv&&event.view===globalThis&&window.event===event&&event.isTrusted&&__elementWheelHandlerContext());if(elementWheelHandlerBodyCalls===1)throw elementWheelHandlerThrown;return false},{apply(fn,receiver,args){elementWheelHandlerApplyCalls++;return Reflect.apply(fn,receiver,args)},get(){elementWheelHandlerProxyReads++;throw "unexpected property"}});
handlerDiv.onwheel=elementWheelHandlerCallable;
handlerDiv.addEventListener("wheel",elementWheelHandlerCallable,{signal:__elementWheelHandlerSignal()});
handlerDiv.addEventListener("wheel",function(){elementWheelHandlerLaterCalls++;return false});
handlerDiv.onwheel===elementWheelHandlerCallable')! == 'true'
	mut mutable_signal := signal
	mutable_signal.signal_abort(dom.js_string('listener-only abort'))
	target := element_wheel_handler_target(fixture, 'handlerDiv')
	assert dom.event_target_dispatch_event(target, element_wheel_handler_event(fixture))
	assert fixture.settings.realm().reported_exceptions.len == 1
	reported := fixture.settings.realm().reported_exceptions[0].value.as_webidl_value()!
	assert runtime.actual_webidl_value(reported)! == runtime.evaluate_host_value('elementWheelHandlerThrown')!
	assert runtime.evaluate_host('elementWheelHandlerApplyCalls===1&&elementWheelHandlerBodyCalls===1&&elementWheelHandlerLaterCalls===1&&elementWheelHandlerProxyReads===0&&elementWheelHandlerProxyChecks.every(Boolean)')! == 'true'
	owner.set_is_scripting_enabled(false)
	assert dom.event_target_dispatch_event(target, element_wheel_handler_event(fixture))
	assert runtime.evaluate_host('elementWheelHandlerApplyCalls===1&&elementWheelHandlerLaterCalls===1')! == 'true'
	owner.set_is_scripting_enabled(true)
	assert !dom.event_target_dispatch_event(target, element_wheel_handler_event(fixture))
	assert runtime.evaluate_host('elementWheelHandlerApplyCalls===2&&elementWheelHandlerBodyCalls===2&&elementWheelHandlerLaterCalls===2&&elementWheelHandlerProxyReads===0&&elementWheelHandlerProxyChecks.length===2&&elementWheelHandlerProxyChecks.every(Boolean)&&window.event===undefined')! == 'true'
	assert fixture.settings.realm().reported_exceptions.len == 1
	element_wheel_handler_assert_contexts(fixture)
	assert runtime.protected_values_.len > 0
	runtime.close()
	assert runtime.closed && runtime.context == unsafe { nil } && runtime.protected_values_.len == 0
	assert fixture.host.closed && fixture.host.records.len == 0 && fixture.host.elements.len == 0
	assert fixture.host.resolver == unsafe { nil }
	assert dom.event_target_dispatch_event(target, element_wheel_handler_event(fixture))
	element_wheel_handler_assert_contexts(fixture)
}
