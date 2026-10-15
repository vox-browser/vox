module main

import browserjs
import dom
import fetch
import html
import page
import time

@[heap]
struct PosterReflectionProbe {
mut:
	replays int
	urls []string
}

fn poster_reflection_fixture(replay ?browserjs.MediaElementReplayHook) !(&browserjs.Runtime, &browserjs.MediaElementHost, &dom.Document, &dom.Element) {
	address := dom.URL{ value: 'https://poster-reflection.example/first/page.html' }
	mut document := html.parse_navigation_document('<!doctype html><video id="pr-video"></video><audio id="pr-audio"></audio>', address, address.origin(), none)!
	mut runtime := browserjs.Runtime.create()
	mut host := browserjs.MediaElementHost.create(document, replay)!
	host.install(mut runtime)!
	for key, element in host.elements_for_binding() {
		if element.local_name() in ['audio', 'video'] {
			name := if element.local_name() == 'video' { 'prVideo' } else { 'prAudio' }
			_ = runtime.evaluate_host('globalThis.${name}={};__ladybirdMediaElementBind(${name},"${key}","${element.local_name()}");0')!
		}
	}
	element := document.get_element_by_id('pr-video') or { return error('missing poster video') }
	return runtime, host, document, element
}

fn poster_reflection_flush(document &dom.Document, runtime &browserjs.Runtime) ! {
	snapshot := runtime.evaluate_host('__ladybirdFinalize()')!
	mut messages := []string{}
	apply_javascript_runtime_state(document, snapshot, runtime, mut messages)
	assert messages == []
	_ = runtime.evaluate_host('__ladybirdClearLogs();0')!
}

fn test_video_poster_native_metadata_and_video_brand_precede_replay_and_conversion() {
	$if !darwin { return }
	probe := &PosterReflectionProbe{}
	mut runtime, _, mut document, element := poster_reflection_fixture(fn [probe] (_ &browserjs.Runtime) ! {
		mut state := unsafe { &PosterReflectionProbe(probe) }
		state.replays++
	})!
	defer { runtime.close(); document.finalize() }
	assert runtime.evaluate_host(r'(()=>{
 const p=HTMLVideoElement.prototype,d=Object.getOwnPropertyDescriptor(p,"poster");
 if(!d||!d.enumerable||!d.configurable||d.get.name!=="get poster"||d.get.length!==0||d.set.name!=="set poster"||d.set.length!==1||![d.get,d.set].every(f=>Function.prototype.toString.call(f).includes("[native code]")))return false;
 if(Object.getPrototypeOf(p)!==HTMLMediaElement.prototype||Object.getPrototypeOf(HTMLVideoElement)!==HTMLMediaElement||Object.getPrototypeOf(prVideo)!==p||!(prVideo instanceof HTMLMediaElement)||!(prVideo instanceof EventTarget)||!(prVideo instanceof HTMLVideoElement)||prAudio instanceof HTMLVideoElement||"poster" in prAudio||Object.hasOwn(prVideo,"poster")||Object.prototype.toString.call(prVideo)!=="[object HTMLVideoElement]")return false;
 let traps=0,conversions=0;const value={[Symbol.toPrimitive](){conversions++;throw "convert"}};
 const proxy=new Proxy(prVideo,{get(){traps++;throw "get"},getPrototypeOf(){traps++;throw "prototype"}}),revoked=Proxy.revocable(prVideo,{});revoked.revoke();
 for(const receiver of [prAudio,Object.create(p),Object.create(prVideo),proxy,revoked.proxy,null,undefined,1,{}]){
  for(const call of [()=>d.get.call(receiver),()=>d.set.call(receiver,value),()=>d.set.call(receiver)]){
   try{call();return false}catch(error){if(!(error instanceof TypeError)||error.message!=="Not an object of type HTMLVideoElement")return false}
  }
 }
 return traps===0&&conversions===0;
})()')! == 'true'
	assert probe.replays == 0 && !element.has_attribute('poster')
	assert runtime.evaluate_host('prVideo.poster===""&&prVideo.paused&&prAudio.paused')! == 'true'
	assert probe.replays == 3
}

