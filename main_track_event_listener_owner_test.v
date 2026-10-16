module main

import browserjs
import dom
import html
import page
import time

@[heap]
struct NativeTrackListenerProbe {
mut:
	urls []string
	cors []html.CORSSettingAttribute
}

fn native_track_listener_document(markup string, address string) !&dom.Document {
	owner := page.Page.create(1)!
	return parse_browser_navigation_document_for_page_with_response_time(markup, dom.URL{value: address}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
}

fn native_track_listener_run(document &dom.Document, runtime &browserjs.Runtime, script string) {
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [script], runtime, mut messages)
	assert messages == []
}

fn native_track_listener_flush(document &dom.Document, runtime &browserjs.Runtime) ! {
	snapshot := runtime.evaluate_host('__ladybirdFinalize()')!
	mut messages := []string{}
	apply_javascript_runtime_state(document, snapshot, runtime, mut messages)
	assert messages == []
	runtime.evaluate_host('__ladybirdClearLogs();0')!
}

fn native_track_listener_balance(document &dom.Document, runtime &browserjs.Runtime) {
	mut queue := html.main_thread_event_loop().task_queue()
	mut count := 0
	for {
		task := queue.take_first_runnable_matching(fn [document] (item &html.Task) bool {
			owner := item.document() or { return false }
			return item.source() == .media_element && voidptr(owner) == voidptr(document)
		}) or { break }
		count++
		assert count < 100
		task.execute()
	}
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
	assert runtime.libjs_vm().execution_context_stack().len == 0 && runtime.libjs_vm().interpreter_stack().depth() == 0
}

fn native_track_listener_model(element &dom.Element, probe &NativeTrackListenerProbe) &html.HTMLTrackElementModel {
	mut model := html.html_track_element_model_for_dom_element(unsafe { &dom.HTMLTrackElement(element) })
	model.set_fetch_hook(fn [probe] (url dom.URL, cors html.CORSSettingAttribute) !html.TextTrackResourceResponse {
		mut observed := unsafe { &NativeTrackListenerProbe(probe) }
		observed.urls << url.serialize();observed.cors << cors
		if url.serialize().contains('broken') { return error('Controlled track listener fetch failure') }
		return html.TextTrackResourceResponse{body: 'WEBVTT\n\n${url.serialize()}\n00:00.000 --> 00:01.000\nlistener cue\n'}
	})
	return model
}

fn test_ordinary_track_listener_methods_inherit_native_target_for_all_html_facades() {
	$if !darwin { return }
	mut document := native_track_listener_document('<!doctype html><track id="ntl-parsed"><div id="ntl-container"></div>', 'https://track-listeners.example/base/')!
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close();document.finalize() }
	native_track_listener_run(document, runtime, r'
globalThis.ntlFacades=[document.getElementById("ntl-parsed")];
const created=document.createElement("track"),qualified=document.createElementNS("http://www.w3.org/1999/xhtml","q:track"),container=document.getElementById("ntl-container");
created.id="ntl-created";qualified.id="ntl-qualified";container.appendChild(created);container.appendChild(qualified);ntlFacades.push(created,qualified);
container.innerHTML="<track id=ntl-imported>";ntlFacades.push(container.querySelector("track"));
globalThis.ntlFacadeEvents=[];
for(const t of ntlFacades){for(const name of ["addEventListener","removeEventListener","dispatchEvent"])if(Object.hasOwn(t,name)||t[name]!==EventTarget.prototype[name])throw "native method inheritance";
 t.addEventListener("load",function(e){ntlFacadeEvents.push(this===t&&e.target===t&&e.currentTarget===t&&e instanceof Event&&!e.isTrusted)});
 if(!t.dispatchEvent(new Event("load")))throw "native dispatch";
}
for(const ns of [null,"http://www.w3.org/2000/svg","urn:foreign"]){const foreign=document.createElementNS(ns,"track");if(foreign instanceof HTMLTrackElement||!Object.hasOwn(foreign,"addEventListener"))throw "foreign facade";}
if(!Object.hasOwn(container,"addEventListener"))throw "ordinary Element boundary";
globalThis.ntlLegacy=0;container.addEventListener("legacy-track-boundary",()=>ntlLegacy++);
if(ntlFacadeEvents.length!==4||!ntlFacadeEvents.every(Boolean))throw "facade event owner";
')
	assert runtime.evaluate_host('__ladybirdDispatch("legacy-track-boundary","ntl-container");ntlLegacy===1')! == 'true'
	for index in 0 .. 4 {
		target := runtime.native_event_target(runtime.evaluate_host_value('ntlFacades[${index}]')!)!
		assert target.event_listener_list().len == 1
		assert unsafe { &dom.Element(target) }.is_html_element()
		assert unsafe { &dom.Element(target) }.local_name() == 'track'
	}
	assert runtime.evaluate_host('ntlFacades.every(t=>t.dispatchEvent(new Event("wheel")))')! == 'true'
	native_track_listener_balance(document, runtime)
}

