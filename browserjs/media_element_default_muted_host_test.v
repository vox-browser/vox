module browserjs

import dom
import html
import math

@[heap]
struct MediaDefaultMutedProbe {
mut:
	replays              int
	fetches              int
	volume_updates       []f64
	add_before_operation bool
	element              &dom.Element = unsafe { nil }
}

fn media_default_muted_fixture(replay ?MediaElementReplayHook) !(&Runtime, &MediaElementHost, &dom.Document, &dom.Element, &html.HTMLMediaElement) {
	address := dom.URL{ value: 'https://media-default-muted.example.test/' }
	mut document := html.parse_navigation_document('<!doctype html><video id="default-muted-video"></video><audio id="default-muted-audio" muted="parsed value"></audio>',
		address, address.origin(), none)!
	mut runtime := Runtime.create()
	mut host := MediaElementHost.create(document, replay)!
	host.install(mut runtime)!
	for key, element in host.elements_for_binding() {
		if element.local_name() == 'video' {
			runtime.evaluate_host('globalThis.mediaDefaultMutedVideo={};__ladybirdMediaElementBind(mediaDefaultMutedVideo,"' + key + '","video");0')!
		} else if element.local_name() == 'audio' {
			runtime.evaluate_host('globalThis.mediaDefaultMutedAudio={};__ladybirdMediaElementBind(mediaDefaultMutedAudio,"' + key + '","audio");0')!
		}
	}
	element := document.get_element_by_id('default-muted-video') or { return error('Missing default-muted video') }
	media := html.html_media_element_for_dom_element(element) or { return error('Missing default-muted media owner') }
	return runtime, host, document, element, media
}

fn test_native_default_muted_metadata_and_brand_checks_precede_replay_without_proxy_traps() {
	$if !darwin { return }
	probe := &MediaDefaultMutedProbe{}
	mut runtime, _, mut document, element, _ := media_default_muted_fixture(fn [probe] (_ &Runtime) ! {
		mut state := unsafe { &MediaDefaultMutedProbe(probe) }
		state.replays++
		if state.add_before_operation {
			mut owner := unsafe { &dom.Element(state.element) }
			owner.set_attribute_value('muted', 'replayed')
		}
	})!
	defer {
		runtime.close()
		document.finalize()
	}
	mut observation := unsafe { &MediaDefaultMutedProbe(probe) }
	observation.element = element
	assert runtime.evaluate_host(r'(()=>{
 const p=HTMLMediaElement.prototype,d=Object.getOwnPropertyDescriptor(p,"defaultMuted");
 if(!d||!d.enumerable||!d.configurable||d.value!==undefined||d.get.name!=="get defaultMuted"||d.get.length!==0||d.set.name!=="set defaultMuted"||d.set.length!==1||Object.hasOwn(mediaDefaultMutedVideo,"defaultMuted")||Object.hasOwn(mediaDefaultMutedAudio,"defaultMuted")||Object.getPrototypeOf(p)!==EventTarget.prototype)return false;
 if(![d.get,d.set].every(fn=>Function.prototype.toString.call(fn).includes("[native code]")))return false;
 let traps=0,conversions=0;
 const proxy=new Proxy(mediaDefaultMutedVideo,{get(){traps++;throw "proxy"},getPrototypeOf(){traps++;throw "proxy"}});
 const value={[Symbol.toPrimitive](){conversions++;throw "conversion"},valueOf(){conversions++;throw "conversion"}};
 const revoked=Proxy.revocable(mediaDefaultMutedVideo,{});revoked.revoke();
 const passed=[Object.create(p),proxy,revoked.proxy,null,undefined,1,{}].every(receiver=>{
  try{d.get.call(receiver);return false}catch(error){if(!(error instanceof TypeError)||error.message!=="Not an object of type HTMLMediaElement")return false}
  for(const args of [[],[value]]){try{d.set.apply(receiver,args);return false}catch(error){if(!(error instanceof TypeError)||error.message!=="Not an object of type HTMLMediaElement")return false}}
  return true;
 });return passed&&traps===0&&conversions===0;
})()')! == 'true'
	assert probe.replays == 0 && !element.has_attribute('muted')
	assert runtime.evaluate_host('mediaDefaultMutedVideo.defaultMuted===false&&mediaDefaultMutedAudio.defaultMuted===true')! == 'true'
	assert probe.replays == 2
	observation.add_before_operation = true
	assert runtime.evaluate_host('mediaDefaultMutedVideo.defaultMuted===true')! == 'true'
	assert element.get_attribute('muted')? == 'replayed'
	assert runtime.evaluate_host('Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"defaultMuted").set.call(mediaDefaultMutedVideo,false)===undefined')! == 'true'
	assert probe.replays == 4 && !element.has_attribute('muted')
}

