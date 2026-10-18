module browserjs

import dom
import html
import page

@[heap]
struct NativeMediaHandlerReplay {
mut:
	calls int
}

fn native_media_handler_fixture(replay ?MediaElementReplayHook) !(&Runtime, &html.HTMLMediaElement, &page.Page, &html.EnvironmentSettingsObject) {
	owner := page.Page.create(1)!
	url := dom.URL{ value: 'https://native-media-handlers.example.test/' }
	mut document := html.create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) })!
	document.set_document_type(.html)
	html.parse_html_from_a_string(document, '<video id="video"></video><audio id="audio"></audio>')
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut runtime := Runtime.create()
	mut host := MediaElementHost.create(document, replay)!
	host.install(mut runtime)!
	for key, element in host.elements_for_binding() {
		if element.local_name() in ['video', 'audio'] {
			name := element.local_name()
			runtime.evaluate_host('globalThis.${name}={};__ladybirdMediaElementBind(${name},"${key}","${name}")')!
		}
	}
	// Runtime.create already returns the heap pointer; the local pointer slot
	// expires when this fixture returns.
	handle := voidptr(runtime)
	runtime.define_value_host_function('__nativeMediaHandlerContext', fn [handle, settings] (_ voidptr, _ []voidptr) !voidptr {
		runtime := unsafe { &Runtime(handle) }
		return C.JSValueMakeBoolean(runtime.context, settings.realm().script_execution_depth > 0
			&& settings.realm().callback_execution_depth > 0)
	})!
	element := document.get_element_by_id('video') or { return error('missing native media video') }
	media := html.html_media_element_for_dom_element(element) or { return error('missing native media model') }
	return runtime, media, owner, settings
}

fn test_native_media_handler_accessors_cover_all_media_names_and_check_brand_before_replay() {
	$if !darwin {
		return
	}
	state := &NativeMediaHandlerReplay{}
	mut runtime, _, _, _ := native_media_handler_fixture(fn [state] (_ &Runtime) ! {
		mut observation := unsafe { &NativeMediaHandlerReplay(state) }
		observation.calls++
	})!
	defer { runtime.close() }
	assert runtime.evaluate_host(r'(()=>{
 const names=["abort","canplay","canplaythrough","durationchange","emptied","ended","error","loadeddata","loadedmetadata","loadstart","pause","play","playing","progress","ratechange","resize","seeked","seeking","stalled","suspend","timeupdate","volumechange","waiting"];
 const p=HTMLMediaElement.prototype;let traps=0,conversions=0;
 const proxy=new Proxy(video,{get(){traps++;throw "proxy"},getPrototypeOf(){traps++;throw "proxy"}}),value={[Symbol.toPrimitive](){conversions++;throw "conversion"}};
 for(const name of names){const attribute="on"+name,d=Object.getOwnPropertyDescriptor(p,attribute);
  if(!d||!d.enumerable||!d.configurable||d.get.name!=="get "+attribute||d.get.length!==0||d.set.name!=="set "+attribute||d.set.length!==1||![d.get,d.set].every(fn=>Function.prototype.toString.call(fn).includes("[native code]"))||Object.hasOwn(video,attribute))return false;
  for(const receiver of [Object.create(p),proxy,null,undefined,1]){
   let get=false,set=false;
   try{d.get.call(receiver)}catch(error){get=error instanceof TypeError&&error.message==="Not an object of type HTMLMediaElement"}
   try{d.set.call(receiver,value)}catch(error){set=error instanceof TypeError&&error.message==="Not an object of type HTMLMediaElement"}
   if(!get||!set)return false;
  }
 }
 globalThis.nativeMediaHandlerNames=names;return traps===0&&conversions===0;
})()')! == 'true'
	assert state.calls == 0
	assert runtime.evaluate_host('nativeMediaHandlerNames.length===23&&nativeMediaHandlerNames.every(name=>video["on"+name]===null&&audio["on"+name]===null)')! == 'true'
	assert state.calls == 46
}

