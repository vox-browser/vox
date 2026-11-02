module browserjs

import dom
import html
import page

@[heap]
struct MovementMediaHandlerReplay {
mut:
	calls int
}

fn movement_media_handler_fixture(replay ?MediaElementReplayHook) !(&Runtime, &html.HTMLMediaElement, &html.HTMLMediaElement, &html.EnvironmentSettingsObject) {
	owner := page.Page.create(1)!
	url := dom.URL{
		value: 'https://native-movement-media-handlers.example.test/'
	}
	mut document := html.create_navigation_document_for_page(url, url.origin(), none,
		unsafe { &dom.Page(owner) })!
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
	runtime.define_value_host_function('__movementMediaHandlerContext', fn [handle, settings] (_ voidptr, _ []voidptr) !voidptr {
		runtime := unsafe { &Runtime(handle) }
		return C.vox_jsc_JSValueMakeBoolean(runtime.context, settings.realm().script_execution_depth > 0
			&& settings.realm().callback_execution_depth > 0)
	})!
	video_element := document.get_element_by_id('video') or {
		return error('missing movement media video')
	}
	video := html.html_media_element_for_dom_element(video_element) or {
		return error('missing movement video model')
	}
	audio_element := document.get_element_by_id('audio') or {
		return error('missing movement media audio')
	}
	audio := html.html_media_element_for_dom_element(audio_element) or {
		return error('missing movement audio model')
	}
	return runtime, video, audio, settings
}

fn test_native_media_movement_handler_descriptors_brand_before_replay_and_proxy_traps() {
	$if !darwin {
		return
	}
	state := &MovementMediaHandlerReplay{}
	mut runtime, _, _, _ := movement_media_handler_fixture(fn [state] (_ &Runtime) ! {
		mut observation := unsafe { &MovementMediaHandlerReplay(state) }
		observation.calls++
	})!
	defer { runtime.close() }
	assert runtime.evaluate_host(r'(()=>{
 const prototype=HTMLMediaElement.prototype,names=["pointermove","mousemove"];
 let traps=0,conversions=0;
 const proxies=[video,audio].map(player=>new Proxy(player,{get(){traps++;throw "proxy get"},getPrototypeOf(){traps++;throw "proxy prototype"}})),value={[Symbol.toPrimitive](){conversions++;throw "conversion"}};
 for(const name of names){
  const property="on"+name,descriptor=Object.getOwnPropertyDescriptor(prototype,property);
  if(!descriptor||!descriptor.enumerable||!descriptor.configurable||descriptor.get.name!=="get "+property||descriptor.get.length!==0||descriptor.set.name!=="set "+property||descriptor.set.length!==1||![descriptor.get,descriptor.set].every(callback=>Function.prototype.toString.call(callback).includes("[native code]"))||Object.hasOwn(video,property)||Object.hasOwn(audio,property))return false;
  for(const receiver of [Object.create(prototype),...proxies,null,undefined,1]){
   let getterError=false,setterError=false;
   try{descriptor.get.call(receiver)}catch(error){getterError=error instanceof TypeError&&error.message==="Not an object of type HTMLMediaElement"}
   try{descriptor.set.call(receiver,value)}catch(error){setterError=error instanceof TypeError&&error.message==="Not an object of type HTMLMediaElement"}
   if(!getterError||!setterError)return false;
  }
 }
 return traps===0&&conversions===0;
})()')! == 'true'
	assert state.calls == 0
	assert runtime.evaluate_host('[video,audio].every(player=>["pointermove","mousemove"].every(name=>player["on"+name]===null))')! == 'true'
	assert state.calls == 4
}