fn test_ordinary_track_listeners_observe_actual_loader_transitions_on_parsed_and_created_owners() {
	$if !darwin { return }
	mut document := native_track_listener_document('<!doctype html><video id="ntl-video" preload="none" crossorigin="use-credentials"><track id="ntl-video-track" src="seed-video.vtt"></video><audio id="ntl-audio" preload="none" crossorigin="anonymous"><track id="ntl-audio-track" src="seed-audio.vtt"></audio>', 'https://track-listeners.example/base/')!
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close();document.finalize() }
	native_track_listener_run(document, runtime, r'
globalThis.ntlTracks=[document.getElementById("ntl-video-track"),document.getElementById("ntl-audio-track")];
const created=document.createElement("track");created.id="ntl-created-track";created.src="seed-created.vtt";document.getElementById("ntl-audio").appendChild(created);ntlTracks.push(created);
globalThis.ntlLoaderOrder=[];globalThis.ntlLoaderChecks=[];globalThis.ntlLoaderEvents=[];globalThis.ntlParentEvents=0;
for(const parent of [document.getElementById("ntl-video"),document.getElementById("ntl-audio")])for(const name of ["load","error"])parent.addEventListener(name,()=>ntlParentEvents++);
for(const t of ntlTracks)for(const name of ["load","error"]){t.addEventListener(name,function(e){
 ntlLoaderOrder.push(t.id+":"+name);ntlLoaderEvents.push(e);ntlLoaderChecks.push(this===t&&e.target===t&&e.currentTarget===t&&e instanceof Event&&e.isTrusted&&!e.bubbles&&!e.cancelable&&!e.composed&&e.eventPhase===Event.AT_TARGET&&e.composedPath()[0]===t&&t.readyState===(name==="load"?HTMLTrackElement.LOADED:HTMLTrackElement.ERROR));
});}if(ntlLoaderOrder.length)throw "fabricated registration event";
')
	probe := &NativeTrackListenerProbe{}
	for index, id in ['ntl-video-track', 'ntl-audio-track', 'ntl-created-track'] {
		element := document.get_element_by_id(id)?
		model := native_track_listener_model(element, probe)
		html.html_track_element_inserted(unsafe { &dom.HTMLTrackElement(element) })
		assert model.ready_state() == .loaded
		assert runtime.evaluate_host('globalThis.ntlLateCount=0;ntlTracks[${index}].addEventListener("load",()=>ntlLateCount++,{once:true});ntlLateCount===0')! == 'true'
		for stage, source in ['changed-${index}.vtt', '', 'broken-${index}.vtt', 'recovered-${index}.vtt'] {
			assert runtime.evaluate_host('ntlTracks[${index}].src="${source}";ntlLoaderChecks.every(Boolean)')! == 'true'
			assert model.ready_state() == if stage in [0,3] { html.TrackElementReadyState.loaded } else { html.TrackElementReadyState.error }
		}
		assert runtime.evaluate_host('ntlLateCount===1')! == 'true'
		assert model.event_count('load') == 3 && model.event_count('error') == 2
		assert probe.cors.last() == if index == 0 { html.CORSSettingAttribute.use_credentials } else { html.CORSSettingAttribute.anonymous }
	}
	assert runtime.evaluate_host('ntlLoaderOrder.length===15&&ntlLoaderChecks.length===15&&ntlLoaderChecks.every(Boolean)&&ntlParentEvents===0&&new Set(ntlLoaderEvents).size===15&&ntlLoaderEvents.every(e=>e.target!==null&&e.currentTarget===null&&e.eventPhase===Event.NONE&&e.composedPath().length===0)')! == 'true'
	assert probe.urls.len == 12
	for id in ['ntl-video', 'ntl-audio'] {
		media := html.html_media_element_for_dom_element(document.get_element_by_id(id)?)?
		assert media.paused() && media.current_src() == '' && media.network_state() == .empty
	}
	native_track_listener_balance(document, runtime)
}

