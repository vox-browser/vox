module main

import browserjs
import dom
import html
import page
import time

fn native_track_element_document(markup string) !&dom.Document {
	owner := page.Page.create(1)!
	return parse_browser_navigation_document_for_page_with_response_time(markup, dom.URL{value: 'https://track-element.example/base/'}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
}

fn native_track_element_run(document &dom.Document, runtime &browserjs.Runtime, script string) {
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [script], runtime, mut messages)
	assert messages == []
}

fn test_native_track_element_readonly_metadata_and_actual_text_track_owner() {
	$if !darwin { return }
	mut document := native_track_element_document('<!doctype html><track id="track-owner" kind="captions" label="English" srclang="en">')!
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close();document.finalize() }
	native_track_element_run(document, runtime, r'
globalThis.nthElement=document.getElementById("track-owner");globalThis.nthTrack=nthElement.track;
const C=HTMLTrackElement,p=C.prototype,g=Object.getOwnPropertyDescriptor(globalThis,"HTMLTrackElement");
if(C.name!=="HTMLTrackElement"||C.length!==0||!g.writable||!g.configurable||g.enumerable||Object.getOwnPropertyDescriptor(C,"prototype").writable)throw "constructor metadata";
for(const call of [()=>C(),()=>new C()]){let ok=false;try{call()}catch(e){ok=e instanceof TypeError}if(!ok)throw "illegal constructor";}
for(const name of ["track","readyState"]){const d=Object.getOwnPropertyDescriptor(p,name);if(!d.enumerable||!d.configurable||d.set!==undefined||d.get.name!=="get "+name||d.get.length!==0||!Function.prototype.toString.call(d.get).includes("[native code]")||Object.hasOwn(nthElement,name)||Reflect.set(nthElement,name,null))throw "readonly getter";}
for(const [name,value] of [["NONE",0],["LOADING",1],["LOADED",2],["ERROR",3]])for(const o of [C,p]){const d=Object.getOwnPropertyDescriptor(o,name);if(d.value!==value||!d.enumerable||d.writable||d.configurable)throw "constant";}
if(!(nthElement instanceof C)||!(nthElement instanceof Element)||!(nthElement instanceof EventTarget)||Object.getPrototypeOf(nthElement)!==p||Object.getPrototypeOf(p)!==Element.prototype||Object.prototype.toString.call(nthElement)!=="[object HTMLTrackElement]")throw "element prototype";
if(nthTrack!==nthElement.track||!(nthTrack instanceof TextTrack)||!(nthTrack instanceof EventTarget)||nthTrack.kind!=="captions"||nthTrack.label!=="English"||nthTrack.language!=="en"||nthTrack.id!=="track-owner"||nthElement.readyState!==C.NONE)throw "native track";
')
	element := document.get_element_by_id('track-owner')?
	track := html.html_track_element_track(unsafe { &dom.HTMLTrackElement(element) })
	assert voidptr(runtime.native_event_target(runtime.evaluate_host_value('nthTrack')!)!) == voidptr(track)
	assert voidptr(runtime.native_event_target(runtime.evaluate_host_value('nthElement')!)!) == voidptr(element)
}

fn test_native_track_element_created_imported_qualified_and_foreign_namespace_facades() {
	$if !darwin { return }
	mut document := native_track_element_document('<!doctype html><audio id="nth-parent" preload="none"></audio><div id="nth-container"></div>')!
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close();document.finalize() }
	native_track_element_run(document, runtime, r'
globalThis.nthCreated=document.createElement("track");nthCreated.id="created-track";nthCreated.setAttribute("label","Created");globalThis.nthCreatedTrack=nthCreated.track;
if(!(nthCreated instanceof HTMLTrackElement)||nthCreatedTrack.label!=="Created"||nthCreated.readyState!==HTMLTrackElement.NONE)throw "created track";
const parent=document.getElementById("nth-parent"),container=document.getElementById("nth-container");parent.appendChild(nthCreated);if(nthCreated.track!==nthCreatedTrack)throw "inserted identity";container.appendChild(nthCreated);nthCreated.remove();parent.appendChild(nthCreated);if(nthCreated.track!==nthCreatedTrack)throw "moved identity";
container.innerHTML="<track id=imported-track label=Imported>";const imported=container.querySelector("track");if(!(imported instanceof HTMLTrackElement)||imported.track.label!=="Imported"||imported.track!==imported.track)throw "imported owner";
globalThis.nthQualified=document.createElementNS("http://www.w3.org/1999/xhtml","q:track");nthQualified.setAttribute("label","Qualified");if(!(nthQualified instanceof HTMLTrackElement)||nthQualified.track.label!=="Qualified"||Object.hasOwn(nthQualified,"readyState"))throw "qualified HTML track";
const savedEndsWith=String.prototype.endsWith;String.prototype.endsWith=function(){throw "author endsWith"};try{if(!(document.createElementNS("http://www.w3.org/1999/xhtml","p:track").track instanceof TextTrack)||document.createElement("div") instanceof HTMLTrackElement)throw "captured namespace check";}finally{String.prototype.endsWith=savedEndsWith;}
for(const ns of [null,"http://www.w3.org/2000/svg","urn:foreign"]){const foreign=document.createElementNS(ns,"track");if(foreign instanceof HTMLTrackElement||foreign.track!==undefined)throw "foreign track cast";}
globalThis.nthRetainedConstructor=HTMLTrackElement;globalThis.HTMLTrackElement=function Replaced(){};const late=document.createElement("track");if(!(late instanceof nthRetainedConstructor)||late instanceof HTMLTrackElement||!(late.track instanceof TextTrack))throw "captured prototype";
')
	element := document.get_element_by_id('created-track')?
	track := html.html_track_element_track(unsafe { &dom.HTMLTrackElement(element) })
	assert voidptr(runtime.native_event_target(runtime.evaluate_host_value('nthCreatedTrack')!)!) == voidptr(track)
	assert element.parent_element()?.local_name() == 'audio'
}

