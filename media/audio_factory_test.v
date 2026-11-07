module main

import browserjs
import dom
import html
import page
import time

@[heap]
struct NativeAudioFactoryProbe {
mut:
	elements []&dom.Element
	urls []string
	replays int
	fail_replay int
}

fn native_audio_factory_fixture(probe &NativeAudioFactoryProbe) !(&browserjs.Runtime, &browserjs.MediaElementHost, &dom.Document) {
	url := dom.URL{ value: 'https://native-audio-factory.example/dir/' }
	owner := page.Page.create(1)!
	document := html.create_navigation_document_for_page(url,url.origin(),none,unsafe { &dom.Page(owner) })!
	mut runtime := browserjs.Runtime.create()
	_ = runtime.evaluate_host('globalThis.nafOrder=[];globalThis.nafReason={};0')!
	handle := voidptr(runtime)
	mut host := browserjs.MediaElementHost.create_with_created_element_hook(document,fn [probe] (runtime &browserjs.Runtime) ! {
		mut state := unsafe { &NativeAudioFactoryProbe(probe) };state.replays++
		if state.fail_replay == state.replays {
			mut current := unsafe { &browserjs.Runtime(runtime) };_ = current.evaluate_host_value('throw nafReason')!
		}
	},fn [probe,handle] (element &dom.Element) {
		mut state := unsafe { &NativeAudioFactoryProbe(probe) };state.elements << element
		mut current := unsafe { &browserjs.Runtime(handle) };_ = current.evaluate_host('nafOrder.push("create");0') or { panic(err) }
		mut media := html.html_media_element_for_dom_element(element) or { panic('Missing Audio model') }
		media.set_fetch_hook(fn [probe,handle] (url dom.URL,_ u64) !html.MediaResourceResponse {
			mut state := unsafe { &NativeAudioFactoryProbe(probe) };state.urls << url.serialize()
			mut current := unsafe { &browserjs.Runtime(handle) };_ = current.evaluate_host('nafOrder.push("fetch");0')!
			return html.MediaResourceResponse{mime_type:'audio/webm',duration:3,buffered_end:3}
		})
	})!
	host.install(mut runtime)!
	runtime.define_value_host_function('__nafPreload',fn [probe,handle] (_ voidptr,_ []voidptr) !voidptr {
		state := unsafe { &NativeAudioFactoryProbe(probe) }
		mut current := unsafe { &browserjs.Runtime(handle) }
		if state.elements.len == 0 { return current.evaluate_host_value('"missing"') }
		preload := state.elements.last().get_attribute('preload') or { 'absent' }
		return current.evaluate_host_value(if preload == 'auto' { '"auto"' } else { '"absent"' })
	})!
	return runtime,host,document
}

fn test_native_audio_factory_metadata_new_target_order_and_actual_source_fetch() {
	$if !darwin { return }
	probe := &NativeAudioFactoryProbe{}
	mut runtime,host,mut document := native_audio_factory_fixture(probe)!
	defer { runtime.close();document.finalize() }
	assert runtime.evaluate_host(r'(()=>{
 const d=Object.getOwnPropertyDescriptor,prototype=d(Audio,"prototype"),global=d(globalThis,"Audio");
 if(Audio.name!=="Audio"||Audio.length!==0||!Function.prototype.toString.call(Audio).includes("[native code]")||Object.getPrototypeOf(Audio)!==Function.prototype||Audio.prototype!==HTMLAudioElement.prototype||Audio.prototype.constructor!==HTMLAudioElement)return false;
 if(prototype.writable||prototype.enumerable||prototype.configurable||!global.writable||global.enumerable||!global.configurable||!d(Audio,"name").configurable||!d(Audio,"length").configurable)return false;
 const target=new Proxy(function(){},{get(object,key){if(key==="prototype"){nafOrder.push("prototype");return HTMLAudioElement.prototype}return Reflect.get(object,key)}});
 const source={[Symbol.toPrimitive](hint){if(hint!=="string"||__nafPreload()!=="auto")throw "conversion ordering";nafOrder.push("source");return "song.webm"}};
 globalThis.nafPlayer=Reflect.construct(Audio,[source,{[Symbol.toPrimitive](){throw "extra argument"}}],target);
 if(nafOrder.join(",")!=="create,prototype,source,fetch"||!(nafPlayer instanceof Audio)||!(nafPlayer instanceof HTMLAudioElement)||!(nafPlayer instanceof HTMLMediaElement)||!(nafPlayer instanceof EventTarget)||nafPlayer.preload!=="auto"||nafPlayer.src!=="https://native-audio-factory.example/dir/song.webm")return false;
 class Derived extends Audio{};globalThis.nafDerived=new Derived();function PrimitiveTarget(){}PrimitiveTarget.prototype=null;globalThis.nafFallback=Reflect.construct(Audio,[],PrimitiveTarget);
 return nafDerived instanceof Derived&&nafDerived instanceof Audio&&Object.getPrototypeOf(nafFallback)===HTMLAudioElement.prototype;
})()')! == 'true'
	assert probe.elements.len == 3 && probe.urls == ['https://native-audio-factory.example/dir/song.webm']
	element := probe.elements[0]
	assert element.is_html_element() && element.local_name() == 'audio' && element.namespace_uri()? == dom.namespace_html_uri
	assert voidptr(element.document()) == voidptr(document)
	assert element.get_attribute('preload')? == 'auto' && element.get_attribute('src')? == 'song.webm'
	media := host.media_element_for_binding(runtime.evaluate_host_value('nafPlayer')!)!
	assert voidptr(media) == voidptr(html.html_media_element_for_dom_element(element)?)
	assert voidptr(runtime.native_event_target(runtime.evaluate_host_value('nafPlayer')!)!) == voidptr(element)
}