fn test_ordinary_track_listener_conversion_options_abort_and_public_dispatch_use_native_list() {
	$if !darwin { return }
	mut document := native_track_listener_document('<!doctype html><track id="ntl-options">', 'https://track-options.example/')!
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close();document.finalize() }
	native_track_listener_run(document, runtime, r'globalThis.ntlOptions=document.getElementById("ntl-options");0')
	signal := dom.AbortSignal.new()
	wrapped := runtime.javascript_event_target(unsafe { &dom.EventTarget(signal) }, none)!
	runtime.define_value_host_function('__ntlSignal', fn [wrapped] (_ voidptr, _ []voidptr) !voidptr { return wrapped })!
	assert runtime.evaluate_host(r'(()=>{
 const t=ntlOptions,marker={},order=[],checks=[];let converted=0,traps=0;
 const input={[Symbol.toPrimitive](hint){if(hint!=="string")throw "hint";converted++;return "tick"}},poison={[Symbol.toPrimitive](){throw marker}},proxy=new Proxy(t,{get(){traps++;throw marker},getPrototypeOf(){traps++;throw marker}}),revoked=Proxy.revocable(t,{});revoked.revoke();
 for(const receiver of [{},Object.create(t),Object.create(HTMLTrackElement.prototype),proxy,revoked.proxy,1])for(const name of ["addEventListener","removeEventListener"])try{t[name].call(receiver,poison,()=>{},{get capture(){throw marker}});return false}catch(e){if(!(e instanceof TypeError))return false}
 if(traps) return false;
 let windowCount=0;const windowListener=function(e){if(this!==window||e.target!==document||e.currentTarget!==window)throw "Window owner";windowCount++};
 for(const receiver of [null,undefined]){t.addEventListener.call(receiver,"nullish-track-receiver",windowListener);t.dispatchEvent.call(receiver,new Event("nullish-track-receiver"));t.removeEventListener.call(receiver,"nullish-track-receiver",windowListener);}
 if(windowCount!==2)throw "nullish Window dispatch";
 for(const name of ["addEventListener","removeEventListener"])try{t[name]({[Symbol.toPrimitive](){throw marker}},()=>{});return false}catch(e){if(e!==marker)return false}
 const optionOrder=[];globalThis.ntlSignalCount=0;
 t.addEventListener("signal",()=>ntlSignalCount++,{get capture(){optionOrder.push("capture");return false},get once(){optionOrder.push("once");return false},get passive(){optionOrder.push("passive");return false},get signal(){optionOrder.push("signal");return __ntlSignal()}});
 if(optionOrder.join(",")!=="capture,once,passive,signal")return false;
 try{t.addEventListener("tick",()=>{}, {get capture(){throw marker}});return false}catch(e){if(e!==marker)return false}
 const shared=function(e){order.push("shared");checks.push(this===t&&e.target===t&&e.currentTarget===t&&!e.isTrusted);return false},capture=()=>order.push("capture"),removed=()=>order.push("removed"),object={handleEvent(e){order.push("object");checks.push(this===object&&e.target===t)}};
 t.addEventListener(input,shared);t.addEventListener("tick",shared);t.addEventListener("tick",capture,true);t.removeEventListener("tick",capture,false);t.addEventListener("tick",removed,true);t.removeEventListener("tick",removed,true);t.addEventListener("tick",object,{once:true});
 t.addEventListener("Tick",()=>order.push("wrong case"));
 const first=new Event("tick",{cancelable:true}),second=new Event("tick");if(!t.dispatchEvent(first)||first.defaultPrevented||!t.dispatchEvent(second))return false;
 t.removeEventListener("tick",shared);t.removeEventListener("tick",capture,true);
 let passive=false;t.addEventListener("passive",e=>{e.preventDefault();passive=e.defaultPrevented},{passive:true,once:true});if(!t.dispatchEvent(new Event("passive",{cancelable:true}))||passive)return false;
 t.addEventListener("cancel",e=>e.preventDefault(),{once:true});if(t.dispatchEvent(new Event("cancel",{cancelable:true})))return false;
 let recursive=false;t.addEventListener("recursive",e=>{try{t.dispatchEvent(e)}catch(reason){recursive=reason instanceof DOMException&&reason.name==="InvalidStateError"}},{once:true});t.dispatchEvent(new Event("recursive"));
 const other=new EventTarget();let borrowed=0;t.addEventListener.call(other,"borrow",()=>borrowed++);other.dispatchEvent(new Event("borrow"));
 if(!(converted===1&&order.join(",")==="capture,shared,object,capture,shared"&&checks.length===3&&checks.every(Boolean)&&first.target===t&&first.currentTarget===null&&first.eventPhase===0&&recursive&&borrowed===1))throw JSON.stringify({converted,order,checks,recursive,borrowed});
 return true;
})()')! == 'true'
	mut mutable_signal := unsafe { &dom.AbortSignal(signal) }
	mutable_signal.signal_abort(dom.js_string('track abort'))
	assert runtime.evaluate_host('ntlOptions.dispatchEvent(new Event("signal"));ntlSignalCount===0')! == 'true'
	target := runtime.native_event_target(runtime.evaluate_host_value('ntlOptions')!)!
	assert voidptr(target) == voidptr(document.get_element_by_id('ntl-options')?)
	assert target.event_listener_list().len == 1
	native_track_listener_balance(document, runtime)
}

