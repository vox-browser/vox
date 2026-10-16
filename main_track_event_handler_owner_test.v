module main

import browserjs
import dom
import html
import page
import time

@[heap]
struct NativeTrackHandlerProbe {
mut:
	replays int
	urls []string
}

fn native_track_handler_document(markup string, address string) !&dom.Document {
	owner := page.Page.create(1)!
	return parse_browser_navigation_document_for_page_with_response_time(markup, dom.URL{value: address}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
}

fn native_track_handler_host(replay ?browserjs.MediaElementReplayHook) !(&browserjs.Runtime, &dom.Document, &dom.Element) {
	document := native_track_handler_document('<!doctype html><track id="nhtDirect"><track id="nhtOther">', 'https://track-handlers.example/base/')!
	mut runtime := browserjs.Runtime.create()
	mut host := browserjs.MediaElementHost.create(document, replay)!
	host.install(mut runtime)!
	for key, element in host.elements_for_binding() {
		if element.local_name() == 'track' {
			id := element.get_attribute_value('id')
			runtime.evaluate_host('globalThis.${id}={};__ladybirdTrackElementBind(${id},"${key}");0')!
		}
	}
	element := document.get_element_by_id('nhtDirect') or { return error('Missing native track handler owner') }
	return runtime, document, element
}

fn native_track_handler_run(document &dom.Document, runtime &browserjs.Runtime, script string) {
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [script], runtime, mut messages)
	assert messages == []
}

fn native_track_handler_flush(document &dom.Document, runtime &browserjs.Runtime) ! {
	snapshot := runtime.evaluate_host('__ladybirdFinalize()')!
	mut messages := []string{}
	apply_javascript_runtime_state(document, snapshot, runtime, mut messages)
	assert messages == []
	runtime.evaluate_host('__ladybirdClearLogs();0')!
}

fn native_track_handler_balanced(document &dom.Document, runtime &browserjs.Runtime, expected_exceptions int) {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == expected_exceptions
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
	assert runtime.libjs_vm().execution_context_stack().len == 0 && runtime.libjs_vm().interpreter_stack().depth() == 0
}

fn native_track_handler_model(element &dom.Element, probe &NativeTrackHandlerProbe) &html.HTMLTrackElementModel {
	mut model := html.html_track_element_model_for_dom_element(unsafe { &dom.HTMLTrackElement(element) })
	model.set_fetch_hook(fn [probe] (url dom.URL, _ html.CORSSettingAttribute) !html.TextTrackResourceResponse {
		mut observed := unsafe { &NativeTrackHandlerProbe(probe) };observed.urls << url.serialize()
		if url.serialize().contains('broken') { return error('Controlled native track handler fetch failure') }
		return html.TextTrackResourceResponse{body: 'WEBVTT\n\n${url.serialize()}\n00:00.000 --> 00:01.000\nhandler cue\n'}
	})
	return model
}