fn test_native_audio_factory_optional_dom_string_keeps_raw_utf16_and_undefined_absence() {
	$if !darwin { return }
	probe := &NativeAudioFactoryProbe{}
	mut runtime,_,mut document := native_audio_factory_fixture(probe)!
	defer { runtime.close();document.finalize() }
	assert runtime.evaluate_host(r'globalThis.nafDefaults=[new Audio(),new Audio(undefined),new Audio("")];nafDefaults.every(a=>a.preload==="auto")&&nafDefaults[0].src===""&&nafDefaults[1].src===""&&nafDefaults[2].src==="https://native-audio-factory.example/dir/"')! == 'true'
	assert !probe.elements[0].has_attribute('src') && !probe.elements[1].has_attribute('src')
	assert probe.elements[2].get_attribute('src')? == '' && probe.urls == []
	assert runtime.evaluate_host(r'globalThis.nafConverted=[new Audio(null),new Audio(false),new Audio(7),new Audio(1n)];globalThis.nafString=String;globalThis.String=()=>{throw "author String"};let count=0;globalThis.nafRaw=new Audio({[Symbol.toPrimitive](hint){if(hint!=="string"||__nafPreload()!=="auto")throw "hint";count++;return "http://[bad\u0000\uD800"}});count===1&&nafRaw.src==="http://[bad\u0000\uFFFD"')! == 'true'
	for index,expected in ['null','false','7','1'] { assert probe.elements[index+3].get_attribute('src')? == expected }
	assert probe.elements.last().get_attribute('src')? == 'http://[bad\x00\xED\xA0\x80'
	assert runtime.evaluate_host('globalThis.String=nafString;0')! == '0'
}

fn test_native_audio_factory_preserves_prototype_conversion_replay_and_facade_failures() {
	$if !darwin { return }
	probe := &NativeAudioFactoryProbe{}
	mut runtime,_,mut document := native_audio_factory_fixture(probe)!
	defer { runtime.close();document.finalize() }
	assert runtime.evaluate_host(r'(()=>{let calls=0;for(const operation of [()=>Audio({[Symbol.toPrimitive](){calls++;throw "conversion"}}),()=>Audio.call({},Symbol())]){try{operation();return false}catch(error){if(!(error instanceof TypeError)||error.message!=="Audio constructor must be called with \u0027new\u0027")return false}}return calls===0})()')! == 'true'
	assert probe.elements.len == 0
	assert runtime.evaluate_host(r'(()=>{try{Reflect.construct(Audio,[{[Symbol.toPrimitive](){throw "wrong conversion"}}],new Proxy(function(){},{get(object,key){if(key==="prototype")throw nafReason;return Reflect.get(object,key)}}));return false}catch(error){return error===nafReason}})()')! == 'true'
	assert probe.elements.len == 1 && !probe.elements[0].has_attribute('preload') && !probe.elements[0].has_attribute('src')
	assert runtime.evaluate_host(r'(()=>{for(const value of [{[Symbol.toPrimitive](){throw nafReason}},{get [Symbol.toPrimitive](){throw nafReason}}]){try{new Audio(value);return false}catch(error){if(error!==nafReason)return false}}for(const value of [Symbol(),Object(Symbol())]){try{new Audio(value);return false}catch(error){if(!(error instanceof TypeError))return false}}return true})()')! == 'true'
	for element in probe.elements[1..] { assert element.get_attribute('preload')? == 'auto' && !element.has_attribute('src') }
	mut state := unsafe { &NativeAudioFactoryProbe(probe) }
	before := state.elements.len
	state.fail_replay=state.replays+1
	assert runtime.evaluate_host('(()=>{try{new Audio();return false}catch(error){return error===nafReason}})()')! == 'true'
	assert state.elements.len == before
	state.fail_replay=state.replays+2
	assert runtime.evaluate_host('(()=>{try{new Audio();return false}catch(error){return error===nafReason}})()')! == 'true'
	assert state.elements.len == before+1 && !state.elements.last().has_attribute('preload')
	state.fail_replay=0
	assert runtime.evaluate_host('__ladybirdMediaElementSetAudioFactory(()=>{throw nafReason});(()=>{try{new Audio();return false}catch(error){return error===nafReason}})()')! == 'true'
	assert runtime.evaluate_host('(()=>{try{__ladybirdMediaElementSetAudioFactory(()=>({}));return false}catch(error){return error instanceof TypeError}})()')! == 'true'
}

