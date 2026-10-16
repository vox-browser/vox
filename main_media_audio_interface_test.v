module main

import browserjs
import dom
import html
import page
import time

fn native_audio_interface_fixture() !(&browserjs.Runtime, &browserjs.MediaElementHost, &dom.Document) {
	url := dom.URL{ value: 'https://audio-interface.example/dir/' }
	mut document := html.parse_navigation_document('<!doctype html><audio id="nai-audio" preload="none"></audio><video id="nai-video" preload="none"></video><svg><audio id="nai-svg"></audio></svg>', url, url.origin(), none)!
	mut runtime := browserjs.Runtime.create()
	mut host := browserjs.MediaElementHost.create(document, none)!
	host.install(mut runtime)!
	for key, element in host.elements_for_binding() {
		if element.is_html_element() && element.local_name() in ['audio', 'video'] {
			name := if element.local_name() == 'audio' { 'naiAudio' } else { 'naiVideo' }
			_ = runtime.evaluate_host('globalThis.${name}={};__ladybirdMediaElementBind(${name},"${key}","${element.local_name()}");0')!
		}
	}
	return runtime, host, document
}

fn test_native_audio_interface_metadata_inheritance_and_unsupported_construction() {
	$if !darwin { return }
	mut runtime, _, mut document := native_audio_interface_fixture()!
	defer { runtime.close();document.finalize() }
	assert runtime.evaluate_host(r'(()=>{
 const c=HTMLAudioElement,p=c.prototype,m=HTMLMediaElement.prototype,v=HTMLVideoElement.prototype;
 const global=Object.getOwnPropertyDescriptor(globalThis,"HTMLAudioElement"),prototype=Object.getOwnPropertyDescriptor(c,"prototype"),back=Object.getOwnPropertyDescriptor(p,"constructor"),tag=Object.getOwnPropertyDescriptor(p,Symbol.toStringTag);
 if(typeof c!=="function"||c.name!=="HTMLAudioElement"||c.length!==0||!Function.prototype.toString.call(c).includes("[native code]"))return false;
 if(global.value!==c||!global.writable||!global.configurable||global.enumerable||prototype.value!==p||prototype.writable||prototype.enumerable||prototype.configurable)return false;
 if(back.value!==c||!back.writable||!back.configurable||back.enumerable||tag.value!=="HTMLAudioElement"||tag.writable||tag.enumerable||!tag.configurable)return false;
 if(Object.getPrototypeOf(c)!==HTMLMediaElement||Object.getPrototypeOf(p)!==m||p===m||p===v||Object.getPrototypeOf(v)!==m)return false;
 if(Reflect.ownKeys(p).length!==2||Object.hasOwn(p,"src")||Object.hasOwn(c,"NETWORK_EMPTY")||c.NETWORK_EMPTY!==0||c.HAVE_ENOUGH_DATA!==4)return false;
 let conversions=0;const argument={[Symbol.toPrimitive](){conversions++;throw "converted"}};
 for(const operation of [()=>c(),()=>c.call(naiAudio,argument),()=>new c(argument),()=>Reflect.construct(c,[argument]),()=>new(class extends c {})()]){
  try{operation();return false}catch(error){if(!(error instanceof TypeError)||error.message!=="Illegal HTMLAudioElement constructor")return false}
 }
 return conversions===0;
})()')! == 'true'
}