fn test_native_track_handler_metadata_brands_and_original_replay_exceptions() {
	$if !darwin { return }
	probe := &NativeTrackHandlerProbe{}
	mut runtime, mut document, element := native_track_handler_host(fn [probe] (runtime &browserjs.Runtime) ! {
		mut observed := unsafe { &NativeTrackHandlerProbe(probe) };observed.replays++
		mut owner := unsafe { &browserjs.Runtime(runtime) }
		value := owner.evaluate_host_value('if(globalThis.nhtThrowReplay)throw nhtReplayReason;0')!
		owner.release_javascript_value(value)
	})!
	defer { runtime.close();document.finalize() }
	assert runtime.evaluate_host(r'(()=>{
 let traps=0;const p=HTMLTrackElement.prototype,proxy=new Proxy(nhtDirect,{get(){traps++;throw 0},getPrototypeOf(){traps++;throw 0}}),revoked=Proxy.revocable(nhtDirect,{});revoked.revoke();
 const value={get handleEvent(){traps++;throw 0},[Symbol.toPrimitive](){traps++;throw 0}};
 for(const name of ["onload","onerror"]){const d=Object.getOwnPropertyDescriptor(p,name);
  if(!d.enumerable||!d.configurable||d.get.name!=="get "+name||d.set.name!=="set "+name||d.get.length!==0||d.set.length!==1||Object.hasOwn(nhtDirect,name))throw "handler metadata";
  for(const f of [d.get,d.set]){if(!Function.prototype.toString.call(f).includes("[native code]")||Object.hasOwn(f,"prototype"))throw "native handler function";try{new f();return false}catch(e){if(!(e instanceof TypeError))throw e}}
  for(const receiver of [null,undefined,1,{},new EventTarget(),Object.create(nhtDirect),Object.create(p),proxy,revoked.proxy])for(const call of [()=>d.get.call(receiver),()=>d.set.call(receiver,value)])try{call();return false}catch(e){if(!(e instanceof TypeError)||e.message!=="Not an object of type HTMLTrackElement")throw e}
 }return traps===0;
})()')! == 'true'
	assert probe.replays == 0
	assert runtime.evaluate_host('nhtDirect.onload===null&&nhtDirect.onerror===null&&nhtOther.onload===null&&nhtOther.onerror===null')! == 'true'
	assert probe.replays == 4
	assert runtime.evaluate_host(r'globalThis.nhtReplayReason={};globalThis.nhtThrowReplay=true;(()=>{for(const name of ["onload","onerror"]){const d=Object.getOwnPropertyDescriptor(HTMLTrackElement.prototype,name);for(const call of [()=>d.get.call(nhtDirect),()=>d.set.call(nhtDirect,function(){})])try{call();return false}catch(e){if(e!==nhtReplayReason)throw e}}return true})()')! == 'true'
	assert probe.replays == 8 && unsafe { &dom.EventTarget(element) }.event_listener_list().len == 0
}

fn test_native_track_handler_legacy_values_replacement_order_and_exact_false_cancellation() {
	$if !darwin { return }
	mut runtime, mut document, element := native_track_handler_host(none)!
	defer { runtime.close();document.finalize() }
	assert runtime.evaluate_host(r'(()=>{
 const t=nhtDirect;let reads=0;
 for(const type of ["load","error"]){const name="on"+type,order=[],before=()=>order.push("before"),after=()=>order.push("after");
  t.addEventListener(type,before);t[name]=()=>order.push("old");t.addEventListener(type,after);
  const replacement=function(e){if(this!==t||arguments.length!==1||e.target!==t||e.currentTarget!==t||!(e instanceof Event))throw "handler receiver";order.push("replacement");return false};
  t[name]=replacement;const event=new Event(type,{cancelable:true});if(t[name]!==replacement||t.dispatchEvent(event)||!event.defaultPrevented)throw "handler replacement";
  t[name]=null;t.dispatchEvent(new Event(type));const reactivated=()=>order.push("reactivated");t[name]=reactivated;t[name]=reactivated;t.dispatchEvent(new Event(type));
  if(order.join(",")!=="before,replacement,after,before,after,before,after,reactivated")throw "handler slot order";
  t.removeEventListener(type,before);t.removeEventListener(type,after);
  for(const value of [null,undefined,false,0,"return false",Symbol(),1n]){t[name]=value;if(t[name]!==null)throw "primitive handler";}
  const object={get handleEvent(){reads++;throw "handleEvent"},[Symbol.toPrimitive](){reads++;throw "conversion"}},proxy=new Proxy({},{get(){reads++;throw "proxy get"},getPrototypeOf(){reads++;throw "proxy prototype"}});
  for(const value of [object,proxy]){t[name]=value;if(t[name]!==value||!t.dispatchEvent(new Event(type,{cancelable:true})))throw "legacy handler object";}
  const callable=new Proxy(function(e){if(this!==t||e.target!==t)throw "callable owner";return false},{get(){reads++;throw "callable get"}});t[name]=callable;
  if(t[name]!==callable||t.dispatchEvent(new Event(type,{cancelable:true})))throw "callable proxy";
  for(const value of [0,"",null,new Boolean(false)]){t[name]=()=>value;if(!t.dispatchEvent(new Event(type,{cancelable:true})))throw "nonboolean cancellation";}
  Object.getOwnPropertyDescriptor(HTMLTrackElement.prototype,name).set.call(t);if(t[name]!==null)throw "omitted setter";
 }return reads===0;
})()')! == 'true'
	assert unsafe { &dom.EventTarget(element) }.event_listener_list().len == 0
	native_track_handler_balanced(document, runtime, 0)
}

