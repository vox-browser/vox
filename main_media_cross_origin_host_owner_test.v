module main

import browserjs
import dom
import html
import page
import time

const media_cross_origin_owner_markup = '<!doctype html><style>html,body{margin:0}#mco-video{display:block;width:100px;height:40px}#mco-result{color:rgb(17,34,51)}#mco-video[crossorigin="use-credentials"]~#mco-result{color:rgb(71,72,73)}</style><video id="mco-video" crossorigin="USE-CREDENTIALS"></video><div id="mco-ordinary"></div><svg width="0" height="0"><video id="mco-svg" crossorigin="anonymous"></video></svg><div id="mco-result">reflection waiting</div>'

@[heap]
struct MediaCrossOriginOwnerProbe {
mut:
	media_fetches int
	track_modes []html.CORSSettingAttribute
	track_owner_ids []dom.UniqueNodeID
}

fn media_cross_origin_owner_fixture() !(&BrowserApp, &dom.Document, &browserjs.Runtime) {
	mut owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time(media_cross_origin_owner_markup, dom.URL{
		value: 'https://media-cross-origin-owner.example.test/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	runtime := browserjs.Runtime.create()
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'
globalThis.mcoVideo=document.getElementById("mco-video");globalThis.mcoSVG=document.getElementById("mco-svg");globalThis.mcoOrdinary=document.getElementById("mco-ordinary");globalThis.mcoResult=document.getElementById("mco-result");globalThis.mcoAudio=document.createElement("audio");mcoAudio.id="mco-audio";document.body.appendChild(mcoAudio);void mcoAudio.paused;mcoAudio.crossOrigin="created invalid";globalThis.mcoReflection=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"crossOrigin");0
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

fn media_cross_origin_owner_take_task(document &dom.Document) ?&html.Task {
	mut queue := html.main_thread_event_loop().task_queue()
	return queue.take_first_runnable_matching(fn [document] (task &html.Task) bool {
		owner := task.document() or { return false }
		return task.source() == .media_element && voidptr(owner) == voidptr(document)
	})
}

fn media_cross_origin_owner_drain(document &dom.Document) {
	mut count := 0
	for {
		task := media_cross_origin_owner_take_task(document) or { break }
		count++
		assert count < 100
		task.execute()
	}
}

fn media_cross_origin_owner_balance(runtime &browserjs.Runtime, document &dom.Document) {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
	assert runtime.libjs_vm().execution_context_stack().len == 0
	assert runtime.libjs_vm().interpreter_stack().depth() == 0
}

fn test_native_cross_origin_owner_preserves_nullable_raw_reflection_dirty_snapshots_and_selector_paint() {
	$if !darwin { return }
	mut app, mut document, mut runtime := media_cross_origin_owner_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	video_element := document.get_element_by_id('mco-video')?
	audio_element := document.get_element_by_id('mco-audio')?
	video := html.html_media_element_for_dom_element(video_element)?
	audio := html.html_media_element_for_dom_element(audio_element)?
	assert runtime.evaluate_host(r'globalThis.crossOrigin="global fake";document.crossOrigin="document fake";mcoVideo.crossOrigin==="use-credentials"&&mcoVideo.getAttribute("crossorigin")==="USE-CREDENTIALS"&&mcoAudio.crossOrigin==="anonymous"&&mcoAudio.getAttribute("crossorigin")==="created invalid"&&!Object.hasOwn(mcoVideo,"crossOrigin")&&!Object.hasOwn(mcoAudio,"crossOrigin")&&!("crossOrigin" in mcoSVG)&&!("crossOrigin" in mcoOrdinary)')! == 'true'
	assert video_element.get_attribute('crossorigin')? == 'USE-CREDENTIALS'
	assert runtime.evaluate_host('mcoVideo.crossOrigin="";mcoVideo.setAttribute("data-stable","empty present");mcoVideo.paused&&mcoVideo.crossOrigin==="anonymous"&&mcoVideo.hasAttribute("crossorigin")&&mcoVideo.getAttribute("crossorigin")===""')! == 'true'
	assert video_element.has_attribute('crossorigin') && video_element.get_attribute('crossorigin')? == ''
	assert runtime.evaluate_host('mcoVideo.crossOrigin=null;mcoVideo.setAttribute("data-stable","null absent");mcoVideo.paused&&mcoVideo.crossOrigin===null&&!mcoVideo.hasAttribute("crossorigin")')! == 'true'
	assert !video_element.has_attribute('crossorigin') && video.crossorigin() == .no_cors
	assert runtime.evaluate_host('mcoAudio.crossOrigin="ANONYMOUS";mcoAudio.crossOrigin==="anonymous"&&mcoAudio.getAttribute("crossorigin")==="ANONYMOUS"')! == 'true'
	assert runtime.evaluate_host('mcoAudio.crossOrigin=undefined;mcoAudio.setAttribute("data-stable","undefined absent");mcoAudio.paused&&mcoAudio.crossOrigin===null&&!mcoAudio.hasAttribute("crossorigin")')! == 'true'
	assert !audio_element.has_attribute('crossorigin')
	assert runtime.evaluate_host('mcoAudio.setAttribute("crossorigin","use-credentials");mcoAudio.crossOrigin==="use-credentials";mcoAudio.removeAttribute("crossorigin");mcoAudio.crossOrigin===null')! == 'true'
	assert runtime.evaluate_host(r'(()=>{
 globalThis.mcoPoisonCalls=0;const define=Object.defineProperty;
 globalThis.mcoSavedGet=mcoVideo.getAttribute;globalThis.mcoSavedHas=mcoVideo.hasAttribute;globalThis.mcoSavedSet=mcoVideo.setAttribute;globalThis.mcoSavedRemove=mcoVideo.removeAttribute;
 globalThis.mcoRestore={define:define,apply:Reflect.apply,remove:Reflect.deleteProperty,get:WeakMap.prototype.get,set:WeakMap.prototype.set,string:String};
 const poison=function(){mcoPoisonCalls++;throw "author poison"};
 for(const name of ["getAttribute","hasAttribute","setAttribute","removeAttribute"])define(mcoVideo,name,{get:poison,configurable:true});
 define(globalThis,"__ladybirdMediaElementSetAttributeSync",{value:poison,configurable:true});define(Object.prototype,"crossorigin",{get:poison,set:poison,configurable:true});
 WeakMap.prototype.get=poison;WeakMap.prototype.set=poison;Reflect.apply=poison;Reflect.deleteProperty=poison;Object.defineProperty=poison;globalThis.String=poison;
 if(mcoReflection.set.call(mcoVideo,undefined)!==undefined||mcoReflection.get.call(mcoVideo)!==null)return false;
 if(mcoReflection.set.call(mcoVideo,"")!==undefined||mcoReflection.get.call(mcoVideo)!=="anonymous")return false;
 globalThis.String=mcoRestore.string;
 if(!mcoSavedHas.call(mcoVideo,"crossorigin")||mcoSavedGet.call(mcoVideo,"crossorigin")!=="")return false;
 mcoSavedSet.call(mcoVideo,"data-stable","poisoned present");void mcoVideo.paused;
 mcoReflection.set.call(mcoVideo,null);mcoSavedSet.call(mcoVideo,"data-stable","poisoned absent");void mcoVideo.paused;
 if(mcoReflection.get.call(mcoVideo)!==null||mcoSavedHas.call(mcoVideo,"crossorigin"))return false;
 mcoReflection.set.call(mcoVideo,"use-credentials");
 mcoRestore.remove(Object.prototype,"crossorigin");Object.defineProperty=mcoRestore.define;Reflect.apply=mcoRestore.apply;Reflect.deleteProperty=mcoRestore.remove;WeakMap.prototype.get=mcoRestore.get;WeakMap.prototype.set=mcoRestore.set;
 return mcoPoisonCalls===0&&mcoSavedGet.call(mcoVideo,"crossorigin")==="use-credentials";
})()')! == 'true'
	assert video_element.get_attribute('crossorigin')? == 'use-credentials' && video.crossorigin() == .use_credentials
	assert video_element.get_attribute('data-stable')? == 'poisoned absent'
	assert runtime.evaluate_host('mcoResult.textContent="native cross origin reflection painted";mcoVideo.crossOrigin==="use-credentials"')! == 'true'
	app.relayout(320, 240 + app.chrome_height())
	assert app.paint_commands.any(it.kind == 'draw_text' && it.text == 'native cross origin reflection painted' && it.color == 'rgb(71 72 73)')
	for media in [video, audio] {
		assert media.paused() && media.current_time() == 0 && media.network_state() == .empty
		assert media.ready_state() == .have_nothing && !media.muted() && media.volume() == 1
		for name in ['loadstart', 'play', 'volumechange'] { assert media.event_count(name) == 0 }
	}
	assert media_cross_origin_owner_take_task(document) == none && app.js_messages == []
	media_cross_origin_owner_balance(runtime, document)
}

fn media_cross_origin_owner_consume_track(element &dom.Element, media &html.HTMLMediaElement, probe &MediaCrossOriginOwnerProbe, index int) ! {
	document := element.document()
	track_element := document.create_element_ns(dom.namespace_html_uri, 'track')!
	mut parent := element.as_node()
	parent.append_child(track_element.as_node())!
	mut track := html.html_track_element_model_for_dom_element(unsafe { &dom.HTMLTrackElement(track_element) })
	track.set_parent_media(media)
	track.set_fetch_hook(fn [probe, element] (url dom.URL, cors html.CORSSettingAttribute) !html.TextTrackResourceResponse {
		mut observed := unsafe { &MediaCrossOriginOwnerProbe(probe) }
		assert url.serialize_path().ends_with('.vtt')
		observed.track_modes << cors
		observed.track_owner_ids << element.document().unique_id()
		return html.TextTrackResourceResponse{ body: 'WEBVTT\n\n00:00.000 --> 00:01.000\nowner CORS\n' }
	})
	track.set_src('/controlled-captions-${index}.vtt')
	track.set_mode(.hidden)
	track.start_the_track_processing_model()
	assert track.ready_state() == .loaded && track.track.cues().length() == 1
	assert track.event_count('load') == 1 && track.event_count('error') == 0
}

fn test_native_cross_origin_owner_updates_real_track_cors_without_reloading_media_and_follows_adoption() {
	$if !darwin { return }
	_, mut document, mut runtime := media_cross_origin_owner_fixture()!
	address := dom.URL{ value: 'https://cross-origin-adopted.example.test/' }
	mut destination := html.parse_navigation_document('<!doctype html><body></body>', address, address.origin(), none)!
	defer {
		runtime.close()
		document.finalize()
		destination.finalize()
	}
	mut video_element := document.get_element_by_id('mco-video')?
	mut audio_element := document.get_element_by_id('mco-audio')?
	mut video := html.html_media_element_for_dom_element(video_element)?
	mut audio := html.html_media_element_for_dom_element(audio_element)?
	probe := &MediaCrossOriginOwnerProbe{}
	for index, item in [video, audio] {
		mut media := unsafe { &html.HTMLMediaElement(item) }
		mime := if index == 0 { 'video/mp4' } else { 'audio/webm' }
		source := if index == 0 { '/video.mp4' } else { '/audio.webm' }
		media.set_source(source)
		media.set_fetch_hook(fn [probe, mime] (_ dom.URL, offset u64) !html.MediaResourceResponse {
			assert offset == 0
			mut observed := unsafe { &MediaCrossOriginOwnerProbe(probe) }
			observed.media_fetches++
			return html.MediaResourceResponse{ mime_type: mime, duration: 3, buffered_end: 3 }
		})
	}
	// Model source prerequisites plus public load avoid the separate automatic src load.
	assert runtime.evaluate_host('mcoVideo.load();mcoAudio.load();mcoVideo.readyState===4&&mcoAudio.readyState===4')! == 'true'
	media_cross_origin_owner_drain(document)
	assert probe.media_fetches == 2
	operations := ['mcoVideo.crossOrigin=null', 'mcoAudio.crossOrigin=""',
		'mcoVideo.crossOrigin="USE-CREDENTIALS"', 'mcoAudio.crossOrigin="invalid"',
		'mcoVideo.setAttribute("crossorigin","ANONYMOUS")', 'mcoAudio.crossOrigin=undefined']
	expected := [html.CORSSettingAttribute.no_cors, .anonymous, .use_credentials,
		.anonymous, .anonymous, .no_cors]
	for index, operation in operations {
		alias := if index % 2 == 0 { 'mcoVideo' } else { 'mcoAudio' }
		element := if index % 2 == 0 { video_element } else { audio_element }
		media := if index % 2 == 0 { video } else { audio }
		assert runtime.evaluate_host(operation + ';' + alias + '.paused')! == 'true'
		assert media.crossorigin() == expected[index]
		media_cross_origin_owner_consume_track(element, media, probe, index)!
		assert probe.track_modes.len == index + 1 && probe.track_modes[index] == expected[index]
		assert probe.track_owner_ids[index] == document.unique_id()
		assert probe.media_fetches == 2
	}
	// Direct V DOM mutations must reach the real consumer even when the old cached enum differs.
	audio_element.set_attribute_value('crossorigin', 'USE-CREDENTIALS')
	assert audio.crossorigin() == .use_credentials
	media_cross_origin_owner_consume_track(audio_element, audio, probe, 6)!
	assert probe.track_modes[6] == .use_credentials
	audio_element.remove_attribute('crossorigin')
	assert audio.crossorigin() == .no_cors
	media_cross_origin_owner_consume_track(audio_element, audio, probe, 7)!
	assert probe.track_modes[7] == .no_cors
	destination.adopt_node(video_element.as_node())
	assert voidptr(video.document()?) == voidptr(destination)
	assert runtime.evaluate_host('mcoVideo.crossOrigin==="anonymous"')! == 'true'
	video_element.set_attribute_value('crossorigin', 'use-credentials')
	media_cross_origin_owner_consume_track(video_element, video, probe, 8)!
	assert probe.track_modes[8] == .use_credentials && probe.track_owner_ids[8] == destination.unique_id()
	assert probe.track_modes.len == 9 && probe.media_fetches == 2
	for index, media in [video, audio] {
		assert media.paused() && media.ready_state() == .have_enough_data && media.network_state() == .idle
		assert media.duration() == 3 && media.current_time() == 0 && media.error() == none
		expected_source := if index == 0 { 'video.mp4' } else { 'audio.webm' }
		assert media.current_src() == 'https://media-cross-origin-owner.example.test/' + expected_source
		assert media.event_count('loadstart') == 1 && media.event_count('play') == 0
	}
	assert media_cross_origin_owner_take_task(document) == none
	media_cross_origin_owner_balance(runtime, document)
}

