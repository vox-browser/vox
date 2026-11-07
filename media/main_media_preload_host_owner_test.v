module main

import browserjs
import dom
import html
import page
import time

const media_preload_owner_markup = '<!doctype html><style>html,body{margin:0}#mpp-video{display:block;width:100px;height:40px}#mpp-result{color:rgb(17,34,51)}#mpp-video[preload="none"]~#mpp-result{color:rgb(71,72,73)}</style><video id="mpp-video" preload="MeTaDaTa"></video><div id="mpp-ordinary"></div><svg width="0" height="0"><video id="mpp-svg" preload="none"></video></svg><div id="mpp-result">reflection waiting</div>'

@[heap]
struct MediaPreloadOwnerProbe {
mut:
	fetches int
	starts int
	getter_saw_raw bool
}

fn media_preload_owner_fixture() !(&BrowserApp, &dom.Document, &browserjs.Runtime) {
	mut owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time(media_preload_owner_markup, dom.URL{
		value: 'https://media-preload-owner.example.test/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	runtime := browserjs.Runtime.create()
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'
globalThis.mppVideo=document.getElementById("mpp-video");globalThis.mppSVG=document.getElementById("mpp-svg");globalThis.mppOrdinary=document.getElementById("mpp-ordinary");globalThis.mppResult=document.getElementById("mpp-result");globalThis.mppAudio=document.createElement("audio");mppAudio.id="mpp-audio";document.body.appendChild(mppAudio);void mppAudio.paused;mppAudio.preload="created invalid";globalThis.mppReflection=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"preload");0
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

fn media_preload_owner_take_task(document &dom.Document) ?&html.Task {
	mut queue := html.main_thread_event_loop().task_queue()
	return queue.take_first_runnable_matching(fn [document] (task &html.Task) bool {
		owner := task.document() or { return false }
		return task.source() == .media_element && voidptr(owner) == voidptr(document)
	})
}

fn media_preload_owner_drain(document &dom.Document) {
	mut count := 0
	for {
		task := media_preload_owner_take_task(document) or { break }
		count++
		assert count < 100
		task.execute()
	}
}

fn media_preload_owner_balance(runtime &browserjs.Runtime, document &dom.Document) {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
	assert runtime.libjs_vm().execution_context_stack().len == 0
	assert runtime.libjs_vm().interpreter_stack().depth() == 0
}

fn test_native_preload_owner_keeps_raw_values_dirty_snapshots_boolean_sync_and_selector_paint() {
	$if !darwin { return }
	mut app, mut document, mut runtime := media_preload_owner_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	video_element := document.get_element_by_id('mpp-video')?
	audio_element := document.get_element_by_id('mpp-audio')?
	video := html.html_media_element_for_dom_element(video_element)?
	audio := html.html_media_element_for_dom_element(audio_element)?
	assert runtime.evaluate_host(r'globalThis.preload="global fake";document.preload="document fake";mppVideo.preload==="metadata"&&mppVideo.getAttribute("preload")==="MeTaDaTa"&&mppAudio.preload==="metadata"&&mppAudio.getAttribute("preload")==="created invalid"&&!Object.hasOwn(mppVideo,"preload")&&!Object.hasOwn(mppAudio,"preload")&&!("preload" in mppSVG)&&!("preload" in mppOrdinary)')! == 'true'
	assert video_element.get_attribute('preload')? == 'MeTaDaTa'
	assert runtime.evaluate_host('mppVideo.preload="NONE";mppVideo.setAttribute("data-stable","present");mppVideo.paused&&mppVideo.preload==="none"&&mppVideo.getAttribute("preload")==="NONE"')! == 'true'
	assert video_element.get_attribute('preload')? == 'NONE'
	assert runtime.evaluate_host('mppVideo.preload="";mppVideo.setAttribute("data-stable","empty present");mppVideo.paused&&mppVideo.preload==="metadata"&&mppVideo.hasAttribute("preload")&&mppVideo.getAttribute("preload")===""')! == 'true'
	assert video_element.has_attribute('preload') && video_element.get_attribute('preload')? == ''
	// Raw empty strings must coexist with the shared callback's boolean empty/remove protocol.
	assert runtime.evaluate_host(r'mppVideo.defaultMuted=true;mppVideo.loop=true;mppVideo.autoplay=true;mppVideo.preload="";mppVideo.setAttribute("data-stable","boolean present");void mppVideo.paused;["muted","loop","autoplay","preload"].every(name=>mppVideo.hasAttribute(name)&&mppVideo.getAttribute(name)==="")&&mppVideo.preload==="metadata"')! == 'true'
	assert runtime.evaluate_host(r'mppVideo.defaultMuted=false;mppVideo.loop=false;mppVideo.autoplay=false;mppVideo.setAttribute("data-stable","boolean absent");void mppVideo.paused;["muted","loop","autoplay"].every(name=>!mppVideo.hasAttribute(name))&&mppVideo.hasAttribute("preload")&&mppVideo.getAttribute("preload")===""&&mppVideo.preload==="metadata"')! == 'true'
	for name in ['muted', 'loop', 'autoplay'] { assert !video_element.has_attribute(name) }
	assert video_element.has_attribute('preload') && video_element.get_attribute('preload')? == ''
	assert runtime.evaluate_host('mppAudio.setAttribute("preload","auto");mppAudio.preload==="auto";mppAudio.removeAttribute("preload");mppAudio.preload==="metadata"&&!mppAudio.hasAttribute("preload")')! == 'true'
	assert !audio_element.has_attribute('preload')
	assert runtime.evaluate_host(r'(()=>{
 globalThis.mppPoisonCalls=0;const define=Object.defineProperty;
 globalThis.mppSavedGet=mppVideo.getAttribute;globalThis.mppSavedHas=mppVideo.hasAttribute;globalThis.mppSavedSet=mppVideo.setAttribute;globalThis.mppSavedRemove=mppVideo.removeAttribute;
 globalThis.mppRestore={define:define,apply:Reflect.apply,remove:Reflect.deleteProperty,get:WeakMap.prototype.get,set:WeakMap.prototype.set,string:String};
 const poison=function(){mppPoisonCalls++;throw "author poison"};
 for(const name of ["getAttribute","hasAttribute","setAttribute","removeAttribute"])define(mppVideo,name,{get:poison,configurable:true});
 define(globalThis,"__ladybirdMediaElementSetAttributeSync",{value:poison,configurable:true});define(Object.prototype,"preload",{get:poison,set:poison,configurable:true});
 WeakMap.prototype.get=poison;WeakMap.prototype.set=poison;Reflect.apply=poison;Reflect.deleteProperty=poison;Object.defineProperty=poison;globalThis.String=poison;
 if(mppReflection.set.call(mppVideo,"")!==undefined||mppReflection.get.call(mppVideo)!=="metadata")return false;
 globalThis.String=mppRestore.string;
 if(!mppSavedHas.call(mppVideo,"preload")||mppSavedGet.call(mppVideo,"preload")!=="")return false;
 mppSavedSet.call(mppVideo,"data-stable","poisoned empty");void mppVideo.paused;
 mppReflection.set.call(mppVideo,"none");if(mppReflection.get.call(mppVideo)!=="none"||mppSavedGet.call(mppVideo,"preload")!=="none")return false;
 mppSavedSet.call(mppVideo,"data-stable","poisoned none");void mppVideo.paused;
 mppRestore.remove(Object.prototype,"preload");Object.defineProperty=mppRestore.define;Reflect.apply=mppRestore.apply;Reflect.deleteProperty=mppRestore.remove;WeakMap.prototype.get=mppRestore.get;WeakMap.prototype.set=mppRestore.set;
 return mppPoisonCalls===0;
})()')! == 'true'
	assert video_element.get_attribute('preload')? == 'none' && video.preload() == 'none'
	assert video_element.get_attribute('data-stable')? == 'poisoned none'
	assert runtime.evaluate_host('mppResult.textContent="native preload reflection painted";mppVideo.preload==="none"')! == 'true'
	app.relayout(320, 240 + app.chrome_height())
	assert app.paint_commands.any(it.kind == 'draw_text' && it.text == 'native preload reflection painted' && it.color == 'rgb(71 72 73)')
	for media in [video, audio] {
		assert media.paused() && media.current_time() == 0 && media.network_state() == .empty
		assert media.ready_state() == .have_nothing && !media.muted() && media.volume() == 1
		for name in ['play', 'loadstart', 'volumechange'] { assert media.event_count(name) == 0 }
	}
	assert media_preload_owner_take_task(document) == none && app.js_messages == []
	media_preload_owner_balance(runtime, document)
}

fn test_native_preload_owner_updates_created_audio_deferral_and_keeps_inner_none_after_fetch_reentry() {
	$if !darwin { return }
	mut policy := html.AutoplaySettings.the()
	previous_policy := policy.policy()
	previous_allowlist := policy.allowlist().map(it.serialize())
	defer { policy.set_policy(previous_policy, previous_allowlist) }
	policy.set_policy(.block_audio_and_video, [])
	for mode in ['metadata', 'remove', 'invalid', 'reentrant'] {
		_, mut document, mut runtime := media_preload_owner_fixture()!
		defer {
			runtime.close()
			document.finalize()
		}
		element := document.get_element_by_id('mpp-audio')?
		mut media := html.html_media_element_for_dom_element(element)?
		probe := &MediaPreloadOwnerProbe{}
		runtime_handle := voidptr(runtime)
		media.set_fetch_hook(fn [probe, runtime_handle, mode] (url dom.URL, offset u64) !html.MediaResourceResponse {
			mut observed := unsafe { &MediaPreloadOwnerProbe(probe) }
			mut current_runtime := unsafe { &browserjs.Runtime(runtime_handle) }
			assert url.serialize() == 'https://media-preload-owner.example.test/deferred.webm' && offset == 0
			observed.fetches++
			raw_check := if mode == 'remove' { 'mppAudio.getAttribute("preload")===null' } else if mode == 'invalid' { 'mppAudio.getAttribute("preload")==="invalid"' } else { 'mppAudio.getAttribute("preload")==="metadata"' }
			observed.getter_saw_raw = current_runtime.evaluate_host('mppAudio.preload==="metadata"&&' + raw_check)! == 'true'
			assert observed.getter_saw_raw
			if mode == 'reentrant' {
				assert current_runtime.evaluate_host('mppAudio.preload="none";mppAudio.setAttribute("data-reentrant","inner none");mppAudio.paused&&mppAudio.preload==="none"&&mppAudio.getAttribute("preload")==="none"')! == 'true'
			}
			return html.MediaResourceResponse{ mime_type: 'audio/webm', duration: 5, buffered_end: 5 }
		})
		media.set_playback_manager_hooks(html.MediaPlaybackManagerHooks{
			play: fn [probe] () {
				mut observed := unsafe { &MediaPreloadOwnerProbe(probe) }
				observed.starts++
			}
		})
		// The facade is already natively bound. A later preload write must govern selection.
		assert runtime.evaluate_host('mppAudio.preload="none";mppAudio.src="/deferred.webm";mppAudio.paused&&mppAudio.preload==="none"&&mppAudio.readyState===0')! == 'true'
		assert element.get_attribute('preload')? == 'none' && media.preload() == 'none'
		assert probe.fetches == 0 && media.network_state() == .idle
		assert media.event_count('loadstart') == 1 && media.event_count('suspend') == 1
		assert runtime.evaluate_host(r'globalThis.mppResourceEvents=[];for(const name of ["loadedmetadata","loadeddata"])mppAudio.addEventListener(name,event=>mppResourceEvents.push(event));mppAudio.preload="NONE";mppAudio.preload==="none"&&mppAudio.paused')! == 'true'
		assert probe.fetches == 0
		operation := if mode == 'remove' { 'mppAudio.removeAttribute("preload")' } else if mode == 'invalid' { 'mppAudio.preload="invalid"' } else { 'mppAudio.preload="metadata"' }
		assert runtime.evaluate_host(operation + ';void mppAudio.preload;mppAudio.readyState===4&&mppAudio.paused&&mppResourceEvents.length===0')! == 'true'
		assert probe.fetches == 1 && probe.starts == 0 && probe.getter_saw_raw
		if mode == 'reentrant' {
			assert element.get_attribute('preload')? == 'none' && media.preload() == 'none'
			assert runtime.evaluate_host('mppAudio.setAttribute("data-stable","outer replay");mppAudio.paused&&mppAudio.preload==="none"&&mppAudio.getAttribute("preload")==="none"&&mppAudio.getAttribute("data-reentrant")==="inner none"')! == 'true'
		} else {
			assert media.preload() == 'metadata'
		}
		media_preload_owner_drain(document)
		assert runtime.evaluate_host('mppResourceEvents.map(event=>event.type).join(",")==="loadedmetadata,loadeddata"&&mppResourceEvents.every(event=>event.isTrusted&&event.target===mppAudio&&event.currentTarget===null&&event.eventPhase===Event.NONE)&&window.event===undefined')! == 'true'
		for index in 0 .. 2 {
			wrapper := runtime.evaluate_host_value('mppResourceEvents[${index}]')!
			event := runtime.native_event(wrapper)!
			assert voidptr(event.target()?) == voidptr(element) && event.is_trusted()
			assert runtime.javascript_event(event)! == wrapper
		}
		assert runtime.evaluate_host('mppAudio.preload="none";mppAudio.preload="auto";mppAudio.paused&&mppAudio.preload==="auto"')! == 'true'
		assert probe.fetches == 1 && probe.starts == 0
		assert media.event_count('play') == 0 && media.event_count('playing') == 0
		assert media_preload_owner_take_task(document) == none
		media_preload_owner_balance(runtime, document)
	}
}
