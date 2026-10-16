module main

import browserjs
import dom
import html
import page
import time
import x.json2

@[heap]
struct NativeMediaSrcProbe {
mut:
	replays int
	urls []string
	saw_outer bool
}

fn native_media_src_fixture(replay ?browserjs.MediaElementReplayHook) !(&browserjs.Runtime, &browserjs.MediaElementHost, &dom.Document, &dom.Element) {
	url := dom.URL{ value: 'https://native-media-src.example/first/page.html' }
	mut document := html.parse_navigation_document('<!doctype html><base id="nms-base" href="/first/"><video id="nms-video" preload="none"></video><audio id="nms-audio" preload="none"></audio>', url, url.origin(), none)!
	mut runtime := browserjs.Runtime.create()
	mut host := browserjs.MediaElementHost.create(document, replay)!
	host.install(mut runtime)!
	for key, element in host.elements_for_binding() {
		if element.local_name() in ['audio', 'video'] {
			name := if element.local_name() == 'video' { 'nmsVideo' } else { 'nmsAudio' }
			_ = runtime.evaluate_host('globalThis.${name}={};__ladybirdMediaElementBind(${name},"${key}","${element.local_name()}");0')!
		}
	}
	element := document.get_element_by_id('nms-video') or { return error('Missing native media src video') }
	return runtime, host, document, element
}

fn native_media_src_flush(document &dom.Document, runtime &browserjs.Runtime) ! {
	snapshot := runtime.evaluate_host('__ladybirdFinalize()')!
	mut messages := []string{}
	apply_javascript_runtime_state(document, snapshot, runtime, mut messages)
	assert messages == []
	_ = runtime.evaluate_host('__ladybirdClearLogs();0')!
}

fn test_native_media_src_metadata_and_owner_brands_precede_conversion_and_replay() {
	$if !darwin { return }
	probe := &NativeMediaSrcProbe{}
	mut runtime, _, mut document, element := native_media_src_fixture(fn [probe] (_ &browserjs.Runtime) ! {
		mut state := unsafe { &NativeMediaSrcProbe(probe) };state.replays++
	})!
	defer { runtime.close();document.finalize() }
	assert runtime.evaluate_host(r'(()=>{
 const p=HTMLMediaElement.prototype,d=Object.getOwnPropertyDescriptor(p,"src");
 if(!d||!d.enumerable||!d.configurable||d.get.name!=="get src"||d.get.length!==0||d.set.name!=="set src"||d.set.length!==1||![d.get,d.set].every(f=>Function.prototype.toString.call(f).includes("[native code]"))||Object.hasOwn(nmsVideo,"src")||Object.hasOwn(nmsAudio,"src"))return false;
 let traps=0,conversions=0;const value={[Symbol.toPrimitive](){conversions++;throw "convert"}},proxy=new Proxy(nmsVideo,{get(){traps++;throw "get"},getPrototypeOf(){traps++;throw "prototype"}}),revoked=Proxy.revocable(nmsVideo,{});revoked.revoke();
 for(const receiver of [{},Object.create(nmsVideo),Object.create(p),proxy,revoked.proxy,null,undefined,1])for(const call of [()=>d.get.call(receiver),()=>d.set.call(receiver,value),()=>d.set.call(receiver)]){try{call();return false}catch(error){if(!(error instanceof TypeError)||error.message!=="Not an object of type HTMLMediaElement")return false}}
 return traps===0&&conversions===0;
})()')! == 'true'
	assert probe.replays == 0 && !element.has_attribute('src')
	assert runtime.evaluate_host('nmsVideo.src===""&&nmsAudio.src===""')! == 'true'
	assert probe.replays == 2
}

fn test_native_media_src_scalar_conversion_once_preserves_raw_text_and_uses_captured_intrinsics() {
	$if !darwin { return }
	mut runtime, _, mut document, element := native_media_src_fixture(none)!
	defer { runtime.close();document.finalize() }
	assert runtime.evaluate_host(r'globalThis.nmsSync=[];__ladybirdMediaElementSetAttributeSync((receiver,name,value)=>nmsSync.push([receiver,name,value]));(()=>{
 const d=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"src");
 for(const receiver of [nmsVideo,nmsAudio])for(const [input,raw] of [[undefined,"undefined"],[null,"null"],[false,"false"],[17,"17"],[1n,"1"],["",""],[" ../movie.webm?q=%20#one "," ../movie.webm?q=%20#one "]]){
  if(d.set.call(receiver,input)!==undefined)return false;const last=nmsSync[nmsSync.length-1];if(last[0]!==receiver||last[1]!=="src"||last[2]!==raw||typeof last[2]!=="string")return false;
 }
 let calls=0;globalThis.String=()=>{throw "author String"};const input={[Symbol.toPrimitive](hint){if(hint!=="string")throw "hint";calls++;return "\u0000\uD800A\uDC00\u{1F642}"}};
 d.set.call(nmsVideo,input,{[Symbol.toPrimitive](){throw "extra"}});
 if(calls!==1||nmsSync[nmsSync.length-1][2]!=="\u0000\uFFFDA\uFFFD\u{1F642}")return false;
 d.set.call(nmsAudio);return nmsSync[nmsSync.length-1][2]==="undefined";
})()')! == 'true'
	assert element.get_attribute_ns(none, 'src')? == '\x00�A�🙂'
}