fn test_native_track_error_handler_receives_one_event_and_reports_original_exception() {
	$if !darwin { return }
	mut runtime, mut document, element := native_track_handler_host(none)!
	defer { runtime.close();document.finalize() }
	runtime.evaluate_host(r'globalThis.nhtErrorReason={};globalThis.nhtErrorOrder=[];globalThis.nhtErrorChecks=[];nhtDirect.onerror=function(e){nhtErrorOrder.push("handler");nhtErrorChecks.push(arguments.length===1&&this===nhtDirect&&e===__nhtErrorEvent()&&e.target===nhtDirect&&e.currentTarget===nhtDirect&&e instanceof Event&&e.isTrusted);throw nhtErrorReason};nhtDirect.addEventListener("error",e=>{nhtErrorOrder.push("later");nhtErrorChecks.push(e===__nhtErrorEvent())});0')!
	error_event := dom.ErrorEvent.create('error', dom.ErrorEventInit{EventInit: dom.EventInit{cancelable: true}, message: 'track error', filename: 'track.js', lineno: 3, colno: 8})
	wrapped := runtime.javascript_event(unsafe { &dom.Event(error_event) })!
	runtime.define_value_host_function('__nhtErrorEvent', fn [wrapped] (_ voidptr, _ []voidptr) !voidptr { return wrapped })!
	target := unsafe { &dom.EventTarget(element) }
	assert target.dispatch_event(unsafe { &dom.Event(error_event) })
	assert runtime.evaluate_host('nhtErrorOrder.join(",")==="handler,later"&&nhtErrorChecks.length===2&&nhtErrorChecks.every(Boolean)&&__nhtErrorEvent().currentTarget===null')! == 'true'
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == 1
	assert runtime.actual_webidl_value(settings.realm().reported_exceptions[0].value.as_webidl_value()!)! == runtime.evaluate_host_value('nhtErrorReason')!
	assert runtime.evaluate_host(r'nhtDirect.onerror=function(e){if(arguments.length!==1||e!==__nhtErrorEvent()||this!==nhtDirect)throw "ErrorEvent signature";return false};nhtDirect.dispatchEvent(__nhtErrorEvent())===false&&__nhtErrorEvent().defaultPrevented&&!__nhtErrorEvent().isTrusted')! == 'true'
	native_track_handler_balanced(document, runtime, 1)
}

