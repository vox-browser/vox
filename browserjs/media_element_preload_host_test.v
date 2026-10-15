module browserjs

import dom
import html
import libjs
import math

@[heap]
struct MediaPreloadProbe {
mut:
	replays int
	fetches int
	rewrite_before_operation bool
	element &dom.Element = unsafe { nil }
}

fn media_preload_fixture(replay ?MediaElementReplayHook) !(&Runtime, &MediaElementHost, &dom.Document, &dom.Element, &html.HTMLMediaElement) {
	address := dom.URL{ value: 'https://media-preload.example.test/' }
	mut document := html.parse_navigation_document('<!doctype html><video id="preload-video"></video><audio id="preload-audio" preload="MeTaDaTa"></audio>',
		address, address.origin(), none)!
	mut runtime := Runtime.create()
	mut host := MediaElementHost.create(document, replay)!
	host.install(mut runtime)!
	for key, element in host.elements_for_binding() {
		if element.local_name() == 'video' {
			runtime.evaluate_host('globalThis.mediaPreloadVideo={};__ladybirdMediaElementBind(mediaPreloadVideo,"' + key + '","video");0')!
		} else if element.local_name() == 'audio' {
			runtime.evaluate_host('globalThis.mediaPreloadAudio={};__ladybirdMediaElementBind(mediaPreloadAudio,"' + key + '","audio");0')!
		}
	}
	element := document.get_element_by_id('preload-video') or { return error('Missing preload video') }
	media := html.html_media_element_for_dom_element(element) or { return error('Missing preload media owner') }
	return runtime, host, document, element, media
}

fn test_native_preload_metadata_brands_precede_dom_string_conversion_and_replay() {
	$if !darwin { return }
	probe := &MediaPreloadProbe{}
	mut runtime, _, mut document, element, _ := media_preload_fixture(fn [probe] (_ &Runtime) ! {
		mut observed := unsafe { &MediaPreloadProbe(probe) }
		observed.replays++
		if observed.rewrite_before_operation {
			mut owner := unsafe { &dom.Element(observed.element) }
			owner.set_attribute_value('preload', 'NOnE')
		}
	})!
	defer {
		runtime.close()
		document.finalize()
	}
	mut observed := unsafe { &MediaPreloadProbe(probe) }
	observed.element = element
	assert runtime.evaluate_host(r'(()=>{
 const p=HTMLMediaElement.prototype,d=Object.getOwnPropertyDescriptor(p,"preload");
 if(!d||!d.enumerable||!d.configurable||d.value!==undefined||d.get.name!=="get preload"||d.get.length!==0||d.set.name!=="set preload"||d.set.length!==1||Object.hasOwn(mediaPreloadVideo,"preload")||Object.hasOwn(mediaPreloadAudio,"preload")||Object.getPrototypeOf(p)!==EventTarget.prototype)return false;
 if(![d.get,d.set].every(fn=>Function.prototype.toString.call(fn).includes("[native code]")))return false;
 let traps=0,conversions=0;
 const proxy=new Proxy(mediaPreloadVideo,{get(){traps++;throw "proxy"},getPrototypeOf(){traps++;throw "proxy"}});
 const revoked=Proxy.revocable(mediaPreloadVideo,{});revoked.revoke();
 const value={[Symbol.toPrimitive](){conversions++;throw "conversion"}};
 return [Object.create(p),proxy,revoked.proxy,null,undefined,1,{}].every(receiver=>{
  try{d.get.call(receiver);return false}catch(error){if(!(error instanceof TypeError)||error.message!=="Not an object of type HTMLMediaElement")return false}
  for(const args of [[],[value],[Symbol()]]){try{d.set.apply(receiver,args);return false}catch(error){if(!(error instanceof TypeError)||error.message!=="Not an object of type HTMLMediaElement")return false}}
  return true;
 })&&traps===0&&conversions===0;
})()')! == 'true'
	assert probe.replays == 0 && !element.has_attribute('preload')
	assert runtime.evaluate_host('mediaPreloadVideo.preload==="metadata"&&mediaPreloadAudio.preload==="metadata"')! == 'true'
	assert document.get_element_by_id('preload-audio')?.get_attribute('preload')? == 'MeTaDaTa'
	observed.rewrite_before_operation = true
	assert runtime.evaluate_host('mediaPreloadVideo.preload==="none"')! == 'true'
	assert element.get_attribute('preload')? == 'NOnE'
	assert runtime.evaluate_host('Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"preload").set.call(mediaPreloadVideo)===undefined')! == 'true'
	assert element.get_attribute('preload')? == 'undefined' && probe.replays == 4
}

