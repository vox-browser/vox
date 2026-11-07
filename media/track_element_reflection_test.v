module main

import browserjs
import dom
import html
import page
import time

@[heap]
struct NativeTrackReflectionProbe {
mut:
	replays int
	urls []string
	saw_outer bool
}

fn native_track_reflection_host(replay ?browserjs.MediaElementReplayHook) !(&browserjs.Runtime, &dom.Document, &dom.Element) {
	url := dom.URL{value: 'https://track-reflection.example/first/page.html'}
	mut document := html.parse_navigation_document('<!doctype html><base id="ntr-base" href="/first/"><track id="ntr-owner">', url, url.origin(), none)!
	mut runtime := browserjs.Runtime.create()
	mut host := browserjs.MediaElementHost.create(document, replay)!
	host.install(mut runtime)!
	for key, element in host.elements_for_binding() {
		if element.local_name() == 'track' { runtime.evaluate_host('globalThis.ntr={};__ladybirdTrackElementBind(ntr,"${key}");0')! }
	}
	element := document.get_element_by_id('ntr-owner') or { return error('Missing native track reflection owner') }
	return runtime, document, element
}

fn native_track_reflection_document(markup string) !&dom.Document {
	owner := page.Page.create(1)!
	return parse_browser_navigation_document_for_page_with_response_time(markup, dom.URL{value: 'https://track-reflection.example/first/'}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
}

fn native_track_reflection_run(document &dom.Document, runtime &browserjs.Runtime, script string) {
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [script], runtime, mut messages)
	assert messages == []
}

fn native_track_reflection_flush(document &dom.Document, runtime &browserjs.Runtime) ! {
	snapshot := runtime.evaluate_host('__ladybirdFinalize()')!
	mut messages := []string{}
	apply_javascript_runtime_state(document, snapshot, runtime, mut messages)
	assert messages == []
	runtime.evaluate_host('__ladybirdClearLogs();0')!
}

fn test_native_track_reflection_metadata_and_brands_precede_conversion_and_replay() {
	$if !darwin { return }
	probe := &NativeTrackReflectionProbe{}
	mut runtime, mut document, element := native_track_reflection_host(fn [probe] (_ &browserjs.Runtime) ! {
		mut observed := unsafe { &NativeTrackReflectionProbe(probe) };observed.replays++
	})!
	defer { runtime.close();document.finalize() }
	assert runtime.evaluate_host(r'(()=>{
 const p=HTMLTrackElement.prototype;let traps=0,conversions=0;
 const input={[Symbol.toPrimitive](){conversions++;throw "converted"}},proxy=new Proxy(ntr,{get(){traps++;throw 0},getPrototypeOf(){traps++;throw 0}}),revoked=Proxy.revocable(ntr,{});revoked.revoke();
 for(const name of ["kind","src","srclang","label","default"]){
  const d=Object.getOwnPropertyDescriptor(p,name);
  if(!d.enumerable||!d.configurable||d.get.name!=="get "+name||d.set.name!=="set "+name||d.get.length!==0||d.set.length!==1||Object.hasOwn(ntr,name))return false;
  for(const f of [d.get,d.set]){if(!Function.prototype.toString.call(f).includes("[native code]")||Object.hasOwn(f,"prototype"))return false;try{new f();return false}catch(e){if(!(e instanceof TypeError))return false}}
  for(const receiver of [null,undefined,1,{},Object.create(ntr),Object.create(p),proxy,revoked.proxy])for(const call of [()=>d.get.call(receiver),()=>d.set.call(receiver,input),()=>d.set.call(receiver)])try{call();return false}catch(e){if(!(e instanceof TypeError)||e.message!=="Not an object of type HTMLTrackElement")return false}
 }
 return traps===0&&conversions===0;
})()')! == 'true'
	assert probe.replays == 0 && !element.has_attribute('default')
	assert runtime.evaluate_host('ntr.kind==="subtitles"&&ntr.src===""&&ntr.label===""&&ntr.srclang===""&&ntr.default===false')! == 'true'
	assert probe.replays == 5
}

