module browserjs

import dom
import html
import math

@[heap]
struct MediaControlsProbe {
mut:
	replays              int
	fetches              int
	volume_updates       []f64
	add_before_operation bool
	element              &dom.Element = unsafe { nil }
}

fn media_controls_fixture(replay ?MediaElementReplayHook) !(&Runtime, &MediaElementHost, &dom.Document, &dom.Element, &html.HTMLMediaElement) {
	address := dom.URL{ value: 'https://media-controls.example.test/' }
	mut document := html.parse_navigation_document('<!doctype html><video id="controls-video"></video><audio id="controls-audio" controls="parsed value"></audio>',
		address, address.origin(), none)!
	mut runtime := Runtime.create()
	mut host := MediaElementHost.create(document, replay)!
	host.install(mut runtime)!
	for key, element in host.elements_for_binding() {
		if element.local_name() == 'video' {
			runtime.evaluate_host('globalThis.mediaControlsVideo={};__ladybirdMediaElementBind(mediaControlsVideo,"' + key + '","video");0')!
		} else if element.local_name() == 'audio' {
			runtime.evaluate_host('globalThis.mediaControlsAudio={};__ladybirdMediaElementBind(mediaControlsAudio,"' + key + '","audio");0')!
		}
	}
	element := document.get_element_by_id('controls-video') or { return error('Missing controls video') }
	media := html.html_media_element_for_dom_element(element) or { return error('Missing controls media owner') }
	return runtime, host, document, element, media
}

fn test_native_controls_metadata_and_brand_checks_precede_replay_without_proxy_or_conversion_hooks() {
	$if !darwin { return }
	probe := &MediaControlsProbe{}
	mut runtime, _, mut document, element, _ := media_controls_fixture(fn [probe] (_ &Runtime) ! {
		mut state := unsafe { &MediaControlsProbe(probe) }
		state.replays++
		if state.add_before_operation {
			mut owner := unsafe { &dom.Element(state.element) }
			owner.set_attribute_value('controls', 'replayed')
		}
	})!
	defer {
		runtime.close()
		document.finalize()
	}
	mut observation := unsafe { &MediaControlsProbe(probe) }
	observation.element = element
	assert runtime.evaluate_host(r'(()=>{
 const p=HTMLMediaElement.prototype,d=Object.getOwnPropertyDescriptor(p,"controls");
 if(!d||!d.enumerable||!d.configurable||d.value!==undefined||d.get.name!=="get controls"||d.get.length!==0||d.set.name!=="set controls"||d.set.length!==1||Object.hasOwn(mediaControlsVideo,"controls")||Object.hasOwn(mediaControlsAudio,"controls")||Object.getPrototypeOf(p)!==EventTarget.prototype)return false;
 if(![d.get,d.set].every(fn=>Function.prototype.toString.call(fn).includes("[native code]")))return false;
 let traps=0,conversions=0;
 const proxy=new Proxy(mediaControlsVideo,{get(){traps++;throw "proxy"},getPrototypeOf(){traps++;throw "proxy"}});
 const revoked=Proxy.revocable(mediaControlsVideo,{});revoked.revoke();
 const value={[Symbol.toPrimitive](){conversions++;throw "conversion"},valueOf(){conversions++;throw "conversion"},toString(){conversions++;throw "conversion"}};
 const passed=[Object.create(p),proxy,revoked.proxy,null,undefined,1,{}].every(receiver=>{
  try{d.get.call(receiver);return false}catch(error){if(!(error instanceof TypeError)||error.message!=="Not an object of type HTMLMediaElement")return false}
  for(const args of [[],[value]]){try{d.set.apply(receiver,args);return false}catch(error){if(!(error instanceof TypeError)||error.message!=="Not an object of type HTMLMediaElement")return false}}
  return true;
 });return passed&&traps===0&&conversions===0;
})()')! == 'true'
	assert probe.replays == 0 && !element.has_attribute_ns(none, 'controls')
	assert runtime.evaluate_host('mediaControlsVideo.controls===false&&mediaControlsAudio.controls===true')! == 'true'
	assert probe.replays == 2
	observation.add_before_operation = true
	assert runtime.evaluate_host('mediaControlsVideo.controls===true')! == 'true'
	assert element.get_attribute_ns(none, 'controls')? == 'replayed'
	assert runtime.evaluate_host('Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"controls").set.call(mediaControlsVideo,false)===undefined')! == 'true'
	assert probe.replays == 4 && !element.has_attribute_ns(none, 'controls')
}