fn test_ordinary_track_load_callback_replaces_source_reentrantly_and_replays_dom_mutations() {
	$if !darwin { return }
	mut document := native_track_listener_document('<!doctype html><audio preload="none"><track id="ntl-reentrant"></audio><p id="ntl-result">before</p>', 'https://track-listeners.example/base/')!
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close();document.finalize() }
	native_track_listener_run(document, runtime, r'
globalThis.ntlReentrant=document.getElementById("ntl-reentrant");globalThis.ntlNativeTrack=ntlReentrant.track;globalThis.ntlReentryEvents=[];globalThis.ntlReentryOrder=[];
ntlReentrant.addEventListener("load",function(e){if(this!==ntlReentrant||e.target!==this||e.currentTarget!==this||!e.isTrusted||this.readyState!==HTMLTrackElement.LOADED||this.track!==ntlNativeTrack)throw "load owner";
 ntlReentryEvents.push(e);ntlReentryOrder.push(this.getAttribute("src"));if(this.getAttribute("src")==="outer.vtt"){this.src="inner.vtt";document.getElementById("ntl-result").textContent="inner source loaded";}
});
')
	probe := &NativeTrackListenerProbe{}
	element := document.get_element_by_id('ntl-reentrant')?
	mut model := native_track_listener_model(element, probe)
	model.set_mode(.hidden);model.start_the_track_processing_model()
	assert runtime.evaluate_host('ntlReentrant.src="outer.vtt";ntlReentryOrder.join(",")==="outer.vtt,inner.vtt"&&ntlReentryEvents[0]!==ntlReentryEvents[1]&&ntlReentryEvents.every(e=>e.currentTarget===null&&e.target===ntlReentrant)')! == 'true'
	native_track_listener_flush(document, runtime)!
	assert element.get_attribute('src')? == 'inner.vtt' && probe.urls.len == 2
	assert model.ready_state() == .loaded && model.track.cues().length() == 1
	assert model.track.cues().get_cue_by_id('https://track-listeners.example/base/inner.vtt')?.text() == 'listener cue'
	assert document.get_element_by_id('ntl-result')?.as_node().text_content()? == 'inner source loaded'
	native_track_listener_balance(document, runtime)
}