fn test_native_preload_preserves_raw_dom_strings_and_orders_conversion_replay_then_string_sync() {
	$if !darwin { return }
	probe := &MediaPreloadProbe{}
	mut runtime, _, mut document, mut element, mut media := media_preload_fixture(fn [probe] (runtime &Runtime) ! {
		mut observed := unsafe { &MediaPreloadProbe(probe) }
		observed.replays++
		_ = runtime.evaluate_host('mediaPreloadOrder.push("replay");0')!
	})!
	defer {
		runtime.close()
		document.finalize()
	}
	media.set_fetch_hook(fn [probe] (_ dom.URL, _ u64) !html.MediaResourceResponse {
		mut observed := unsafe { &MediaPreloadProbe(probe) }
		observed.fetches++
		return error('resource-less preload reflection must not fetch')
	})
	assert runtime.evaluate_host(r'globalThis.mediaPreloadOrder=[];globalThis.mediaPreloadSync=[];__ladybirdMediaElementSetAttributeSync(function(receiver,name,value){mediaPreloadOrder.push("sync");mediaPreloadSync.push([receiver,name,value])});(()=>{
 const setter=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"preload").set;
 const rows=[["none","none"],["NONE","none"],["MeTaDaTa","metadata"],["auto","auto"],["AUTO","auto"],["","metadata"],["invalid","metadata"],[" none ","metadata"],["\tnone","metadata"],["none\u0000","metadata"],["none\u{1F642}","metadata"],["\uD800","metadata"]];
 for(const [raw,canonical] of rows){if(setter.call(mediaPreloadVideo,raw)!==undefined||mediaPreloadVideo.preload!==canonical)return false;const saved=mediaPreloadSync[mediaPreloadSync.length-1];if(saved[0]!==mediaPreloadVideo||saved[1]!=="preload"||typeof saved[2]!=="string"||saved[2]!==raw)return false}
 const primitives=[[undefined,"undefined"],[null,"null"],[true,"true"],[false,"false"],[0,"0"],[-0,"0"],[NaN,"NaN"],[Infinity,"Infinity"],[12n,"12"],[Object(12n),"12"]];
 for(const [value,raw] of primitives){setter.call(mediaPreloadAudio,value);if(mediaPreloadAudio.preload!=="metadata"||mediaPreloadSync[mediaPreloadSync.length-1][2]!==raw)return false}
 globalThis.mediaPreloadAuthorStringCalls=0;globalThis.String=function(){mediaPreloadAuthorStringCalls++;throw "author String"};
 mediaPreloadOrder.length=0;let conversions=0;
 const value={[Symbol.toPrimitive](hint){conversions++;mediaPreloadOrder.push("convert:"+hint);return "NONE"},toString(){throw "second conversion"},valueOf(){throw "wrong hint"}};
 if(setter.call(mediaPreloadVideo,value,{[Symbol.toPrimitive](){throw "extra argument"}})!==undefined||mediaPreloadVideo.preload!=="none"||conversions!==1||mediaPreloadOrder.join(",")!=="convert:string,replay,sync,replay")return false;
 mediaPreloadOrder.length=0;
 setter.call(mediaPreloadVideo,{toString(){mediaPreloadOrder.push("toString");return {}},valueOf(){mediaPreloadOrder.push("valueOf");return "metadata"}});
 if(mediaPreloadOrder.join(",")!=="toString,valueOf,replay,sync"||mediaPreloadVideo.preload!=="metadata")return false;
 globalThis.mediaPreloadRaw="\u0000\uD800X\uDC00\u{1F642}";setter.call(mediaPreloadVideo,mediaPreloadRaw);
 return mediaPreloadVideo.preload==="metadata"&&mediaPreloadSync[mediaPreloadSync.length-1][2]===mediaPreloadRaw&&mediaPreloadAuthorStringCalls===0;
})()')! == 'true'
	expected_units := [u16(0), 0xd800, 0x58, 0xdc00, 0xd83d, 0xde42]
	assert libjs.utf16_string_from_utf8_without_validation(element.get_attribute('preload')?).code_units() == expected_units
	media.set_preload('none')
	assert element.get_attribute('preload')? == 'none' && media.preload() == 'none'
	element.set_attribute_value('preload', 'AUTO')
	assert runtime.evaluate_host('mediaPreloadVideo.preload==="auto"')! == 'true'
	media.set_preload(none)
	assert !element.has_attribute('preload')
	assert runtime.evaluate_host('mediaPreloadVideo.preload==="metadata"')! == 'true'
	assert probe.fetches == 0 && media.current_src() == '' && media.network_state() == .empty
	assert media.ready_state() == .have_nothing && math.is_nan(media.duration())
	assert media.paused() && !media.ended() && !media.seeking() && media.current_time() == 0
	assert media.volume() == 1 && !media.muted() && media.error() == none
	for name in ['play', 'loadstart', 'volumechange'] { assert media.event_count(name) == 0 }
}

