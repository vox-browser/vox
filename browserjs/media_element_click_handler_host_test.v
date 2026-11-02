module browserjs

import dom
import html
import page

@[heap]
struct ClickMediaHandlerReplay {
mut:
	calls int
}

fn click_media_handler_fixture(replay ?MediaElementReplayHook) !(&Runtime, &html.HTMLMediaElement, &html.HTMLMediaElement, &html.EnvironmentSettingsObject) {
	owner := page.Page.create(1)!
	url := dom.URL{ value: 'https://native-click-media-handlers.example.test/' }
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
	runtime.define_value_host_function('__clickMediaHandlerContext', fn [handle, settings] (_ voidptr, _ []voidptr) !voidptr {
		runtime := unsafe { &Runtime(handle) }
		return C.vox_jsc_JSValueMakeBoolean(runtime.context, settings.realm().script_execution_depth > 0
			&& settings.realm().callback_execution_depth > 0)
	})!
	video_element := document.get_element_by_id('video') or { return error('missing click media video') }
	video := html.html_media_element_for_dom_element(video_element) or { return error('missing click video model') }
	audio_element := document.get_element_by_id('audio') or { return error('missing click media audio') }
	audio := html.html_media_element_for_dom_element(audio_element) or { return error('missing click audio model') }
	return runtime, video, audio, settings
}

fn test_native_media_click_handler_descriptor_checks_brands_before_replay_and_author_traps() {
	$if !darwin {
		return
	}
	state := &ClickMediaHandlerReplay{}
	mut runtime, _, _, _ := click_media_handler_fixture(fn [state] (_ &Runtime) ! {
		mut observation := unsafe { &ClickMediaHandlerReplay(state) }
		observation.calls++
	})!
	defer { runtime.close() }
	assert runtime.evaluate_host(r'(()=>{
 const prototype=HTMLMediaElement.prototype,descriptor=Object.getOwnPropertyDescriptor(prototype,"onclick");
 if(!descriptor||!descriptor.enumerable||!descriptor.configurable||descriptor.get.name!=="get onclick"||descriptor.get.length!==0||descriptor.set.name!=="set onclick"||descriptor.set.length!==1||![descriptor.get,descriptor.set].every(callback=>Function.prototype.toString.call(callback).includes("[native code]"))||Object.hasOwn(video,"onclick")||Object.hasOwn(audio,"onclick"))return false;
 let traps=0,conversions=0;
 const proxies=[video,audio].map(player=>new Proxy(player,{get(){traps++;throw "proxy get"},getPrototypeOf(){traps++;throw "proxy prototype"}})),value={[Symbol.toPrimitive](){conversions++;throw "conversion"}};
 for(const receiver of [Object.create(prototype),...proxies,null,undefined,1]){
  let getterError=false,setterError=false;
  try{descriptor.get.call(receiver)}catch(error){getterError=error instanceof TypeError&&error.message==="Not an object of type HTMLMediaElement"}
  try{descriptor.set.call(receiver,value)}catch(error){setterError=error instanceof TypeError&&error.message==="Not an object of type HTMLMediaElement"}
  if(!getterError||!setterError)return false;
 }
 return traps===0&&conversions===0;
})()')! == 'true'
	assert state.calls == 0
	assert runtime.evaluate_host('video.onclick===null&&audio.onclick===null')! == 'true'
	assert state.calls == 2
}

