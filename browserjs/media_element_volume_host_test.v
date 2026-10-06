module browserjs

import dom
import html

@[heap]
struct NativeMediaVolumeObservation {
mut:
	reads       int
	hook_values []f64
}

fn native_media_volume_fixture(replay ?MediaElementReplayHook) !(&Runtime, &html.HTMLMediaElement) {
	address := dom.URL{
		value: 'https://native-media-volume.example.test/'
	}
	document := html.parse_navigation_document('<video id="video"></video><audio id="audio"></audio>',
		address, address.origin(), none)!
	mut runtime := Runtime.create()
	mut host := MediaElementHost.create(document, replay)!
	host.install(mut runtime)!
	for key, element in host.elements_for_binding() {
		if element.local_name() in ['video', 'audio'] {
			name := element.local_name()
			runtime.evaluate_host('globalThis.${name}={};__ladybirdMediaElementBind(${name},"${key}","${name}")')!
		}
	}
	element := document.get_element_by_id('video') or { return error('missing video') }
	media := html.html_media_element_for_dom_element(element) or {
		return error('missing media owner')
	}
	return runtime, media
}

fn test_native_volume_accessors_check_the_receiver_before_conversion_and_replay() {
	$if !darwin { return }
	probe := &NativeMediaVolumeObservation{}
	mut runtime, _ := native_media_volume_fixture(fn [probe] (_ &Runtime) ! {
		mut state := unsafe { &NativeMediaVolumeObservation(probe) }
		state.reads++
	})!
	defer { runtime.close() }
	assert runtime.evaluate_host(r'(()=>{
 let traps=0,conversions=0;
 const p=HTMLMediaElement.prototype,proxy=new Proxy(video,{get(){traps++;throw "proxy"},getPrototypeOf(){traps++;throw "proxy"}});
 const value={[Symbol.toPrimitive](){conversions++;return 0.5}};
 const passed=["volume","muted"].every(name=>{
  const d=Object.getOwnPropertyDescriptor(p,name);if(!d)return false;
  if(!d.enumerable||!d.configurable||d.get.length!==0||d.set.length!==1||d.get.name!=="get "+name||d.set.name!=="set "+name||Object.hasOwn(video,name))return false;
  if(![d.get,d.set].every(fn=>Function.prototype.toString.call(fn).includes("[native code]")))return false;
  return [Object.create(p),proxy,null,undefined,1].every(receiver=>{
   let getters=false,setters=false;
   try{d.get.call(receiver)}catch(error){getters=error instanceof TypeError}
   try{d.set.call(receiver,value)}catch(error){setters=error instanceof TypeError}
   return getters&&setters;
  });
 });return passed&&traps===0&&conversions===0;
})()')! == 'true'
	assert probe.reads == 0
	assert runtime.evaluate_host('video.volume===1&&video.muted===false')! == 'true'
	assert probe.reads == 2
}

fn test_native_volume_uses_restricted_double_and_muted_uses_boolean_without_author_conversion() {
	$if !darwin { return }
	mut runtime, media := native_media_volume_fixture(none)!
	defer { runtime.close() }
	assert runtime.evaluate_host(r'(()=>{
 const p=HTMLMediaElement.prototype,volume=Object.getOwnPropertyDescriptor(p,"volume"),muted=Object.getOwnPropertyDescriptor(p,"muted");
 if(!volume||!muted)return false;
 const invalid=[undefined,NaN,Infinity,-Infinity,Symbol(),1n,Object(1n),{valueOf(){return NaN}},{[Symbol.toPrimitive](){return 2n}}];
 if(!invalid.every(value=>{try{video.volume=value;return false}catch(error){return error instanceof TypeError&&video.volume===1}}))return false;
 try{video.volume=Infinity;return false}catch(error){if(error.message!=="Expected volume to be a finite floating-point number")return false}
 const cases=[["0.5",0.5],[null,0],[false,0],[true,1],["",0],[{valueOf(){return 0.25}},0.25]];
 if(!cases.every(([value,expected])=>{video.volume=value;return video.volume===expected}))return false;
 const D=DOMException;globalThis.savedVolumeRangeError=null;
 if(![-1,1.01].every(value=>{try{video.volume=value;return false}catch(error){savedVolumeRangeError=error;return error instanceof D&&error.name==="IndexSizeError"&&error.code===1&&error.message==="Volume must be in the range 0.0 to 1.0, inclusive"&&video.volume===0.25}}))return false;
 let conversions=0;const object={[Symbol.toPrimitive](){conversions++;throw "must not convert"},valueOf(){conversions++;throw "must not convert"}};
 const revoked=Proxy.revocable({},{});revoked.revoke();
 const truthy=[object,revoked.proxy,[],{},Symbol(),1n,"0",Object(false),Object(0n)];
 const falsy=[undefined,null,false,0,-0,NaN,"",0n];
 if(!truthy.every(value=>{video.muted=value;return video.muted===true})||!falsy.every(value=>{video.muted=value;return video.muted===false})||conversions!==0)return false;
 video.muted=true;muted.set.call(video);if(video.muted!==false)return false;
 try{volume.set.call(video);return false}catch(error){if(!(error instanceof TypeError))return false}
 video.volume=0;video.volume=-0;if(!Object.is(video.volume,0))return false;
 globalThis.Number=function(){throw "author Number"};globalThis.Boolean=function(){throw "author Boolean"};globalThis.DOMException=function(){throw "author DOMException"};
 video.volume="1";video.muted=object;
 try{video.volume=2;return false}catch(error){return error instanceof D&&error.name==="IndexSizeError"&&video.volume===1&&video.muted===true&&conversions===0}
})()')! == 'true'
	assert media.volume() == 1 && media.muted()
	native := runtime.native_dom_exception(runtime.evaluate_host_value('savedVolumeRangeError')!)!
	assert native.dom_exception_ != none
	media_pointer := voidptr(media)
	mut owner := unsafe { &html.HTMLMediaElement(media_pointer) }
	owner.load()!
}

