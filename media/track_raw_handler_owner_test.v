module main

import browserjs
import dom
import html
import page
import time

@[heap]
struct TrackRawOwnerProbe {
mut:
	urls []string
}

fn track_raw_owner_document(markup string) !&dom.Document {
	owner := page.Page.create(1)!
	return parse_browser_navigation_document_for_page_with_response_time(markup,dom.URL{value:'https://track-raw-owner.example/base/'},none,none,unsafe { &dom.Page(owner) },time.sys_mono_now())
}

fn track_raw_owner_run(document &dom.Document,runtime &browserjs.Runtime,script string) {
	mut messages := []string{}
	run_document_javascript(document,document.url.serialize(),[script],runtime,mut messages)
	assert messages == []
}

fn track_raw_owner_flush(document &dom.Document,runtime &browserjs.Runtime) ! {
	snapshot := runtime.evaluate_host('__ladybirdFinalize()')!
	mut messages := []string{}
	apply_javascript_runtime_state(document,snapshot,runtime,mut messages)
	assert messages == []
	runtime.evaluate_host('__ladybirdClearLogs();0')!
}

fn track_raw_owner_model(element &dom.Element,probe &TrackRawOwnerProbe) &html.HTMLTrackElementModel {
	mut model := html.html_track_element_model_for_dom_element(unsafe { &dom.HTMLTrackElement(element) })
	model.set_fetch_hook(fn [probe] (url dom.URL,_ html.CORSSettingAttribute) !html.TextTrackResourceResponse {
		mut observed := unsafe { &TrackRawOwnerProbe(probe) };observed.urls << url.serialize()
		if url.serialize().contains('broken') { return error('Controlled track fetch failure') }
		return html.TextTrackResourceResponse{body:'WEBVTT\n\n${url.serialize()}\n00:00.000 --> 00:01.000\nraw handler cue\n'}
	})
	return model
}

fn track_raw_owner_balanced(document &dom.Document,runtime &browserjs.Runtime,exceptions int) {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == exceptions
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
	assert runtime.libjs_vm().execution_context_stack().len == 0 && runtime.libjs_vm().interpreter_stack().depth() == 0
}

fn test_track_raw_actual_loader_parsed_created_and_qualified_scopes_readiness_and_dom_replay() {
	$if !darwin { return }
	body := r'troRuns++;troOrder.push(this.id+":"+event.type);troEvents.push(event);troChecks.push(arguments.length===1&&event===arguments[0]&&event.target===this&&event.currentTarget===this&&event.isTrusted&&!event.bubbles&&!event.cancelable&&window.event===event&&readyState===(event.type==="load"?HTMLTrackElement.LOADED:HTMLTrackElement.ERROR));troScopes.push(scopeKey);delete this.scopeKey;troScopes.push(scopeKey);delete document.scopeKey;troScopes.push(scopeKey);document.scopeKey="document";this.scopeKey=this.id;document.getElementById("tro-result").textContent=this.id+":"+event.type;'
	attribute_body := body.replace('"','&quot;')
	mut document := track_raw_owner_document('<!doctype html><form id="tro-form"><audio id="tro-parent" preload="none"><track id="tro-parsed" src="seed.vtt" onload="${attribute_body}" onerror="${attribute_body}"></audio></form><p id="tro-result">waiting</p>')!
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close();document.finalize() }
	track_raw_owner_run(document,runtime,r'
globalThis.troRuns=0;globalThis.troOrder=[];globalThis.troEvents=[];globalThis.troChecks=[];globalThis.troScopes=[];globalThis.scopeKey="global";document.scopeKey="document";
globalThis.troTracks=[document.getElementById("tro-parsed")];const body=troTracks[0].getAttribute("onload");
for(const [i,t] of [document.createElement("track"),document.createElementNS("http://www.w3.org/1999/xhtml","q:track")].entries()){t.id="tro-created-"+i;t.src="seed.vtt";t.setAttribute("onload",body);t.setAttribute("onerror",body);document.getElementById("tro-parent").appendChild(t);troTracks.push(t);}
Object.defineProperty(document.getElementById("tro-form"),"scopeKey",{get(){throw "ancestor form scope"}});
for(const t of troTracks){t.scopeKey=t.id;t.event={sentinel:true};if(typeof t.onload!=="function"||typeof t.onerror!=="function"||t.onload===t.onerror||t.onload.name!=="onload"||t.onerror.length!==1||Object.hasOwn(t,"onload"))throw "raw track metadata";}
if(troRuns!==0)throw "eager raw track invocation";
')
	probe := &TrackRawOwnerProbe{}
	for id in ['tro-parsed','tro-created-0','tro-created-1'] {
		element := document.get_element_by_id(id)?
		model := track_raw_owner_model(element,probe)
		html.html_track_element_inserted(unsafe { &dom.HTMLTrackElement(element) })
		assert model.ready_state() == .loaded
		assert runtime.evaluate_host('document.getElementById("${id}").src="broken.vtt";document.getElementById("${id}").src="recovered.vtt";troChecks.every(Boolean)')! == 'true'
		assert model.event_count('load') == 2 && model.event_count('error') == 1
	}
	assert runtime.evaluate_host('troRuns===9&&troChecks.length===9&&troChecks.every(Boolean)&&new Set(troEvents).size===9&&troEvents.every(e=>e.currentTarget===null&&e.eventPhase===Event.NONE)&&troScopes.length===27&&troScopes.every((s,i)=>s===(i%3===0?troOrder[Math.floor(i/3)].split(":")[0]:i%3===1?"document":"global"))&&window.event===undefined')! == 'true'
	assert probe.urls.len == 9
	track_raw_owner_flush(document,runtime)!
	assert document.get_element_by_id('tro-result')?.as_node().text_content()? == 'tro-created-1:load'
	track_raw_owner_balanced(document,runtime,0)
}