fn test_native_audio_interface_separates_real_owner_brands_from_prototype_forgery() {
	$if !darwin { return }
	mut runtime, host, mut document := native_audio_interface_fixture()!
	defer { runtime.close();document.finalize() }
	audio := document.get_element_by_id('nai-audio')?
	video := document.get_element_by_id('nai-video')?
	assert runtime.evaluate_host(r'(()=>{
 if(Object.getPrototypeOf(naiAudio)!==HTMLAudioElement.prototype||naiAudio.constructor!==HTMLAudioElement||!(naiAudio instanceof HTMLAudioElement)||!(naiAudio instanceof HTMLMediaElement)||!(naiAudio instanceof EventTarget)||naiAudio instanceof HTMLVideoElement)return false;
 if(Object.getPrototypeOf(naiVideo)!==HTMLVideoElement.prototype||!(naiVideo instanceof HTMLVideoElement)||naiVideo instanceof HTMLAudioElement)return false;
 if(Object.prototype.toString.call(naiAudio)!=="[object HTMLAudioElement]"||Object.prototype.toString.call(naiVideo)!=="[object HTMLVideoElement]")return false;
 const getter=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"paused").get;
 let traps=0;const proxy=new Proxy(naiAudio,{get(){traps++;throw "get"},getPrototypeOf(){traps++;throw "prototype"}}),revoked=Proxy.revocable(naiAudio,{});revoked.revoke();
 for(const fake of [Object.create(HTMLAudioElement.prototype),Object.create(naiAudio),proxy,revoked.proxy,HTMLAudioElement.prototype]){
  try{getter.call(fake);return false}catch(error){if(!(error instanceof TypeError)||error.message!=="Not an object of type HTMLMediaElement")return false}
 }
 naiAudio.controls=true;naiAudio.src="sound.webm";
 return traps===0&&naiAudio.paused&&naiAudio.controls&&naiAudio.src==="https://audio-interface.example/dir/sound.webm"&&!Object.hasOwn(naiAudio,"src");
})()')! == 'true'
	assert audio.has_attribute('controls') && audio.get_attribute('src')? == 'sound.webm'
	audio_model := host.media_element_for_binding(runtime.evaluate_host_value('naiAudio')!)!
	video_model := host.media_element_for_binding(runtime.evaluate_host_value('naiVideo')!)!
	assert voidptr(audio_model) == voidptr(html.html_media_element_for_dom_element(audio)?)
	assert voidptr(video_model) == voidptr(html.html_media_element_for_dom_element(video)?)
	assert voidptr(runtime.native_event_target(runtime.evaluate_host_value('naiAudio')!)!) == voidptr(audio)
	assert html.html_media_element_for_dom_element(document.get_element_by_id('nai-svg')?) == none
}