fn test_native_media_handler_replacement_preserves_listener_order_and_null_reactivation() {
	$if !darwin {
		return
	}
	mut runtime, media, _, settings := native_media_handler_fixture(none)!
	defer { runtime.close() }
	assert runtime.evaluate_host(r'globalThis.nativeMediaHandlerOrder=[];globalThis.nativeMediaHandlerChecks=[];(()=>{
 const before=function(){nativeMediaHandlerOrder.push("before")},after=function(){nativeMediaHandlerOrder.push("after")};
 const first=function(){nativeMediaHandlerOrder.push("old")};
 const replacement=function(event){nativeMediaHandlerOrder.push("replacement");nativeMediaHandlerChecks.push(this===video&&event===nativeMediaHandlerExpected&&event.target===video&&event.currentTarget===video&&event instanceof Event&&__nativeMediaHandlerContext());return false};
 video.addEventListener("play",before);video.onplay=first;video.addEventListener("play",after);video.onplay=replacement;
 globalThis.nativeMediaHandlerExpected=new Event("play",{cancelable:true});
 const identity=video.onplay===replacement&&!Object.hasOwn(video,"onplay"),cancelled=video.dispatchEvent(nativeMediaHandlerExpected)===false&&nativeMediaHandlerExpected.defaultPrevented;
 video.onplay=null;const cleared=video.onplay===null&&video.dispatchEvent(new Event("play"));
 globalThis.nativeMediaHandlerReactivated=function(){nativeMediaHandlerOrder.push("reactivated")};video.onplay=nativeMediaHandlerReactivated;video.onplay=nativeMediaHandlerReactivated;
 video.dispatchEvent(new Event("play"));
 return identity&&cancelled&&cleared&&video.onplay===nativeMediaHandlerReactivated&&nativeMediaHandlerExpected.currentTarget===null;
})()')! == 'true'
	assert runtime.evaluate_host('nativeMediaHandlerOrder.join(",")')! == 'before,replacement,after,before,after,before,after,reactivated'
	assert runtime.evaluate_host('nativeMediaHandlerChecks.length===1&&nativeMediaHandlerChecks[0]')! == 'true'
	assert media.event_target().event_listener_list().len == 3
	assert runtime.javascript_event_handler(media.event_target(), 'play')! == runtime.evaluate_host_value('nativeMediaHandlerReactivated')!
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
}

fn test_native_media_handler_legacy_values_preserve_noncallable_objects_without_gets() {
	$if !darwin {
		return
	}
	mut runtime, media, _, settings := native_media_handler_fixture(none)!
	defer { runtime.close() }
	assert runtime.evaluate_host(r'globalThis.nativeMediaHandlerObjectReads=0;globalThis.nativeMediaHandlerProxyCalls=0;globalThis.nativeMediaHandlerProxyChecks=[];(()=>{
 for(const primitive of [null,undefined,false,0,"return false",Symbol("handler"),1n]){video.onpause=primitive;if(video.onpause!==null)return false}
 const object={get handleEvent(){nativeMediaHandlerObjectReads++;throw "handler getter"},[Symbol.toPrimitive](){nativeMediaHandlerObjectReads++;throw "handler conversion"}},proxy=new Proxy({},{get(){nativeMediaHandlerObjectReads++;throw "proxy get"},getPrototypeOf(){nativeMediaHandlerObjectReads++;throw "proxy prototype"}});
 for(const value of [object,proxy]){video.onpause=value;if(video.onpause!==value||video.dispatchEvent(new Event("pause",{cancelable:true}))!==true)return false}
 const callable=new Proxy(function(event){nativeMediaHandlerProxyCalls++;nativeMediaHandlerProxyChecks.push(this===video&&event.target===video&&event.currentTarget===video&&event instanceof Event);return false},{apply(target,receiver,args){nativeMediaHandlerProxyCalls++;return Reflect.apply(target,receiver,args)},get(){nativeMediaHandlerObjectReads++;throw "callable get"}});
 video.onpause=callable;const event=new Event("pause",{cancelable:true});
 return video.onpause===callable&&!video.dispatchEvent(event)&&event.defaultPrevented&&nativeMediaHandlerObjectReads===0&&nativeMediaHandlerProxyCalls===2&&nativeMediaHandlerProxyChecks.length===1&&nativeMediaHandlerProxyChecks[0];
})()')! == 'true'
	assert media.event_target().event_listener_list().len == 1
	assert settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
}

