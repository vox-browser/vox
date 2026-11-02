module browserjs

import dom
import html
import page

@[heap]
struct WheelMediaHandlerFixture {
	runtime  &Runtime
	host     &MediaElementHost
	video    &html.HTMLMediaElement
	audio    &html.HTMLMediaElement
	owner    &page.Page
	settings &html.EnvironmentSettingsObject
}

@[heap]
struct WheelMediaHandlerReplay {
mut:
	calls int
}

fn wheel_media_handler_fixture(replay ?MediaElementReplayHook) !&WheelMediaHandlerFixture {
	owner := page.Page.create(1)!
	url := dom.URL{ value: 'https://native-wheel-media-handlers.example.test/' }
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
	runtime.define_value_host_function('__wheelMediaHandlerContext', fn [handle, settings] (_ voidptr, _ []voidptr) !voidptr {
		runtime := unsafe { &Runtime(handle) }
		return C.vox_jsc_JSValueMakeBoolean(runtime.context, settings.realm().script_execution_depth > 0
			&& settings.realm().callback_execution_depth > 0
			&& runtime.libjs_vm().has_running_execution_context()
			&& voidptr(html.current_principal_settings_object()) == voidptr(settings)
			&& voidptr(html.incumbent_settings_object()) == voidptr(settings))
	})!
	video_element := document.get_element_by_id('video') or { return error('missing wheel media video') }
	audio_element := document.get_element_by_id('audio') or { return error('missing wheel media audio') }
	video := html.html_media_element_for_dom_element(video_element) or { return error('missing wheel video model') }
	audio := html.html_media_element_for_dom_element(audio_element) or { return error('missing wheel audio model') }
	return &WheelMediaHandlerFixture{ runtime: runtime, host: host, video: video, audio: audio,
		owner: owner, settings: settings }
}

fn wheel_media_handler_guard(runtime &Runtime) !bool {
	return runtime.evaluate_host('!!Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"onwheel")')! == 'true'
}

fn wheel_media_handler_event(fixture &WheelMediaHandlerFixture) &dom.WheelEvent {
	return dom.WheelEvent.create('wheel', dom.WheelEventInit{
		MouseEventInit: dom.MouseEventInit{
			EventModifierInit: dom.EventModifierInit{
				UIEventInit: dom.UIEventInit{
					EventInit: dom.EventInit{ cancelable: true }
					view:      voidptr(fixture.host.document.get_window() or { panic('missing wheel owner Window') })
					detail:    7
				}
				ctrl_key:  true
				shift_key: true
			}
			screen_x:   8.875
			screen_y:   -7.125
			client_x:   3.75
			client_y:   4.625
			page_x:     3.75
			page_y:     4.625
			offset_x:   3.75
			offset_y:   4.625
			movement_x: 1.25
			movement_y: -2.5
			button:     2
			buttons:    5
		}
		delta_x:       2.5
		delta_y:       -3.6
		delta_z:       0.25
		delta_mode:    dom.dom_delta_line
		wheel_delta_x: 120
	})
}

fn wheel_media_handler_assert_contexts(fixture &WheelMediaHandlerFixture) {
	assert fixture.settings.realm().reported_exceptions.len == 0
	assert fixture.settings.realm().script_execution_depth == 0
		&& fixture.settings.realm().callback_execution_depth == 0
	assert !fixture.runtime.libjs_vm().has_running_execution_context()
	assert fixture.runtime.libjs_vm().execution_context_stack().len == 0
	assert fixture.runtime.libjs_vm().interpreter_stack().depth() == 0
}

fn test_native_media_wheel_handler_descriptor_brands_precede_replay_and_proxy_traps() {
	$if !darwin { return }
	state := &WheelMediaHandlerReplay{}
	fixture := wheel_media_handler_fixture(fn [state] (_ &Runtime) ! {
		mut observation := unsafe { &WheelMediaHandlerReplay(state) }
		observation.calls++
	})!
	mut runtime := fixture.runtime
	defer { runtime.close() }
	assert wheel_media_handler_guard(runtime)!
	assert runtime.evaluate_host(r'(()=>{
 const p=HTMLMediaElement.prototype,d=Object.getOwnPropertyDescriptor(p,"onwheel");let reads=0;
 if(!d.enumerable||!d.configurable||d.get.name!=="get onwheel"||d.set.name!=="set onwheel"||d.get.length!==0||d.set.length!==1||![d.get,d.set].every(fn=>Function.prototype.toString.call(fn).includes("[native code]"))||Object.hasOwn(video,"onwheel")||Object.hasOwn(audio,"onwheel"))return false;
 const value={[Symbol.toPrimitive](){reads++;throw 0}},proxies=[video,audio].map(player=>new Proxy(player,{get(){reads++;throw 0},getPrototypeOf(){reads++;throw 0}}));
 for(const receiver of [Object.create(p),...proxies,null,undefined,1])for(const accessor of [d.get,d.set]){let rejected=false;try{accessor.call(receiver,value)}catch(error){rejected=error instanceof TypeError&&error.message==="Not an object of type HTMLMediaElement"}if(!rejected)return false}
 return reads===0;
})()')! == 'true'
	assert state.calls == 0
	assert runtime.evaluate_host('video.onwheel===null&&audio.onwheel===null')! == 'true'
	assert state.calls == 2
	wheel_media_handler_assert_contexts(fixture)
}