fn test_compact_track_handlers_reach_actual_parsed_created_and_qualified_loader_owners() {
	$if !darwin { return }
	mut document := native_track_handler_document('<!doctype html><audio id="nht-parent" preload="none"><track id="nht-parsed" src="seed.vtt" onload="globalThis.nhtRawCalls++"></audio>', 'https://track-handlers.example/base/')!
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close();document.finalize() }
	native_track_handler_run(document, runtime, r'
globalThis.nhtTracks=[document.getElementById("nht-parsed")];globalThis.nhtRawCalls=0;globalThis.nhtLoaderOrder=[];globalThis.nhtLoaderChecks=[];globalThis.nhtSavedHandlers=[];
for(const [i,t] of [document.createElement("track"),document.createElementNS("http://www.w3.org/1999/xhtml","q:track")].entries()){t.id="nht-created-"+i;t.src="seed-created.vtt";document.getElementById("nht-parent").appendChild(t);nhtTracks.push(t);}
for(const t of nhtTracks){const saved={};nhtSavedHandlers.push(saved);if((t.hasAttribute("onload")?typeof t.onload!=="function":t.onload!==null)||t.onerror!==null||Object.hasOwn(t,"onload")||Object.hasOwn(t,"onerror"))throw "initial native handlers";
 t.onload=null;t.onerror=null;
 for(const type of ["load","error"]){t.addEventListener(type,()=>nhtLoaderOrder.push(t.id+":"+type+":before"));t["on"+type]=()=>{throw "old handler"};t.addEventListener(type,()=>nhtLoaderOrder.push(t.id+":"+type+":after"));
  saved[type]=function(e){nhtLoaderOrder.push(t.id+":"+type+":handler");nhtLoaderChecks.push(arguments.length===1&&this===t&&e.target===t&&e.currentTarget===t&&e.isTrusted&&!e.bubbles&&!e.cancelable&&t.readyState===(type==="load"?HTMLTrackElement.LOADED:HTMLTrackElement.ERROR));};t["on"+type]=saved[type];
 }
}if(nhtLoaderOrder.length||nhtRawCalls)throw "fabricated handler invocation";
')
	probe := &NativeTrackHandlerProbe{}
	for id in ['nht-parsed', 'nht-created-0', 'nht-created-1'] {
		element := document.get_element_by_id(id)?
		model := native_track_handler_model(element, probe)
		html.html_track_element_inserted(unsafe { &dom.HTMLTrackElement(element) })
		assert model.ready_state() == .loaded
		assert runtime.evaluate_host('document.getElementById("${id}").src="broken.vtt";document.getElementById("${id}").src="recovered.vtt";nhtLoaderChecks.every(Boolean)')! == 'true'
		assert model.event_count('load') == 2 && model.event_count('error') == 1
	}
	assert runtime.evaluate_host('nhtRawCalls===0&&nhtLoaderChecks.length===9&&nhtLoaderChecks.every(Boolean)&&nhtLoaderOrder.length===27')! == 'true'
	assert runtime.evaluate_host(r'(()=>{for(let i=0;i<27;i+=3){const prefix=nhtLoaderOrder[i].slice(0,-6);if(nhtLoaderOrder[i+1]!==prefix+"handler"||nhtLoaderOrder[i+2]!==prefix+"after")return false}return true})()')! == 'true'
	assert runtime.evaluate_host(r'(()=>{const t=nhtTracks[0],raw=t.getAttribute("onload");t.setAttribute("onload",raw);if(typeof t.onload!=="function"||t.onload===nhtSavedHandlers[0].load||t.getAttribute("onload")!==raw)return false;t.onload=nhtSavedHandlers[0].load;return t.onload===nhtSavedHandlers[0].load})()')! == 'true'
	assert probe.urls.len == 9
	native_track_handler_flush(document, runtime)!
	native_track_handler_balanced(document, runtime, 0)
}