fn test_native_track_element_getters_replay_metadata_and_read_live_native_readiness() {
	$if !darwin { return }
	mut document := native_track_element_document('<!doctype html><track id="live-track" kind="captions" label="Original" srclang="en">')!
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close();document.finalize() }
	native_track_element_run(document, runtime, r'
globalThis.nthLive=document.getElementById("live-track");globalThis.nthLiveTrack=nthLive.track;nthLive.setAttribute("kind","descriptions");nthLive.setAttribute("label","λ\0🎵");nthLive.setAttribute("srclang","fr");nthLive.id="renamed-track";
if(nthLive.track!==nthLiveTrack||nthLiveTrack.kind!=="descriptions"||nthLiveTrack.label!=="λ\0🎵"||nthLiveTrack.language!=="fr"||nthLiveTrack.id!=="renamed-track")throw "live metadata";
nthLive.removeAttribute("kind");nthLive.removeAttribute("label");nthLive.removeAttribute("srclang");if(nthLive.track!==nthLiveTrack||nthLiveTrack.kind!=="subtitles"||nthLiveTrack.label!==""||nthLiveTrack.language!=="")throw "removed metadata";
')
	element := document.get_element_by_id('renamed-track')?
	mut track := html.html_track_element_track(unsafe { &dom.HTMLTrackElement(element) })
	for index, state in [html.TextTrackReadinessState.not_loaded, .loading, .loaded, .failed_to_load] {
		track.set_readiness_state(state)
		assert runtime.evaluate_host('nthLive.readyState===${index}&&nthLive.track===nthLiveTrack')! == 'true'
	}
	track.set_label('Native change')
	assert runtime.evaluate_host('nthLive.track.label==="Native change"')! == 'true'
}

fn test_native_track_element_text_target_and_track_event_resolve_before_direct_getter() {
	$if !darwin { return }
	mut document := native_track_element_document('<!doctype html><track id="event-track" label="Event payload">')!
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close();document.finalize() }
	element := document.get_element_by_id('event-track')?
	track := html.html_track_element_track(unsafe { &dom.HTMLTrackElement(element) })
	native_track_element_run(document, runtime, r'globalThis.nthEventElement=document.getElementById("event-track");0')
	event := html.TrackEvent.create('payload', html.TrackEventInit{track: html.TrackEventTrack.from_text(track)})
	wrapped := runtime.javascript_event(unsafe { &dom.Event(event) })!
	runtime.define_value_host_function('__nthNativeEvent', fn [wrapped] (_ voidptr, _ []voidptr) !voidptr { return wrapped })!
	assert runtime.evaluate_host('globalThis.nthPayload=__nthNativeEvent().track;nthPayload instanceof TextTrack&&nthPayload===nthEventElement.track&&nthPayload.label==="Event payload"')! == 'true'
	assert runtime.javascript_event_target(&track.EventTarget, none)! == runtime.evaluate_host_value('nthPayload')!
	// A second model exercises EventTarget resolution before either IDL getter.
	mut second := document.create_element('track')!
	second.set_attribute_value('id', 'target-track')
	body := document.body()?
	mut body_node := unsafe { &dom.Node(body) }
	body_node.append_child(unsafe { &dom.Node(second) })!
	second_track := html.html_track_element_track(unsafe { &dom.HTMLTrackElement(second) })
	assert runtime.evaluate_host('globalThis.nthTargetElement=document.getElementById("target-track");nthTargetElement instanceof HTMLTrackElement')! == 'true'
	assert runtime.javascript_event_target(&second_track.EventTarget, none)! == runtime.evaluate_host_value('nthTargetElement.track')!
}

@[heap]
struct NativeTrackReplayProbe {
mut:
	calls int
}