fn test_video_poster_reflection_keeps_raw_scalar_text_qualified_reads_and_live_document_urls() {
	$if !darwin { return }
	mut runtime, _, mut document, mut element := poster_reflection_fixture(none)!
	defer { runtime.close(); document.finalize() }
	assert runtime.evaluate_host(r'globalThis.prSync=[];__ladybirdMediaElementSetAttributeSync((receiver,name,value)=>prSync.push([receiver,name,value]));(()=>{
 const d=Object.getOwnPropertyDescriptor(HTMLVideoElement.prototype,"poster");
 for(const [value,raw] of [[null,"null"],[undefined,"undefined"],[false,"false"],[12,"12"],["",""],["../image.png?q=%20#frame","../image.png?q=%20#frame"]]){
  if(d.set.call(prVideo,value)!==undefined||prSync[prSync.length-1][0]!==prVideo||prSync[prSync.length-1][1]!=="poster"||prSync[prSync.length-1][2]!==raw)return false;
 }
 let calls=0;globalThis.String=()=>{throw "author String"};
 const value={[Symbol.toPrimitive](hint){if(hint!=="string")throw "hint";calls++;return "\u0000\uD800A\uDC00\u{1F642}"}};
 d.set.call(prVideo,value,{[Symbol.toPrimitive](){throw "extra argument"}});
 if(calls!==1||prSync[prSync.length-1][2]!=="\u0000\uFFFDA\uFFFD\u{1F642}")return false;
 d.set.call(prVideo,"../image.png?q=%20#frame");
 return prVideo.poster==="https://poster-reflection.example/image.png?q=%20#frame";
})()')! == 'true'
	assert element.get_attribute_ns(none, 'poster')? == '../image.png?q=%20#frame'
	element.set_attribute_value('poster', '')
	assert runtime.evaluate_host('prVideo.poster==="https://poster-reflection.example/first/page.html"')! == 'true'
	element.set_attribute_value('poster', 'http://[bad\xED\xA0\x80')
	assert runtime.evaluate_host(r'prVideo.poster==="http://[bad\uFFFD"')! == 'true'
	element.remove_attribute_ns(none, 'poster')
	element.set_attribute_value_ns('poster', 'foreign.png', none, 'urn:poster-test')
	foreign := element.get_attribute_node_ns('urn:poster-test', 'poster')?
	assert runtime.evaluate_host('prVideo.poster="own.png";prVideo.poster==="https://poster-reflection.example/first/foreign.png"')! == 'true'
	assert element.get_attribute_ns(none, 'poster')? == 'own.png'
	assert element.get_attribute_ns('urn:poster-test', 'poster')? == 'foreign.png'
	assert voidptr(element.get_attribute_node_ns('urn:poster-test', 'poster')?) == voidptr(foreign)
	element.remove_attribute_ns('urn:poster-test', 'poster')
	address := dom.URL{ value: 'https://adopted-poster.example/second/page.html' }
	mut adopted := html.parse_navigation_document('<!doctype html>', address, address.origin(), none)!
	defer { adopted.finalize() }
	adopted.adopt_node(unsafe { &dom.Node(element) })
	assert runtime.evaluate_host('prVideo.poster==="https://adopted-poster.example/second/own.png"')! == 'true'
	element.remove_attribute_ns(none, 'poster')
	assert runtime.evaluate_host('prVideo.poster===""')! == 'true'
}

fn test_video_poster_conversion_and_replay_keep_original_exception_identity_and_runtime_cleanup() {
	$if !darwin { return }
	probe := &PosterReflectionProbe{}
	mut runtime, host, mut document, element := poster_reflection_fixture(fn [probe] (runtime &browserjs.Runtime) ! {
		mut state := unsafe { &PosterReflectionProbe(probe) }
		state.replays++
		mut owner := unsafe { &browserjs.Runtime(runtime) }
		_ = owner.evaluate_host_value('throw prReplayReason')!
	})!
	defer { runtime.close(); document.finalize() }
	assert runtime.evaluate_host(r'globalThis.prReplayReason={};globalThis.prConversionReason={};globalThis.prSyncCalls=0;__ladybirdMediaElementSetAttributeSync(()=>prSyncCalls++);(()=>{
 const d=Object.getOwnPropertyDescriptor(HTMLVideoElement.prototype,"poster");let conversions=0;
 for(const value of [{[Symbol.toPrimitive](){throw prConversionReason}},{get [Symbol.toPrimitive](){throw prConversionReason}}]){try{d.set.call(prVideo,value);return false}catch(error){if(error!==prConversionReason)return false}}
 for(const value of [Symbol(),Object(Symbol()),{[Symbol.toPrimitive](){return {}}}]){try{d.set.call(prVideo,value);return false}catch(error){if(!(error instanceof TypeError))return false}}
 for(const operation of [()=>d.get.call(prVideo),()=>d.set.call(prVideo,{[Symbol.toPrimitive](){conversions++;return "image.png"}}),()=>d.set.call(prVideo)]){try{operation();return false}catch(error){if(error!==prReplayReason)return false}}
 return conversions===1&&prSyncCalls===0;
})()')! == 'true'
	assert probe.replays == 3 && !element.has_attribute('poster')
	value := runtime.evaluate_host_value('prVideo')!
	runtime.close()
	if _ := runtime.evaluate_host('prVideo.poster') { assert false } else { assert err.msg() == 'JavaScript runtime is closed' }
	assert host.elements_for_binding().len == 0
	if _ := host.media_element_for_binding(value) { assert false } else { assert err.msg() == 'Media element binding is closed' }
}

