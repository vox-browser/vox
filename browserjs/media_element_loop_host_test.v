module browserjs

import dom
import html
import math

@[heap]
struct MediaLoopProbe {
mut:
	replays              int
	fetches              int
	volume_updates       []f64
	add_before_operation bool
	element              &dom.Element = unsafe { nil }
}

fn media_loop_fixture(replay ?MediaElementReplayHook) !(&Runtime, &MediaElementHost, &dom.Document, &dom.Element, &html.HTMLMediaElement) {
	address := dom.URL{ value: 'https://media-loop.example.test/' }
	mut document := html.parse_navigation_document('<!doctype html><video id="loop-video"></video><audio id="loop-audio" loop="parsed value"></audio>',
		address, address.origin(), none)!
	mut runtime := Runtime.create()
	mut host := MediaElementHost.create(document, replay)!
	host.install(mut runtime)!
	for key, element in host.elements_for_binding() {
		if element.local_name() == 'video' {
			runtime.evaluate_host('globalThis.mediaLoopVideo={};__ladybirdMediaElementBind(mediaLoopVideo,"' + key + '","video");0')!
		} else if element.local_name() == 'audio' {
			runtime.evaluate_host('globalThis.mediaLoopAudio={};__ladybirdMediaElementBind(mediaLoopAudio,"' + key + '","audio");0')!
		}
	}
	element := document.get_element_by_id('loop-video') or { return error('Missing loop video') }
	media := html.html_media_element_for_dom_element(element) or { return error('Missing loop media owner') }
	return runtime, host, document, element, media
}

fn test_native_loop_metadata_and_brand_checks_precede_replay_without_proxy_traps() {
	$if !darwin { return }
	probe := &MediaLoopProbe{}
	mut runtime, _, mut document, element, _ := media_loop_fixture(fn [probe] (_ &Runtime) ! {
		mut state := unsafe { &MediaLoopProbe(probe) }
		state.replays++
		if state.add_before_operation {
			mut owner := unsafe { &dom.Element(state.element) }
			owner.set_attribute_value('loop', 'replayed')
		}
	})!
	defer {
		runtime.close()
		document.finalize()
	}
	mut observation := unsafe { &MediaLoopProbe(probe) }
	observation.element = element
	assert runtime.evaluate_host(r'(()=>{
 const p=HTMLMediaElement.prototype,d=Object.getOwnPropertyDescriptor(p,"loop");
 if(!d||!d.enumerable||!d.configurable||d.value!==undefined||d.get.name!=="get loop"||d.get.length!==0||d.set.name!=="set loop"||d.set.length!==1||Object.hasOwn(mediaLoopVideo,"loop")||Object.hasOwn(mediaLoopAudio,"loop")||Object.getPrototypeOf(p)!==EventTarget.prototype)return false;
 if(![d.get,d.set].every(fn=>Function.prototype.toString.call(fn).includes("[native code]")))return false;
 let traps=0,conversions=0;
 const proxy=new Proxy(mediaLoopVideo,{get(){traps++;throw "proxy"},getPrototypeOf(){traps++;throw "proxy"}});
 const value={[Symbol.toPrimitive](){conversions++;throw "conversion"},valueOf(){conversions++;throw "conversion"}};
 const revoked=Proxy.revocable(mediaLoopVideo,{});revoked.revoke();
 const passed=[Object.create(p),proxy,revoked.proxy,null,undefined,1,{}].every(receiver=>{
  try{d.get.call(receiver);return false}catch(error){if(!(error instanceof TypeError)||error.message!=="Not an object of type HTMLMediaElement")return false}
  for(const args of [[],[value]]){try{d.set.apply(receiver,args);return false}catch(error){if(!(error instanceof TypeError)||error.message!=="Not an object of type HTMLMediaElement")return false}}
  return true;
 });return passed&&traps===0&&conversions===0;
})()')! == 'true'
	assert probe.replays == 0 && !element.has_attribute('loop')
	assert runtime.evaluate_host('mediaLoopVideo.loop===false&&mediaLoopAudio.loop===true')! == 'true'
	assert probe.replays == 2
	observation.add_before_operation = true
	assert runtime.evaluate_host('mediaLoopVideo.loop===true')! == 'true'
	assert element.get_attribute('loop')? == 'replayed'
	assert runtime.evaluate_host('Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"loop").set.call(mediaLoopVideo,false)===undefined')! == 'true'
	assert probe.replays == 4 && !element.has_attribute('loop')
}

