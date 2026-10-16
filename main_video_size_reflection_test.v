module main

import browserjs
import dom
import html
import page
import time

@[heap]
struct VideoSizeReflectionProbe {
mut:
	replays int
}

fn video_size_reflection_fixture(replay ?browserjs.MediaElementReplayHook) !(&browserjs.Runtime, &browserjs.MediaElementHost, &dom.Document, &dom.Element) {
	address := dom.URL{ value: 'https://video-size.example/page.html' }
	mut document := html.parse_navigation_document('<!doctype html><video id="vs-video" preload="none"></video><audio id="vs-audio"></audio>', address, address.origin(), none)!
	mut runtime := browserjs.Runtime.create()
	mut host := browserjs.MediaElementHost.create(document, replay)!
	host.install(mut runtime)!
	for key, element in host.elements_for_binding() {
		if element.local_name() in ['audio', 'video'] {
			name := if element.local_name() == 'video' { 'vsVideo' } else { 'vsAudio' }
			_ = runtime.evaluate_host('globalThis.${name}={};__ladybirdMediaElementBind(${name},"${key}","${element.local_name()}");0')!
		}
	}
	element := document.get_element_by_id('vs-video') or { return error('missing size video') }
	return runtime, host, document, element
}

fn video_size_reflection_flush(document &dom.Document, runtime &browserjs.Runtime) ! {
	snapshot := runtime.evaluate_host('__ladybirdFinalize()')!
	mut messages := []string{}
	apply_javascript_runtime_state(document, snapshot, runtime, mut messages)
	assert messages == []
	_ = runtime.evaluate_host('__ladybirdClearLogs();0')!
}

fn test_video_size_native_metadata_and_brand_precede_conversion_and_replay() {
	$if !darwin { return }
	probe := &VideoSizeReflectionProbe{}
	mut runtime, _, mut document, element := video_size_reflection_fixture(fn [probe] (_ &browserjs.Runtime) ! {
		mut state := unsafe { &VideoSizeReflectionProbe(probe) }
		state.replays++
	})!
	defer { runtime.close(); document.finalize() }
	assert runtime.evaluate_host(r'(()=>{
 let traps=0,conversions=0;const value={[Symbol.toPrimitive](){conversions++;throw "conversion"}};
 const proxy=new Proxy(vsVideo,{get(){traps++;throw "get"},getPrototypeOf(){traps++;throw "prototype"}}),revoked=Proxy.revocable(vsVideo,{});revoked.revoke();
 for(const name of ["width","height"]){
  const d=Object.getOwnPropertyDescriptor(HTMLVideoElement.prototype,name);
  if(!d||!d.enumerable||!d.configurable||d.get.name!=="get "+name||d.get.length!==0||d.set.name!=="set "+name||d.set.length!==1||![d.get,d.set].every(f=>Function.prototype.toString.call(f).includes("[native code]"))||Object.hasOwn(vsVideo,name)||name in vsAudio)return false;
  for(const receiver of [vsAudio,{},Object.create(vsVideo),Object.create(HTMLVideoElement.prototype),proxy,revoked.proxy,null,undefined,1]){
   for(const call of [()=>d.get.call(receiver),()=>d.set.call(receiver,value),()=>d.set.call(receiver)]){
    try{call();return false}catch(error){if(!(error instanceof TypeError)||error.message!=="Not an object of type HTMLVideoElement")return false}
   }
  }
 }
 return traps===0&&conversions===0;
})()')! == 'true'
	assert probe.replays == 0 && !element.has_attribute('width') && !element.has_attribute('height')
	assert runtime.evaluate_host('vsVideo.width===0&&vsVideo.height===0')! == 'true'
	assert probe.replays == 2
}

fn test_video_size_reads_html_non_negative_integer_syntax_and_the_source_range() {
	$if !darwin { return }
	mut runtime, _, mut document, mut element := video_size_reflection_fixture(none)!
	defer { runtime.close(); document.finalize() }
	cases := {
		'': u32(0)
		'  \t+0017px': 17
		'19.75': 19
		'1e3': 1
		'0x10': 0
		'-0': 0
		'-1': 0
		'Infinity': 0
		'\x0b23': 0
		'\xc2\xa023': 0
		'0000000000000000000000000000000042tail': 42
		'2147483647': 2147483647
		'2147483648': 0
		'4294967295': 0
		'4294967296': 0
		'999999999999999999999999999999999': 0
	}
	for raw, expected in cases {
		element.set_attribute_value('width', raw)
		element.set_attribute_value('height', raw)
		assert runtime.evaluate_host('vsVideo.width===${expected}&&vsVideo.height===${expected}&&!Object.is(vsVideo.width,-0)')! == 'true', raw
		assert element.get_attribute('width')? == raw && element.get_attribute('height')? == raw
	}
	element.remove_attribute('width')
	element.remove_attribute('height')
	assert runtime.evaluate_host('vsVideo.width===0&&vsVideo.height===0')! == 'true'
}

