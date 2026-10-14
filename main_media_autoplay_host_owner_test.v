module main

import browserjs
import dom
import html
import page
import time

const media_autoplay_owner_markup = '<!doctype html><style>html,body{margin:0}#map-video{display:block;width:100px;height:40px}#map-result{color:rgb(17,34,51)}#map-video[autoplay]~#map-result{color:rgb(71,72,73)}</style><video id="map-video" preload="none"></video><div id="map-ordinary"></div><svg width="0" height="0"><video id="map-svg" autoplay="svg value"></video></svg><audio id="map-resource-audio" preload="none"></audio><div id="map-result">reflection waiting</div>'

@[heap]
struct MediaAutoplayOwnerProbe {
mut:
	fetches int
	starts int
	getter_saw_reflection bool
}

fn media_autoplay_owner_fixture() !(&BrowserApp, &dom.Document, &browserjs.Runtime) {
	mut owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time(media_autoplay_owner_markup, dom.URL{
		value: 'https://media-autoplay-owner.example.test/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	runtime := browserjs.Runtime.create()
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'
globalThis.mapVideo=document.getElementById("map-video");globalThis.mapSVG=document.getElementById("map-svg");globalThis.mapOrdinary=document.getElementById("map-ordinary");globalThis.mapResult=document.getElementById("map-result");globalThis.mapResourceAudio=document.getElementById("map-resource-audio");globalThis.mapAudio=document.createElement("audio");mapAudio.id="map-audio";mapAudio.setAttribute("preload","none");mapAudio.setAttribute("autoplay","created value");document.body.appendChild(mapAudio);void mapAudio.paused;globalThis.mapReflection=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"autoplay");globalThis.mapEvents=[];mapVideo.addEventListener("volumechange",event=>mapEvents.push(event.type));0
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

fn media_autoplay_owner_take_task(document &dom.Document) ?&html.Task {
	mut queue := html.main_thread_event_loop().task_queue()
	return queue.take_first_runnable_matching(fn [document] (task &html.Task) bool {
		owner := task.document() or { return false }
		return task.source() == .media_element && voidptr(owner) == voidptr(document)
	})
}

fn media_autoplay_owner_drain(document &dom.Document) {
	mut count := 0
	for {
		task := media_autoplay_owner_take_task(document) or { break }
		count++
		assert count < 100
		task.execute()
	}
}

fn media_autoplay_owner_balance(runtime &browserjs.Runtime, document &dom.Document) {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
	assert runtime.libjs_vm().execution_context_stack().len == 0
	assert runtime.libjs_vm().interpreter_stack().depth() == 0
}

fn test_native_autoplay_owner_reflects_parsed_created_attributes_and_survives_dirty_snapshots() {
	$if !darwin { return }
	mut app, mut document, mut runtime := media_autoplay_owner_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	video_element := document.get_element_by_id('map-video')?
	audio_element := document.get_element_by_id('map-audio')?
	video := html.html_media_element_for_dom_element(video_element)?
	audio := html.html_media_element_for_dom_element(audio_element)?
	assert !document.get_element_by_id('map-svg')?.is_html_element()
	assert runtime.evaluate_host(r'globalThis.autoplay="global fake";document.autoplay="document fake";mapVideo.autoplay===false&&mapAudio.autoplay===true&&!Object.hasOwn(mapVideo,"autoplay")&&!Object.hasOwn(mapAudio,"autoplay")&&!("autoplay" in mapSVG)&&!("autoplay" in mapOrdinary)&&mapAudio.getAttribute("autoplay")==="created value"')! == 'true'
	assert !video_element.has_attribute('autoplay') && audio_element.get_attribute('autoplay')? == 'created value'
	assert runtime.evaluate_host('mapVideo.autoplay=true;mapVideo.autoplay===true&&mapVideo.hasAttribute("autoplay")&&mapVideo.getAttribute("autoplay")===""')! == 'true'
	assert video_element.get_attribute('autoplay')? == ''
	assert runtime.evaluate_host('mapVideo.setAttribute("data-stable","first");mapVideo.paused===true')! == 'true'
	assert video_element.get_attribute('autoplay')? == '' && video_element.get_attribute('data-stable')? == 'first'
	assert runtime.evaluate_host('mapVideo.autoplay=false;!mapVideo.hasAttribute("autoplay")&&mapVideo.getAttribute("autoplay")===null')! == 'true'
	assert !video_element.has_attribute('autoplay')
	assert runtime.evaluate_host('mapVideo.setAttribute("data-stable","second");mapVideo.paused===true')! == 'true'
	assert !video_element.has_attribute('autoplay') && video_element.get_attribute('data-stable')? == 'second'
	assert runtime.evaluate_host('mapAudio.autoplay=true;mapAudio.getAttribute("autoplay")===""')! == 'true'
	assert audio_element.get_attribute('autoplay')? == ''
	assert runtime.evaluate_host('mapAudio.setAttribute("autoplay","manual value");mapAudio.autoplay===true&&mapAudio.getAttribute("autoplay")==="manual value"')! == 'true'
	assert audio_element.get_attribute('autoplay')? == 'manual value'
	assert runtime.evaluate_host('mapAudio.removeAttribute("autoplay");mapAudio.autoplay===false')! == 'true'
	assert !audio_element.has_attribute('autoplay')
	assert runtime.evaluate_host('mapResult.textContent="native autoplay reflection painted";mapVideo.autoplay=true;mapVideo.autoplay===true')! == 'true'
	assert video_element.get_attribute('autoplay')? == ''
	assert document.get_element_by_id('map-result')?.text_content()? == 'native autoplay reflection painted'
	for media in [video, audio] {
		assert !media.muted() && media.volume() == 1 && media.paused() && media.current_time() == 0
		assert media.network_state() == .empty && media.ready_state() == .have_nothing
		assert media.current_src() == '' && media.error() == none
		for name in ['volumechange', 'play', 'loadstart'] { assert media.event_count(name) == 0 }
	}
	assert runtime.evaluate_host('mapEvents.length===0')! == 'true'
	assert media_autoplay_owner_take_task(document) == none
	assert runtime.evaluate_host(r'(()=>{
 globalThis.mapPoisonCalls=0;const define=Object.defineProperty;
 globalThis.mapSavedGet=mapVideo.getAttribute;globalThis.mapSavedHas=mapVideo.hasAttribute;globalThis.mapSavedSet=mapVideo.setAttribute;globalThis.mapSavedRemove=mapVideo.removeAttribute;
 globalThis.mapRestoreIntrinsics={define:define,apply:Reflect.apply,remove:Reflect.deleteProperty,get:WeakMap.prototype.get,set:WeakMap.prototype.set,boolean:Boolean};
 const poison=function(){mapPoisonCalls++;throw "author poison"};
 for(const name of ["getAttribute","hasAttribute","setAttribute","removeAttribute"])define(mapVideo,name,{get:poison,configurable:true});
 define(globalThis,"__ladybirdMediaElementSetAttributeSync",{value:poison,configurable:true});
 define(Object.prototype,"autoplay",{get:poison,set:poison,configurable:true});
 globalThis.Boolean=poison;WeakMap.prototype.get=poison;WeakMap.prototype.set=poison;Reflect.apply=poison;Reflect.deleteProperty=poison;Object.defineProperty=poison;
 if(mapReflection.set.call(mapVideo,false)!==undefined||mapReflection.get.call(mapVideo)!==false||mapSavedHas.call(mapVideo,"autoplay"))return false;
 mapSavedSet.call(mapVideo,"data-stable","poisoned absent");void mapVideo.paused;
 mapReflection.set.call(mapVideo,{[Symbol.toPrimitive]:poison});
 if(mapReflection.get.call(mapVideo)!==true||mapSavedGet.call(mapVideo,"autoplay")!=="")return false;
 mapSavedSet.call(mapVideo,"data-stable","poisoned present");void mapVideo.paused;
 mapRestoreIntrinsics.remove(Object.prototype,"autoplay");
 mapSavedSet.call(mapVideo,"autoplay","public write");if(mapReflection.get.call(mapVideo)!==true)return false;
 mapSavedRemove.call(mapVideo,"autoplay");if(mapReflection.get.call(mapVideo)!==false)return false;
 mapReflection.set.call(mapVideo,true);
 Object.defineProperty=mapRestoreIntrinsics.define;Reflect.apply=mapRestoreIntrinsics.apply;Reflect.deleteProperty=mapRestoreIntrinsics.remove;WeakMap.prototype.get=mapRestoreIntrinsics.get;WeakMap.prototype.set=mapRestoreIntrinsics.set;globalThis.Boolean=mapRestoreIntrinsics.boolean;
 return mapPoisonCalls===0&&mapSavedGet.call(mapVideo,"autoplay")===""&&mapVideo.autoplay===true;
})()')! == 'true'
	assert video_element.get_attribute('autoplay')? == '' && video.autoplay()
	assert video_element.get_attribute('data-stable')? == 'poisoned present'
	// Explicit layout verifies retained paint rather than assuming a queued JS poll.
	app.relayout(320, 240 + app.chrome_height())
	assert app.paint_commands.any(it.kind == 'draw_text' && it.text == 'native autoplay reflection painted' && it.color == 'rgb(71 72 73)')
	assert app.js_messages == []
	media_autoplay_owner_balance(runtime, document)
}

fn test_native_autoplay_owner_promotes_deferred_selection_once_and_preserves_reentrant_false() {
	$if !darwin { return }
	mut policy := html.AutoplaySettings.the()
	previous_policy := policy.policy()
	previous_allowlist := policy.allowlist().map(it.serialize())
	defer { policy.set_policy(previous_policy, previous_allowlist) }
	policy.set_policy(.block_audio_and_video, [])
	_, mut document, mut runtime := media_autoplay_owner_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	video_element := document.get_element_by_id('map-video')?
	audio_element := document.get_element_by_id('map-resource-audio')?
	mut video := html.html_media_element_for_dom_element(video_element)?
	mut audio := html.html_media_element_for_dom_element(audio_element)?
	video_probe := &MediaAutoplayOwnerProbe{}
	audio_probe := &MediaAutoplayOwnerProbe{}
	video.set_fetch_hook(fn [video_probe] (url dom.URL, offset u64) !html.MediaResourceResponse {
		mut observation := unsafe { &MediaAutoplayOwnerProbe(video_probe) }
		assert url.serialize() == 'https://media-autoplay-owner.example.test/deferred-video.mp4' && offset == 0
		observation.fetches++
		return html.MediaResourceResponse{ mime_type: 'video/mp4', duration: 5, buffered_end: 5 }
	})
	runtime_handle := voidptr(runtime)
	audio.set_fetch_hook(fn [audio_probe, runtime_handle] (url dom.URL, offset u64) !html.MediaResourceResponse {
		mut observation := unsafe { &MediaAutoplayOwnerProbe(audio_probe) }
		mut current_runtime := unsafe { &browserjs.Runtime(runtime_handle) }
		assert url.serialize() == 'https://media-autoplay-owner.example.test/deferred-audio.webm' && offset == 0
		observation.fetches++
		observation.getter_saw_reflection = current_runtime.evaluate_host('mapResourceAudio.autoplay===true&&mapResourceAudio.hasAttribute("autoplay")&&mapResourceAudio.getAttribute("autoplay")===""')! == 'true'
		assert observation.getter_saw_reflection
		assert current_runtime.evaluate_host('mapResourceAudio.autoplay=false;mapResourceAudio.setAttribute("data-reentrant","inner false");mapResourceAudio.paused===true&&!mapResourceAudio.autoplay&&!mapResourceAudio.hasAttribute("autoplay")')! == 'true'
		return html.MediaResourceResponse{ mime_type: 'audio/webm', duration: 5, buffered_end: 5 }
	})
	for index, item in [video, audio] {
		probe := if index == 0 { video_probe } else { audio_probe }
		mut media := unsafe { &html.HTMLMediaElement(item) }
		media.set_playback_manager_hooks(html.MediaPlaybackManagerHooks{
			play: fn [probe] () {
				mut observation := unsafe { &MediaAutoplayOwnerProbe(probe) }
				observation.starts++
			}
		})
	}
	// Use the automatic src path alone; an explicit load would bypass preload deferral.
	assert runtime.evaluate_host('mapVideo.autoplay=false;mapResourceAudio.autoplay=false;mapVideo.src="/deferred-video.mp4";mapResourceAudio.src="/deferred-audio.webm";mapVideo.paused&&mapResourceAudio.paused&&mapVideo.readyState===0&&mapResourceAudio.readyState===0')! == 'true'
	assert video_probe.fetches == 0 && audio_probe.fetches == 0
	assert video.network_state() == .idle && audio.network_state() == .idle
	assert runtime.evaluate_host('mapVideo.autoplay=true;mapVideo.autoplay===true&&mapVideo.paused&&mapVideo.readyState===0')! == 'true'
	assert video_probe.fetches == 0 && video.paused()
	assert runtime.evaluate_host('mapVideo.autoplay=false;mapVideo.setAttribute("autoplay","blocked manual");mapVideo.autoplay===true&&mapVideo.getAttribute("autoplay")==="blocked manual"')! == 'true'
	assert video_probe.fetches == 0
	assert runtime.evaluate_host('mapVideo.removeAttribute("autoplay");mapVideo.autoplay===false')! == 'true'
	policy.set_policy(.allow_audio_and_video, [])
	document.set_active_sandboxing_flag_bits(u32(html.SandboxingFlag.sandboxed_automatic_features))
	assert runtime.evaluate_host('mapVideo.autoplay=true;mapVideo.autoplay===true&&mapVideo.paused')! == 'true'
	assert video_probe.fetches == 0 && !video.is_eligible_for_autoplay()
	assert runtime.evaluate_host('mapVideo.autoplay=false;mapVideo.autoplay===false')! == 'true'
	document.set_active_sandboxing_flag_bits(0)
	assert runtime.evaluate_host(r'globalThis.mapPlayEvents=[];globalThis.mapPlayChecks=[];for(const name of ["play","playing"])mapVideo.addEventListener(name,function(event){mapPlayEvents.push(event);mapPlayChecks.push(this===mapVideo&&event.target===this&&event.currentTarget===this&&event.isTrusted&&!event.bubbles&&!event.cancelable&&window.event===event&&this.autoplay===true&&!this.paused)});mapVideo.autoplay=true;mapVideo.autoplay===true&&!mapVideo.paused&&mapVideo.readyState===4&&mapPlayEvents.length===0')! == 'true'
	assert video_probe.fetches == 1 && video_probe.starts == 1
	assert video.autoplay() && !video.paused() && video.ready_state() == .have_enough_data
	assert video.event_count('loadstart') == 1 && video.event_count('play') == 0
	media_autoplay_owner_drain(document)
	assert runtime.evaluate_host('mapPlayEvents.map(event=>event.type).join(",")==="play,playing"&&mapPlayChecks.length===2&&mapPlayChecks.every(Boolean)&&mapPlayEvents.every(event=>event.currentTarget===null&&event.eventPhase===Event.NONE)&&window.event===undefined')! == 'true'
	for index in 0 .. 2 {
		wrapper := runtime.evaluate_host_value('mapPlayEvents[${index}]')!
		event := runtime.native_event(wrapper)!
		assert event.is_trusted() && voidptr(event.target()?) == voidptr(video_element)
		assert runtime.javascript_event(event)! == wrapper
	}
	assert video.event_count('play') == 1 && video.event_count('playing') == 1
	assert runtime.evaluate_host('mapResourceAudio.autoplay=true;mapResourceAudio.autoplay===false&&!mapResourceAudio.hasAttribute("autoplay")&&mapResourceAudio.paused&&mapResourceAudio.readyState===4&&mapResourceAudio.getAttribute("data-reentrant")==="inner false"')! == 'true'
	assert audio_probe.fetches == 1 && audio_probe.starts == 0 && audio_probe.getter_saw_reflection
	assert !audio.autoplay() && !audio_element.has_attribute('autoplay') && audio.paused()
	assert runtime.evaluate_host('mapResourceAudio.setAttribute("data-stable","outer replay");mapResourceAudio.paused&&!mapResourceAudio.autoplay&&!mapResourceAudio.hasAttribute("autoplay")&&mapResourceAudio.getAttribute("data-reentrant")==="inner false"')! == 'true'
	media_autoplay_owner_drain(document)
	assert audio.event_count('play') == 0 && audio.event_count('playing') == 0
	assert video_probe.fetches == 1 && audio_probe.fetches == 1
	assert video_probe.starts == 1 && audio_probe.starts == 0
	assert media_autoplay_owner_take_task(document) == none
	media_autoplay_owner_balance(runtime, document)
}

