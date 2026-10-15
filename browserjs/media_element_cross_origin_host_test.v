module browserjs

import dom
import html
import libjs
import math

@[heap]
struct MediaCrossOriginProbe {
mut:
	replays int
	fetches int
	rewrite_before_operation bool
	element &dom.Element = unsafe { nil }
}

fn media_cross_origin_fixture(replay ?MediaElementReplayHook) !(&Runtime, &MediaElementHost, &dom.Document, &dom.Element, &html.HTMLMediaElement) {
	address := dom.URL{ value: 'https://media-cross-origin.example.test/' }
	mut document := html.parse_navigation_document('<!doctype html><video id="cross-origin-video"></video><audio id="cross-origin-audio" crossorigin="USE-CREDENTIALS"></audio>',
		address, address.origin(), none)!
	mut runtime := Runtime.create()
	mut host := MediaElementHost.create(document, replay)!
	host.install(mut runtime)!
	for key, element in host.elements_for_binding() {
		if element.local_name() == 'video' {
			runtime.evaluate_host('globalThis.mediaCrossOriginVideo={};__ladybirdMediaElementBind(mediaCrossOriginVideo,"' + key + '","video");0')!
		} else if element.local_name() == 'audio' {
			runtime.evaluate_host('globalThis.mediaCrossOriginAudio={};__ladybirdMediaElementBind(mediaCrossOriginAudio,"' + key + '","audio");0')!
		}
	}
	element := document.get_element_by_id('cross-origin-video') or { return error('Missing cross-origin video') }
	media := html.html_media_element_for_dom_element(element) or { return error('Missing cross-origin media owner') }
	return runtime, host, document, element, media
}

fn test_native_cross_origin_metadata_brands_precede_dom_string_conversion_and_replay() {
	$if !darwin { return }
	probe := &MediaCrossOriginProbe{}
	mut runtime, _, mut document, element, _ := media_cross_origin_fixture(fn [probe] (_ &Runtime) ! {
		mut observed := unsafe { &MediaCrossOriginProbe(probe) }
		observed.replays++
		if observed.rewrite_before_operation {
			mut owner := unsafe { &dom.Element(observed.element) }
			owner.set_attribute_value('crossorigin', 'UsE-CrEdEnTiAlS')
		}
	})!
	defer {
		runtime.close()
		document.finalize()
	}
	mut observed := unsafe { &MediaCrossOriginProbe(probe) }
	observed.element = element
	assert runtime.evaluate_host(r'(()=>{
 const p=HTMLMediaElement.prototype,d=Object.getOwnPropertyDescriptor(p,"crossOrigin");
 if(!d||!d.enumerable||!d.configurable||d.value!==undefined||d.get.name!=="get crossOrigin"||d.get.length!==0||d.set.name!=="set crossOrigin"||d.set.length!==1||Object.hasOwn(mediaCrossOriginVideo,"crossOrigin")||Object.hasOwn(mediaCrossOriginAudio,"crossOrigin")||Object.getPrototypeOf(p)!==EventTarget.prototype)return false;
 if(![d.get,d.set].every(fn=>Function.prototype.toString.call(fn).includes("[native code]")))return false;
 let traps=0,conversions=0;
 const proxy=new Proxy(mediaCrossOriginVideo,{get(){traps++;throw "proxy"},getPrototypeOf(){traps++;throw "proxy"}});
 const revoked=Proxy.revocable(mediaCrossOriginVideo,{});revoked.revoke();
 const value={[Symbol.toPrimitive](){conversions++;throw "conversion"}};
 return [Object.create(p),proxy,revoked.proxy,null,undefined,1,{}].every(receiver=>{
  try{d.get.call(receiver);return false}catch(error){if(!(error instanceof TypeError)||error.message!=="Not an object of type HTMLMediaElement")return false}
  for(const args of [[],[value],[Symbol()]]){try{d.set.apply(receiver,args);return false}catch(error){if(!(error instanceof TypeError)||error.message!=="Not an object of type HTMLMediaElement")return false}}
  return true;
 })&&traps===0&&conversions===0;
})()')! == 'true'
	assert probe.replays == 0 && !element.has_attribute('crossorigin')
	assert runtime.evaluate_host('mediaCrossOriginVideo.crossOrigin===null&&mediaCrossOriginAudio.crossOrigin==="use-credentials"')! == 'true'
	assert document.get_element_by_id('cross-origin-audio')?.get_attribute('crossorigin')? == 'USE-CREDENTIALS'
	observed.rewrite_before_operation = true
	assert runtime.evaluate_host('mediaCrossOriginVideo.crossOrigin==="use-credentials"')! == 'true'
	assert element.get_attribute('crossorigin')? == 'UsE-CrEdEnTiAlS'
	assert runtime.evaluate_host('Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"crossOrigin").set.call(mediaCrossOriginVideo)===undefined')! == 'true'
	assert !element.has_attribute('crossorigin') && probe.replays == 4
}

