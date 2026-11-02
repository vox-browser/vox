module browserjs

import dom
import html
import page

@[heap]
struct PointerMediaHandlerReplay {
mut:
	calls int
}

fn pointer_media_handler_fixture(replay ?MediaElementReplayHook) !(&Runtime, &html.HTMLMediaElement, &html.HTMLMediaElement, &html.EnvironmentSettingsObject) {
	owner := page.Page.create(1)!
	url := dom.URL{ value: 'https://native-pointer-media-handlers.example.test/' }
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
			runtime.evaluate_host('globalThis.${name}={};__ladybirdMediaElementBind(${name},"${key}","${name}");0')!
		}
	}
	handle := voidptr(runtime)
	runtime.define_value_host_function('__pointerMediaHandlerContext', fn [handle, settings] (_ voidptr, _ []voidptr) !voidptr {
		runtime := unsafe { &Runtime(handle) }
		return C.vox_jsc_JSValueMakeBoolean(runtime.context, settings.realm().script_execution_depth > 0
			&& settings.realm().callback_execution_depth > 0)
	})!
	video_element := document.get_element_by_id('video') or { return error('missing pointer media video') }
	video := html.html_media_element_for_dom_element(video_element) or { return error('missing pointer video model') }
	audio_element := document.get_element_by_id('audio') or { return error('missing pointer media audio') }
	audio := html.html_media_element_for_dom_element(audio_element) or { return error('missing pointer audio model') }
	return runtime, video, audio, settings
}

fn test_native_media_pointer_handler_descriptors_check_brands_before_replay_and_author_traps() {
	$if !darwin {
		return
	}
	state := &PointerMediaHandlerReplay{}
	mut runtime, _, _, _ := pointer_media_handler_fixture(fn [state] (_ &Runtime) ! {
		mut observation := unsafe { &PointerMediaHandlerReplay(state) }
		observation.calls++
	})!
	defer { runtime.close() }
	assert runtime.evaluate_host(r'(()=>{
 const names=["pointerdown","pointerup","mousedown","mouseup"],prototype=HTMLMediaElement.prototype;
 let traps=0,conversions=0;
 const proxy=new Proxy(video,{get(){traps++;throw "proxy get"},getPrototypeOf(){traps++;throw "proxy prototype"}}),value={[Symbol.toPrimitive](){conversions++;throw "conversion"}};
 for(const name of names){const attribute="on"+name,descriptor=Object.getOwnPropertyDescriptor(prototype,attribute);
  if(!descriptor||!descriptor.enumerable||!descriptor.configurable||descriptor.get.name!=="get "+attribute||descriptor.get.length!==0||descriptor.set.name!=="set "+attribute||descriptor.set.length!==1||![descriptor.get,descriptor.set].every(callback=>Function.prototype.toString.call(callback).includes("[native code]"))||Object.hasOwn(video,attribute)||Object.hasOwn(audio,attribute))return false;
  for(const receiver of [Object.create(prototype),proxy,null,undefined,1]){
   let getterError=false,setterError=false;
   try{descriptor.get.call(receiver)}catch(error){getterError=error instanceof TypeError&&error.message==="Not an object of type HTMLMediaElement"}
   try{descriptor.set.call(receiver,value)}catch(error){setterError=error instanceof TypeError&&error.message==="Not an object of type HTMLMediaElement"}
   if(!getterError||!setterError)return false;
  }
 }
 globalThis.pointerMediaHandlerNames=names;return traps===0&&conversions===0;
})()')! == 'true'
	assert state.calls == 0
	assert runtime.evaluate_host('pointerMediaHandlerNames.length===4&&pointerMediaHandlerNames.every(name=>video["on"+name]===null&&audio["on"+name]===null)')! == 'true'
	assert state.calls == 8
}