fn test_native_loop_boolean_conversion_normalization_and_sync_do_not_change_media_state() {
	$if !darwin { return }
	probe := &MediaLoopProbe{}
	mut runtime, _, mut document, mut element, mut media := media_loop_fixture(fn [probe] (_ &Runtime) ! {
		mut state := unsafe { &MediaLoopProbe(probe) }
		state.replays++
	})!
	defer {
		runtime.close()
		document.finalize()
	}
	media.set_fetch_hook(fn [probe] (_ dom.URL, _ u64) !html.MediaResourceResponse {
		mut state := unsafe { &MediaLoopProbe(probe) }
		state.fetches++
		return error('loop must not fetch')
	})
	media.set_playback_manager_hooks(html.MediaPlaybackManagerHooks{
		set_volume: fn [probe] (volume f64) {
			mut state := unsafe { &MediaLoopProbe(probe) }
			state.volume_updates << volume
		}
	})
	assert runtime.evaluate_host(r'globalThis.mediaLoopSync=[];(()=>{
 const register=__ladybirdMediaElementSetAttributeSync;
 for(const args of [[],[undefined],[null],[{}],[1],[()=>{},()=>{}]]){try{register(...args);return false}catch(error){if(!(error instanceof TypeError))return false}}
 const callback=function(receiver,name,present){mediaLoopSync.push([receiver,name,present]);};
 if(register(callback)!==undefined)return false;
 try{register(callback);return false}catch(error){if(!(error instanceof TypeError))return false}
 let conversions=0;const value={[Symbol.toPrimitive](){conversions++;throw "conversion"},valueOf(){conversions++;throw "conversion"},toString(){conversions++;throw "conversion"}};
 const revoked=Proxy.revocable({},{});revoked.revoke();
 globalThis.Boolean=function(){conversions++;throw "author Boolean"};
 const truthy=[true,1,-1,Infinity,"false",1n,Symbol(),Object(false),{},value,revoked.proxy,[]];
 const falsy=[undefined,null,false,0,-0,NaN,"",0n];
 if(!truthy.every(value=>{mediaLoopVideo.loop=value;return mediaLoopVideo.loop===true})||!falsy.every(value=>{mediaLoopVideo.loop=value;return mediaLoopVideo.loop===false}))return false;
 const setter=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"loop").set;
 if(setter.call(mediaLoopVideo)!==undefined||mediaLoopVideo.loop!==false)return false;
 mediaLoopAudio.loop=true;
 return mediaLoopAudio.loop===true&&conversions===0&&mediaLoopSync.length===22&&mediaLoopSync.every(([receiver,name,present],index)=>name==="loop"&&typeof present==="boolean"&&receiver===(index===21?mediaLoopAudio:mediaLoopVideo)&&present===(index<12||index===21));
})()')! == 'true'
	assert probe.replays == 44 && !element.has_attribute('loop')
	assert document.get_element_by_id('loop-audio')?.get_attribute('loop')? == ''
	element.set_attribute_value('loop', 'nonempty existing value')
	assert runtime.evaluate_host('mediaLoopVideo.loop=true;mediaLoopVideo.loop===true&&mediaLoopSync.length===23')! == 'true'
	assert element.get_attribute('loop')? == '' && probe.replays == 46
	element.remove_attribute('loop')
	assert runtime.evaluate_host('mediaLoopVideo.loop===false')! == 'true'
	assert probe.replays == 47 && probe.fetches == 0 && probe.volume_updates == []
	media.set_loop(true)
	assert element.get_attribute('loop')? == '' && media.loop()
	assert runtime.evaluate_host('mediaLoopVideo.loop===true')! == 'true'
	media.set_loop(false)
	assert !element.has_attribute('loop') && !media.loop()
	assert runtime.evaluate_host('mediaLoopVideo.loop===false')! == 'true'
	assert probe.replays == 49 && probe.fetches == 0
	assert !media.muted() && media.volume() == 1 && media.paused() && media.current_time() == 0
	assert media.current_src() == '' && media.network_state() == .empty && media.ready_state() == .have_nothing
	assert math.is_nan(media.duration()) && media.error() == none && !media.seeking() && !media.ended()
	assert !media.loop()
	for name in ['volumechange', 'ratechange', 'play', 'loadstart'] { assert media.event_count(name) == 0 }
}

fn test_native_loop_preserves_replay_exception_identity_and_releases_sync_on_close() {
	$if !darwin { return }
	probe := &MediaLoopProbe{}
	mut runtime, _, mut document, element, media := media_loop_fixture(fn [probe] (runtime &Runtime) ! {
		mut state := unsafe { &MediaLoopProbe(probe) }
		state.replays++
		mut owner := unsafe { &Runtime(runtime) }
		_ = owner.evaluate_host_value('throw mediaLoopReplayReason')!
	})!
	defer {
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host(r'globalThis.mediaLoopReplayReason={};globalThis.mediaLoopSyncCalls=0;__ladybirdMediaElementSetAttributeSync(()=>mediaLoopSyncCalls++);(()=>{
 const d=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"loop");let conversions=0;
 const value={[Symbol.toPrimitive](){conversions++;throw "conversion"}};
 for(const operation of [()=>d.get.call(mediaLoopVideo),()=>d.set.call(mediaLoopVideo,value),()=>d.set.call(mediaLoopVideo)]){try{operation();return false}catch(error){if(error!==mediaLoopReplayReason)return false}}
 return conversions===0&&mediaLoopSyncCalls===0;
})()')! == 'true'
	assert probe.replays == 3 && !element.has_attribute('loop') && !media.loop() && !media.muted()
	mut normal, mut host, mut normal_document, _, _ := media_loop_fixture(none)!
	defer {
		normal.close()
		normal_document.finalize()
	}
	assert normal.evaluate_host('__ladybirdMediaElementSetAttributeSync(()=>{});mediaLoopVideo.loop=true;mediaLoopVideo.loop===true')! == 'true'
	player := normal.evaluate_host_value('mediaLoopVideo')!
	assert host.attribute_sync != unsafe { nil } && host.bound_elements.len == 2
	normal.close()
	assert normal.closed && normal.context == unsafe { nil } && normal.protected_values_.len == 0
	assert host.attribute_sync == unsafe { nil } && host.bound_elements.len == 0 && host.elements_for_binding().len == 0
	if _ := normal.evaluate_host_value('mediaLoopVideo.loop') { assert false } else { assert err.msg() == 'JavaScript runtime is closed' }
	if _ := host.loop(player) { assert false } else { assert err.msg() == 'Media element binding is closed' }
	if _ := host.set_loop(player, player) { assert false } else { assert err.msg() == 'Media element binding is closed' }
}