fn test_native_track_reflection_converts_once_preserves_utf16_and_original_exceptions() {
	$if !darwin { return }
	probe := &NativeTrackReflectionProbe{}
	mut runtime, mut document, element := native_track_reflection_host(fn [probe] (runtime &browserjs.Runtime) ! {
		mut observed := unsafe { &NativeTrackReflectionProbe(probe) };observed.replays++
		mut owner := unsafe { &browserjs.Runtime(runtime) }
		value := owner.evaluate_host_value('if(globalThis.ntrThrowReplay)throw ntrReason;0')!
		owner.release_javascript_value(value)
	})!
	defer { runtime.close();document.finalize() }
	assert runtime.evaluate_host(r'globalThis.ntrReason={};(()=>{
 const p=HTMLTrackElement.prototype;let calls=0;
 for(const name of ["kind","src","srclang","label"]){const d=Object.getOwnPropertyDescriptor(p,name);
  for(const value of [{[Symbol.toPrimitive](){throw ntrReason}},{get [Symbol.toPrimitive](){throw ntrReason}}])try{d.set.call(ntr,value);return false}catch(e){if(e!==ntrReason)return false}
  for(const value of [Symbol(),Object(Symbol()),{[Symbol.toPrimitive](){return {}}}])try{d.set.call(ntr,value);return false}catch(e){if(!(e instanceof TypeError))return false}
 }
 globalThis.ntrThrowReplay=true;
 for(const name of ["kind","src","srclang","label","default"]){const d=Object.getOwnPropertyDescriptor(p,name);
  for(const call of [()=>d.get.call(ntr),()=>d.set.call(ntr,{[Symbol.toPrimitive](hint){if(hint!=="string")throw "hint";calls++;return "captions"}})])try{call();return false}catch(e){if(e!==ntrReason)return false}
 }
 return calls===4;
})()')! == 'true'
	assert probe.replays == 10
	for name in ['kind', 'src', 'srclang', 'label', 'default'] { assert !element.has_attribute(name) }
	assert runtime.evaluate_host(r'globalThis.ntrThrowReplay=false;(()=>{
 let calls=0;globalThis.String=()=>{throw "author String"};
 for(const name of ["kind","src","srclang","label"]){const d=Object.getOwnPropertyDescriptor(HTMLTrackElement.prototype,name);
  for(const [input,raw] of [[undefined,"undefined"],[null,"null"],[false,"false"],[17,"17"],[1n,"1"]]){if(d.set.call(ntr,input)!==undefined)return false;if(name!=="kind"&&name!=="src"&&ntr[name]!==raw)return false;}
  d.set.call(ntr,{[Symbol.toPrimitive](hint){if(hint!=="string")throw "hint";calls++;return "\0\uD800A\uDC00🙂"}},{[Symbol.toPrimitive](){throw "extra"}});
  if((name==="label"||name==="srclang")&&ntr[name]!=="\0\uD800A\uDC00🙂")return false;
 }
 const d=Object.getOwnPropertyDescriptor(HTMLTrackElement.prototype,"default"),input={[Symbol.toPrimitive](){throw "boolean conversion"},valueOf(){throw 0},toString(){throw 0}};
 for(const v of [input,Symbol(),1n,"false"]){if(d.set.call(ntr,v)!==undefined||!ntr.default)return false;}
 for(const v of [undefined,null,false,0,0n,"",NaN]){d.set.call(ntr,v);if(ntr.default)return false;}d.set.call(ntr);return !ntr.default&&calls===4;
})()')! == 'true'
	assert element.get_attribute('label')? == '\x00\xED\xA0\x80A\xED\xB0\x80🙂'
	assert element.get_attribute('src')? == '\x00�A�🙂'
}

fn test_native_track_reflection_reads_live_qualified_attributes_and_current_document_urls() {
	$if !darwin { return }
	mut runtime, mut document, mut element := native_track_reflection_host(none)!
	defer { runtime.close();document.finalize() }
	assert runtime.evaluate_host(r'(()=>{for(const [raw,result] of [["CaPtIoNs","captions"],["descriptions","descriptions"],["chapters","chapters"],["SUBTITLES","subtitles"],["metadata","metadata"],["","metadata"],[" captions ","metadata"],["ſubtitles","metadata"],["unknown","metadata"]]){ntr.kind=raw;if(ntr.kind!==result)return false;}return true})()')! == 'true'
	element.remove_attribute('kind')
	assert runtime.evaluate_host('ntr.kind==="subtitles"')! == 'true'
	assert runtime.evaluate_host('ntr.src="../captions.vtt?q=%20#cue";ntr.src==="https://track-reflection.example/captions.vtt?q=%20#cue"')! == 'true'
	element.set_attribute_value('src', '')
	assert runtime.evaluate_host('ntr.src==="https://track-reflection.example/first/"')! == 'true'
	element.set_attribute_value('src', 'http://[bad\xED\xA0\x80')
	assert runtime.evaluate_host(r'ntr.src==="http://[bad\uFFFD"')! == 'true'
	element.remove_attribute('src')
	element.set_attribute_ns_for_bindings('urn:foreign', 'src', 'foreign.vtt')!
	assert runtime.evaluate_host('ntr.src="own.vtt";ntr.src==="https://track-reflection.example/first/foreign.vtt"')! == 'true'
	assert element.get_attribute_ns(none, 'src')? == 'own.vtt'
	element.remove_attribute_ns('urn:foreign', 'src')
	mut base := document.get_element_by_id('ntr-base')?
	base.set_attribute_value('href', '/changed/')
	assert runtime.evaluate_host('ntr.src==="https://track-reflection.example/changed/own.vtt"')! == 'true'
	url := dom.URL{value: 'https://adopted-track.example/other/'}
	mut adopted := html.parse_navigation_document('<!doctype html>', url, url.origin(), none)!
	defer { adopted.finalize() }
	adopted.adopt_node(element.as_node())
	assert runtime.evaluate_host('ntr.src==="https://adopted-track.example/other/own.vtt"')! == 'true'
	assert runtime.evaluate_host('ntr.src="after.vtt";ntr.src==="https://adopted-track.example/other/after.vtt"')! == 'true'
	element.remove_attribute('src')
	element.set_attribute_ns_for_bindings('urn:foreign', 'p:src', 'ignored.vtt')!
	assert runtime.evaluate_host('ntr.src===""')! == 'true'
}