fn test_video_size_setters_convert_once_wrap_unsigned_then_apply_the_reflection_limit() {
	$if !darwin { return }
	mut runtime, _, mut document, element := video_size_reflection_fixture(none)!
	defer { runtime.close(); document.finalize() }
	assert runtime.evaluate_host(r'globalThis.vsSync=[];__ladybirdMediaElementSetAttributeSync((receiver,name,value)=>vsSync.push([receiver,name,value]));(()=>{
 const cases=[[undefined,0],[null,0],[false,0],[true,1],[NaN,0],[Infinity,0],[-Infinity,0],[-0,0],[-0.5,0],[17.9,17],["0x10",16],["7.9",7],[2147483647,2147483647],[2147483648,0],[4294967295,0],[4294967296,0],[4294967297.75,1],[-1,0],[-2147483649,2147483647],[-4294967295,1],[-4294967297,0],[9007199254740991,0]];
 for(const name of ["width","height"]){
  const d=Object.getOwnPropertyDescriptor(HTMLVideoElement.prototype,name);
  for(const [input,expected] of cases){
   if(d.set.call(vsVideo,input)!==undefined||d.get.call(vsVideo)!==expected)return false;
   const last=vsSync[vsSync.length-1];if(last[0]!==vsVideo||last[1]!==name||last[2]!==""+expected||typeof last[2]!=="string")return false;
  }
  d.set.call(vsVideo);if(vsVideo[name]!==0)return false;
 }
 let conversions=0;globalThis.Number=()=>{throw "author Number"};globalThis.String=()=>{throw "author String"};
 const input={[Symbol.toPrimitive](hint){if(hint!=="number")throw "hint";conversions++;return "4294967298.75"}};
 for(const name of ["width","height"]){const d=Object.getOwnPropertyDescriptor(HTMLVideoElement.prototype,name);d.set.call(vsVideo,input,{[Symbol.toPrimitive](){throw "extra"}});if(vsVideo[name]!==2)return false}
 return conversions===2;
})()')! == 'true'
	assert element.get_attribute_ns(none, 'width')? == '2'
	assert element.get_attribute_ns(none, 'height')? == '2'
}

fn test_video_size_conversion_and_replay_preserve_original_exceptions_and_close_guards() {
	$if !darwin { return }
	probe := &VideoSizeReflectionProbe{}
	mut runtime, host, mut document, element := video_size_reflection_fixture(fn [probe] (runtime &browserjs.Runtime) ! {
		mut state := unsafe { &VideoSizeReflectionProbe(probe) }
		state.replays++
		mut owner := unsafe { &browserjs.Runtime(runtime) }
		_ = owner.evaluate_host_value('throw vsReplayReason')!
	})!
	defer { runtime.close(); document.finalize() }
	assert runtime.evaluate_host(r'globalThis.vsReplayReason={};globalThis.vsConversionReason={};globalThis.vsSyncCalls=0;__ladybirdMediaElementSetAttributeSync(()=>vsSyncCalls++);(()=>{
 let conversions=0;
 for(const name of ["width","height"]){
  const d=Object.getOwnPropertyDescriptor(HTMLVideoElement.prototype,name);
  for(const input of [{[Symbol.toPrimitive](){throw vsConversionReason}},{get [Symbol.toPrimitive](){throw vsConversionReason}}]){try{d.set.call(vsVideo,input);return false}catch(error){if(error!==vsConversionReason)return false}}
  for(const input of [1n,Object(1n),Symbol(),Object(Symbol()),{[Symbol.toPrimitive](){return {}}}]){try{d.set.call(vsVideo,input);return false}catch(error){if(!(error instanceof TypeError))return false}}
  for(const call of [()=>d.get.call(vsVideo),()=>d.set.call(vsVideo,{[Symbol.toPrimitive](){conversions++;return 17}}),()=>d.set.call(vsVideo)]){try{call();return false}catch(error){if(error!==vsReplayReason)return false}}
 }
 return conversions===2&&vsSyncCalls===0;
})()')! == 'true'
	assert probe.replays == 6 && !element.has_attribute('width') && !element.has_attribute('height')
	value := runtime.evaluate_host_value('vsVideo')!
	runtime.close()
	if _ := runtime.evaluate_host('vsVideo.width') { assert false } else { assert err.msg() == 'JavaScript runtime is closed' }
	if _ := host.media_element_for_binding(value) { assert false } else { assert err.msg() == 'Media element binding is closed' }
	assert host.elements_for_binding().len == 0
}