fn test_compact_video_poster_property_reaches_parsed_and_created_owners_without_duplicate_replay_fetches() {
	$if !darwin { return }
	owner := page.Page.create(1)!
	mut document := parse_browser_navigation_document_for_page_with_response_time(
		'<!doctype html><base href="/first/"><video id="pr-parsed" preload="none"></video>',
		dom.URL{ value: 'https://poster-reflection.example/page.html' }, none, none,
		unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'globalThis.prPlayers=[document.getElementById("pr-parsed")];const created=document.createElement("video");created.id="pr-created";created.preload="none";document.body.appendChild(created);prPlayers.push(created);0'], runtime, mut messages)
	assert messages == []
	for index, id in ['pr-parsed', 'pr-created'] {
		element := document.get_element_by_id(id) or { panic('missing reflected poster owner') }
		mut video := html.html_video_element_model_for_dom_element(unsafe { &dom.HTMLVideoElement(element) })
		probe := &PosterReflectionProbe{}
		video.set_poster_request_fetch_hook(fn [probe, document] (request &fetch.Request) !&dom.Bitmap_ {
			mut observed := unsafe { &PosterReflectionProbe(probe) }
			assert (request.destination or { panic('missing poster destination') }) == .image
			assert (request.initiator_type or { panic('missing poster initiator') }) == .video
			client := request.client or { panic('missing poster client') }
			assert (client.fetch_request_client_document_url() or { panic('missing client URL') }) == document.url
			observed.urls << request.url_list[0].serialize()
			return &dom.Bitmap_{ width: 17, height: 9, pitch: 68, data: []u8{len: 17 * 9 * 4} }
		})
		assert runtime.evaluate_host('prPlayers[${index}].poster="image.png";prPlayers[${index}].getAttribute("poster")==="image.png"&&prPlayers[${index}].poster==="https://poster-reflection.example/first/image.png"')! == 'true'
		assert probe.urls == ['https://poster-reflection.example/first/image.png']
		attribute := element.get_attribute_node_ns(none, 'poster')?
		poster_reflection_flush(document, runtime)!
		assert probe.urls.len == 1
		assert runtime.evaluate_host('prPlayers[${index}].poster="image.png";prPlayers[${index}].poster="image.png";0')! == '0'
		assert probe.urls.len == 3
		poster_reflection_flush(document, runtime)!
		assert probe.urls.len == 3 && voidptr(element.get_attribute_node_ns(none, 'poster')?) == voidptr(attribute)
		assert (video.natural_element_size() or { panic('missing reflected poster size') }) == html.VideoDimensions{17, 9}
		assert video.poster_frame() != none && video.current_representation() == .poster_frame
		assert video.media.paused() && video.media.current_src() == '' && video.media.network_state() == .empty
		assert runtime.evaluate_host('prPlayers[${index}].removeAttribute("poster");prPlayers[${index}].poster===""')! == 'true'
		assert video.poster_frame() == none && probe.urls.len == 3
	}
	assert runtime.evaluate_host('prPlayers[0].poster="live.png";document.querySelector("base").setAttribute("href","/second/");prPlayers[0].poster==="https://poster-reflection.example/second/live.png"')! == 'true'
	poster_reflection_flush(document, runtime)!
}