fn test_compact_track_reflection_updates_parsed_created_and_qualified_owners_and_dirty_state() {
	$if !darwin { return }
	mut document := native_track_reflection_document('<!doctype html><track id="ntr-parsed" kind="CAPTIONS" label="Parsed" srclang="en" default="false"><p id="ntr-result"></p>')!
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close();document.finalize() }
	native_track_reflection_run(document, runtime, r'
globalThis.ntrParsed=document.getElementById("ntr-parsed");if(ntrParsed.kind!=="captions"||!ntrParsed.default||ntrParsed.getAttribute("default")!=="false")throw "parsed reflection";
globalThis.ntrCreated=document.createElement("track");ntrCreated.id="ntr-created";document.body.appendChild(ntrCreated);
globalThis.ntrQualified=document.createElementNS("http://www.w3.org/1999/xhtml","q:track");ntrQualified.id="ntr-qualified";document.body.appendChild(ntrQualified);
for(const t of [ntrParsed,ntrCreated,ntrQualified]){const track=t.track;
 if(Object.hasOwn(t,"src"))throw "own src";t.kind="DeScRiPtIoNs";t.label="λ\0🎵";t.srclang="fr";t.default=true;t.src="../captions.vtt";
 if(t.kind!=="descriptions"||t.getAttribute("kind")!=="DeScRiPtIoNs"||t.label!=="λ\0🎵"||t.srclang!=="fr"||!t.default||t.getAttribute("default")!==""||t.src!=="https://track-reflection.example/captions.vtt"||t.getAttribute("src")!=="../captions.vtt")throw "raw reflection";
 if(t.track!==track||track.kind!=="descriptions"||track.label!=="λ\0🎵"||track.language!=="fr")throw "model metadata";
 t.setAttribute("label","dirty");t.label="final";t.default=false;t.setAttribute("data-after","dirty");
 if(t.getAttribute("label")!=="final"||t.hasAttribute("default")||t.track.label!=="final")throw "dirty reflection";
}
const saved=[Object.defineProperty,Reflect.apply,WeakMap.prototype.get,WeakMap.prototype.set,Array.prototype.push,Array.prototype.splice];
ntrParsed.getAttribute=ntrParsed.setAttribute=ntrParsed.removeAttribute=()=>{throw "author attribute method"};
try{Object.defineProperty=Reflect.apply=WeakMap.prototype.get=WeakMap.prototype.set=Array.prototype.push=Array.prototype.splice=()=>{throw "author intrinsic"};ntrParsed.label="captured";ntrParsed.default=true;ntrParsed.src="retained.vtt";}finally{[Object.defineProperty,Reflect.apply,WeakMap.prototype.get,WeakMap.prototype.set,Array.prototype.push,Array.prototype.splice]=saved;}
if(ntrParsed.label!=="captured"||!ntrParsed.default||ntrParsed.src!=="https://track-reflection.example/first/retained.vtt")throw "captured synchronization";
document.getElementById("ntr-result").textContent="track reflection";
')
	native_track_reflection_flush(document, runtime)!
	for id in ['ntr-parsed', 'ntr-created', 'ntr-qualified'] {
		element := document.get_element_by_id(id)?
		assert element.get_attribute('kind')? == 'DeScRiPtIoNs'
		assert element.get_attribute('srclang')? == 'fr'
		assert element.get_attribute('label')? == if id == 'ntr-parsed' { 'captured' } else { 'final' }
		assert element.has_attribute('default') == (id == 'ntr-parsed')
		assert html.html_track_element_track(unsafe { &dom.HTMLTrackElement(element) }).label() == if id == 'ntr-parsed' { 'captured' } else { 'final' }
	}
}