fn test_track_raw_loader_reentry_preserves_final_source_cues_native_events_and_dom_writes() {
	$if !darwin { return }
	mut document := track_raw_owner_document('<!doctype html><audio preload="none"><track id="tro-reentrant"></audio><p id="tro-result">waiting</p>')!
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close();document.finalize() }
	track_raw_owner_run(document,runtime,r'globalThis.troReentrant=document.getElementById("tro-reentrant");globalThis.troStable=troReentrant.track;globalThis.troOrder=[];globalThis.troChecks=[];globalThis.troEvents=[];0')
	probe := &TrackRawOwnerProbe{}
	element := document.get_element_by_id('tro-reentrant')?
	mut model := track_raw_owner_model(element,probe)
	model.set_mode(.hidden);model.start_the_track_processing_model()
	assert runtime.evaluate_host(r'
troReentrant.setAttribute("onload",`troOrder.push("load:"+this.getAttribute("src"));troEvents.push(event);troChecks.push(this===troReentrant&&event.target===this&&event.currentTarget===this&&event.isTrusted&&this.track===troStable);if(this.getAttribute("src")==="outer.vtt"){this.src="";document.getElementById("tro-result").textContent="raw recovered cue";}`);
troReentrant.setAttribute("onerror",`troOrder.push("error:"+this.getAttribute("src"));troEvents.push(event);troChecks.push(this===troReentrant&&event.target===this&&arguments.length===1&&event.isTrusted);this.src="recovered.vtt";`);
globalThis.troSavedLoad=troReentrant.onload;globalThis.troSavedError=troReentrant.onerror;
troReentrant.src="outer.vtt";troOrder.join(",")==="load:outer.vtt,error:,load:recovered.vtt"&&troChecks.every(Boolean)&&new Set(troEvents).size===3&&troEvents.every(e=>e.currentTarget===null)&&troReentrant.onload===troSavedLoad&&troReentrant.onerror===troSavedError')! == 'true'
	track_raw_owner_flush(document,runtime)!
	assert element.get_attribute('src')? == 'recovered.vtt' && probe.urls.len == 2
	assert model.ready_state() == .loaded && model.track.cues().length() == 1
	assert model.track.cues().get_cue_by_id('https://track-raw-owner.example/base/recovered.vtt')?.text() == 'raw handler cue'
	assert document.get_element_by_id('tro-result')?.as_node().text_content()? == 'raw recovered cue'
	track_raw_owner_balanced(document,runtime,0)
}

fn test_track_raw_loader_gates_strict_original_exception_and_later_listener_continuation() {
	$if !darwin { return }
	mut document := track_raw_owner_document('<!doctype html><audio preload="none"><track id="tro-gated" src="seed.vtt"></audio>')!
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close();document.finalize() }
	track_raw_owner_run(document,runtime,r'globalThis.troGated=document.getElementById("tro-gated");globalThis.troThrown={};globalThis.troRuns=0;globalThis.troLater=0;globalThis.troStrict=false;0')
	probe := &TrackRawOwnerProbe{}
	element := document.get_element_by_id('tro-gated')?
	model := track_raw_owner_model(element,probe)
	assert runtime.evaluate_host(r'troGated.setAttribute("onload",`"use strict";troRuns++;troStrict=this===troGated&&arguments.length===1&&event===arguments[0]&&event.isTrusted&&this.readyState===HTMLTrackElement.LOADED;throw troThrown;`);typeof troGated.onload==="function"')! == 'true'
	assert runtime.evaluate_host('troGated.addEventListener("load",function(e){if(this!==troGated||e.currentTarget!==this||!e.isTrusted)throw "later owner";troLater++});0')! == '0'
	mut owner := unsafe { &page.Page(document.page()) }
	owner.set_is_scripting_enabled(false)
	html.html_track_element_inserted(unsafe { &dom.HTMLTrackElement(element) })
	assert model.ready_state() == .loaded && probe.urls.len == 1
	owner.set_is_scripting_enabled(true)
	assert runtime.evaluate_host('troRuns===0&&troLater===0')! == 'true'
	assert runtime.evaluate_host('troGated.src="second.vtt";troRuns===1&&troLater===1&&troStrict&&window.event===undefined')! == 'true'
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == 1
	assert runtime.actual_webidl_value(settings.realm().reported_exceptions[0].value.as_webidl_value()!)! == runtime.evaluate_host_value('troThrown')!
	assert runtime.evaluate_host('troGated.removeAttribute("onload");troGated.src="third.vtt";troRuns===1&&troLater===2&&troGated.onload===null')! == 'true'
	track_raw_owner_balanced(document,runtime,1)
}