fn test_compact_audio_interface_parsed_created_namespace_and_live_owner_mutations() {
	$if !darwin { return }
	owner := page.Page.create(1)!
	mut document := parse_browser_navigation_document_for_page_with_response_time('<!doctype html><audio id="nai-parsed" preload="none"></audio><video id="nai-video"></video><svg><audio id="nai-svg"></audio></svg>', dom.URL{ value: 'https://audio-interface.example/dir/' }, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close();document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'
globalThis.naiParsed=document.getElementById("nai-parsed");
globalThis.naiCreated=document.createElement("audio");naiCreated.id="nai-created";naiCreated.preload="none";document.body.appendChild(naiCreated);
globalThis.naiCreatedNS=document.createElementNS("http://www.w3.org/1999/xhtml","audio");naiCreatedNS.id="nai-created-ns";naiCreatedNS.preload="none";document.body.appendChild(naiCreatedNS);
globalThis.naiForeign=document.createElementNS("urn:audio-interface","audio");naiForeign.id="nai-foreign";document.body.appendChild(naiForeign);
globalThis.naiOwners=[naiParsed,naiCreated,naiCreatedNS];
if(!naiOwners.every(a=>a instanceof HTMLAudioElement&&a instanceof HTMLMediaElement&&a.constructor===HTMLAudioElement&&Object.prototype.toString.call(a)==="[object HTMLAudioElement]"&&Object.getPrototypeOf(a)===HTMLAudioElement.prototype))throw "audio identity";
if([document.getElementById("nai-video"),document.getElementById("nai-svg"),naiForeign].some(a=>a instanceof HTMLAudioElement))throw "foreign audio identity";
for(let i=0;i<naiOwners.length;i++){const a=naiOwners[i];a.controls=true;a.src="sound"+i+".webm";a.setAttribute("data-audio-owner","retained");}
globalThis.naiEvents=[];naiCreated.addEventListener("volumechange",event=>naiEvents.push(event.target===naiCreated&&event.currentTarget===naiCreated));naiCreated.volume=0.25;
naiCreated.remove();document.body.appendChild(naiCreated);
if(!(naiCreated instanceof HTMLAudioElement)||naiCreated.src!=="https://audio-interface.example/dir/sound1.webm")throw "moved identity";
'], runtime, mut messages)
	assert messages == []
	for i, id in ['nai-parsed', 'nai-created', 'nai-created-ns'] {
		element := document.get_element_by_id(id)?
		assert element.is_html_element() && element.local_name() == 'audio'
		assert element.has_attribute('controls') && element.get_attribute('src')? == 'sound${i}.webm'
		assert element.get_attribute('data-audio-owner')? == 'retained'
		media := html.html_media_element_for_dom_element(element)?
		if i == 1 { assert media.volume() == 0.25 }
		assert voidptr(runtime.native_event_target(runtime.evaluate_host_value('naiOwners[${i}]')!)!) == voidptr(element)
	}
	mut queue := html.main_thread_event_loop().task_queue()
	mut task_count := 0
	for {
		task := queue.take_first_runnable_matching(fn [document] (task &html.Task) bool {
			owner := task.document() or { return false }
			return task.source() == .media_element && voidptr(owner) == voidptr(document)
		}) or { break }
		task_count++
		assert task_count < 100
		task.execute()
	}
	assert runtime.evaluate_host('naiEvents.length===1&&naiEvents[0]')! == 'true'
	for id in ['nai-svg', 'nai-foreign'] { assert html.html_media_element_for_dom_element(document.get_element_by_id(id)?) == none }
	url := dom.URL{ value: 'https://audio-adoption.example/new/' }
	mut adopted := html.parse_navigation_document('<!doctype html>', url, url.origin(), none)!
	defer { adopted.finalize() }
	created := document.get_element_by_id('nai-created')?
	adopted.adopt_node(created.as_node())
	assert runtime.evaluate_host('naiCreated instanceof HTMLAudioElement&&naiCreated.src==="https://audio-adoption.example/new/sound1.webm"')! == 'true'
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
}

fn test_native_audio_interface_retains_private_prototypes_across_global_replacement_and_runtime_close() {
	$if !darwin { return }
	mut first, host, mut document := native_audio_interface_fixture()!
	mut second, _, mut second_document := native_audio_interface_fixture()!
	defer { first.close();second.close();document.finalize();second_document.finalize() }
	assert first.evaluate_host(r'globalThis.naiSavedAudio=HTMLAudioElement;globalThis.naiSavedMedia=HTMLMediaElement;globalThis.naiSavedVideo=HTMLVideoElement;globalThis.HTMLAudioElement=function Replacement(){};globalThis.HTMLMediaElement=null;globalThis.HTMLVideoElement=null;globalThis.naiFresh={};__ladybirdMediaElementBind(naiFresh,"__created_audio_interface","audio");naiFresh instanceof naiSavedAudio&&naiFresh instanceof naiSavedMedia&&!(naiFresh instanceof naiSavedVideo)&&Object.getPrototypeOf(naiFresh)===naiSavedAudio.prototype&&naiFresh.constructor===naiSavedAudio')! == 'true'
	assert second.evaluate_host('HTMLAudioElement.name==="HTMLAudioElement"&&naiAudio instanceof HTMLAudioElement&&naiVideo instanceof HTMLVideoElement')! == 'true'
	assert first.evaluate_host('naiFresh.preload="none";naiFresh.src="created.webm";naiFresh.src==="https://audio-interface.example/dir/created.webm"')! == 'true'
	value := first.evaluate_host_value('naiFresh')!
	media := host.media_element_for_binding(value)!
	assert media.current_src() == 'https://audio-interface.example/dir/created.webm'
	first.close()
	assert host.elements_for_binding().len == 0
	if _ := host.media_element_for_binding(value) { assert false } else { assert err.msg() == 'Media element binding is closed' }
	assert second.evaluate_host('naiAudio instanceof HTMLAudioElement&&naiAudio.paused')! == 'true'
}