fn test_native_media_wheel_handler_slots_preserve_real_payload_identity_order_and_false_cancellation() {
	$if !darwin { return }
	fixture := wheel_media_handler_fixture(none)!
	mut runtime := fixture.runtime
	defer { runtime.close() }
	assert wheel_media_handler_guard(runtime)!
	assert runtime.evaluate_host(r'(()=>{
 globalThis.wheelMediaChecks=[];globalThis.wheelMediaCallbacks={};
 const init={view:globalThis,detail:7,cancelable:true,screenX:8.875,screenY:-7.125,clientX:3.75,clientY:4.625,movementX:1.25,movementY:-2.5,button:2,buttons:5,ctrlKey:true,shiftKey:true,deltaX:2.5,deltaY:-3.6,deltaZ:0.25,deltaMode:1,wheelDeltaX:120};
 for(const [ownerName,player] of [["video",video],["audio",audio]]){
  const order=[];let expected;
  const valid=event=>event instanceof WheelEvent&&event instanceof MouseEvent&&event instanceof UIEvent&&event instanceof Event&&event.type==="wheel"&&event.target===player&&event.currentTarget===player&&event.view===globalThis&&event.detail===7&&event.clientX===(event.isTrusted?3.75:3)&&event.pageY===(event.isTrusted?4.625:4)&&event.screenY===(event.isTrusted?-7.125:-8)&&event.movementX===1.25&&event.movementY===-2.5&&event.which===3&&event.buttons===5&&event.ctrlKey&&event.shiftKey&&event.deltaX===2.5&&event.deltaY===-3.6&&event.deltaZ===0.25&&event.deltaMode===1&&event.wheelDeltaX===120&&event.wheelDeltaY===4&&event.wheelDelta===4&&__wheelMediaHandlerContext();
  const before=()=>order.push("before"),after=()=>order.push("after"),replacement=function(event){order.push("replacement");wheelMediaChecks.push(arguments.length===1&&this===player&&event===expected&&valid(event));return false};
  player.addEventListener("wheel",before);player.onwheel=()=>order.push("old");player.addEventListener("wheel",after);player.onwheel=replacement;player.onwheel=replacement;
  player.addEventListener("wheel",replacement);player.removeEventListener("wheel",replacement);
  expected=new WheelEvent("wheel",init);
  if(player.onwheel!==replacement||player.dispatchEvent(expected)!==false||!expected.defaultPrevented||expected.currentTarget!==null||order.join(",")!=="before,replacement,after")return false;
  order.length=0;player.onwheel=function(event){order.push("zero");wheelMediaChecks.push(this===player&&event===expected&&valid(event));return 0};expected=new WheelEvent("wheel",init);
  if(!player.dispatchEvent(expected)||expected.defaultPrevented||order.join(",")!=="before,zero,after")return false;
  order.length=0;player.onwheel=null;expected=new WheelEvent("wheel",init);
  if(player.onwheel!==null||!player.dispatchEvent(expected)||order.join(",")!=="before,after")return false;
  const reactivated=function(event){order.push("reactivated");wheelMediaChecks.push(arguments.length===1&&this===player&&event===(event.isTrusted?wheelMediaNativeExpected:expected)&&valid(event));return false};player.onwheel=reactivated;player.onwheel=reactivated;wheelMediaCallbacks[ownerName]=reactivated;expected=new WheelEvent("wheel",init);order.length=0;
  if(player.onwheel!==reactivated||Object.hasOwn(player,"onwheel")||player.dispatchEvent(expected)!==false||!expected.defaultPrevented||order.join(",")!=="before,after,reactivated")return false;
  // The pinned ordinary handler sets the canceled flag directly for exact false.
  expected=new WheelEvent("wheel",{...init,cancelable:false});order.length=0;
  if(player.dispatchEvent(expected)!==false||!expected.defaultPrevented||expected.cancelable||order.join(",")!=="before,after,reactivated")return false;
 }
 return wheelMediaChecks.length===8&&wheelMediaChecks.every(Boolean);
})()')! == 'true'
	for index, media in [fixture.video, fixture.audio] {
		name := if index == 0 { 'video' } else { 'audio' }
		assert media.event_target().event_listener_list().len == 3
		assert runtime.javascript_event_handler(media.event_target(), 'wheel')! == runtime.evaluate_host_value('wheelMediaCallbacks.${name}')!
		event := wheel_media_handler_event(fixture)
		base := unsafe { &dom.Event(event) }
		wrapper := runtime.javascript_event(base)!
		assert runtime.javascript_event(base)! == wrapper
		assert voidptr(runtime.native_event(wrapper)!) == voidptr(base)
		export_name := '__wheelMediaNative_${name}'
		runtime.define_value_host_function(export_name, fn [wrapper] (_ voidptr, _ []voidptr) !voidptr { return wrapper })!
		runtime.evaluate_host('globalThis.wheelMediaNativeExpected=${export_name}();0')!
		assert voidptr(runtime.native_event(runtime.evaluate_host_value('wheelMediaNativeExpected')!)!) == voidptr(base)
		assert !media.event_target().dispatch_event(base)
		assert event.is_trusted() && event.default_prevented() && event.current_target() == none
	}
	assert runtime.evaluate_host('wheelMediaChecks.length===10&&wheelMediaChecks.every(Boolean)&&wheelMediaNativeExpected.currentTarget===null')! == 'true'
	wheel_media_handler_assert_contexts(fixture)
}

