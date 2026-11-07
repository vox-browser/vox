module main

import browserjs
import dom
import html
import page
import time

const media_default_muted_owner_markup = '<!doctype html><style>html,body{margin:0}#mdm-video{display:block;width:100px;height:40px}#mdm-result{color:rgb(17,34,51)}#mdm-video[muted]~#mdm-result{color:rgb(71,72,73)}</style><video id="mdm-video"></video><div id="mdm-ordinary"></div><svg width="0" height="0"><video id="mdm-svg" muted="svg value"></video></svg><div id="mdm-result">reflection waiting</div>'

@[heap]
struct MediaDefaultMutedOwnerProbe {
mut:
	fetches        int
	volume_updates []f64
}

fn media_default_muted_owner_fixture() !(&BrowserApp, &dom.Document, &browserjs.Runtime) {
	mut owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time(media_default_muted_owner_markup, dom.URL{
		value: 'https://media-default-muted-owner.example.test/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	runtime := browserjs.Runtime.create()
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'
globalThis.mdmVideo=document.getElementById("mdm-video");globalThis.mdmSVG=document.getElementById("mdm-svg");globalThis.mdmOrdinary=document.getElementById("mdm-ordinary");globalThis.mdmResult=document.getElementById("mdm-result");globalThis.mdmAudio=document.createElement("audio");mdmAudio.id="mdm-audio";mdmAudio.setAttribute("muted","created value");document.body.appendChild(mdmAudio);void mdmAudio.paused;globalThis.mdmReflection=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"defaultMuted");globalThis.mdmEvents=[];mdmVideo.addEventListener("volumechange",event=>mdmEvents.push(event.type));0
'], runtime, mut messages)
	assert messages == []
	mut app := &BrowserApp{
		page_model:      owner
		document:        document
		js_runtime:      runtime
		viewport_width:  320
		viewport_height: 240
	}
	app.relayout(320, 240 + app.chrome_height())
	assert document.layout_is_up_to_date() && document.paintable_box() != none
	return app, document, runtime
}

fn media_default_muted_owner_take_task(document &dom.Document) ?&html.Task {
	mut queue := html.main_thread_event_loop().task_queue()
	return queue.take_first_runnable_matching(fn [document] (task &html.Task) bool {
		owner := task.document() or { return false }
		return task.source() == .media_element && voidptr(owner) == voidptr(document)
	})
}

fn media_default_muted_owner_drain(document &dom.Document) {
	mut count := 0
	for {
		task := media_default_muted_owner_take_task(document) or { break }
		count++
		assert count < 100
		task.execute()
	}
}

fn media_default_muted_owner_balance(runtime &browserjs.Runtime, document &dom.Document) {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
	assert runtime.libjs_vm().execution_context_stack().len == 0
	assert runtime.libjs_vm().interpreter_stack().depth() == 0
}

fn test_native_default_muted_owner_reflects_parsed_created_attributes_and_survives_dirty_snapshots() {
	$if !darwin { return }
	mut app, mut document, mut runtime := media_default_muted_owner_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	video_element := document.get_element_by_id('mdm-video')?
	audio_element := document.get_element_by_id('mdm-audio')?
	video := html.html_media_element_for_dom_element(video_element)?
	audio := html.html_media_element_for_dom_element(audio_element)?
	assert !document.get_element_by_id('mdm-svg')?.is_html_element()
	assert runtime.evaluate_host(r'globalThis.defaultMuted="global fake";document.defaultMuted="document fake";mdmVideo.defaultMuted===false&&mdmAudio.defaultMuted===true&&!Object.hasOwn(mdmVideo,"defaultMuted")&&!Object.hasOwn(mdmAudio,"defaultMuted")&&!("defaultMuted" in mdmSVG)&&!("defaultMuted" in mdmOrdinary)&&mdmAudio.getAttribute("muted")==="created value"')! == 'true'
	assert !video_element.has_attribute('muted') && audio_element.get_attribute('muted')? == 'created value'
	assert runtime.evaluate_host('mdmVideo.defaultMuted=true;mdmVideo.defaultMuted===true&&mdmVideo.hasAttribute("muted")&&mdmVideo.getAttribute("muted")===""')! == 'true'
	assert video_element.get_attribute('muted')? == ''
	assert runtime.evaluate_host('mdmVideo.setAttribute("data-stable","first");mdmVideo.paused===true')! == 'true'
	assert video_element.get_attribute('muted')? == '' && video_element.get_attribute('data-stable')? == 'first'
	assert runtime.evaluate_host('mdmVideo.defaultMuted=false;!mdmVideo.hasAttribute("muted")&&mdmVideo.getAttribute("muted")===null')! == 'true'
	assert !video_element.has_attribute('muted')
	assert runtime.evaluate_host('mdmVideo.setAttribute("data-stable","second");mdmVideo.paused===true')! == 'true'
	assert !video_element.has_attribute('muted') && video_element.get_attribute('data-stable')? == 'second'
	assert runtime.evaluate_host('mdmAudio.defaultMuted=true;mdmAudio.getAttribute("muted")===""')! == 'true'
	assert audio_element.get_attribute('muted')? == ''
	assert runtime.evaluate_host('mdmAudio.setAttribute("muted","manual value");mdmAudio.defaultMuted===true&&mdmAudio.getAttribute("muted")==="manual value"')! == 'true'
	assert audio_element.get_attribute('muted')? == 'manual value'
	assert runtime.evaluate_host('mdmAudio.removeAttribute("muted");mdmAudio.defaultMuted===false')! == 'true'
	assert !audio_element.has_attribute('muted')
	assert runtime.evaluate_host('mdmResult.textContent="native default muted reflection painted";mdmVideo.defaultMuted=true;mdmVideo.defaultMuted===true')! == 'true'
	assert video_element.get_attribute('muted')? == ''
	assert document.get_element_by_id('mdm-result')?.text_content()? == 'native default muted reflection painted'
	for media in [video, audio] {
		assert !media.muted() && media.volume() == 1 && media.paused() && media.current_time() == 0
		assert media.network_state() == .empty && media.ready_state() == .have_nothing
		assert media.current_src() == '' && media.error() == none
		for name in ['volumechange', 'play', 'loadstart'] { assert media.event_count(name) == 0 }
	}
	assert runtime.evaluate_host('mdmEvents.length===0')! == 'true'
	assert media_default_muted_owner_take_task(document) == none
	// Explicit layout verifies retained paint rather than assuming a queued JS poll.
	app.relayout(320, 240 + app.chrome_height())
	assert app.paint_commands.any(it.kind == 'draw_text' && it.text == 'native default muted reflection painted' && it.color == 'rgb(71 72 73)')
	assert app.js_messages == []
	media_default_muted_owner_balance(runtime, document)
}

fn test_native_default_muted_owner_uses_captured_sync_intrinsics_and_preserves_runtime_muted_events() {
	$if !darwin { return }
	_, mut document, mut runtime := media_default_muted_owner_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	video_element := document.get_element_by_id('mdm-video')?
	mut video := html.html_media_element_for_dom_element(video_element)?
	probe := &MediaDefaultMutedOwnerProbe{}
	video.set_fetch_hook(fn [probe] (_ dom.URL, _ u64) !html.MediaResourceResponse {
		mut state := unsafe { &MediaDefaultMutedOwnerProbe(probe) }
		state.fetches++
		return error('defaultMuted reflection must not fetch')
	})
	video.set_playback_manager_hooks(html.MediaPlaybackManagerHooks{
		set_volume: fn [probe] (volume f64) {
			mut state := unsafe { &MediaDefaultMutedOwnerProbe(probe) }
			state.volume_updates << volume
		}
	})
	video.set_muted(true)
	media_default_muted_owner_drain(document)
	assert video.muted() && video.event_count('volumechange') == 1 && probe.volume_updates == [0.0]
	assert runtime.evaluate_host('mdmEvents.join(",")==="volumechange"&&mdmVideo.muted===true&&mdmVideo.defaultMuted===false')! == 'true'
	assert runtime.evaluate_host(r'(()=>{
 globalThis.mdmPoisonCalls=0;
 globalThis.mdmSavedGet=mdmVideo.getAttribute;globalThis.mdmSavedHas=mdmVideo.hasAttribute;globalThis.mdmSavedSet=mdmVideo.setAttribute;globalThis.mdmSavedRemove=mdmVideo.removeAttribute;
 const define=Object.defineProperty;globalThis.mdmRestoreIntrinsics={define:define,apply:Reflect.apply,remove:Reflect.deleteProperty,get:WeakMap.prototype.get,set:WeakMap.prototype.set};
 const poison=function(){mdmPoisonCalls++;throw "author poison"};
 for(const name of ["getAttribute","hasAttribute","setAttribute","removeAttribute"])define(mdmVideo,name,{get:poison,configurable:true});
 define(globalThis,"__ladybirdMediaElementSetAttributeSync",{value:poison,configurable:true});
 define(Object.prototype,"muted",{get:poison,set:poison,configurable:true});
 globalThis.Boolean=poison;WeakMap.prototype.get=poison;WeakMap.prototype.set=poison;Reflect.apply=poison;Reflect.deleteProperty=poison;Object.defineProperty=poison;
 if(mdmReflection.set.call(mdmVideo,{[Symbol.toPrimitive]:poison})!==undefined||mdmReflection.get.call(mdmVideo)!==true||mdmSavedGet.call(mdmVideo,"muted")!==""||!mdmSavedHas.call(mdmVideo,"muted"))return false;
 mdmSavedSet.call(mdmVideo,"data-stable","poisoned present");void mdmVideo.paused;
 return mdmPoisonCalls===0&&mdmSavedGet.call(mdmVideo,"muted")===""&&mdmVideo.muted===true;
})()')! == 'true'
	assert video_element.get_attribute('muted')? == ''
	assert video_element.get_attribute('data-stable')? == 'poisoned present'
	assert runtime.evaluate_host(r'(()=>{
 mdmReflection.set.call(mdmVideo,false);
 if(mdmSavedHas.call(mdmVideo,"muted")||mdmSavedGet.call(mdmVideo,"muted")!==null)return false;
 mdmSavedSet.call(mdmVideo,"data-stable","poisoned absent");void mdmVideo.paused;
 mdmRestoreIntrinsics.remove(Object.prototype,"muted");
 mdmSavedSet.call(mdmVideo,"muted","public write");if(mdmReflection.get.call(mdmVideo)!==true)return false;
 mdmSavedRemove.call(mdmVideo,"muted");if(mdmReflection.get.call(mdmVideo)!==false)return false;
 if(mdmPoisonCalls!==0||mdmVideo.muted!==true||mdmEvents.join(",")!=="volumechange")return false;
 Object.defineProperty=mdmRestoreIntrinsics.define;Reflect.apply=mdmRestoreIntrinsics.apply;Reflect.deleteProperty=mdmRestoreIntrinsics.remove;WeakMap.prototype.get=mdmRestoreIntrinsics.get;WeakMap.prototype.set=mdmRestoreIntrinsics.set;
 return true;
})()')! == 'true'
	assert !video_element.has_attribute('muted') && video_element.get_attribute('data-stable')? == 'poisoned absent'
	assert video.muted() && video.volume() == 1 && video.paused() && video.current_time() == 0
	assert video.current_src() == '' && video.network_state() == .empty && video.ready_state() == .have_nothing
	assert video.error() == none && video.event_count('volumechange') == 1
	assert video.event_count('play') == 0 && video.event_count('loadstart') == 0
	assert probe.fetches == 0 && probe.volume_updates == [0.0]
	assert media_default_muted_owner_take_task(document) == none
	media_default_muted_owner_balance(runtime, document)
}