fn test_ordinary_track_listeners_survive_adoption_respect_callback_gate_and_close_independently() {
	$if !darwin { return }
	mut document := native_track_listener_document('<!doctype html><audio preload="none"><track id="ntl-adopt" src="seed.vtt"></audio>', 'https://old-track-listener.example/base/')!
	mut adopted := native_track_listener_document('<!doctype html><audio id="ntl-destination" preload="none" crossorigin="use-credentials"></audio><track id="ntl-independent">', 'https://new-track-listener.example/other/')!
	mut runtime := browserjs.Runtime.create();mut independent := browserjs.Runtime.create()
	defer { runtime.close();independent.close();document.finalize();adopted.finalize() }
	native_track_listener_run(document, runtime, r'globalThis.ntlAdopt=document.getElementById("ntl-adopt");globalThis.ntlAdoptEvents=[];ntlAdopt.addEventListener("load",function(e){if(this!==ntlAdopt||e.target!==ntlAdopt||e.currentTarget!==ntlAdopt||!e.isTrusted)throw "adopted owner";ntlAdoptEvents.push(e)});0')
	native_track_listener_run(adopted, independent, r'globalThis.ntlIndependent=document.getElementById("ntl-independent");globalThis.ntlIndependentCount=0;ntlIndependent.addEventListener("load",()=>ntlIndependentCount++);0')
	probe := &NativeTrackListenerProbe{}
	element := document.get_element_by_id('ntl-adopt')?
	model := native_track_listener_model(element, probe)
	html.html_track_element_inserted(unsafe { &dom.HTMLTrackElement(element) })
	assert runtime.evaluate_host('ntlAdoptEvents.length===1')! == 'true'
	adopted.adopt_node(element.as_node())
	parent := adopted.get_element_by_id('ntl-destination')?
	mut parent_node := unsafe { &dom.Node(parent) };parent_node.append_child(element.as_node())!
	assert runtime.evaluate_host('ntlAdopt.src="adopted.vtt";ntlAdoptEvents.length===2&&ntlAdoptEvents.every(e=>e.target===ntlAdopt&&e.currentTarget===null)')! == 'true'
	assert probe.urls.last() == 'https://new-track-listener.example/other/adopted.vtt' && probe.cors.last() == .use_credentials
	assert html.html_track_element_model_for_dom_element(unsafe { &dom.HTMLTrackElement(element) }) == model
	mut owner := unsafe { &page.Page(document.page()) }
	target := unsafe { &dom.EventTarget(element) }
	owner.set_is_scripting_enabled(false)
	target.dispatch_event(dom.Event.create('load', dom.EventInit{}))
	owner.set_is_scripting_enabled(true)
	assert runtime.evaluate_host('ntlAdoptEvents.length===2')! == 'true'
	target.dispatch_event(dom.Event.create('load', dom.EventInit{}))
	assert runtime.evaluate_host('ntlAdoptEvents.length===3')! == 'true'
	native_track_listener_balance(document, runtime)
	native_track_listener_balance(adopted, independent)
	runtime.close()
	assert target.dispatch_event(dom.Event.create('load', dom.EventInit{}))
	independent_target := unsafe { &dom.EventTarget(adopted.get_element_by_id('ntl-independent')?) }
	independent_target.dispatch_event(dom.Event.create('load', dom.EventInit{}))
	assert independent.evaluate_host('ntlIndependentCount===1')! == 'true'
}
