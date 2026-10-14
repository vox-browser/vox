module browserjs

import dom
import html
import math

@[heap]
struct MediaCanPlayTypeProbe {
mut:
	replays int
	fetches int
}

fn media_can_play_type_fixture(replay ?MediaElementReplayHook) !(&Runtime, &MediaElementHost, &dom.Document, &html.HTMLMediaElement) {
	address := dom.URL{ value: 'https://media-can-play-type.example.test/' }
	mut document := html.parse_navigation_document('<!doctype html><video id="can-play-video"></video><audio id="can-play-audio"></audio>',
		address, address.origin(), none)!
	mut runtime := Runtime.create()
	mut host := MediaElementHost.create(document, replay)!
	host.install(mut runtime)!
	for key, element in host.elements_for_binding() {
		if element.local_name() == 'video' {
			runtime.evaluate_host('globalThis.mediaCanPlayTypeVideo={};__ladybirdMediaElementBind(mediaCanPlayTypeVideo,"' + key + '","video");0')!
		} else if element.local_name() == 'audio' {
			runtime.evaluate_host('globalThis.mediaCanPlayTypeAudio={};__ladybirdMediaElementBind(mediaCanPlayTypeAudio,"' + key + '","audio");0')!
		}
	}
	element := document.get_element_by_id('can-play-video') or { return error('Missing can-play video') }
	media := html.html_media_element_for_dom_element(element) or { return error('Missing can-play media owner') }
	return runtime, host, document, media
}

fn test_native_media_can_play_type_metadata_and_brand_before_arity_conversion_or_replay() {
	$if !darwin { return }
	probe := &MediaCanPlayTypeProbe{}
	mut runtime, _, mut document, _ := media_can_play_type_fixture(fn [probe] (_ &Runtime) ! {
		mut state := unsafe { &MediaCanPlayTypeProbe(probe) }
		state.replays++
	})!
	defer {
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host(r'(()=>{
 const p=HTMLMediaElement.prototype,d=Object.getOwnPropertyDescriptor(p,"canPlayType");
 if(!d||!d.writable||!d.enumerable||!d.configurable||d.get!==undefined||d.set!==undefined||d.value.name!=="canPlayType"||d.value.length!==1||!Function.prototype.toString.call(d.value).includes("[native code]")||Object.hasOwn(mediaCanPlayTypeVideo,"canPlayType")||Object.hasOwn(mediaCanPlayTypeAudio,"canPlayType")||Object.getPrototypeOf(p)!==EventTarget.prototype)return false;
 let traps=0,conversions=0;
 const proxy=new Proxy(mediaCanPlayTypeVideo,{get(){traps++;throw "proxy"},getPrototypeOf(){traps++;throw "proxy"}});
 const value={[Symbol.toPrimitive](){conversions++;throw "conversion"}};
 if(![Object.create(p),proxy,null,undefined,1,{}].every(receiver=>{
  return [[],[value]].every(args=>{try{d.value.apply(receiver,args);return false}catch(error){return error instanceof TypeError&&error.message==="Not an object of type HTMLMediaElement"}});
 }))return false;
 try{mediaCanPlayTypeVideo.canPlayType();return false}catch(error){return error instanceof TypeError&&error.message==="canPlayType() needs one argument"&&traps===0&&conversions===0}
})()')! == 'true'
	assert probe.replays == 0
	assert runtime.evaluate_host('HTMLMediaElement.prototype.canPlayType.call(mediaCanPlayTypeVideo,"video/mp4")==="maybe"&&HTMLMediaElement.prototype.canPlayType.call(mediaCanPlayTypeAudio,"audio/webm;codecs=opus")==="probably"')! == 'true'
	assert probe.replays == 2
}

