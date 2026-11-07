module main

import browserjs
import dom
import html
import page
import time

@[heap]
struct TextModeOwnerProbe {
mut:
	fetches int
}

fn text_mode_owner_document(markup string) !&dom.Document {
	owner := page.Page.create(1)!
	return parse_browser_navigation_document_for_page_with_response_time(markup,dom.URL{value:'https://text-mode-owner.example/'},none,none,unsafe { &dom.Page(owner) },time.sys_mono_now())
}

fn text_mode_owner_run(document &dom.Document,runtime &browserjs.Runtime,script string) {
	mut messages := []string{}
	run_document_javascript(document,document.url.serialize(),[script],runtime,mut messages)
	assert messages == []
}

fn text_mode_owner_flush(document &dom.Document,runtime &browserjs.Runtime) ! {
	snapshot := runtime.evaluate_host('__ladybirdFinalize()')!
	mut messages := []string{}
	apply_javascript_runtime_state(document,snapshot,runtime,mut messages)
	assert messages == []
	runtime.evaluate_host('__ladybirdClearLogs();0')!
}

fn text_mode_owner_drain(document &dom.Document) int {
	mut queue := html.main_thread_event_loop().task_queue()
	mut count := 0
	for {
		task := queue.take_first_runnable_matching(fn [document] (task &html.Task) bool {
			owner := task.document() or { return false }
			return task.source() == .media_element && voidptr(owner) == voidptr(document)
		}) or { break }
		count++;assert count < 100;task.execute()
	}
	return count
}

fn text_mode_owner_balanced(document &dom.Document,runtime &browserjs.Runtime) {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
	assert runtime.libjs_vm().execution_context_stack().len == 0 && runtime.libjs_vm().interpreter_stack().depth() == 0
}

fn test_text_mode_enum_setter_uses_parsed_created_and_qualified_track_owners_without_processing_side_effects() {
	$if !darwin { return }
	mut document := text_mode_owner_document('<!doctype html><audio id="tmo-parent" preload="none"><track id="tmo-parsed" kind="captions" label="Parsed" src="seed.vtt"></audio><p id="tmo-result">waiting</p>')!
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close();document.finalize() }
	text_mode_owner_run(document,runtime,r'
globalThis.tmoTracks=[document.getElementById("tmo-parsed").track];globalThis.tmoCueEvents=0;
for(const [i,e] of [document.createElement("track"),document.createElementNS("http://www.w3.org/1999/xhtml","q:track")].entries()){e.id="tmo-created-"+i;document.getElementById("tmo-parent").appendChild(e);tmoTracks.push(e.track);}
for(const t of tmoTracks)t.oncuechange=()=>tmoCueEvents++;0
')
	probe := &TextModeOwnerProbe{}
	mut models := []&html.HTMLTrackElementModel{}
	mut readiness := []html.TextTrackReadinessState{}
	mut cue_counts := []int{}
	for id in ['tmo-parsed','tmo-created-0','tmo-created-1'] {
		mut model := html.html_track_element_model_for_dom_element(unsafe { &dom.HTMLTrackElement(document.get_element_by_id(id)?) })
		model.set_fetch_hook(fn [probe] (_ dom.URL,_ html.CORSSettingAttribute) !html.TextTrackResourceResponse {
			mut observed := unsafe { &TextModeOwnerProbe(probe) };observed.fetches++
			return html.TextTrackResourceResponse{body:'WEBVTT\n\n'}
		})
		models << model;readiness << model.track.readiness_state();cue_counts << model.track.cues().length()
	}
	assert runtime.evaluate_host(r'(()=>{
 const set=Object.getOwnPropertyDescriptor(TextTrack.prototype,"mode").set,reason={};
 for(const [i,t] of tmoTracks.entries()){
  t.mode="showing";for(const value of [null,undefined,"SHOWING",Symbol(),{toString(){throw reason}}])if(set.call(t,value)!==undefined||t.mode!=="showing")return false;
  t.mode={toString(){t.mode="disabled";document.getElementById("tmo-result").textContent="ignored mode conversion preserved DOM";throw reason}};
  if(t.mode!=="disabled")return false;t.mode="hidden";
  const element=document.getElementById(i===0?"tmo-parsed":"tmo-created-"+(i-1));if(element.track!==t)return false;
 }return tmoCueEvents===0;
})()')! == 'true'
	text_mode_owner_flush(document,runtime)!
	for index,model in models {
		assert model.track.mode() == .hidden && model.track.readiness_state() == readiness[index]
		assert model.track.cues().length() == cue_counts[index]
	}
	assert probe.fetches == 0 && document.get_element_by_id('tmo-parsed')?.get_attribute('src')? == 'seed.vtt'
	assert document.get_element_by_id('tmo-result')?.as_node().text_content()? == 'ignored mode conversion preserved DOM'
	text_mode_owner_balanced(document,runtime)
}

fn test_text_mode_enum_attribute_failure_is_ignored_inside_native_addtrack_delivery_but_argument_failures_throw() {
	$if !darwin { return }
	mut document := text_mode_owner_document('<!doctype html><audio id="tmo-audio" preload="none"></audio><p id="tmo-result">waiting</p>')!
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close();document.finalize() }
	text_mode_owner_run(document,runtime,r'
globalThis.tmoAudio=document.getElementById("tmo-audio");globalThis.tmoList=tmoAudio.textTracks;globalThis.tmoReason={};globalThis.tmoChecks=[];globalThis.tmoEvents=[];globalThis.tmoCues=0;
tmoList.onaddtrack=function(e){tmoEvents.push(e.type);tmoChecks.push(this===tmoList&&e.track===tmoAdded&&e.target===this&&e.currentTarget===this&&e.track.mode==="showing");const set=Object.getOwnPropertyDescriptor(TextTrack.prototype,"mode").set;if(set.call(e.track,{toString(){throw tmoReason}})!==undefined)throw "ignored setter return";tmoChecks.push(e.track.mode==="showing");e.track.mode="hidden";document.getElementById("tmo-result").textContent="native addtrack continued";};
globalThis.tmoAdded=tmoAudio.addTextTrack("captions","Mode callback","en");tmoAdded.oncuechange=()=>tmoCues++;tmoAdded.mode="showing";
const length=tmoList.length;for(const value of [null,undefined,"invalid",Symbol()]){try{tmoAudio.addTextTrack(value);throw "argument accepted"}catch(e){if(!(e instanceof TypeError)||tmoList.length!==length)throw e}}
try{tmoAudio.addTextTrack({toString(){throw tmoReason}});throw "argument exception swallowed"}catch(e){if(e!==tmoReason||tmoList.length!==length)throw e}
if(tmoEvents.length!==0||tmoCues!==0)throw "mode synthesized event";
')
	assert text_mode_owner_drain(document) >= 1
	assert runtime.evaluate_host('tmoEvents.join(",")==="addtrack"&&tmoChecks.length===2&&tmoChecks.every(Boolean)&&tmoAdded.mode==="hidden"&&tmoCues===0&&tmoAudio.textTracks===tmoList&&tmoList.length===1')! == 'true'
	text_mode_owner_flush(document,runtime)!
	assert text_mode_owner_drain(document) == 0
	assert document.get_element_by_id('tmo-result')?.as_node().text_content()? == 'native addtrack continued'
	text_mode_owner_balanced(document,runtime)
}