fn test_native_cross_origin_nullable_conversion_raw_strings_and_enum_reads_preserve_media_state() {
	$if !darwin { return }
	probe := &MediaCrossOriginProbe{}
	mut runtime, _, mut document, mut element, mut media := media_cross_origin_fixture(fn [probe] (runtime &Runtime) ! {
		mut observed := unsafe { &MediaCrossOriginProbe(probe) }
		observed.replays++
		_ = runtime.evaluate_host('mediaCrossOriginOrder.push("replay");0')!
	})!
	defer {
		runtime.close()
		document.finalize()
	}
	media.set_fetch_hook(fn [probe] (_ dom.URL, _ u64) !html.MediaResourceResponse {
		mut observed := unsafe { &MediaCrossOriginProbe(probe) }
		observed.fetches++
		return error('crossOrigin reflection must not fetch')
	})
	assert runtime.evaluate_host(r'globalThis.mediaCrossOriginOrder=[];globalThis.mediaCrossOriginSync=[];__ladybirdMediaElementSetAttributeSync(function(receiver,name,value){mediaCrossOriginOrder.push("sync");mediaCrossOriginSync.push([receiver,name,value])});(()=>{
 const setter=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"crossOrigin").set;
 const rows=[["anonymous","anonymous"],["ANONYMOUS","anonymous"],["use-credentials","use-credentials"],["UsE-CrEdEnTiAlS","use-credentials"],["","anonymous"],["invalid","anonymous"],[" use-credentials ","anonymous"],["use-credentials\u0000","anonymous"],["\uD800","anonymous"],["\u{1F642}","anonymous"]];
 for(const [raw,canonical] of rows){if(setter.call(mediaCrossOriginVideo,raw)!==undefined||mediaCrossOriginVideo.crossOrigin!==canonical)return false;const saved=mediaCrossOriginSync[mediaCrossOriginSync.length-1];if(saved[0]!==mediaCrossOriginVideo||saved[1]!=="crossorigin"||typeof saved[2]!=="string"||saved[2]!==raw)return false}
 for(const value of [null,undefined]){setter.call(mediaCrossOriginVideo,value);if(mediaCrossOriginVideo.crossOrigin!==null||mediaCrossOriginSync[mediaCrossOriginSync.length-1][2]!==false)return false}
 if(setter.call(mediaCrossOriginVideo)!==undefined||mediaCrossOriginVideo.crossOrigin!==null||mediaCrossOriginSync[mediaCrossOriginSync.length-1][2]!==false)return false;
 const primitives=[[true,"true"],[false,"false"],[0,"0"],[-0,"0"],[NaN,"NaN"],[Infinity,"Infinity"],[12n,"12"],[Object(12n),"12"]];
 for(const [value,raw] of primitives){setter.call(mediaCrossOriginAudio,value);if(mediaCrossOriginAudio.crossOrigin!=="anonymous"||mediaCrossOriginSync[mediaCrossOriginSync.length-1][2]!==raw)return false}
 globalThis.mediaCrossOriginAuthorStringCalls=0;globalThis.String=function(){mediaCrossOriginAuthorStringCalls++;throw "author String"};
 mediaCrossOriginOrder.length=0;let conversions=0;
 const value={[Symbol.toPrimitive](hint){conversions++;mediaCrossOriginOrder.push("convert:"+hint);return "USE-CREDENTIALS"},toString(){throw "second conversion"},valueOf(){throw "wrong hint"}};
 if(setter.call(mediaCrossOriginVideo,value,{[Symbol.toPrimitive](){throw "extra conversion"}})!==undefined||mediaCrossOriginVideo.crossOrigin!=="use-credentials"||conversions!==1||mediaCrossOriginOrder.join(",")!=="convert:string,replay,sync,replay")return false;
 mediaCrossOriginOrder.length=0;setter.call(mediaCrossOriginAudio,{toString(){mediaCrossOriginOrder.push("toString");return {}},valueOf(){mediaCrossOriginOrder.push("valueOf");return "anonymous"}});
 if(mediaCrossOriginOrder.join(",")!=="toString,valueOf,replay,sync"||mediaCrossOriginAudio.crossOrigin!=="anonymous")return false;
 for(const [value,raw] of [[{[Symbol.toPrimitive](){return null}},"null"],[{[Symbol.toPrimitive](){return undefined}},"undefined"]]){setter.call(mediaCrossOriginAudio,value);if(mediaCrossOriginAudio.crossOrigin!=="anonymous"||mediaCrossOriginSync[mediaCrossOriginSync.length-1][2]!==raw)return false}
 globalThis.mediaCrossOriginRaw="\u0000\uD800X\uDC00\u{1F642}";setter.call(mediaCrossOriginVideo,mediaCrossOriginRaw);
 return mediaCrossOriginVideo.crossOrigin==="anonymous"&&mediaCrossOriginSync[mediaCrossOriginSync.length-1][2]===mediaCrossOriginRaw&&mediaCrossOriginAuthorStringCalls===0;
})()')! == 'true'
	assert libjs.utf16_string_from_utf8_without_validation(element.get_attribute('crossorigin')?).code_units() == [u16(0), 0xd800, 0x58, 0xdc00, 0xd83d, 0xde42]
	assert media.crossorigin() == .anonymous && media.cross_origin()? == 'anonymous'
	media.set_crossorigin('USE-CREDENTIALS')
	assert element.get_attribute('crossorigin')? == 'USE-CREDENTIALS' && media.crossorigin() == .use_credentials
	element.remove_attribute('crossorigin')
	assert runtime.evaluate_host('mediaCrossOriginVideo.crossOrigin===null')! == 'true'
	assert media.crossorigin() == .no_cors && media.cross_origin() == none
	assert probe.fetches == 0 && media.current_src() == '' && media.network_state() == .empty
	assert media.ready_state() == .have_nothing && math.is_nan(media.duration())
	assert media.paused() && !media.ended() && !media.seeking() && media.current_time() == 0
	assert media.volume() == 1 && !media.muted() && media.error() == none
	for name in ['loadstart', 'play', 'volumechange'] { assert media.event_count(name) == 0 }
}