fn test_native_media_movement_handlers_keep_native_owner_slots_and_legacy_return_rules() {
	$if !darwin {
		return
	}
	mut runtime, video, audio, settings := movement_media_handler_fixture(none)!
	defer { runtime.close() }
	assert runtime.evaluate_host(r'(()=>{
 const names=["pointermove","mousemove"];
 if(names.some(name=>!Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"on"+name)))return false;
 globalThis.movementHandlerChecks=[];globalThis.movementHandlerReads=0;globalThis.movementHandlerCallbacks={};
 for(const [ownerName,player,name] of [["video",video,"pointermove"],["audio",audio,"mousemove"]]){
  const property="on"+name,order=[];let expected;
  const valid=event=>event instanceof Event&&event.type===name&&event.target===player&&event.currentTarget===player&&!event.isTrusted&&__movementMediaHandlerContext();
  const before=function(){order.push("before")},after=function(){order.push("after")};
  const replacement=function(event){order.push("replacement");movementHandlerChecks.push(this===player&&event===expected&&valid(event));return false};
  player.addEventListener(name,before);player[property]=()=>order.push("old");player.addEventListener(name,after);player[property]=replacement;player[property]=replacement;
  // An ordinary registration of this same function is separate from the IDL slot.
  player.addEventListener(name,replacement);player.removeEventListener(name,replacement);
  expected=new Event(name,{cancelable:true});
  if(player[property]!==replacement||player.dispatchEvent(expected)!==false||!expected.defaultPrevented||expected.currentTarget!==null||order.join(",")!=="before,replacement,after")return false;
  order.length=0;const zero=function(event){order.push("zero");movementHandlerChecks.push(this===player&&event===expected&&valid(event));return 0};player[property]=zero;expected=new Event(name,{cancelable:true});
  if(player[property]!==zero||player.dispatchEvent(expected)!==true||expected.defaultPrevented||order.join(",")!=="before,zero,after")return false;
  order.length=0;player[property]=undefined;expected=new Event(name,{cancelable:true});
  if(player[property]!==null||player.dispatchEvent(expected)!==true||order.join(",")!=="before,after")return false;
  const object={get handleEvent(){movementHandlerReads++;throw "handleEvent"},[Symbol.toPrimitive](){movementHandlerReads++;throw "conversion"}};
  order.length=0;player[property]=object;expected=new Event(name,{cancelable:true});
  if(player[property]!==object||player.dispatchEvent(expected)!==true||expected.defaultPrevented||order.join(",")!=="before,after")return false;
  order.length=0;player[property]=null;expected=new Event(name,{cancelable:true});
  if(player[property]!==null||player.dispatchEvent(expected)!==true||order.join(",")!=="before,after")return false;
  const reactivated=function(event){order.push("reactivated");movementHandlerChecks.push(this===player&&valid(event));return false};
  player[property]=reactivated;player[property]=reactivated;movementHandlerCallbacks[ownerName+":"+name]=reactivated;expected=new Event(name,{cancelable:true});order.length=0;
  if(player[property]!==reactivated||Object.hasOwn(player,property)||player.dispatchEvent(expected)!==false||!expected.defaultPrevented||expected.currentTarget!==null||order.join(",")!=="before,after,reactivated")return false;
 }
 return movementHandlerChecks.length===6&&movementHandlerChecks.every(Boolean)&&movementHandlerReads===0;
})()')! == 'true'
	for index, media in [video, audio] {
		owner_name := if index == 0 { 'video' } else { 'audio' }
		assert voidptr(runtime.native_event_target(runtime.evaluate_host_value(owner_name)!)!) == voidptr(media.event_target())
		assert media.event_target().event_listener_list().len == 3
		name := if index == 0 { 'pointermove' } else { 'mousemove' }
		handler := media.event_target().data.event_handler(name) or {
			panic('missing native movement media handler slot')
		}
		assert handler.listener != none
		assert runtime.javascript_event_handler(media.event_target(), name)! == runtime.evaluate_host_value('movementHandlerCallbacks["${owner_name}:${name}"]')!
		event := dom.Event.construct_impl(name, dom.EventInit{ cancelable: true })!
		assert !media.event_target().dispatch_event(event)
		assert event.default_prevented() && event.current_target() == none
	}
	assert runtime.evaluate_host('movementHandlerChecks.length===8&&movementHandlerChecks.every(Boolean)&&movementHandlerReads===0')! == 'true'
	assert settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0
		&& settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
}