fn test_native_media_wheel_handler_legacy_values_callable_proxy_page_gate_and_close() {
	$if !darwin { return }
	fixture := wheel_media_handler_fixture(none)!
	mut runtime := fixture.runtime
	mut owner := fixture.owner
	defer { runtime.close() }
	assert wheel_media_handler_guard(runtime)!
	assert runtime.evaluate_host(r'(()=>{
 globalThis.wheelMediaReads=0;globalThis.wheelMediaProxyCalls=0;globalThis.wheelMediaProxyChecks=[];
 for(const player of [video,audio]){
  for(const primitive of [null,undefined,false,0,"return false",Symbol("handler"),1n]){player.onwheel=primitive;if(player.onwheel!==null)return false}
  const object={get handleEvent(){wheelMediaReads++;throw 0},[Symbol.toPrimitive](){wheelMediaReads++;throw 0}},proxy=new Proxy({},{get(){wheelMediaReads++;throw 0},getPrototypeOf(){wheelMediaReads++;throw 0}});
  for(const value of [object,proxy]){player.onwheel=value;const event=new WheelEvent("wheel",{cancelable:true});if(player.onwheel!==value||!player.dispatchEvent(event)||event.defaultPrevented)return false}
  const callable=new Proxy(function(event){wheelMediaProxyCalls++;wheelMediaProxyChecks.push(arguments.length===1&&this===player&&event instanceof WheelEvent&&event.target===player&&event.currentTarget===player&&__wheelMediaHandlerContext());return false},{apply(fn,receiver,args){wheelMediaProxyCalls++;return Reflect.apply(fn,receiver,args)},get(){wheelMediaReads++;throw 0}});
  player.onwheel=callable;const event=new WheelEvent("wheel",{cancelable:true});
  if(player.onwheel!==callable||Object.hasOwn(player,"onwheel")||player.dispatchEvent(event)!==false||!event.defaultPrevented)return false;
 }
 return wheelMediaReads===0&&wheelMediaProxyCalls===4&&wheelMediaProxyChecks.length===2&&wheelMediaProxyChecks.every(Boolean);
})()')! == 'true'
	owner.set_is_scripting_enabled(false)
	for media in [fixture.video, fixture.audio] {
		assert media.event_target().dispatch_event(unsafe { &dom.Event(wheel_media_handler_event(fixture)) })
	}
	assert runtime.evaluate_host('wheelMediaProxyCalls===4')! == 'true'
	owner.set_is_scripting_enabled(true)
	for media in [fixture.video, fixture.audio] {
		assert !media.event_target().dispatch_event(unsafe { &dom.Event(wheel_media_handler_event(fixture)) })
	}
	assert runtime.evaluate_host('wheelMediaReads===0&&wheelMediaProxyCalls===8&&wheelMediaProxyChecks.length===4&&wheelMediaProxyChecks.every(Boolean)')! == 'true'
	wheel_media_handler_assert_contexts(fixture)
	assert runtime.protected_values_.len > 0 && fixture.host.records.len == 2
	runtime.close()
	assert runtime.closed && runtime.context == unsafe { nil } && runtime.protected_values_.len == 0
	assert fixture.host.closed && fixture.host.records.len == 0 && fixture.host.elements.len == 0
	for media in [fixture.video, fixture.audio] {
		assert media.event_target().dispatch_event(unsafe { &dom.Event(wheel_media_handler_event(fixture)) })
	}
	wheel_media_handler_assert_contexts(fixture)
}