fn test_native_preload_keeps_conversion_and_replay_exception_identity_and_closes_owned_values() {
	$if !darwin { return }
	probe := &MediaPreloadProbe{}
	mut runtime, _, mut document, element, _ := media_preload_fixture(fn [probe] (runtime &Runtime) ! {
		mut observed := unsafe { &MediaPreloadProbe(probe) }
		observed.replays++
		mut owner := unsafe { &Runtime(runtime) }
		_ = owner.evaluate_host_value('throw mediaPreloadReplayReason')!
	})!
	defer {
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host(r'globalThis.mediaPreloadConversionReason={};globalThis.mediaPreloadReplayReason={};globalThis.mediaPreloadSyncCalls=0;__ladybirdMediaElementSetAttributeSync(()=>mediaPreloadSyncCalls++);(()=>{
 const d=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"preload");let conversions=0;
 for(const value of [{[Symbol.toPrimitive](){conversions++;throw mediaPreloadConversionReason}},{get [Symbol.toPrimitive](){throw mediaPreloadConversionReason}}]){try{d.set.call(mediaPreloadVideo,value);return false}catch(error){if(error!==mediaPreloadConversionReason)return false}}
 for(const value of [Symbol(),Object(Symbol()),{[Symbol.toPrimitive](){return {} }}]){try{d.set.call(mediaPreloadVideo,value);return false}catch(error){if(!(error instanceof TypeError))return false}}
 for(const operation of [()=>d.get.call(mediaPreloadVideo),()=>d.set.call(mediaPreloadVideo,{[Symbol.toPrimitive](hint){conversions++;if(hint!=="string")throw "wrong hint";return "auto"}}),()=>d.set.call(mediaPreloadVideo)]){try{operation();return false}catch(error){if(error!==mediaPreloadReplayReason)return false}}
 return conversions===2&&mediaPreloadSyncCalls===0;
})()')! == 'true'
	assert probe.replays == 3 && !element.has_attribute('preload')
	mut normal, mut host, mut normal_document, _, _ := media_preload_fixture(none)!
	defer {
		normal.close()
		normal_document.finalize()
	}
	assert normal.evaluate_host('__ladybirdMediaElementSetAttributeSync(()=>{});mediaPreloadVideo.preload="";mediaPreloadVideo.preload==="metadata"')! == 'true'
	player := normal.evaluate_host_value('mediaPreloadVideo')!
	assert host.attribute_sync != unsafe { nil } && host.bound_elements.len == 2
	normal.close()
	assert normal.closed && normal.context == unsafe { nil } && normal.protected_values_.len == 0
	assert host.attribute_sync == unsafe { nil } && host.bound_elements.len == 0 && host.elements_for_binding().len == 0
	if _ := normal.evaluate_host_value('mediaPreloadVideo.preload') { assert false } else { assert err.msg() == 'JavaScript runtime is closed' }
	if _ := host.preload(player) { assert false } else { assert err.msg() == 'Media element binding is closed' }
	if _ := host.set_preload(player, player) { assert false } else { assert err.msg() == 'Media element binding is closed' }
}