fn test_native_controls_boolean_normalization_live_namespace_and_captured_dirty_replay_preserve_media_state() {
	$if !darwin { return }
	probe := &MediaControlsProbe{}
	mut runtime, _, mut document, mut element, mut media := media_controls_fixture(fn [probe] (runtime &Runtime) ! {
		mut state := unsafe { &MediaControlsProbe(probe) }
		state.replays++
		if runtime.evaluate_host('mediaControlsVideoState.attributesDirty===true')! == 'true' {
			mut owner := unsafe { &dom.Element(state.element) }
			present := runtime.evaluate_host('Object.hasOwn(mediaControlsVideoState.attributes,"controls")')! == 'true'
			if present {
				owner.set_attribute_value('controls', '')
			} else {
				owner.remove_attribute_ns(none, 'controls')
			}
			if runtime.evaluate_host('Object.hasOwn(mediaControlsVideoState.attributes,"data-controls-dirty")')! == 'true' {
				owner.set_attribute_value('data-controls-dirty', 'retained')
			}
			_ = runtime.evaluate_host('mediaControlsVideoState.attributesDirty=false;0')!
		}
	})!
	defer {
		runtime.close()
		document.finalize()
	}
	mut observation := unsafe { &MediaControlsProbe(probe) }
	observation.element = element
	media.set_fetch_hook(fn [probe] (_ dom.URL, _ u64) !html.MediaResourceResponse {
		mut state := unsafe { &MediaControlsProbe(probe) }
		state.fetches++
		return error('controls reflection must not fetch')
	})
	media.set_playback_manager_hooks(html.MediaPlaybackManagerHooks{
		set_volume: fn [probe] (volume f64) {
			mut state := unsafe { &MediaControlsProbe(probe) }
			state.volume_updates << volume
		}
	})
	assert !media.has_controls()
	_ = runtime.evaluate_host(media_element_reflection_bootstrap())!
	assert runtime.evaluate_host(r'globalThis.mediaControlsVideoState={attributes:{},attributesDirty:false};globalThis.mediaControlsAudioState={attributes:{controls:"parsed value"},attributesDirty:false};__recordMediaAttributes(mediaControlsVideo,mediaControlsVideoState);__recordMediaAttributes(mediaControlsAudio,mediaControlsAudioState);true')! == 'true'
	element.set_attribute_ns_for_bindings('urn:controls-test', 'controls', 'foreign value')!
	assert element.has_attribute('controls') && !element.has_attribute_ns(none, 'controls')
	assert runtime.evaluate_host('mediaControlsVideo.controls===false')! == 'true'
	assert runtime.evaluate_host(r'(()=>{
 let conversions=0;const value={[Symbol.toPrimitive](){conversions++;throw "conversion"},valueOf(){conversions++;throw "conversion"},toString(){conversions++;throw "conversion"}};
 const revoked=Proxy.revocable({},{});revoked.revoke();
 globalThis.Boolean=function(){conversions++;throw "author Boolean"};
 const truthy=[true,1,-1,Infinity,"false",1n,Symbol(),Object(false),{},value,revoked.proxy,[]];
 const falsy=[undefined,null,false,0,-0,NaN,"",0n];
 if(!truthy.every(value=>{mediaControlsVideo.controls=value;return mediaControlsVideo.controls===true&&mediaControlsVideoState.attributes.controls===""})||!falsy.every(value=>{mediaControlsVideo.controls=value;return mediaControlsVideo.controls===false&&!Object.hasOwn(mediaControlsVideoState.attributes,"controls")}))return false;
 const setter=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"controls").set;
 if(setter.call(mediaControlsVideo)!==undefined||mediaControlsVideo.controls!==false)return false;
 mediaControlsAudio.controls=true;
 return mediaControlsAudio.controls===true&&mediaControlsAudioState.attributes.controls===""&&conversions===0;
})()')! == 'true'
	assert probe.replays == 45 && !element.has_attribute_ns(none, 'controls')
	assert element.get_attribute_ns('urn:controls-test', 'controls')? == 'foreign value'
	audio := document.get_element_by_id('controls-audio') or { panic('Missing controls audio') }
	assert audio.get_attribute_ns(none, 'controls')? == ''
	element.set_attribute_value('controls', 'nonempty existing value')
	assert runtime.evaluate_host('mediaControlsVideo.controls===true')! == 'true'
	assert element.get_attribute_ns(none, 'controls')? == 'nonempty existing value'
	assert runtime.evaluate_host('mediaControlsVideo.controls=true;mediaControlsVideoState.attributes["data-controls-dirty"]="retained";mediaControlsVideoState.attributesDirty=true;mediaControlsVideo.controls===true')! == 'true'
	assert element.get_attribute_ns(none, 'controls')? == ''
	assert element.get_attribute('data-controls-dirty')? == 'retained'
	assert runtime.evaluate_host('mediaControlsVideo.controls=false;mediaControlsVideoState.attributes["data-controls-dirty"]="retained";mediaControlsVideoState.attributesDirty=true;mediaControlsVideo.controls===false')! == 'true'
	assert !element.has_attribute_ns(none, 'controls')
	assert element.get_attribute_ns('urn:controls-test', 'controls')? == 'foreign value'
	element.set_attribute_value('controls', 'direct DOM')
	assert runtime.evaluate_host('mediaControlsVideo.controls===true')! == 'true'
	element.remove_attribute_ns(none, 'controls')
	assert runtime.evaluate_host('mediaControlsVideo.controls===false')! == 'true'
	assert probe.replays == 52 && probe.fetches == 0 && probe.volume_updates == []
	assert !media.has_controls() && !media.muted() && media.volume() == 1 && media.paused()
	assert media.current_time() == 0 && media.current_src() == '' && !media.seeking() && !media.ended()
	assert media.network_state() == .empty && media.ready_state() == .have_nothing
	assert math.is_nan(media.duration()) && media.error() == none
	for name in ['volumechange', 'ratechange', 'play', 'pause', 'loadstart'] { assert media.event_count(name) == 0 }
}