fn test_native_media_error_handler_receives_one_event_reports_original_throw_and_continues() {
	$if !darwin {
		return
	}
	mut runtime, mut media, _, settings := native_media_handler_fixture(none)!
	defer { runtime.close() }
	assert runtime.evaluate_host('__nativeMediaHandlerContext() === false')! == 'true'
	runtime.evaluate_host(r'globalThis.nativeMediaHandlerErrorOrder=[];globalThis.nativeMediaHandlerErrorChecks=[];globalThis.nativeMediaHandlerReason={};globalThis.nativeMediaHandlerErrorEvent=null;
 video.onerror=function(event){nativeMediaHandlerErrorOrder.push("handler");nativeMediaHandlerErrorEvent=event;nativeMediaHandlerErrorChecks.push(arguments.length===1&&this===video&&event.target===video&&event.currentTarget===video&&event instanceof Event&&event.isTrusted&&__nativeMediaHandlerContext());throw nativeMediaHandlerReason};
 video.addEventListener("error",function(event){nativeMediaHandlerErrorOrder.push("later");nativeMediaHandlerErrorChecks.push(this===video&&event===nativeMediaHandlerErrorEvent&&event.target===video&&event.currentTarget===video)});')!
	media.handle_media_source_failure([], 'actual media failure')
	assert runtime.evaluate_host('nativeMediaHandlerErrorOrder.join(",")')! == 'handler,later'
	assert runtime.evaluate_host('nativeMediaHandlerErrorChecks.length===2&&nativeMediaHandlerErrorChecks.every(Boolean)&&nativeMediaHandlerErrorEvent.currentTarget===null')! == 'true'
	assert settings.realm().reported_exceptions.len == 1
	assert runtime.actual_webidl_value(settings.realm().reported_exceptions[0].value.as_webidl_value()!)! == runtime.evaluate_host_value('nativeMediaHandlerReason')!
	// Even an actual ErrorEvent uses the one-Event handler signature on media.
	runtime.evaluate_host(r'video.onerror=function(event){nativeMediaHandlerErrorEvent=event;globalThis.nativeMediaSingleError=arguments.length===1&&this===video&&event instanceof Event;return false}')!
	error_event := dom.ErrorEvent.create('error', dom.ErrorEventInit{
		EventInit: dom.EventInit{ cancelable: true }
		message:   'single event'
		filename:  'media.js'
		lineno:    7
		colno:     9
	})
	wrapped := runtime.javascript_event(unsafe { &dom.Event(error_event) })!
	runtime.define_value_host_function('__nativeMediaHandlerError', fn [wrapped] (_ voidptr, _ []voidptr) !voidptr {
		return wrapped
	})!
	assert runtime.evaluate_host('video.dispatchEvent(__nativeMediaHandlerError())===false&&nativeMediaSingleError')! == 'true'
	assert error_event.default_prevented()
	assert settings.realm().reported_exceptions.len == 1
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
}

fn test_native_media_handler_dispatch_respects_page_script_gate_and_closed_runtime() {
	$if !darwin {
		return
	}
	mut runtime, media, mut owner, settings := native_media_handler_fixture(none)!
	defer { runtime.close() }
	runtime.evaluate_host(r'globalThis.nativeMediaHandlerGateCount=0;video.onplay=function(event){nativeMediaHandlerGateCount++;globalThis.nativeMediaHandlerGateValid=this===video&&event.target===video&&event.currentTarget===video&&__nativeMediaHandlerContext();return false}')!
	owner.set_is_scripting_enabled(false)
	assert media.event_target().dispatch_event(dom.Event.create('play', dom.EventInit{ cancelable: true }))
	assert runtime.evaluate_host('nativeMediaHandlerGateCount')! == '0'
	owner.set_is_scripting_enabled(true)
	assert !media.event_target().dispatch_event(dom.Event.create('play', dom.EventInit{ cancelable: true }))
	assert runtime.evaluate_host('nativeMediaHandlerGateCount===1&&nativeMediaHandlerGateValid')! == 'true'
	assert settings.realm().reported_exceptions.len == 0
	runtime.close()
	assert runtime.closed && runtime.context == unsafe { nil } && runtime.protected_values_.len == 0
	assert media.event_target().dispatch_event(dom.Event.create('play', dom.EventInit{ cancelable: true }))
	assert settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
}