fn test_native_volume_writes_update_effective_volume_and_queue_live_owner_events() {
	$if !darwin { return }
	mut runtime, media := native_media_volume_fixture(none)!
	defer { runtime.close() }
	state := &NativeMediaVolumeObservation{}
	mut owner := unsafe { &html.HTMLMediaElement(media) }
	owner.set_playback_manager_hooks(html.MediaPlaybackManagerHooks{
		set_volume: fn [state] (value f64) {
			mut observation := unsafe { &NativeMediaVolumeObservation(state) }
			observation.hook_values << value
		}
	})
	assert runtime.evaluate_host(r'globalThis.nativeVolumeEvents=[];globalThis.nativeVolumeChecks=[];globalThis.savedNativeVolumeEvent=null;
 video.addEventListener("volumechange",function(event){nativeVolumeEvents.push([video.volume,video.muted]);nativeVolumeChecks.push(this===video&&event.target===video&&event.currentTarget===video&&event instanceof Event&&event.isTrusted&&!event.bubbles&&!event.cancelable);savedNativeVolumeEvent=event});
 audio.addEventListener("volumechange",()=>nativeVolumeChecks.push(false));
 video.volume=0.5;video.muted=true;video.volume=0.75;video.volume=0.75;video.muted=true;
 nativeVolumeEvents.length===0&&video.volume===0.75&&video.muted===true&&!Object.hasOwn(video,"volume")&&!Object.hasOwn(video,"muted")')! == 'true'
	assert owner.volume() == 0.75 && owner.muted()
	assert state.hook_values == [0.5, 0.0, 0.0]
	mut loop := html.main_thread_event_loop()
	loop.perform_a_microtask_checkpoint()
	assert runtime.evaluate_host('nativeVolumeEvents.length===0')! == 'true'
	for _ in 0 .. 100 {
		if media.event_count('volumechange') == 3 { break
		 }
		loop.process()
	}
	assert runtime.evaluate_host('nativeVolumeEvents.length===3&&nativeVolumeEvents.every(value=>value[0]===0.75&&value[1]===true)&&nativeVolumeChecks.length===3&&nativeVolumeChecks.every(Boolean)&&savedNativeVolumeEvent.currentTarget===null&&audio.volume===1&&audio.muted===false')! == 'true'
	owner.set_page_muted(true)
	assert runtime.evaluate_host('video.muted=false;video.volume===0.75&&video.muted===false&&nativeVolumeEvents.length===3')! == 'true'
	assert owner.effective_media_volume() == 0 && state.hook_values == [0.5, 0.0, 0.0, 0.0, 0.0]
	owner.set_page_muted(false)
	assert owner.effective_media_volume() == 0.75
	assert state.hook_values == [0.5, 0.0, 0.0, 0.0, 0.0, 0.75]
	for _ in 0 .. 100 {
		if media.event_count('volumechange') == 4 { break
		 }
		loop.process()
	}
	assert runtime.evaluate_host('nativeVolumeEvents.length===4&&nativeVolumeEvents[3][0]===0.75&&nativeVolumeEvents[3][1]===false&&nativeVolumeChecks.every(Boolean)')! == 'true'
	settings := unsafe { &html.EnvironmentSettingsObject(media.document()?.relevant_settings_object()) }
	assert settings.realm().script_execution_depth == 0
		&& settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
}

fn test_native_volume_conversion_precedes_replay_and_preserves_original_exceptions() {
	$if !darwin { return }
	probe := &NativeMediaVolumeObservation{}
	mut runtime, media := native_media_volume_fixture(fn [probe] (runtime &Runtime) ! {
		mut state := unsafe { &NativeMediaVolumeObservation(probe) }
		state.reads++
		mut owner := unsafe { &Runtime(runtime) }
		_ = owner.evaluate_host_value('throw volumeReplayReason')!
	})!
	defer { runtime.close() }
	assert runtime.evaluate_host(r'(()=>{
 globalThis.volumeReplayReason={};globalThis.volumeConversionReason={};
 const p=HTMLMediaElement.prototype,v=Object.getOwnPropertyDescriptor(p,"volume"),m=Object.getOwnPropertyDescriptor(p,"muted");if(!v||!m)return false;
 let getVolume=false,getMuted=false,setVolume=false,setMuted=false,conversion=false,finite=false,booleanConversions=0;
 try{v.get.call(video)}catch(error){getVolume=error===volumeReplayReason}
 try{m.get.call(video)}catch(error){getMuted=error===volumeReplayReason}
 try{v.set.call(video,{[Symbol.toPrimitive](hint){if(hint!=="number")throw "wrong hint";return 0.5}})}catch(error){setVolume=error===volumeReplayReason}
 try{m.set.call(video,{[Symbol.toPrimitive](){booleanConversions++;throw volumeConversionReason}})}catch(error){setMuted=error===volumeReplayReason}
 try{v.set.call(video,{[Symbol.toPrimitive](){throw volumeConversionReason}})}catch(error){conversion=error===volumeConversionReason}
 try{v.set.call(video,Infinity)}catch(error){finite=error instanceof TypeError}
 return getVolume&&getMuted&&setVolume&&setMuted&&conversion&&finite&&booleanConversions===0;
})()')! == 'true'
	assert probe.reads == 4 && media.volume() == 1 && !media.muted()
}