fn test_native_media_src_live_qualified_url_reads_null_writes_base_changes_and_adoption() {
	$if !darwin { return }
	mut runtime, _, mut document, mut element := native_media_src_fixture(none)!
	defer { runtime.close();document.finalize() }
	assert runtime.evaluate_host('nmsVideo.src="../movie.webm?q=%20#frame";nmsVideo.src==="https://native-media-src.example/movie.webm?q=%20#frame"')! == 'true'
	element.set_attribute_value('src', '')
	assert runtime.evaluate_host('nmsVideo.src==="https://native-media-src.example/first/"')! == 'true'
	element.set_attribute_value('src', 'http://[bad\xED\xA0\x80')
	assert runtime.evaluate_host(r'nmsVideo.src==="http://[bad\uFFFD"')! == 'true'
	element.remove_attribute('src')
	element.set_attribute_value_ns('src', 'foreign.webm', none, 'urn:native-media-src')
	foreign := element.get_attribute_node_ns('urn:native-media-src', 'src')?
	assert runtime.evaluate_host('nmsVideo.src="own.webm";nmsVideo.src==="https://native-media-src.example/first/foreign.webm"')! == 'true'
	plain := element.get_attribute_node_ns(none, 'src')?
	assert element.get_attribute_ns(none, 'src')? == 'own.webm'
	assert voidptr(element.get_attribute_node_ns('urn:native-media-src', 'src')?) == voidptr(foreign)
	element.remove_attribute_ns('urn:native-media-src', 'src')
	mut base := document.get_element_by_id('nms-base')?
	base.set_attribute_value('href', '/changed/')
	assert runtime.evaluate_host('nmsVideo.src==="https://native-media-src.example/changed/own.webm"')! == 'true'
	url := dom.URL{ value: 'https://adopted-native-src.example/other/' }
	mut adopted := html.parse_navigation_document('<!doctype html>', url, url.origin(), none)!
	defer { adopted.finalize() }
	adopted.adopt_node(element.as_node())
	assert runtime.evaluate_host('nmsVideo.src==="https://adopted-native-src.example/other/own.webm"')! == 'true'
	assert runtime.evaluate_host('nmsVideo.src="after.webm";nmsVideo.src==="https://adopted-native-src.example/other/after.webm"')! == 'true'
	assert voidptr(element.get_attribute_node_ns(none, 'src')?) == voidptr(plain)
	element.remove_attribute('src')
	assert runtime.evaluate_host('nmsVideo.src===""')! == 'true'
}

fn test_native_media_src_conversion_replay_sync_exceptions_and_close_keep_original_identity() {
	$if !darwin { return }
	probe := &NativeMediaSrcProbe{}
	mut runtime, host, mut document, element := native_media_src_fixture(fn [probe] (runtime &browserjs.Runtime) ! {
		mut observed := unsafe { &NativeMediaSrcProbe(probe) };observed.replays++
		mut owner := unsafe { &browserjs.Runtime(runtime) };_ = owner.evaluate_host_value('throw nmsReplayReason')!
	})!
	defer { runtime.close();document.finalize() }
	assert runtime.evaluate_host(r'globalThis.nmsReplayReason={};globalThis.nmsConversionReason={};globalThis.nmsSyncCalls=0;__ladybirdMediaElementSetAttributeSync(()=>nmsSyncCalls++);(()=>{
 const d=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"src");let conversions=0;
 for(const receiver of [nmsVideo,nmsAudio]){
  for(const value of [{[Symbol.toPrimitive](){throw nmsConversionReason}},{get [Symbol.toPrimitive](){throw nmsConversionReason}}]){try{d.set.call(receiver,value);return false}catch(error){if(error!==nmsConversionReason)return false}}
  for(const value of [Symbol(),Object(Symbol()),{[Symbol.toPrimitive](){return {}}}]){try{d.set.call(receiver,value);return false}catch(error){if(!(error instanceof TypeError))return false}}
  for(const call of [()=>d.get.call(receiver),()=>d.set.call(receiver,{[Symbol.toPrimitive](){conversions++;return "movie.webm"}}),()=>d.set.call(receiver)]){try{call();return false}catch(error){if(error!==nmsReplayReason)return false}}
 }
 return conversions===2&&nmsSyncCalls===0;
})()')! == 'true'
	assert probe.replays == 6 && !element.has_attribute('src')
	value := runtime.evaluate_host_value('nmsVideo')!
	runtime.close()
	if _ := runtime.evaluate_host('nmsVideo.src') { assert false } else { assert err.msg() == 'JavaScript runtime is closed' }
	if _ := host.media_element_for_binding(value) { assert false } else { assert err.msg() == 'Media element binding is closed' }
	assert host.elements_for_binding().len == 0
	mut second, _, mut other, other_element := native_media_src_fixture(none)!
	defer { second.close();other.finalize() }
	assert second.evaluate_host(r'globalThis.nmsReason={};__ladybirdMediaElementSetAttributeSync(()=>{throw nmsReason});(()=>{try{nmsVideo.src="not-written.webm";return false}catch(error){return error===nmsReason}})()')! == 'true'
	assert !other_element.has_attribute('src')
}