fn test_compact_track_reflection_preserves_namespace_identity_and_qualified_boolean_removal() {
	$if !darwin { return }
	mut document := native_track_reflection_document('<!doctype html><track id="ntr-namespaces">')!
	mut element := document.get_element_by_id('ntr-namespaces')?
	for name in ['kind', 'label', 'srclang', 'src', 'default'] {
		element.set_attribute_ns_for_bindings('urn:first', name, if name == 'kind' { 'CHAPTERS' } else { 'foreign' })!
		element.set_attribute_ns_for_bindings('urn:prefixed', 'p:${name}', 'prefixed')!
	}
	foreign_label := element.get_attribute_node_ns('urn:first', 'label')?
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close();document.finalize() }
	native_track_reflection_run(document, runtime, r'
globalThis.ntrNs=document.getElementById("ntr-namespaces");
if(ntrNs.kind!=="chapters"||ntrNs.label!=="foreign"||ntrNs.srclang!=="foreign"||!ntrNs.default||ntrNs.src!=="https://track-reflection.example/first/foreign")throw "qualified read";
ntrNs.kind="captions";ntrNs.label="own label";ntrNs.srclang="en";ntrNs.src="own.vtt";ntrNs.default=true;
if(ntrNs.kind!=="chapters"||ntrNs.getAttribute("label")!=="foreign"||ntrNs.track.label!=="own label")throw "namespace overwrite";
ntrNs.default=false;if(!ntrNs.default||ntrNs.getAttribute("default")!=="")throw "first removal";
ntrNs.default=false;if(ntrNs.default||ntrNs.hasAttribute("default")||ntrNs.getAttribute("p:default")!=="prefixed")throw "second removal";
ntrNs.setAttribute("data-after","dirty");
')
	native_track_reflection_flush(document, runtime)!
	assert element.get_attribute_ns(none, 'label')? == 'own label'
	assert element.get_attribute_ns(none, 'src')? == 'own.vtt'
	assert element.get_attribute_node_ns('urn:first', 'label')? == foreign_label
	assert !element.has_attribute_ns('urn:first', 'default') && !element.has_attribute_ns(none, 'default')
	assert element.get_attribute_ns('urn:prefixed', 'default')? == 'prefixed'
}

fn test_compact_track_reflection_source_fetch_reentry_keeps_inner_write_and_actual_model() {
	$if !darwin { return }
	mut document := native_track_reflection_document('<!doctype html><audio preload="none"><track id="ntr-reentrant"></audio>')!
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close();document.finalize() }
	native_track_reflection_run(document, runtime, r'globalThis.ntrReentrant=document.getElementById("ntr-reentrant");globalThis.ntrTrack=ntrReentrant.track;0')
	element := document.get_element_by_id('ntr-reentrant')?
	mut model := html.html_track_element_model_for_dom_element(unsafe { &dom.HTMLTrackElement(element) })
	model.set_mode(.hidden)
	// The existing empty-source failure leaves the model waiting for a URL.
	model.start_the_track_processing_model()
	probe := &NativeTrackReflectionProbe{}
	handle := voidptr(runtime)
	model.set_fetch_hook(fn [probe, handle] (url dom.URL, _ html.CORSSettingAttribute) !html.TextTrackResourceResponse {
		mut observed := unsafe { &NativeTrackReflectionProbe(probe) };observed.urls << url.serialize()
		mut current := unsafe { &browserjs.Runtime(handle) }
		if observed.urls.len == 1 {
			observed.saw_outer = current.evaluate_host('ntrReentrant.getAttribute("src")==="outer.vtt"&&ntrReentrant.src==="https://track-reflection.example/first/outer.vtt"')! == 'true'
			assert observed.saw_outer
			assert current.evaluate_host('ntrReentrant.src="inner.vtt";ntrReentrant.getAttribute("src")==="inner.vtt"')! == 'true'
		}
		return html.TextTrackResourceResponse{body: 'WEBVTT\n\n${url.serialize()}\n00:00.000 --> 00:01.000\nreflected cue\n'}
	})
	assert runtime.evaluate_host('ntrReentrant.src="outer.vtt";ntrReentrant.src==="https://track-reflection.example/first/inner.vtt"&&ntrReentrant.getAttribute("src")==="inner.vtt"&&ntrReentrant.track===ntrTrack')! == 'true'
	assert probe.saw_outer && probe.urls == ['https://track-reflection.example/first/outer.vtt', 'https://track-reflection.example/first/inner.vtt']
	native_track_reflection_flush(document, runtime)!
	assert element.get_attribute('src')? == 'inner.vtt' && probe.urls.len == 2
	assert model.ready_state() == .loaded
	assert model.track.cues().get_cue_by_id('https://track-reflection.example/first/inner.vtt')?.text() == 'reflected cue'
}