fn test_video_size_qualified_reads_null_namespace_writes_and_adoption_keep_attr_identity() {
	$if !darwin { return }
	mut runtime, _, mut document, mut element := video_size_reflection_fixture(none)!
	defer { runtime.close(); document.finalize() }
	element.set_attribute_value_ns('width', '+037tail', none, 'urn:video-size')
	foreign := element.get_attribute_node_ns('urn:video-size', 'width')?
	assert runtime.evaluate_host('vsVideo.width=84;vsVideo.width===37')! == 'true'
	assert element.get_attribute_ns(none, 'width')? == '84'
	assert element.get_attribute_ns('urn:video-size', 'width')? == '+037tail'
	assert voidptr(element.get_attribute_node_ns('urn:video-size', 'width')?) == voidptr(foreign)
	element.remove_attribute_ns('urn:video-size', 'width')
	width := element.get_attribute_node_ns(none, 'width')?
	element.set_attribute_value('height', '19')
	element.set_attribute_value_ns('height', '23', none, 'urn:video-size')
	height := element.get_attribute_node_ns(none, 'height')?
	assert runtime.evaluate_host('vsVideo.height=42;vsVideo.width=85;vsVideo.width===85&&vsVideo.height===42')! == 'true'
	assert voidptr(element.get_attribute_node_ns(none, 'width')?) == voidptr(width)
	assert voidptr(element.get_attribute_node_ns(none, 'height')?) == voidptr(height)
	assert element.get_attribute_ns('urn:video-size', 'height')? == '23'
	address := dom.URL{ value: 'https://adopted-video-size.example/page.html' }
	mut adopted := html.parse_navigation_document('<!doctype html>', address, address.origin(), none)!
	defer { adopted.finalize() }
	adopted.adopt_node(unsafe { &dom.Node(element) })
	element.set_attribute_value('width', '9px')
	assert runtime.evaluate_host('vsVideo.width===9&&vsVideo.height===42')! == 'true'
	assert element.document() == adopted
}

fn test_compact_video_sizes_use_live_owners_and_sync_attributes_without_canvas_defaults() {
	$if !darwin { return }
	owner := page.Page.create(1)!
	mut document := parse_browser_navigation_document_for_page_with_response_time(
		'<!doctype html><video id="vs-parsed" width="015tail" height="999999999999" preload="none"></video><canvas id="vs-canvas"></canvas>',
		dom.URL{ value: 'https://video-size.example/page.html' }, none, none,
		unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'globalThis.vsPlayers=[document.getElementById("vs-parsed")];const v=document.createElement("video");v.id="vs-created";v.preload="none";v.setAttribute("width","21tail");v.setAttribute("height","22%");document.body.appendChild(v);vsPlayers.push(v);if(vsPlayers[0].width!==15||vsPlayers[0].height!==0||v.width!==21||v.height!==22)throw "initial sizes";for(const p of vsPlayers){if(Object.hasOwn(p,"width")||Object.hasOwn(p,"height"))throw "own size";p.__state.width="888";p.__state.height="999";let conversions=0;p.width={valueOf(){conversions++;p.setAttribute("height","14px");return 17.9}};if(conversions!==1||p.width!==17||p.height!==14)throw "live conversion";p.setAttribute=()=>{throw "author setter"};const get=p.getAttribute;p.getAttribute=()=>{throw "author getter"};p.height=31;if(get.call(p,"width")!=="17"||get.call(p,"height")!=="31")throw "raw sync";}const c=document.getElementById("vs-canvas");if(c.width!==300||c.height!==150)throw "canvas defaults";c.width=7.9;if(c.width!==7)throw "canvas width";0'], runtime, mut messages)
	assert messages == []
	for index, id in ['vs-parsed', 'vs-created'] {
		mut element := document.get_element_by_id(id) or { panic('missing size owner') }
		assert element.get_attribute_ns(none, 'width')? == '17'
		assert element.get_attribute_ns(none, 'height')? == '31'
		mut video := html.html_video_element_model_for_dom_element(unsafe { &dom.HTMLVideoElement(element) })
		mut media := video.media
		assert media.paused() && media.current_src() == '' && media.ready_state() == .have_nothing
		video.set_video_dimensions(640, 360)
		media.set_ready_state(.have_metadata)
		assert runtime.evaluate_host('vsPlayers[${index}].width=88;vsPlayers[${index}].height=99;vsPlayers[${index}].width===88&&vsPlayers[${index}].height===99&&vsPlayers[${index}].videoWidth===640&&vsPlayers[${index}].videoHeight===360')! == 'true'
		video_size_reflection_flush(document, runtime)!
		video_size_reflection_flush(document, runtime)!
		assert element.get_attribute_ns(none, 'width')? == '88'
		assert element.get_attribute_ns(none, 'height')? == '99'
		element.set_attribute_value('width', '27suffix')
		element.set_attribute_value('height', '28suffix')
		assert runtime.evaluate_host('vsPlayers[${index}].width===27&&vsPlayers[${index}].height===28')! == 'true'
		assert video.video_width() == 640 && video.video_height() == 360
	}
}