fn test_native_media_click_handlers_preserve_owner_slots_identity_and_legacy_callback_returns() {
	$if !darwin {
		return
	}
	mut runtime, video, audio, settings := click_media_handler_fixture(none)!
	defer { runtime.close() }
	assert runtime.evaluate_host(r'(()=>{
 globalThis.clickMediaHandlerChecks=[];globalThis.clickMediaHandlerReads=0;globalThis.clickMediaHandlerProxyCalls=0;globalThis.clickMediaHandlerProxyChecks=[];globalThis.clickMediaHandlerCallbacks={};
 for(const [ownerName,player] of [["video",video],["audio",audio]]){
  const order=[];let expected;
  const valid=event=>event instanceof Event&&event.type==="click"&&event.target===player&&event.currentTarget===player&&!event.isTrusted&&__clickMediaHandlerContext();
  const before=function(){order.push("before")},after=function(){order.push("after")},old=function(){order.push("old")};
  const replacement=function(event){order.push("replacement");clickMediaHandlerChecks.push(this===player&&event===expected&&valid(event));return false};
  player.addEventListener("click",before);player.onclick=old;player.addEventListener("click",after);player.onclick=replacement;player.onclick=replacement;
  // Removing an ordinary registration of the same function leaves the IDL slot active.
  player.addEventListener("click",replacement);player.removeEventListener("click",replacement);
  expected=new Event("click",{cancelable:true});const firstCancelled=player.dispatchEvent(expected)===false;
  if(!firstCancelled||player.onclick!==replacement||Object.hasOwn(player,"onclick")||!expected.defaultPrevented||expected.currentTarget!==null||order.join(",")!=="before,replacement,after")return false;
  // Source cancels for exact boolean false; a falsy nonboolean return is not coerced.
  order.length=0;const zero=function(event){order.push("zero");clickMediaHandlerChecks.push(this===player&&event===expected&&valid(event));return 0};player.onclick=zero;expected=new Event("click",{cancelable:true});
  if(player.onclick!==zero||player.dispatchEvent(expected)!==true||expected.defaultPrevented||order.join(",")!=="before,zero,after")return false;
  order.length=0;player.onclick=null;expected=new Event("click",{cancelable:true});
  if(player.onclick!==null||player.dispatchEvent(expected)!==true||order.join(",")!=="before,after")return false;
  order.length=0;const reactivated=function(event){order.push("reactivated");clickMediaHandlerChecks.push(this===player&&event===expected&&valid(event))};player.onclick=reactivated;player.onclick=reactivated;expected=new Event("click");
  if(player.onclick!==reactivated||!player.dispatchEvent(expected)||order.join(",")!=="before,after,reactivated")return false;
  for(const primitive of [null,undefined,false,0,"return false",Symbol("handler"),1n]){player.onclick=primitive;if(player.onclick!==null)return false}
  const object={get handleEvent(){clickMediaHandlerReads++;throw "handleEvent"},[Symbol.toPrimitive](){clickMediaHandlerReads++;throw "conversion"}},proxy=new Proxy({},{get(){clickMediaHandlerReads++;throw "proxy get"},getPrototypeOf(){clickMediaHandlerReads++;throw "proxy prototype"}});
  for(const value of [object,proxy]){order.length=0;player.onclick=value;expected=new Event("click",{cancelable:true});if(player.onclick!==value||player.dispatchEvent(expected)!==true||expected.defaultPrevented||order.join(",")!=="before,after")return false}
  order.length=0;const callable=new Proxy(function(event){order.push("proxy");clickMediaHandlerProxyCalls++;clickMediaHandlerProxyChecks.push(this===player&&valid(event));return false},{apply(callback,receiver,args){clickMediaHandlerProxyCalls++;return Reflect.apply(callback,receiver,args)},get(){clickMediaHandlerReads++;throw "callable get"}});
  player.onclick=callable;clickMediaHandlerCallbacks[ownerName]=callable;expected=new Event("click",{cancelable:true});
  if(player.onclick!==callable||Object.hasOwn(player,"onclick")||player.dispatchEvent(expected)!==false||!expected.defaultPrevented||expected.currentTarget!==null||order.join(",")!=="before,after,proxy")return false;
 }
 return clickMediaHandlerChecks.length===6&&clickMediaHandlerChecks.every(Boolean)&&clickMediaHandlerReads===0&&clickMediaHandlerProxyCalls===4&&clickMediaHandlerProxyChecks.length===2&&clickMediaHandlerProxyChecks.every(Boolean);
})()')! == 'true'
	for index, media in [video, audio] {
		owner_name := if index == 0 { 'video' } else { 'audio' }
		assert voidptr(runtime.native_event_target(runtime.evaluate_host_value(owner_name)!)!) == voidptr(media.event_target())
		assert media.event_target().event_listener_list().len == 3
		assert runtime.javascript_event_handler(media.event_target(), 'click')! == runtime.evaluate_host_value('clickMediaHandlerCallbacks["${owner_name}"]')!
		event := dom.Event.construct_impl('click', dom.EventInit{ cancelable: true })!
		assert !media.event_target().dispatch_event(event)
		assert event.default_prevented() && event.current_target() == none
	}
	assert runtime.evaluate_host('clickMediaHandlerReads===0&&clickMediaHandlerProxyCalls===8&&clickMediaHandlerProxyChecks.length===4&&clickMediaHandlerProxyChecks.every(Boolean)')! == 'true'
	assert settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
}