fn test_compact_track_handler_content_writes_replace_idl_slots_in_operation_order() {
	$if !darwin { return }
	mut document := native_track_handler_document('<!doctype html><track id="nht-raw" onload="globalThis.nhtRawRuns++" onerror="globalThis.nhtRawRuns++"><track id="nht-ns">', 'https://track-handlers.example/raw/')!
	mut namespaced := document.get_element_by_id('nht-ns')?
	namespaced.set_attribute_ns_for_bindings('urn:track-handler', 'onload', 'globalThis.nhtRawRuns++')!
	attribute := namespaced.get_attribute_node_ns('urn:track-handler', 'onload')?
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close();document.finalize() }
	native_track_handler_run(document, runtime, r'
globalThis.nhtRawRuns=0;globalThis.nhtAssignedRuns=0;globalThis.nhtRawTrack=document.getElementById("nht-raw");
for(const type of ["load","error"]){const t=nhtRawTrack,name="on"+type,raw=t.getAttribute(name),handler=function(e){if(this!==t||arguments.length!==1||e.target!==t||e.currentTarget!==t)throw "raw replacement owner";nhtAssignedRuns++};
 if(typeof t[name]!=="function")throw "raw compiler unavailable";
 t[name]=handler;t.setAttribute("data-dirty",type);if(t[name]!==handler||t.getAttribute(name)!==raw)throw "unchanged snapshot replaced IDL";
 t.dispatchEvent(new Event(type));const before=nhtAssignedRuns;
 t.setAttribute(name,raw);if(typeof t[name]!=="function"||t[name]===handler||t.getAttribute(name)!==raw)throw "equal raw write retained IDL";
 t.dispatchEvent(new Event(type));if(nhtAssignedRuns!==before||nhtRawRuns!==(type==="load"?1:2))throw "raw invocation count";
 t.setAttribute(name,raw+";");t[name]=handler;if(t[name]!==handler||t.getAttribute(name)!==raw+";")throw "pending raw replay replaced new IDL";
 t.removeAttribute(name);if(t[name]!==null||t.hasAttribute(name))throw "raw removal retained IDL";
 t[name]=handler;t.removeAttribute(name);if(t[name]!==handler)throw "absent raw removal cleared IDL";
 t.setAttribute(name,raw);t[name]=handler;t.dispatchEvent(new Event(type));
}if(nhtAssignedRuns!==4||nhtRawRuns!==2)throw "raw and IDL dispatch count";
const ns=document.getElementById("nht-ns"),nsRaw=ns.getAttribute("onload"),nsHandler=()=>{};
ns.onload=nsHandler;ns.setAttribute("onload",nsRaw);if(typeof ns.onload!=="function"||ns.onload===nsHandler||ns.getAttribute("onload")!==nsRaw)throw "qualified Attr hook";ns.onload=nsHandler;
')
	native_track_handler_flush(document, runtime)!
	element := document.get_element_by_id('nht-raw')?
	target := unsafe { &dom.EventTarget(element) }
	for name in ['load', 'error'] {
		assert element.get_attribute('on' + name)? == 'globalThis.nhtRawRuns++'
		handler := target.data.event_handler(name)?
		assert handler.value.kind == .object
	}
	assert runtime.evaluate_host('nhtRawTrack.onload!==null&&nhtRawTrack.onerror!==null&&nhtAssignedRuns===4&&nhtRawRuns===2')! == 'true'
	assert namespaced.get_attribute_node_ns('urn:track-handler', 'onload')? == attribute
	assert namespaced.get_attribute_ns(none, 'onload') == none
	native_track_handler_balanced(document, runtime, 0)
}

fn test_compact_track_handlers_reenter_source_completion_and_preserve_loaded_cues_and_dom_writes() {
	$if !darwin { return }
	mut document := native_track_handler_document('<!doctype html><audio preload="none"><track id="nht-reentrant"></audio><p id="nht-result">before</p>', 'https://track-handlers.example/base/')!
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close();document.finalize() }
	native_track_handler_run(document, runtime, r'globalThis.nhtReentrant=document.getElementById("nht-reentrant");globalThis.nhtStableTrack=nhtReentrant.track;globalThis.nhtReentryOrder=[];globalThis.nhtReentryEvents=[];0')
	probe := &NativeTrackHandlerProbe{}
	element := document.get_element_by_id('nht-reentrant')?
	mut model := native_track_handler_model(element, probe)
	model.set_mode(.hidden);model.start_the_track_processing_model()
	assert runtime.evaluate_host(r'
nhtReentrant.onload=function(e){if(this!==nhtReentrant||e.target!==this||e.currentTarget!==this||!e.isTrusted||this.track!==nhtStableTrack)throw "load identity";nhtReentryOrder.push("load:"+this.getAttribute("src"));nhtReentryEvents.push(e);if(this.getAttribute("src")==="outer.vtt"){this.src="";document.getElementById("nht-result").textContent="recovered track";}};
nhtReentrant.onerror=function(e){if(arguments.length!==1||this!==nhtReentrant||e.target!==this||!e.isTrusted)throw "error identity";nhtReentryOrder.push("error:"+this.getAttribute("src"));nhtReentryEvents.push(e);this.src="recovered.vtt";};
nhtReentrant.src="outer.vtt";nhtReentryOrder.join(",")==="load:outer.vtt,error:,load:recovered.vtt"&&new Set(nhtReentryEvents).size===3&&nhtReentryEvents.every(e=>e.target===nhtReentrant&&e.currentTarget===null)')! == 'true'
	native_track_handler_flush(document, runtime)!
	assert element.get_attribute('src')? == 'recovered.vtt' && probe.urls.len == 2
	assert model.ready_state() == .loaded && model.track.cues().length() == 1
	assert model.track.cues().get_cue_by_id('https://track-handlers.example/base/recovered.vtt')?.text() == 'handler cue'
	assert document.get_element_by_id('nht-result')?.as_node().text_content()? == 'recovered track'
	native_track_handler_balanced(document, runtime, 0)
}