fn test_native_default_muted_boolean_conversion_normalization_and_sync_do_not_change_media_state() {
	$if !darwin { return }
	probe := &MediaDefaultMutedProbe{}
	mut runtime, _, mut document, mut element, mut media := media_default_muted_fixture(fn [probe] (_ &Runtime) ! {
		mut state := unsafe { &MediaDefaultMutedProbe(probe) }
		state.replays++
	})!
	defer {
		runtime.close()
		document.finalize()
	}
	media.set_fetch_hook(fn [probe] (_ dom.URL, _ u64) !html.MediaResourceResponse {
		mut state := unsafe { &MediaDefaultMutedProbe(probe) }
		state.fetches++
		return error('defaultMuted must not fetch')
	})
	media.set_playback_manager_hooks(html.MediaPlaybackManagerHooks{
		set_volume: fn [probe] (volume f64) {
			mut state := unsafe { &MediaDefaultMutedProbe(probe) }
			state.volume_updates << volume
		}
	})
	assert runtime.evaluate_host(r'globalThis.mediaDefaultMutedSync=[];(()=>{
 const register=__ladybirdMediaElementSetAttributeSync;
 for(const args of [[],[undefined],[null],[{}],[1],[()=>{},()=>{}]]){try{register(...args);return false}catch(error){if(!(error instanceof TypeError))return false}}
 const callback=function(receiver,name,present){mediaDefaultMutedSync.push([receiver,name,present]);};
 if(register(callback)!==undefined)return false;
 try{register(callback);return false}catch(error){if(!(error instanceof TypeError))return false}
 let conversions=0;const value={[Symbol.toPrimitive](){conversions++;throw "conversion"},valueOf(){conversions++;throw "conversion"},toString(){conversions++;throw "conversion"}};
 const revoked=Proxy.revocable({},{});revoked.revoke();
 globalThis.Boolean=function(){conversions++;throw "author Boolean"};
 const truthy=[true,1,-1,Infinity,"false",1n,Symbol(),Object(false),{},value,revoked.proxy,[]];
 const falsy=[undefined,null,false,0,-0,NaN,"",0n];
 if(!truthy.every(value=>{mediaDefaultMutedVideo.defaultMuted=value;return mediaDefaultMutedVideo.defaultMuted===true})||!falsy.every(value=>{mediaDefaultMutedVideo.defaultMuted=value;return mediaDefaultMutedVideo.defaultMuted===false}))return false;
 const setter=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"defaultMuted").set;
 if(setter.call(mediaDefaultMutedVideo)!==undefined||mediaDefaultMutedVideo.defaultMuted!==false)return false;
 mediaDefaultMutedAudio.defaultMuted=true;
 return mediaDefaultMutedAudio.defaultMuted===true&&conversions===0&&mediaDefaultMutedSync.length===22&&mediaDefaultMutedSync.every(([receiver,name,present],index)=>name==="muted"&&typeof present==="boolean"&&receiver===(index===21?mediaDefaultMutedAudio:mediaDefaultMutedVideo)&&present===(index<12||index===21));
})()')! == 'true'
	assert probe.replays == 44 && !element.has_attribute('muted')
	assert document.get_element_by_id('default-muted-audio')?.get_attribute('muted')? == ''
	element.set_attribute_value('muted', 'nonempty existing value')
	assert runtime.evaluate_host('mediaDefaultMutedVideo.defaultMuted=true;mediaDefaultMutedVideo.defaultMuted===true&&mediaDefaultMutedSync.length===23')! == 'true'
	assert element.get_attribute('muted')? == '' && probe.replays == 46
	element.remove_attribute('muted')
	assert runtime.evaluate_host('mediaDefaultMutedVideo.defaultMuted===false')! == 'true'
	assert probe.replays == 47 && probe.fetches == 0 && probe.volume_updates == []
	assert !media.muted() && media.volume() == 1 && media.paused() && media.current_time() == 0
	assert media.current_src() == '' && media.network_state() == .empty && media.ready_state() == .have_nothing
	assert math.is_nan(media.duration()) && media.error() == none && !media.seeking() && !media.ended()
	for name in ['volumechange', 'ratechange', 'play', 'loadstart'] { assert media.event_count(name) == 0 }
}