fn test_native_cross_origin_keeps_conversion_and_replay_exception_identity_and_closes_owned_values() {
	$if !darwin { return }
	probe := &MediaCrossOriginProbe{}
	mut runtime, _, mut document, element, _ := media_cross_origin_fixture(fn [probe] (runtime &Runtime) ! {
		mut observed := unsafe { &MediaCrossOriginProbe(probe) }
		observed.replays++
		mut owner := unsafe { &Runtime(runtime) }
		_ = owner.evaluate_host_value('throw mediaCrossOriginReplayReason')!
	})!
	defer {
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host(r'globalThis.mediaCrossOriginConversionReason={};globalThis.mediaCrossOriginReplayReason={};globalThis.mediaCrossOriginSyncCalls=0;__ladybirdMediaElementSetAttributeSync(()=>mediaCrossOriginSyncCalls++);(()=>{
 const d=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"crossOrigin");let conversions=0;
 for(const value of [{[Symbol.toPrimitive](){conversions++;throw mediaCrossOriginConversionReason}},{get [Symbol.toPrimitive](){throw mediaCrossOriginConversionReason}}]){try{d.set.call(mediaCrossOriginVideo,value);return false}catch(error){if(error!==mediaCrossOriginConversionReason)return false}}
 for(const value of [Symbol(),Object(Symbol()),{[Symbol.toPrimitive](){return {} }}]){try{d.set.call(mediaCrossOriginVideo,value);return false}catch(error){if(!(error instanceof TypeError))return false}}
 for(const operation of [()=>d.get.call(mediaCrossOriginVideo),()=>d.set.call(mediaCrossOriginVideo,{[Symbol.toPrimitive](hint){conversions++;if(hint!=="string")throw "wrong hint";return "use-credentials"}}),()=>d.set.call(mediaCrossOriginVideo)]){try{operation();return false}catch(error){if(error!==mediaCrossOriginReplayReason)return false}}
 return conversions===2&&mediaCrossOriginSyncCalls===0;
})()')! == 'true'
	assert probe.replays == 3 && !element.has_attribute('crossorigin')
	mut normal, mut host, mut normal_document, _, _ := media_cross_origin_fixture(none)!
	defer {
		normal.close()
		normal_document.finalize()
	}
	assert normal.evaluate_host('__ladybirdMediaElementSetAttributeSync(()=>{});mediaCrossOriginVideo.crossOrigin="";mediaCrossOriginVideo.crossOrigin==="anonymous"')! == 'true'
	player := normal.evaluate_host_value('mediaCrossOriginVideo')!
	assert host.attribute_sync != unsafe { nil } && host.bound_elements.len == 2
	normal.close()
	assert normal.closed && normal.context == unsafe { nil } && normal.protected_values_.len == 0
	assert host.attribute_sync == unsafe { nil } && host.bound_elements.len == 0 && host.elements_for_binding().len == 0
	if _ := normal.evaluate_host_value('mediaCrossOriginVideo.crossOrigin') { assert false } else { assert err.msg() == 'JavaScript runtime is closed' }
	if _ := host.cross_origin(player) { assert false } else { assert err.msg() == 'Media element binding is closed' }
	if _ := host.set_cross_origin(player, player) { assert false } else { assert err.msg() == 'Media element binding is closed' }
}