fn test_compact_track_handlers_keep_adopted_owner_page_gate_and_independent_runtime() {
	$if !darwin { return }
	mut document := native_track_handler_document('<!doctype html><audio preload="none"><track id="nht-adopt" src="seed.vtt"></audio>', 'https://old-track-handler.example/base/')!
	mut adopted := native_track_handler_document('<!doctype html><audio id="nht-destination" preload="none"></audio>', 'https://new-track-handler.example/other/')!
	mut runtime := browserjs.Runtime.create();mut independent := browserjs.Runtime.create()
	defer { runtime.close();independent.close();document.finalize();adopted.finalize() }
	native_track_handler_run(document, runtime, r'globalThis.nhtAdopt=document.getElementById("nht-adopt");globalThis.nhtAdoptCount=0;globalThis.nhtAdoptHandler=function(e){if(this!==nhtAdopt||e.target!==this||e.currentTarget!==this||!e.isTrusted)throw "adopted handler";nhtAdoptCount++;return false};nhtAdopt.onload=nhtAdoptHandler;0')
	native_track_handler_run(adopted, independent, r'globalThis.nhtIndependent=document.createElement("track");globalThis.nhtIndependentCount=0;globalThis.nhtIndependentHandler=function(){nhtIndependentCount++};nhtIndependent.onload=nhtIndependentHandler;0')
	probe := &NativeTrackHandlerProbe{}
	element := document.get_element_by_id('nht-adopt')?
	model := native_track_handler_model(element, probe)
	html.html_track_element_inserted(unsafe { &dom.HTMLTrackElement(element) })
	assert runtime.evaluate_host('nhtAdoptCount===1')! == 'true'
	adopted.adopt_node(element.as_node())
	mut parent := unsafe { &dom.Node(adopted.get_element_by_id('nht-destination')?) };parent.append_child(element.as_node())!
	assert runtime.evaluate_host('nhtAdopt.src="after.vtt";nhtAdoptCount===2&&nhtAdopt.onload===nhtAdoptHandler')! == 'true'
	assert probe.urls.last() == 'https://new-track-handler.example/other/after.vtt'
	assert html.html_track_element_model_for_dom_element(unsafe { &dom.HTMLTrackElement(element) }) == model
	mut owner := unsafe { &page.Page(document.page()) }
	target := unsafe { &dom.EventTarget(element) }
	owner.set_is_scripting_enabled(false)
	assert target.dispatch_event(dom.Event.create('load', dom.EventInit{cancelable: true}))
	owner.set_is_scripting_enabled(true)
	assert runtime.evaluate_host('nhtAdoptCount===2')! == 'true'
	assert !target.dispatch_event(dom.Event.create('load', dom.EventInit{cancelable: true}))
	assert runtime.evaluate_host('nhtAdoptCount===3')! == 'true'
	native_track_handler_balanced(document, runtime, 0)
	runtime.close()
	assert target.dispatch_event(dom.Event.create('load', dom.EventInit{cancelable: true}))
	assert independent.evaluate_host('nhtIndependent.onload===nhtIndependentHandler&&nhtIndependent.dispatchEvent(new Event("load"))&&nhtIndependentCount===1')! == 'true'
	native_track_handler_balanced(adopted, independent, 0)
}