fn test_native_track_element_brands_before_replay_and_preserves_original_replay_exception() {
	$if !darwin { return }
	url := dom.URL{value: 'https://track-brand.example/'}
	mut document := html.parse_navigation_document('<!doctype html><track id="brand-track"><track id="unwrapped-track"><div id="ordinary"></div>', url, url.origin(), none)!
	mut runtime := browserjs.Runtime.create()
	probe := &NativeTrackReplayProbe{}
	mut host := browserjs.MediaElementHost.create(document, fn [probe] (runtime &browserjs.Runtime) ! {
		mut mutable_probe := unsafe { &NativeTrackReplayProbe(probe) };mutable_probe.calls++
		mut owner := unsafe { &browserjs.Runtime(runtime) }
		value := owner.evaluate_host_value('if(globalThis.nthThrowReplay)throw globalThis.nthReplayMarker;0')!
		owner.release_javascript_value(value)
	})!
	host.install(mut runtime)!
	defer { runtime.close();document.finalize() }
	for key, element in host.elements_for_binding() {
		if element.get_attribute_value('id') == 'brand-track' { runtime.evaluate_host('globalThis.nthBrand={};__ladybirdTrackElementBind(nthBrand,"${key}");0')! }
		if element.get_attribute_value('id') == 'unwrapped-track' { runtime.evaluate_host('globalThis.nthUnwrappedKey="${key}";0')! }
		if element.local_name() == 'div' { assert runtime.evaluate_host('(()=>{try{__ladybirdTrackElementBind({},"${key}");return false}catch(e){return e instanceof TypeError}})()')! == 'true' }
	}
	assert probe.calls == 0
	assert runtime.evaluate_host('(()=>{try{__ladybirdTrackElementBind(nthBrand,nthUnwrappedKey);return false}catch(e){return e instanceof TypeError}})()')! == 'true'
	assert voidptr(runtime.native_event_target(runtime.evaluate_host_value('nthBrand')!)!) == voidptr(document.get_element_by_id('brand-track')?)
	assert runtime.evaluate_host(r'(()=>{let traps=0;for(const name of ["track","readyState"]){const get=Object.getOwnPropertyDescriptor(HTMLTrackElement.prototype,name).get;for(const receiver of [null,undefined,1,{},Object.create(nthBrand),Object.create(HTMLTrackElement.prototype),new Proxy(nthBrand,{get(){traps++;throw 0},getPrototypeOf(){traps++;throw 0}})])try{get.call(receiver);return false}catch(e){if(!(e instanceof TypeError))return false}}return traps===0})()')! == 'true'
	assert probe.calls == 0
	assert runtime.evaluate_host('nthBrand.track instanceof TextTrack&&nthBrand.readyState===HTMLTrackElement.NONE')! == 'true'
	assert probe.calls == 2
	assert runtime.evaluate_host(r'globalThis.nthReplayMarker={};globalThis.nthThrowReplay=true;(()=>{for(const name of ["track","readyState"])try{Object.getOwnPropertyDescriptor(HTMLTrackElement.prototype,name).get.call(nthBrand);return false}catch(e){if(e!==nthReplayMarker)return false}return true})()')! == 'true'
	assert probe.calls == 4
}

fn test_native_track_element_adoption_keeps_actual_model_and_independent_runtime() {
	$if !darwin { return }
	mut document := native_track_element_document('<!doctype html><track id="adopt-track" label="Before adoption">')!
	mut other_document := native_track_element_document('<!doctype html><body></body>')!
	mut runtime := browserjs.Runtime.create()
	mut other_runtime := browserjs.Runtime.create()
	defer { runtime.close();other_runtime.close();document.finalize();other_document.finalize() }
	native_track_element_run(document, runtime, r'globalThis.nthAdopt=document.getElementById("adopt-track");globalThis.nthAdoptTrack=nthAdopt.track;0')
	mut element := document.get_element_by_id('adopt-track')?
	track := html.html_track_element_track(unsafe { &dom.HTMLTrackElement(element) })
	other_document.adopt_node(unsafe { &dom.Node(element) })
	element.set_attribute_value('label', 'After adoption')
	assert runtime.evaluate_host('nthAdopt.track===nthAdoptTrack&&nthAdoptTrack.label==="After adoption"&&new TrackEvent("saved",{track:nthAdoptTrack}).track===nthAdoptTrack')! == 'true'
	assert html.html_track_element_track(unsafe { &dom.HTMLTrackElement(element) }) == track
	native_track_element_run(other_document, other_runtime, r'globalThis.nthOther=document.createElement("track");globalThis.nthOtherTrack=nthOther.track;if(!(nthOtherTrack instanceof TextTrack))throw "independent track";0')
	runtime.close()
	assert other_runtime.evaluate_host('nthOther.track===nthOtherTrack&&nthOther.readyState===HTMLTrackElement.NONE')! == 'true'
}