fn test_native_media_can_play_type_dom_string_conversion_and_existing_model_results_do_not_mutate_media() {
	$if !darwin { return }
	probe := &MediaCanPlayTypeProbe{}
	mut runtime, _, mut document, mut media := media_can_play_type_fixture(fn [probe] (runtime &Runtime) ! {
		mut state := unsafe { &MediaCanPlayTypeProbe(probe) }
		state.replays++
		_ = runtime.evaluate_host('mediaCanPlayTypeOrder.push("replay");0')!
	})!
	defer {
		runtime.close()
		document.finalize()
	}
	media.set_fetch_hook(fn [probe] (_ dom.URL, _ u64) !html.MediaResourceResponse {
		mut state := unsafe { &MediaCanPlayTypeProbe(probe) }
		state.fetches++
		return error('canPlayType must not fetch')
	})
	// Preserve this model whitelist and substring heuristic, not upstream capabilities.
	assert runtime.evaluate_host(r'globalThis.mediaCanPlayTypeOrder=[];(()=>{
 const cases=[
  ["video/webm","maybe"],["video/mp4","maybe"],["video/mpeg","maybe"],["video/ogg","maybe"],
  ["audio/flac","maybe"],["audio/mp3","maybe"],["audio/mpeg","maybe"],["audio/ogg","maybe"],["audio/wav","maybe"],["audio/webm","maybe"],
  [" \tVIDEO/MP4 ","maybe"],["video/mp4; codecs=\"\"","probably"],["audio/webm; CODECS=unknown","probably"],
  ["audio/ogg;note=codecs=unknown","probably"],["video/mp4; codecs = \"avc1\"","maybe"],
  ["video/mp4;note=\u0000;codecs=x","probably"],["video/mp4;note=\uD800;codecs=x","probably"],["audio/ogg;note=\uDC00\u{1F642}","maybe"],
  ["audio/mp4",""],["video/wav",""],["application/octet-stream",""],["application/json",""],["",""],["video /mp4",""],["video/mp4/extra",""],["\uD800video/mp4",""]
 ];
 return [mediaCanPlayTypeVideo,mediaCanPlayTypeAudio].every(media=>cases.every(([type,result])=>{const actual=media.canPlayType(type);return typeof actual==="string"&&actual===result}));
})()')! == 'true'
	assert probe.replays == 52
	assert runtime.evaluate_host(r'(()=>{
 globalThis.mediaCanPlayTypeAuthorStringCalls=0;globalThis.String=function(){mediaCanPlayTypeAuthorStringCalls++;throw "author String"};
 if(![undefined,null,true,false,0,NaN,Infinity,12n,Object(12n)].every(value=>mediaCanPlayTypeVideo.canPlayType(value)===""))return false;
 if(![Symbol(),Object(Symbol()),{[Symbol.toPrimitive](){return Symbol()}}].every(value=>{try{mediaCanPlayTypeVideo.canPlayType(value);return false}catch(error){return error instanceof TypeError}}))return false;
 let conversions=0;mediaCanPlayTypeOrder.length=0;
 const value={[Symbol.toPrimitive](hint){conversions++;mediaCanPlayTypeOrder.push("convert:"+hint);return "video/mp4;codecs=avc1"},toString(){throw "second conversion"},valueOf(){throw "wrong hint"}};
 const extra={[Symbol.toPrimitive](){throw "extra conversion"}};
 if(mediaCanPlayTypeVideo.canPlayType(value,extra,Symbol())!=="probably"||conversions!==1||mediaCanPlayTypeOrder.join(",")!=="convert:string,replay")return false;
 mediaCanPlayTypeOrder.length=0;
 if(mediaCanPlayTypeAudio.canPlayType({toString(){mediaCanPlayTypeOrder.push("toString");return "audio/webm"},valueOf(){throw "wrong ordinary hint"}})!=="maybe"||mediaCanPlayTypeOrder.join(",")!=="toString,replay")return false;
 mediaCanPlayTypeOrder.length=0;
 if(mediaCanPlayTypeVideo.canPlayType({toString(){mediaCanPlayTypeOrder.push("toString");return {}},valueOf(){mediaCanPlayTypeOrder.push("valueOf");return "audio/wav"}})!=="maybe"||mediaCanPlayTypeOrder.join(",")!=="toString,valueOf,replay")return false;
 return mediaCanPlayTypeVideo.canPlayType(Object("video/ogg"))==="maybe"&&mediaCanPlayTypeAuthorStringCalls===0;
})()')! == 'true'
	assert probe.replays == 65 && probe.fetches == 0
	assert media.current_src() == '' && media.network_state() == .empty && media.ready_state() == .have_nothing
	assert math.is_nan(media.duration()) && media.paused() && !media.ended() && !media.seeking()
	assert media.current_time() == 0 && media.default_playback_rate() == 1 && media.playback_rate() == 1
	assert media.volume() == 1 && !media.muted() && media.error() == none && media.show_poster()
	assert media.buffered().length() == 0 && media.played().length() == 0 && media.seekable().length() == 0
}

fn test_native_media_can_play_type_preserves_original_conversion_replay_exceptions_and_public_close_guards() {
	$if !darwin { return }
	probe := &MediaCanPlayTypeProbe{}
	mut runtime, _, mut document, media := media_can_play_type_fixture(fn [probe] (runtime &Runtime) ! {
		mut state := unsafe { &MediaCanPlayTypeProbe(probe) }
		state.replays++
		mut owner := unsafe { &Runtime(runtime) }
		_ = owner.evaluate_host_value('throw mediaCanPlayTypeReplayReason')!
	})!
	defer {
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host(r'globalThis.mediaCanPlayTypeReplayReason={};globalThis.mediaCanPlayTypeConversionReason={};(()=>{
 let conversions=0;
 const throwing={[Symbol.toPrimitive](){conversions++;throw mediaCanPlayTypeConversionReason}};
 try{mediaCanPlayTypeVideo.canPlayType(throwing);return false}catch(error){if(error!==mediaCanPlayTypeConversionReason)return false}
 try{mediaCanPlayTypeVideo.canPlayType({get [Symbol.toPrimitive](){throw mediaCanPlayTypeConversionReason}});return false}catch(error){if(error!==mediaCanPlayTypeConversionReason)return false}
 try{mediaCanPlayTypeVideo.canPlayType({[Symbol.toPrimitive](){return {}}});return false}catch(error){if(!(error instanceof TypeError))return false}
 try{mediaCanPlayTypeVideo.canPlayType({[Symbol.toPrimitive](hint){conversions++;if(hint!=="string")throw "wrong hint";return "video/mp4"}});return false}catch(error){return error===mediaCanPlayTypeReplayReason&&conversions===2}
})()')! == 'true'
	assert probe.replays == 1 && media.show_poster() && media.current_time() == 0 && media.error() == none
	mut normal, host, mut normal_document, _ := media_can_play_type_fixture(none)!
	defer {
		normal.close()
		normal_document.finalize()
	}
	player := normal.evaluate_host_value('mediaCanPlayTypeVideo')!
	normal.close()
	assert normal.closed && normal.context == unsafe { nil } && normal.protected_values_.len == 0
	if _ := normal.evaluate_host_value('mediaCanPlayTypeVideo.canPlayType("video/mp4")') {
		assert false
	} else {
		assert err.msg() == 'JavaScript runtime is closed'
	}
	if _ := host.media_element_for_binding(player) {
		assert false
	} else {
		assert err.msg() == 'Media element binding is closed'
	}
	assert host.elements_for_binding().len == 0
}
