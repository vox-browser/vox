module main

import browserjs
import dom
import html
import page
import time

const media_loop_owner_markup = '<!doctype html><style>html,body{margin:0}#mlp-video{display:block;width:100px;height:40px}#mlp-result{color:rgb(17,34,51)}#mlp-video[loop]~#mlp-result{color:rgb(71,72,73)}</style><video id="mlp-video"></video><div id="mlp-ordinary"></div><svg width="0" height="0"><video id="mlp-svg" loop="svg value"></video></svg><div id="mlp-result">reflection waiting</div>'

@[heap]
struct MediaLoopOwnerProbe {
mut:
	fetches        int
}

fn media_loop_owner_fixture() !(&BrowserApp, &dom.Document, &browserjs.Runtime) {
	mut owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time(media_loop_owner_markup, dom.URL{
		value: 'https://media-loop-owner.example.test/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	runtime := browserjs.Runtime.create()
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'
globalThis.mlpVideo=document.getElementById("mlp-video");globalThis.mlpSVG=document.getElementById("mlp-svg");globalThis.mlpOrdinary=document.getElementById("mlp-ordinary");globalThis.mlpResult=document.getElementById("mlp-result");globalThis.mlpAudio=document.createElement("audio");mlpAudio.id="mlp-audio";mlpAudio.setAttribute("loop","created value");document.body.appendChild(mlpAudio);void mlpAudio.paused;globalThis.mlpReflection=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"loop");globalThis.mlpEvents=[];mlpVideo.addEventListener("volumechange",event=>mlpEvents.push(event.type));0
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

fn media_loop_owner_take_task(document &dom.Document) ?&html.Task {
	mut queue := html.main_thread_event_loop().task_queue()
	return queue.take_first_runnable_matching(fn [document] (task &html.Task) bool {
		owner := task.document() or { return false }
		return task.source() == .media_element && voidptr(owner) == voidptr(document)
	})
}

fn media_loop_owner_drain(document &dom.Document) {
	mut count := 0
	for {
		task := media_loop_owner_take_task(document) or { break }
		count++
		assert count < 100
		task.execute()
	}
}

fn media_loop_owner_balance(runtime &browserjs.Runtime, document &dom.Document) {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
	assert runtime.libjs_vm().execution_context_stack().len == 0
	assert runtime.libjs_vm().interpreter_stack().depth() == 0
}

fn test_native_loop_owner_reflects_parsed_created_attributes_and_survives_dirty_snapshots() {
	$if !darwin { return }
	mut app, mut document, mut runtime := media_loop_owner_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	video_element := document.get_element_by_id('mlp-video')?
	audio_element := document.get_element_by_id('mlp-audio')?
	video := html.html_media_element_for_dom_element(video_element)?
	audio := html.html_media_element_for_dom_element(audio_element)?
	assert !document.get_element_by_id('mlp-svg')?.is_html_element()
	assert runtime.evaluate_host(r'globalThis.loop="global fake";document.loop="document fake";mlpVideo.loop===false&&mlpAudio.loop===true&&!Object.hasOwn(mlpVideo,"loop")&&!Object.hasOwn(mlpAudio,"loop")&&!("loop" in mlpSVG)&&!("loop" in mlpOrdinary)&&mlpAudio.getAttribute("loop")==="created value"')! == 'true'
	assert !video_element.has_attribute('loop') && audio_element.get_attribute('loop')? == 'created value'
	assert runtime.evaluate_host('mlpVideo.loop=true;mlpVideo.loop===true&&mlpVideo.hasAttribute("loop")&&mlpVideo.getAttribute("loop")===""')! == 'true'
	assert video_element.get_attribute('loop')? == ''
	assert runtime.evaluate_host('mlpVideo.setAttribute("data-stable","first");mlpVideo.paused===true')! == 'true'
	assert video_element.get_attribute('loop')? == '' && video_element.get_attribute('data-stable')? == 'first'
	assert runtime.evaluate_host('mlpVideo.loop=false;!mlpVideo.hasAttribute("loop")&&mlpVideo.getAttribute("loop")===null')! == 'true'
	assert !video_element.has_attribute('loop')
	assert runtime.evaluate_host('mlpVideo.setAttribute("data-stable","second");mlpVideo.paused===true')! == 'true'
	assert !video_element.has_attribute('loop') && video_element.get_attribute('data-stable')? == 'second'
	assert runtime.evaluate_host('mlpAudio.loop=true;mlpAudio.getAttribute("loop")===""')! == 'true'
	assert audio_element.get_attribute('loop')? == ''
	assert runtime.evaluate_host('mlpAudio.setAttribute("loop","manual value");mlpAudio.loop===true&&mlpAudio.getAttribute("loop")==="manual value"')! == 'true'
	assert audio_element.get_attribute('loop')? == 'manual value'
	assert runtime.evaluate_host('mlpAudio.removeAttribute("loop");mlpAudio.loop===false')! == 'true'
	assert !audio_element.has_attribute('loop')
	assert runtime.evaluate_host('mlpResult.textContent="native loop reflection painted";mlpVideo.loop=true;mlpVideo.loop===true')! == 'true'
	assert video_element.get_attribute('loop')? == ''
	assert document.get_element_by_id('mlp-result')?.text_content()? == 'native loop reflection painted'
	for media in [video, audio] {
		assert !media.muted() && media.volume() == 1 && media.paused() && media.current_time() == 0
		assert media.network_state() == .empty && media.ready_state() == .have_nothing
		assert media.current_src() == '' && media.error() == none
		for name in ['volumechange', 'play', 'loadstart'] { assert media.event_count(name) == 0 }
	}
	assert runtime.evaluate_host('mlpEvents.length===0')! == 'true'
	assert media_loop_owner_take_task(document) == none
	assert runtime.evaluate_host(r'(()=>{
 globalThis.mlpPoisonCalls=0;const define=Object.defineProperty;
 globalThis.mlpSavedGet=mlpVideo.getAttribute;globalThis.mlpSavedHas=mlpVideo.hasAttribute;globalThis.mlpSavedSet=mlpVideo.setAttribute;globalThis.mlpSavedRemove=mlpVideo.removeAttribute;
 globalThis.mlpRestoreIntrinsics={define:define,apply:Reflect.apply,remove:Reflect.deleteProperty,get:WeakMap.prototype.get,set:WeakMap.prototype.set,boolean:Boolean};
 const poison=function(){mlpPoisonCalls++;throw "author poison"};
 for(const name of ["getAttribute","hasAttribute","setAttribute","removeAttribute"])define(mlpVideo,name,{get:poison,configurable:true});
 define(globalThis,"__ladybirdMediaElementSetAttributeSync",{value:poison,configurable:true});
 define(Object.prototype,"loop",{get:poison,set:poison,configurable:true});
 globalThis.Boolean=poison;WeakMap.prototype.get=poison;WeakMap.prototype.set=poison;Reflect.apply=poison;Reflect.deleteProperty=poison;Object.defineProperty=poison;
 if(mlpReflection.set.call(mlpVideo,false)!==undefined||mlpReflection.get.call(mlpVideo)!==false||mlpSavedHas.call(mlpVideo,"loop"))return false;
 mlpSavedSet.call(mlpVideo,"data-stable","poisoned absent");void mlpVideo.paused;
 mlpReflection.set.call(mlpVideo,{[Symbol.toPrimitive]:poison});
 if(mlpReflection.get.call(mlpVideo)!==true||mlpSavedGet.call(mlpVideo,"loop")!=="")return false;
 mlpSavedSet.call(mlpVideo,"data-stable","poisoned present");void mlpVideo.paused;
 mlpRestoreIntrinsics.remove(Object.prototype,"loop");
 mlpSavedSet.call(mlpVideo,"loop","public write");if(mlpReflection.get.call(mlpVideo)!==true)return false;
 mlpSavedRemove.call(mlpVideo,"loop");if(mlpReflection.get.call(mlpVideo)!==false)return false;
 mlpReflection.set.call(mlpVideo,true);
 Object.defineProperty=mlpRestoreIntrinsics.define;Reflect.apply=mlpRestoreIntrinsics.apply;Reflect.deleteProperty=mlpRestoreIntrinsics.remove;WeakMap.prototype.get=mlpRestoreIntrinsics.get;WeakMap.prototype.set=mlpRestoreIntrinsics.set;globalThis.Boolean=mlpRestoreIntrinsics.boolean;
 return mlpPoisonCalls===0&&mlpSavedGet.call(mlpVideo,"loop")===""&&mlpVideo.loop===true;
})()')! == 'true'
	assert video_element.get_attribute('loop')? == '' && video.loop()
	assert video_element.get_attribute('data-stable')? == 'poisoned present'
	// Explicit layout verifies retained paint rather than assuming a queued JS poll.
	app.relayout(320, 240 + app.chrome_height())
	assert app.paint_commands.any(it.kind == 'draw_text' && it.text == 'native loop reflection painted' && it.color == 'rgb(71 72 73)')
	assert app.js_messages == []
	media_loop_owner_balance(runtime, document)
}

fn test_native_loop_owner_restarts_actual_endpoint_then_restores_completion_and_raw_owner_scope() {
	$if !darwin { return }
	_, mut document, mut runtime := media_loop_owner_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	video_element := document.get_element_by_id('mlp-video')?
	audio_element := document.get_element_by_id('mlp-audio')?
	mut video := html.html_media_element_for_dom_element(video_element)?
	mut audio := html.html_media_element_for_dom_element(audio_element)?
	probe := &MediaLoopOwnerProbe{}
	for item in [video, audio] {
		mut media := unsafe { &html.HTMLMediaElement(item) }
		media.set_fetch_hook(fn [probe] (_ dom.URL, _ u64) !html.MediaResourceResponse {
			mut observation := unsafe { &MediaLoopOwnerProbe(probe) }
			observation.fetches++
			return html.MediaResourceResponse{ mime_type: 'video/mp4', duration: 1, buffered_end: 1 }
		})
	}
	// Controlled response metadata establishes the real owner's translated seekable range.
	assert runtime.evaluate_host('mlpVideo.src="/loop-video.mp4";mlpVideo.load();mlpAudio.src="/loop-audio.mp4";mlpAudio.load();mlpVideo.readyState===4&&mlpAudio.readyState===4')! == 'true'
	media_loop_owner_drain(document)
	// src replay selects automatically, and the explicit load fetches again per owner.
	assert probe.fetches == 4
	assert video.event_count('loadstart') == 2 && audio.event_count('loadstart') == 2
	assert video.seekable().length() == 1
	assert audio.seekable().length() == 1
	assert runtime.evaluate_host(r'globalThis.loop="global fake";document.loop="document fake";globalThis.mlpEnds=[];globalThis.mlpEndChecks=[];globalThis.mlpEndEvents=[];
for(const target of [mlpVideo,mlpAudio]){target.loop=true;target.setAttribute("onended","mlpEnds.push(this.id);mlpEndEvents.push(event);mlpEndChecks.push(loop===false&&this.loop===false&&document.loop===\"document fake\"&&globalThis.loop===\"global fake\"&&event===arguments[0]&&event instanceof Event&&event.isTrusted&&event.target===this&&event.currentTarget===this&&window.event===event&&paused===true&&ended===true);return false;");void target.onended}mlpEnds.length===0')! == 'true'
	mut event_loop := html.main_thread_event_loop()
	event_loop.process()
	media_loop_owner_drain(document)
	for item in [video, audio] {
		mut media := unsafe { &html.HTMLMediaElement(item) }
		media.set_current_playback_position(1)
		media.set_official_playback_position(1)
		media.set_paused(false)
		media.reached_end_of_media_playback()
		assert media.loop() && media.current_time() == 0 && !media.paused()
		assert media.event_count('pause') == 0 && media.event_count('ended') == 0
	}
	event_loop.perform_a_microtask_checkpoint()
	assert runtime.evaluate_host('mlpEnds.length===0&&!mlpVideo.paused&&!mlpAudio.paused')! == 'true'
	event_loop.process()
	media_loop_owner_drain(document)
	event_loop.process()
	media_loop_owner_drain(document)
	assert runtime.evaluate_host('mlpVideo.loop&&mlpAudio.loop&&mlpVideo.currentTime===0&&mlpAudio.currentTime===0&&!mlpVideo.ended&&!mlpAudio.ended&&mlpEnds.length===0')! == 'true'
	assert runtime.evaluate_host('mlpVideo.removeAttribute("loop");mlpAudio.loop=false;!mlpVideo.loop&&!mlpAudio.loop')! == 'true'
	assert !video_element.has_attribute('loop') && !audio_element.has_attribute('loop')
	for item in [video, audio] {
		mut media := unsafe { &html.HTMLMediaElement(item) }
		media.set_current_playback_position(1)
		media.set_official_playback_position(1)
		media.reached_end_of_media_playback()
		assert !media.loop() && !media.paused() && !media.ended()
	}
	event_loop.perform_a_microtask_checkpoint()
	assert runtime.evaluate_host('mlpEnds.length===0&&!mlpVideo.ended&&!mlpAudio.ended')! == 'true'
	event_loop.process()
	media_loop_owner_drain(document)
	assert runtime.evaluate_host('mlpEnds.join(",")==="mlp-video,mlp-audio"&&mlpEndChecks.length===2&&mlpEndChecks.every(Boolean)&&mlpEndEvents.every(event=>event.defaultPrevented&&event.currentTarget===null&&event.eventPhase===Event.NONE)&&window.event===undefined')! == 'true'
	for index, element in [video_element, audio_element] {
		wrapper := runtime.evaluate_host_value('mlpEndEvents[${index}]')!
		event := runtime.native_event(wrapper)!
		assert event.is_trusted() && event.type_name() == 'ended'
		assert !event.bubbles() && !event.cancelable() && event.default_prevented()
		assert voidptr(event.target()?) == voidptr(element)
		assert runtime.javascript_event(event)! == wrapper
	}
	for media in [video, audio] {
		assert media.paused() && media.ended() && media.current_time() == 1
		assert media.event_count('pause') == 1 && media.event_count('ended') == 1
	}
	assert probe.fetches == 4
	assert media_loop_owner_take_task(document) == none
	media_loop_owner_balance(runtime, document)
}

