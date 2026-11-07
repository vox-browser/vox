module main

import browserjs
import css
import dom
import html
import page
import time

const mct_owner_markup = '<!doctype html><style>html,body{margin:0}#mct-video{display:block;width:100px;height:40px}#mct-result{color:rgb(17,34,51)}#mct-video[controls]~#mct-result{color:rgb(71,72,73)}</style><video id="mct-video"></video><audio id="mct-audio" controls="parsed value"></audio><audio id="mct-bare-audio"></audio><div id="mct-ordinary"></div><svg width="0" height="0"><video id="mct-svg" controls="svg value"></video></svg><div id="mct-result">reflection waiting</div>'

@[heap]
struct MctOwnerProbe {
mut:
	fetches int
}

fn mct_owner_fixture() !(&BrowserApp, &dom.Document, &browserjs.Runtime) {
	mut owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time(mct_owner_markup, dom.URL{
		value: 'https://media-controls-owner.example.test/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	runtime := browserjs.Runtime.create()
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'
globalThis.mctVideo=document.getElementById("mct-video");globalThis.mctAudio=document.getElementById("mct-audio");globalThis.mctBareAudio=document.getElementById("mct-bare-audio");globalThis.mctSVG=document.getElementById("mct-svg");globalThis.mctOrdinary=document.getElementById("mct-ordinary");globalThis.mctResult=document.getElementById("mct-result");
globalThis.mctCreatedAudio=document.createElement("audio");mctCreatedAudio.id="mct-created-audio";mctCreatedAudio.setAttribute("controls","created value");document.body.appendChild(mctCreatedAudio);void mctCreatedAudio.paused;
globalThis.mctCreatedVideo=document.createElement("video");mctCreatedVideo.id="mct-created-video";document.body.appendChild(mctCreatedVideo);void mctCreatedVideo.paused;globalThis.mctReflection=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"controls");0
'], runtime, mut messages)
	assert messages == []
	mut app := &BrowserApp{
		page_model: owner
		document: document
		js_runtime: runtime
		viewport_width: 320
		viewport_height: 240
	}
	app.relayout(320, 240 + app.chrome_height())
	assert document.layout_is_up_to_date() && document.paintable_box() != none
	return app, document, runtime
}

fn mct_owner_element(document &dom.Document, id string) !&dom.Element {
	return document.get_element_by_id(id) or { return error('missing controls owner element ${id}') }
}

fn mct_owner_take_task(document &dom.Document) ?&html.Task {
	mut queue := html.main_thread_event_loop().task_queue()
	return queue.take_first_runnable_matching(fn [document] (task &html.Task) bool {
		owner := task.document() or { return false }
		return task.source() == .media_element && voidptr(owner) == voidptr(document)
	})
}

fn mct_owner_balance(runtime &browserjs.Runtime, document &dom.Document) {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
	assert runtime.libjs_vm().execution_context_stack().len == 0
	assert runtime.libjs_vm().interpreter_stack().depth() == 0
}

fn test_native_controls_owner_reflects_parsed_created_attributes_and_captured_sync_into_retained_paint() {
	$if !darwin { return }
	mut app, mut document, mut runtime := mct_owner_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	video_element := mct_owner_element(document, 'mct-video')!
	audio_element := mct_owner_element(document, 'mct-audio')!
	created_audio := mct_owner_element(document, 'mct-created-audio')!
	created_video := mct_owner_element(document, 'mct-created-video')!
	assert runtime.evaluate_host(r'globalThis.controls="global fake";document.controls="document fake";!mctVideo.controls&&mctAudio.controls&&mctCreatedAudio.controls&&!mctCreatedVideo.controls&&[mctVideo,mctAudio,mctCreatedAudio,mctCreatedVideo].every(target=>!Object.hasOwn(target,"controls"))&&!("controls" in mctSVG)&&!("controls" in mctOrdinary)&&mctAudio.getAttribute("controls")==="parsed value"&&mctCreatedAudio.getAttribute("controls")==="created value"')! == 'true'
	assert !video_element.has_attribute('controls') && !created_video.has_attribute('controls')
	assert audio_element.get_attribute('controls') or { '' } == 'parsed value'
	assert created_audio.get_attribute('controls') or { '' } == 'created value'
	assert !mct_owner_element(document, 'mct-svg')!.is_html_element()
	assert runtime.evaluate_host('mctVideo.controls=true;mctVideo.setAttribute("data-stable","present");mctVideo.paused&&mctVideo.controls&&mctVideo.getAttribute("controls")===""')! == 'true'
	assert video_element.has_attribute('controls') && video_element.get_attribute('controls') or { 'missing' } == ''
	assert runtime.evaluate_host('mctVideo.controls=false;mctVideo.setAttribute("data-stable","absent");mctVideo.paused&&!mctVideo.controls&&!mctVideo.hasAttribute("controls")&&mctVideo.getAttribute("controls")===null')! == 'true'
	assert !video_element.has_attribute('controls') && video_element.get_attribute('data-stable') or { '' } == 'absent'
	assert runtime.evaluate_host('mctAudio.controls=true;mctAudio.getAttribute("controls")==="";mctAudio.setAttribute("controls","manual value");mctAudio.controls&&mctAudio.getAttribute("controls")==="manual value"')! == 'true'
	assert audio_element.get_attribute('controls') or { '' } == 'manual value'
	assert runtime.evaluate_host('mctAudio.removeAttribute("controls");!mctAudio.controls&&!mctAudio.hasAttribute("controls");mctCreatedVideo.controls=true;mctCreatedVideo.controls&&mctCreatedVideo.getAttribute("controls")===""')! == 'true'
	assert !audio_element.has_attribute('controls') && created_video.has_attribute('controls')
	assert runtime.evaluate_host(r'(()=>{
 globalThis.mctPoisonCalls=0;const define=Object.defineProperty;
 const saved={get:mctVideo.getAttribute,has:mctVideo.hasAttribute,set:mctVideo.setAttribute,remove:mctVideo.removeAttribute,define:define,apply:Reflect.apply,delete:Reflect.deleteProperty,weakGet:WeakMap.prototype.get,weakSet:WeakMap.prototype.set,boolean:Boolean,bind:globalThis.__ladybirdMediaElementBind,sync:globalThis.__ladybirdMediaElementSetAttributeSync};
 const poison=function(){mctPoisonCalls++;throw "author poison"};
 for(const name of ["getAttribute","hasAttribute","setAttribute","removeAttribute"])define(mctVideo,name,{get:poison,configurable:true});
 define(globalThis,"__ladybirdMediaElementBind",{value:poison,configurable:true});define(globalThis,"__ladybirdMediaElementSetAttributeSync",{value:poison,configurable:true});define(Object.prototype,"controls",{get:poison,set:poison,configurable:true});
 globalThis.Boolean=poison;WeakMap.prototype.get=poison;WeakMap.prototype.set=poison;Reflect.apply=poison;Reflect.deleteProperty=poison;Object.defineProperty=poison;
 try {
  if(mctReflection.set.call(mctVideo,{[Symbol.toPrimitive]:poison})!==undefined||mctReflection.get.call(mctVideo)!==true||saved.get.call(mctVideo,"controls")!=="")return false;
  saved.set.call(mctVideo,"data-stable","poisoned present");void mctVideo.paused;
  mctReflection.set.call(mctVideo,false);saved.set.call(mctVideo,"data-stable","poisoned absent");void mctVideo.paused;
  if(mctReflection.get.call(mctVideo)!==false||saved.has.call(mctVideo,"controls")||saved.get.call(mctVideo,"controls")!==null)return false;
  saved.delete(Object.prototype,"controls");saved.set.call(mctVideo,"controls","public write");if(mctReflection.get.call(mctVideo)!==true)return false;
  saved.remove.call(mctVideo,"controls");if(mctReflection.get.call(mctVideo)!==false)return false;
  mctReflection.set.call(mctVideo,true);return mctPoisonCalls===0&&saved.get.call(mctVideo,"controls")==="";
 } finally {
  saved.delete(Object.prototype,"controls");Object.defineProperty=saved.define;Reflect.apply=saved.apply;Reflect.deleteProperty=saved.delete;WeakMap.prototype.get=saved.weakGet;WeakMap.prototype.set=saved.weakSet;globalThis.Boolean=saved.boolean;
  saved.define(globalThis,"__ladybirdMediaElementBind",{value:saved.bind,configurable:true});saved.define(globalThis,"__ladybirdMediaElementSetAttributeSync",{value:saved.sync,configurable:true});
  for(const name of ["getAttribute","hasAttribute","setAttribute","removeAttribute"])saved.delete(mctVideo,name);
 }
})()')! == 'true'
	assert video_element.has_attribute('controls') && video_element.get_attribute('data-stable') or { '' } == 'poisoned absent'
	assert runtime.evaluate_host('mctResult.textContent="native controls reflection painted";mctVideo.controls')! == 'true'
	app.relayout(320, 240 + app.chrome_height())
	assert app.paint_commands.any(it.kind == 'draw_text' && it.text == 'native controls reflection painted' && it.color == 'rgb(71 72 73)')
	for element in [video_element, audio_element, created_audio, created_video] {
		media := html.html_media_element_for_dom_element(element) or { panic('controls media owner') }
		assert media.paused() && media.current_time() == 0 && !media.muted() && media.volume() == 1
		assert media.current_src() == '' && media.network_state() == .empty && media.ready_state() == .have_nothing
		assert media.error() == none
		for name in ['loadstart', 'play', 'pause', 'volumechange'] { assert media.event_count(name) == 0 }
	}
	assert mct_owner_take_task(document) == none && app.js_messages == []
	mct_owner_balance(runtime, document)
}