fn test_native_default_muted_preserves_replay_exception_identity_and_releases_sync_on_close() {
	$if !darwin { return }
	probe := &MediaDefaultMutedProbe{}
	mut runtime, _, mut document, element, media := media_default_muted_fixture(fn [probe] (runtime &Runtime) ! {
		mut state := unsafe { &MediaDefaultMutedProbe(probe) }
		state.replays++
		mut owner := unsafe { &Runtime(runtime) }
		_ = owner.evaluate_host_value('throw mediaDefaultMutedReplayReason')!
	})!
	defer {
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host(r'globalThis.mediaDefaultMutedReplayReason={};globalThis.mediaDefaultMutedSyncCalls=0;__ladybirdMediaElementSetAttributeSync(()=>mediaDefaultMutedSyncCalls++);(()=>{
 const d=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"defaultMuted");let conversions=0;
 const value={[Symbol.toPrimitive](){conversions++;throw "conversion"}};
 for(const operation of [()=>d.get.call(mediaDefaultMutedVideo),()=>d.set.call(mediaDefaultMutedVideo,value),()=>d.set.call(mediaDefaultMutedVideo)]){try{operation();return false}catch(error){if(error!==mediaDefaultMutedReplayReason)return false}}
 return conversions===0&&mediaDefaultMutedSyncCalls===0;
})()')! == 'true'
	assert probe.replays == 3 && !element.has_attribute('muted') && !media.muted()
	mut normal, mut host, mut normal_document, _, _ := media_default_muted_fixture(none)!
	defer {
		normal.close()
		normal_document.finalize()
	}
	assert normal.evaluate_host('__ladybirdMediaElementSetAttributeSync(()=>{});mediaDefaultMutedVideo.defaultMuted=true;mediaDefaultMutedVideo.defaultMuted===true')! == 'true'
	player := normal.evaluate_host_value('mediaDefaultMutedVideo')!
	assert host.attribute_sync != unsafe { nil } && host.bound_elements.len == 2
	normal.close()
	assert normal.closed && normal.context == unsafe { nil } && normal.protected_values_.len == 0
	assert host.attribute_sync == unsafe { nil } && host.bound_elements.len == 0 && host.elements_for_binding().len == 0
	if _ := normal.evaluate_host_value('mediaDefaultMutedVideo.defaultMuted') { assert false } else { assert err.msg() == 'JavaScript runtime is closed' }
	if _ := host.default_muted(player) { assert false } else { assert err.msg() == 'Media element binding is closed' }
	if _ := host.set_default_muted(player, player) { assert false } else { assert err.msg() == 'Media element binding is closed' }
}