fn test_native_media_pointer_handlers_preserve_owner_slots_and_legacy_callback_return_rules() {
	$if !darwin {
		return
	}
	mut runtime, video, audio, settings := pointer_media_handler_fixture(none)!
	defer { runtime.close() }
	assert runtime.evaluate_host(r'(()=>{
 const names=["pointerdown","pointerup","mousedown","mouseup"];
 if(!names.every(name=>{const descriptor=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"on"+name);return !!descriptor&&typeof descriptor.get==="function"&&typeof descriptor.set==="function"&&video["on"+name]===null&&audio["on"+name]===null}))return false;
 globalThis.pointerMediaHandlerChecks=[];globalThis.pointerMediaHandlerReads=0;globalThis.pointerMediaHandlerProxyCalls=0;globalThis.pointerMediaHandlerProxyChecks=[];globalThis.pointerMediaHandlerCallbacks={};
 for(const [ownerName,player] of [["video",video],["audio",audio]])for(const name of names){
  const attribute="on"+name,order=[];let expected;
  const valid=event=>event instanceof Event&&event.type===name&&event.target===player&&event.currentTarget===player&&!event.isTrusted&&__pointerMediaHandlerContext();
  const before=function(){order.push("before")},after=function(){order.push("after")},old=function(){order.push("old")};
  const replacement=function(event){order.push("replacement");pointerMediaHandlerChecks.push(this===player&&event===expected&&valid(event));return false};
  player.addEventListener(name,before);player[attribute]=old;player.addEventListener(name,after);player[attribute]=replacement;player[attribute]=replacement;
  expected=new Event(name,{cancelable:true});
  if(player[attribute]!==replacement||Object.hasOwn(player,attribute)||player.dispatchEvent(expected)!==false||!expected.defaultPrevented||expected.currentTarget!==null||order.join(",")!=="before,replacement,after")return false;
  // Source cancels for the exact boolean false; nonboolean falsy values are not coerced.
  order.length=0;const zero=function(event){order.push("zero");pointerMediaHandlerChecks.push(this===player&&event===expected&&valid(event));return 0};player[attribute]=zero;expected=new Event(name,{cancelable:true});
  if(player[attribute]!==zero||player.dispatchEvent(expected)!==true||expected.defaultPrevented||order.join(",")!=="before,zero,after")return false;
  order.length=0;player[attribute]=null;expected=new Event(name,{cancelable:true});
  if(player[attribute]!==null||player.dispatchEvent(expected)!==true||order.join(",")!=="before,after")return false;
  order.length=0;const reactivated=function(event){order.push("reactivated");pointerMediaHandlerChecks.push(this===player&&event===expected&&valid(event))};player[attribute]=reactivated;player[attribute]=reactivated;expected=new Event(name);
  if(player[attribute]!==reactivated||!player.dispatchEvent(expected)||order.join(",")!=="before,after,reactivated")return false;
  for(const primitive of [null,undefined,false,0,"return false",Symbol("handler"),1n]){player[attribute]=primitive;if(player[attribute]!==null)return false}
  const object={get handleEvent(){pointerMediaHandlerReads++;throw "handleEvent"},[Symbol.toPrimitive](){pointerMediaHandlerReads++;throw "conversion"}},proxy=new Proxy({},{get(){pointerMediaHandlerReads++;throw "proxy get"},getPrototypeOf(){pointerMediaHandlerReads++;throw "proxy prototype"}});
  for(const value of [object,proxy]){order.length=0;player[attribute]=value;expected=new Event(name,{cancelable:true});if(player[attribute]!==value||player.dispatchEvent(expected)!==true||expected.defaultPrevented||order.join(",")!=="before,after")return false}
  order.length=0;const callable=new Proxy(function(event){order.push("proxy");pointerMediaHandlerProxyCalls++;pointerMediaHandlerProxyChecks.push(this===player&&valid(event));return false},{apply(callback,receiver,args){pointerMediaHandlerProxyCalls++;return Reflect.apply(callback,receiver,args)},get(){pointerMediaHandlerReads++;throw "callable get"}});
  player[attribute]=callable;pointerMediaHandlerCallbacks[ownerName+":"+name]=callable;expected=new Event(name,{cancelable:true});
  if(player[attribute]!==callable||Object.hasOwn(player,attribute)||player.dispatchEvent(expected)!==false||!expected.defaultPrevented||expected.currentTarget!==null||order.join(",")!=="before,after,proxy")return false;
 }
 return pointerMediaHandlerChecks.length===24&&pointerMediaHandlerChecks.every(Boolean)&&pointerMediaHandlerReads===0&&pointerMediaHandlerProxyCalls===16&&pointerMediaHandlerProxyChecks.length===8&&pointerMediaHandlerProxyChecks.every(Boolean);
})()')! == 'true'
	for index, media in [video, audio] {
		owner_name := if index == 0 { 'video' } else { 'audio' }
		assert voidptr(runtime.native_event_target(runtime.evaluate_host_value(owner_name)!)!) == voidptr(media.event_target())
		assert media.event_target().event_listener_list().len == 12
		for name in ['pointerdown', 'pointerup', 'mousedown', 'mouseup'] {
			assert runtime.javascript_event_handler(media.event_target(), name)! == runtime.evaluate_host_value('pointerMediaHandlerCallbacks["${owner_name}:${name}"]')!
			event := dom.Event.construct_impl(name, dom.EventInit{ cancelable: true })!
			assert !media.event_target().dispatch_event(event)
			assert event.default_prevented() && event.current_target() == none
		}
	}
	assert runtime.evaluate_host('pointerMediaHandlerReads===0&&pointerMediaHandlerProxyCalls===32&&pointerMediaHandlerProxyChecks.length===16&&pointerMediaHandlerProxyChecks.every(Boolean)')! == 'true'
	assert settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
}