fn test_native_controls_owner_drives_the_controller_shadow_layout_without_replacing_media_state() {
	$if !darwin { return }
	mut app, mut document, mut runtime := mct_owner_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	video_element := mct_owner_element(document, 'mct-video')!
	audio_element := mct_owner_element(document, 'mct-bare-audio')!
	video := html.html_media_element_for_dom_element(video_element) or { panic('controls video owner') }
	audio := html.html_media_element_for_dom_element(audio_element) or { panic('controls audio owner') }
	assert video_element.shadow_root() == none && audio_element.shadow_root() == none
	probe := &MctOwnerProbe{}
	for item in [video, audio] {
		mut media := unsafe { &html.HTMLMediaElement(item) }
		media.set_fetch_hook(fn [probe] (_ dom.URL, _ u64) !html.MediaResourceResponse {
			mut observed := unsafe { &MctOwnerProbe(probe) }
			observed.fetches++
			return error('controls reflection must not fetch')
		})
		media.set_current_playback_position(7)
		media.set_official_playback_position(7)
		media.set_paused(false)
		assert !media.has_controls()
	}
	assert runtime.evaluate_host('mctVideo.controls=true;mctBareAudio.controls=true;mctVideo.controls&&mctBareAudio.controls&&mctVideo.currentTime===7&&mctBareAudio.currentTime===7&&!mctVideo.paused&&!mctBareAudio.paused')! == 'true'
	assert video_element.has_attribute('controls') && audio_element.has_attribute('controls')
	// Layout consumes the actual owner's controller, including its current timestamp.
	app.relayout(320, 240 + app.chrome_height())
	for index, element in [video_element, audio_element] {
		shadow := element.shadow_root() or { panic('native controls did not reach initial shadow layout') }
		assert shadow.is_user_agent_internal() && shadow.mode() == .closed
		selector := if index == 0 { '.container.video' } else { '.container.audio' }
		container := css.query_selector(shadow.as_node(), selector) or { panic('controls shadow container') }
		assert container.as_node().unsafe_layout_node() != none
		assert css.query_selector(shadow.as_node(), '.timeline-track') != none
		assert css.query_selector(shadow.as_node(), '.play-pause-button') != none
		retained := html.html_media_element_for_dom_element(element) or { panic('retained controls owner') }
		expected := if index == 0 { video } else { audio }
		assert voidptr(retained) == voidptr(expected)
		assert retained.current_time() == 7 && !retained.paused()
		assert retained.current_src() == '' && retained.network_state() == .empty && retained.ready_state() == .have_nothing
		assert retained.has_controls() && retained.error() == none
		for name in ['loadstart', 'play', 'pause', 'volumechange'] { assert retained.event_count(name) == 0 }
	}
	assert app.paint_commands.any(it.kind == 'draw_text' && it.text == '00:07 / 00:00')
	assert probe.fetches == 0 && mct_owner_take_task(document) == none && app.js_messages == []
	mct_owner_balance(runtime, document)
}