fn test_compact_native_media_src_parsed_created_owners_load_once_and_preserve_raw_dirty_state() {
	$if !darwin { return }
	owner := page.Page.create(1)!
	mut document := parse_browser_navigation_document_for_page_with_response_time('<!doctype html><video id="nms-parsed" preload="none" src="parsed.webm"></video><div id="nms-ordinary"></div><svg><video id="nms-svg"></video></svg>', dom.URL{ value: 'https://native-media-src.example/' }, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close();document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'globalThis.nmsPlayers=[document.getElementById("nms-parsed")];const a=document.createElement("audio");a.id="nms-created";a.preload="none";document.body.appendChild(a);nmsPlayers.push(a);if(nmsPlayers[0].src!=="https://native-media-src.example/parsed.webm"||a.src!==""||nmsPlayers.some(p=>Object.hasOwn(p,"src")))throw "native src facade";const ordinary=document.getElementById("nms-ordinary"),svg=document.getElementById("nms-svg");ordinary.src="ordinary.raw";svg.src="svg.raw";if(!Object.hasOwn(ordinary,"src")||!Object.hasOwn(svg,"src")||ordinary.src!=="ordinary.raw"||svg.src!=="svg.raw"||svg instanceof HTMLMediaElement)throw "retained src fallbacks";0'], runtime, mut messages)
	assert messages == []
	for index, id in ['nms-parsed', 'nms-created'] {
		mut element := document.get_element_by_id(id)?
		mut media := html.html_media_element_for_dom_element(element)?
		probe := &NativeMediaSrcProbe{}
		media.set_fetch_hook(fn [probe] (url dom.URL, _ u64) !html.MediaResourceResponse {
			mut observed := unsafe { &NativeMediaSrcProbe(probe) };observed.urls << url.serialize()
			return html.MediaResourceResponse{ mime_type: 'audio/webm', duration: 9, buffered_end: 9 }
		})
		assert runtime.evaluate_host('nmsPlayers[${index}].__state.src="stale.webm";nmsPlayers[${index}].src="first.webm";nmsPlayers[${index}].src==="https://native-media-src.example/first.webm"&&nmsPlayers[${index}].getAttribute("src")==="first.webm"')! == 'true'
		assert probe.urls.len == 0 && media.current_src() == 'https://native-media-src.example/first.webm'
		assert runtime.evaluate_host('nmsPlayers[${index}].preload="auto";nmsPlayers[${index}].currentSrc==="https://native-media-src.example/first.webm"')! == 'true'
		assert probe.urls.len == 1
		attribute := element.get_attribute_node_ns(none, 'src')?
		assert runtime.evaluate_host('nmsPlayers[${index}].src="first.webm";nmsPlayers[${index}].src==="https://native-media-src.example/first.webm"')! == 'true'
		assert probe.urls.len == 2
		native_media_src_flush(document, runtime)!
		native_media_src_flush(document, runtime)!
		assert probe.urls.len == 2 && voidptr(element.get_attribute_node_ns(none, 'src')?) == voidptr(attribute)
		assert runtime.evaluate_host('(()=>{const p=nmsPlayers[${index}],saved=globalThis.String;p.setAttribute=p.removeAttribute=()=>{throw "author mutation"};globalThis.String=()=>{throw "author String"};let passed=false;try{p.src={toString(){p.setAttribute=undefined;return "next.webm"}};passed=p.src==="https://native-media-src.example/next.webm"}finally{globalThis.String=saved}return passed&&p.getAttribute("src")==="next.webm"})()')! == 'true'
		assert probe.urls.len == 3 && element.get_attribute_ns(none, 'src')? == 'next.webm'
		native_media_src_flush(document, runtime)!
		assert probe.urls.len == 3
	}
}