fn test_native_controls_preserves_replay_and_sync_exceptions_before_dom_write_and_releases_roots_on_close() {
	$if !darwin { return }
	probe := &MediaControlsProbe{}
	mut runtime, _, mut document, element, media := media_controls_fixture(fn [probe] (runtime &Runtime) ! {
		mut state := unsafe { &MediaControlsProbe(probe) }
		state.replays++
		mut owner := unsafe { &Runtime(runtime) }
		_ = owner.evaluate_host_value('throw mediaControlsReplayReason')!
	})!
	defer {
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host(r'globalThis.mediaControlsReplayReason={};globalThis.mediaControlsSyncCalls=0;__ladybirdMediaElementSetAttributeSync(()=>mediaControlsSyncCalls++);(()=>{
 const d=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"controls");let conversions=0;
 const value={[Symbol.toPrimitive](){conversions++;throw "conversion"}};
 for(const operation of [()=>d.get.call(mediaControlsVideo),()=>d.set.call(mediaControlsVideo,value),()=>d.set.call(mediaControlsVideo)]){try{operation();return false}catch(error){if(error!==mediaControlsReplayReason)return false}}
 return conversions===0&&mediaControlsSyncCalls===0;
})()')! == 'true'
	assert probe.replays == 3 && !element.has_attribute_ns(none, 'controls') && !media.has_controls()
	mut normal, mut host, mut normal_document, mut normal_element, normal_media := media_controls_fixture(none)!
	defer {
		normal.close()
		normal_document.finalize()
	}
	assert normal.evaluate_host(r'globalThis.mediaControlsSyncReason={};globalThis.mediaControlsRejectSync=true;globalThis.mediaControlsObserved=[];__ladybirdMediaElementSetAttributeSync((receiver,name,present)=>{mediaControlsObserved.push([receiver===mediaControlsVideo,name,present,receiver.controls]);if(mediaControlsRejectSync)throw mediaControlsSyncReason;});(()=>{try{mediaControlsVideo.controls=true;return false}catch(error){return error===mediaControlsSyncReason&&mediaControlsObserved.length===1&&mediaControlsObserved[0][3]===false}})()')! == 'true'
	assert !normal_element.has_attribute_ns(none, 'controls')
	normal_element.set_attribute_value('controls', 'unchanged after failed removal')
	assert normal.evaluate_host('(()=>{try{mediaControlsVideo.controls=false;return false}catch(error){return error===mediaControlsSyncReason&&mediaControlsObserved.length===2&&mediaControlsObserved[1][3]===true}})()')! == 'true'
	assert normal_element.get_attribute_ns(none, 'controls')? == 'unchanged after failed removal'
	assert normal.evaluate_host(r'mediaControlsRejectSync=false;mediaControlsVideo.controls=false;mediaControlsVideo.controls=true;mediaControlsVideo.controls===true&&mediaControlsObserved.length===4&&mediaControlsObserved.every(([receiver,name,present,previous],index)=>receiver&&name==="controls"&&typeof present==="boolean"&&present===(index===0||index===3)&&previous===(index===1||index===2))')! == 'true'
	assert normal_element.get_attribute_ns(none, 'controls')? == '' && !normal_media.has_controls()
	player := normal.evaluate_host_value('mediaControlsVideo')!
	assert host.attribute_sync != unsafe { nil } && host.bound_elements.len == 2
	normal.close()
	assert normal.closed && normal.context == unsafe { nil } && normal.protected_values_.len == 0
	assert host.attribute_sync == unsafe { nil } && host.bound_elements.len == 0 && host.elements_for_binding().len == 0
	if _ := normal.evaluate_host_value('mediaControlsVideo.controls') { assert false } else { assert err.msg() == 'JavaScript runtime is closed' }
	if _ := host.controls(player) { assert false } else { assert err.msg() == 'Media element binding is closed' }
	if _ := host.set_controls(player, player) { assert false } else { assert err.msg() == 'Media element binding is closed' }
}
