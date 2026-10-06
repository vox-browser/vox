module browserjs

import dom
import html

@[heap]
struct MediaRateReplayProbe {
mut:
	reads int
}

fn native_media_rate_fixture(replay ?MediaElementReplayHook) !(&Runtime, &html.HTMLMediaElement) {
	address := dom.URL{
		value: 'https://native-media-rate-properties.example.test/'
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

fn test_native_media_rate_accessors_check_the_receiver_before_conversion_and_replay() {
	$if !darwin { return }
	probe := &MediaRateReplayProbe{}
	mut runtime, _ := native_media_rate_fixture(fn [probe] (_ &Runtime) ! {
		mut state := unsafe { &MediaRateReplayProbe(probe) }
		state.reads++
	})!
	defer { runtime.close() }
	assert runtime.evaluate_host(r'(()=>{
 let traps=0,conversions=0;
 const p=HTMLMediaElement.prototype,proxy=new Proxy(video,{get(){traps++;throw "proxy"},getPrototypeOf(){traps++;throw "proxy"}});
 const value={[Symbol.toPrimitive](){conversions++;return 2}};
 const passed=["defaultPlaybackRate","playbackRate"].every(name=>{
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
	assert runtime.evaluate_host('video.defaultPlaybackRate===1&&video.playbackRate===1')! == 'true'
	assert probe.reads == 2
}

fn test_native_media_rates_convert_restricted_doubles_and_keep_range_errors_as_dom_exceptions() {
	$if !darwin { return }
	mut runtime, media := native_media_rate_fixture(none)!
	defer { runtime.close() }
	assert runtime.evaluate_host(r'(()=>{
 const names=["defaultPlaybackRate","playbackRate"],invalid=[undefined,NaN,Infinity,-Infinity,Symbol(),1n,Object(1n),{valueOf(){return NaN}},{[Symbol.toPrimitive](){return 2n}}];
 if(!names.every(name=>typeof Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,name)?.set==="function"))return false;
 if(!names.every(name=>invalid.every(value=>{try{video[name]=value;return false}catch(error){return error instanceof TypeError&&video[name]===1}})))return false;
 const cases=[["2.5",2.5],[null,0],[false,0],[true,1],["",0],[{valueOf(){return 0.25}},0.25]];
 if(!names.every(name=>cases.every(([value,expected])=>{video[name]=value;return video[name]===expected})))return false;
 video.defaultPlaybackRate=-2;video.defaultPlaybackRate=65;
 const D=DOMException;globalThis.savedRateRangeError=null;
 if(![-1,64.01].every(value=>{try{video.playbackRate=value;return false}catch(error){savedRateRangeError=error;return error instanceof D&&error.name==="NotSupportedError"&&error.code===9&&error.message==="Playback rate is outside of the supported range."&&video.playbackRate===0.25}}))return false;
 const set=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"playbackRate").set;
 try{set.call(video);return false}catch(error){if(!(error instanceof TypeError))return false}
 globalThis.Number=function(){throw "author Number"};globalThis.DOMException=function(){throw "author DOMException"};
 video.playbackRate="64";
 try{video.playbackRate=65;return false}catch(error){return error instanceof D&&error.name==="NotSupportedError"&&video.playbackRate===64&&video.defaultPlaybackRate===65}
})()')! == 'true'
	assert media.playback_rate() == 64 && media.default_playback_rate() == 65
	native := runtime.native_dom_exception(runtime.evaluate_host_value('savedRateRangeError')!)!
	assert native.dom_exception_ != none
	// Clear queued owner tasks before closing their native callbacks.
	media_pointer := voidptr(media)
	mut owner := unsafe { &html.HTMLMediaElement(media_pointer) }
	owner.set_default_playback_rate(1)
	owner.load()!
}

fn test_native_rate_writes_queue_live_dom_events_and_preserve_equal_signed_zero() {
	$if !darwin { return }
	mut runtime, media := native_media_rate_fixture(none)!
	defer { runtime.close() }
	assert runtime.evaluate_host(r'globalThis.nativeRateEvents=[];globalThis.nativeRateChecks=[];globalThis.savedNativeRateEvent=null;
 video.addEventListener("ratechange",function(event){nativeRateEvents.push([video.defaultPlaybackRate,video.playbackRate]);nativeRateChecks.push(this===video&&event.target===video&&event.currentTarget===video&&event instanceof Event&&event.isTrusted&&!event.bubbles&&!event.cancelable);savedNativeRateEvent=event});
 audio.addEventListener("ratechange",()=>nativeRateChecks.push(false));
 video.defaultPlaybackRate=2;video.playbackRate=0.5;video.defaultPlaybackRate=3;video.defaultPlaybackRate=3;
 nativeRateEvents.length===0&&video.defaultPlaybackRate===3&&video.playbackRate===0.5&&!Object.hasOwn(video,"playbackRate")')! == 'true'
	assert media.default_playback_rate() == 3 && media.playback_rate() == 0.5
	mut loop := html.main_thread_event_loop()
	loop.perform_a_microtask_checkpoint()
	assert runtime.evaluate_host('nativeRateEvents.length===0')! == 'true'
	for _ in 0 .. 100 {
		if media.event_count('ratechange') == 3 { break
		 }
		loop.process()
	}
	assert runtime.evaluate_host('nativeRateEvents.length===3&&nativeRateEvents.every(value=>value[0]===3&&value[1]===0.5)&&nativeRateChecks.length===3&&nativeRateChecks.every(Boolean)&&savedNativeRateEvent.currentTarget===null&&audio.defaultPlaybackRate===1&&audio.playbackRate===1')! == 'true'
	assert runtime.evaluate_host(r'video.defaultPlaybackRate=0;video.defaultPlaybackRate=-0;
 video.playbackRate=-0;const negativeCurrent=Object.is(video.playbackRate,-0);video.playbackRate=0;
 Object.is(video.defaultPlaybackRate,-0)&&negativeCurrent&&Object.is(video.playbackRate,0)&&nativeRateEvents.length===3')! == 'true'
	for _ in 0 .. 100 {
		if media.event_count('ratechange') == 5 { break
		 }
		loop.process()
	}
	assert runtime.evaluate_host('nativeRateEvents.length===5&&nativeRateChecks.every(Boolean)')! == 'true'
	settings := unsafe { &html.EnvironmentSettingsObject(media.document()?.relevant_settings_object()) }
	assert settings.realm().script_execution_depth == 0
		&& settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
}

fn test_native_rate_conversion_precedes_replay_and_keeps_original_thrown_values() {
	$if !darwin { return }
	probe := &MediaRateReplayProbe{}
	mut runtime, media := native_media_rate_fixture(fn [probe] (runtime &Runtime) ! {
		mut state := unsafe { &MediaRateReplayProbe(probe) }
		state.reads++
		mut owner := unsafe { &Runtime(runtime) }
		_ = owner.evaluate_host_value('throw rateReplayReason')!
	})!
	defer { runtime.close() }
	assert runtime.evaluate_host(r'globalThis.rateReplayReason={};globalThis.rateConversionReason={};
 ["defaultPlaybackRate","playbackRate"].every(name=>{
  const d=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,name);if(!d)return false;
  let get=false,set=false,conversion=false,finite=false;
  try{d.get.call(video)}catch(error){get=error===rateReplayReason}
  try{d.set.call(video,{[Symbol.toPrimitive](hint){if(hint!=="number")throw "wrong hint";return 2}})}catch(error){set=error===rateReplayReason}
  try{d.set.call(video,{[Symbol.toPrimitive](){throw rateConversionReason}})}catch(error){conversion=error===rateConversionReason}
  try{d.set.call(video,Infinity)}catch(error){finite=error instanceof TypeError}
  return get&&set&&conversion&&finite;
 })')! == 'true'
	assert probe.reads == 4 && media.playback_rate() == 1 && media.default_playback_rate() == 1
}