fn test_compact_native_media_src_fetch_reentry_sees_published_outer_text_and_keeps_inner_write() {
	$if !darwin { return }
	owner := page.Page.create(1)!
	mut document := parse_browser_navigation_document_for_page_with_response_time('<!doctype html><audio id="nms-reentrant" preload="none"></audio>', dom.URL{ value: 'https://native-media-src.example/' }, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close();document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'globalThis.nmsReentrant=document.getElementById("nms-reentrant");void nmsReentrant.paused;0'], runtime, mut messages)
	assert messages == []
	element := document.get_element_by_id('nms-reentrant')?
	mut media := html.html_media_element_for_dom_element(element)?
	probe := &NativeMediaSrcProbe{}
	handle := voidptr(runtime)
	media.set_fetch_hook(fn [probe, handle] (url dom.URL, _ u64) !html.MediaResourceResponse {
		mut observed := unsafe { &NativeMediaSrcProbe(probe) };observed.urls << url.serialize()
		mut current := unsafe { &browserjs.Runtime(handle) }
		if observed.urls.len == 1 {
			observed.saw_outer = current.evaluate_host('nmsReentrant.src==="https://native-media-src.example/outer.webm"&&nmsReentrant.getAttribute("src")==="outer.webm"')! == 'true'
			assert observed.saw_outer
			assert current.evaluate_host('nmsReentrant.preload="none";nmsReentrant.src="inner.webm";nmsReentrant.src==="https://native-media-src.example/inner.webm"&&nmsReentrant.getAttribute("src")==="inner.webm"')! == 'true'
		}
		return html.MediaResourceResponse{ mime_type: 'audio/webm', duration: 9, buffered_end: 9 }
	})
	assert runtime.evaluate_host('nmsReentrant.preload="auto";nmsReentrant.src="outer.webm";nmsReentrant.src==="https://native-media-src.example/inner.webm"&&nmsReentrant.getAttribute("src")==="inner.webm"')! == 'true'
	assert probe.saw_outer && probe.urls == ['https://native-media-src.example/outer.webm']
	native_media_src_flush(document, runtime)!
	native_media_src_flush(document, runtime)!
	assert probe.urls.len == 1 && element.get_attribute_ns(none, 'src')? == 'inner.webm'
}

fn test_native_media_src_captured_frame_synchronizer_preserves_actual_canvas_pixels() {
	$if !darwin { return }
	mut runtime, host, mut document, element := native_media_src_fixture(none)!
	defer { runtime.close();document.finalize() }
	mut canvas_host := browserjs.CanvasHost.create(document)
	canvas_host.install(mut runtime)!
	mut key := ''
	for name, owner in host.elements_for_binding() {
		if voidptr(owner) == voidptr(element) { key = name }
	}
	assert key != ''
	records, attributes := browserjs.compact_attribute_state(element)
	state := json2.encode({
		'tagName': json2.Any('video')
		'bridgeKey': json2.Any(key)
		'attributeRecords': json2.Any(records)
		'attributes': json2.Any(attributes)
		'attributesDirty': json2.Any(false)
	})
	_ = runtime.evaluate_host(browserjs.compact_attribute_bootstrap())!
	_ = runtime.evaluate_host(browserjs.media_element_reflection_bootstrap())!
	_ = runtime.evaluate_host(r'const __state={videoSources:{"red.webm":{width:1,height:1,pixels:"/wAA/w=="},"blue.webm":{width:1,height:1,pixels:"AAD//w=="}}};' + r'const __reflectMediaAttribute=__createMediaSourceSynchronizer(__compactAttributes.reflect,__state.videoSources);')!
	_ = runtime.evaluate_host('globalThis.nmsFrameState=' + state + ';Object.defineProperty(nmsVideo,"__state",{value:nmsFrameState});__recordMediaAttributes(nmsVideo,nmsFrameState,__reflectMediaAttribute);0')!
	_ = runtime.evaluate_host(r'const __canvases=Object.create(null);function __canvasDimension(s,name){return +s[name];}function __element(s){return {__state:s};}' + browserjs.canvas_bootstrap() + r'globalThis.nmsFrameContext=__canvasContext({bridgeKey:"nms-pixels",width:1,height:1,tagName:"canvas"});0')!
	assert runtime.evaluate_host(r'nmsVideo.src="red.webm";nmsFrameContext.drawImage(nmsVideo,0,0);nmsVideo.src==="https://native-media-src.example/first/red.webm"&&nmsFrameContext.getImageData(0,0,1,1).data.join(",")==="255,0,0,255"')! == 'true'
	assert runtime.evaluate_host(r'nmsFrameState.__videoFrame={stale:true};nmsVideo.src="blue.webm";nmsFrameContext.drawImage(nmsVideo,0,0);nmsFrameState.__videoFrame===null&&nmsFrameState.src==="blue.webm"&&nmsFrameContext.getImageData(0,0,1,1).data.join(",")==="0,0,255,255"')! == 'true'
	assert element.get_attribute_ns(none, 'src')? == 'blue.webm'
}