fn test_compact_audio_factory_captured_creation_append_and_dirty_attribute_replay() {
	$if !darwin { return }
	owner := page.Page.create(1)!
	mut document := parse_browser_navigation_document_for_page_with_response_time('<!doctype html><div id="naf-result"></div>',dom.URL{value:'https://compact-audio-factory.example/'},none,none,unsafe { &dom.Page(owner) },time.sys_mono_now())
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close();document.finalize() }
	mut messages := []string{}
	run_document_javascript(document,document.url.serialize(),[r'
globalThis.nafSavedAudio=HTMLAudioElement;globalThis.nafSavedString=String;globalThis.nafSavedCreate=document.createElement;document.createElement=()=>{throw "author createElement"};document.createElementNS=()=>{throw "author createElementNS"};globalThis.HTMLAudioElement=function ForgedAudio(){};globalThis.String=()=>{throw "author String"};
globalThis.nafCompact=new Audio();if(!(nafCompact instanceof nafSavedAudio)||!(nafCompact instanceof Audio)||nafCompact.preload!=="auto")throw "native factory identity";
globalThis.String=nafSavedString;document.createElement=nafSavedCreate;nafCompact.id="naf-created";nafCompact.preload="none";nafCompact.src="song.webm";nafCompact.setAttribute("data-native-audio","retained");document.body.appendChild(nafCompact);
if(nafCompact.getAttribute("preload")!=="none"||nafCompact.getAttribute("src")!=="song.webm"||nafCompact.src!=="https://compact-audio-factory.example/song.webm")throw "factory reflection";
globalThis.nafOrdinary=document.createElement("div");nafOrdinary.id="naf-div";document.body.appendChild(nafOrdinary);document.getElementById("naf-result").textContent="created audio";
'],runtime,mut messages)
	assert messages == []
	element := document.get_element_by_id('naf-created')?
	assert element.is_html_element() && element.local_name() == 'audio'
	assert element.get_attribute('preload')? == 'none' && element.get_attribute('src')? == 'song.webm'
	assert element.get_attribute('data-native-audio')? == 'retained'
	assert voidptr(runtime.native_event_target(runtime.evaluate_host_value('nafCompact')!)!) == voidptr(element)
	assert html.html_media_element_for_dom_element(document.get_element_by_id('naf-div')?) == none
	assert runtime.evaluate_host('nafCompact.setAttribute("data-later","yes");nafCompact.src="later.webm";nafCompact.getAttribute("src")==="later.webm"')! == 'true'
	state := runtime.evaluate_host('__ladybirdFinalize()')!
	apply_javascript_runtime_state(document,state,runtime,mut messages)
	assert messages == [] && element.get_attribute('src')? == 'later.webm' && element.get_attribute('data-later')? == 'yes'
	assert runtime.evaluate_host('nafCompact instanceof nafSavedAudio&&nafCompact instanceof Audio&&!Object.hasOwn(nafCompact,"src")')! == 'true'
}

fn test_native_audio_factory_captured_prototype_separate_runtime_and_close_guards() {
	$if !darwin { return }
	first_probe := &NativeAudioFactoryProbe{}
	second_probe := &NativeAudioFactoryProbe{}
	mut first,first_host,mut document := native_audio_factory_fixture(first_probe)!
	mut second,second_host,mut second_document := native_audio_factory_fixture(second_probe)!
	defer { first.close();second.close();document.finalize();second_document.finalize() }
	assert first.evaluate_host(r'globalThis.nafConstructor=Audio;globalThis.nafPrototype=HTMLAudioElement.prototype;globalThis.HTMLAudioElement=null;globalThis.Audio=null;function Target(){}Target.prototype=3;globalThis.nafRetained=Reflect.construct(nafConstructor,[],Target);Object.getPrototypeOf(nafRetained)===nafPrototype&&nafRetained.preload==="auto"')! == 'true'
	actual := first.evaluate_host_value('nafRetained')!
	if _ := second_host.media_element_for_binding(actual) { assert false } else { assert err.msg() == 'TypeError: Not an object of type HTMLMediaElement' }
	first.close()
	assert first_host.elements_for_binding().len == 0
	if _ := first_host.media_element_for_binding(actual) { assert false } else { assert err.msg() == 'Media element binding is closed' }
	if _ := first.evaluate_host('new nafConstructor()') { assert false } else { assert err.msg() == 'JavaScript runtime is closed' }
	assert second.evaluate_host('new Audio() instanceof HTMLAudioElement')! == 'true'
}
