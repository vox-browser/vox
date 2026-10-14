module main

import browserjs
import dom
import html
import json2
import page
import time

const media_can_play_type_owner_markup = '<!doctype html><style>html,body{margin:0}#mct-video{display:block;width:180px;height:60px}#mct-result{position:absolute;top:100px;left:0}</style><video id="mct-video"></video><div id="mct-ordinary"></div><svg><video id="mct-svg-video"></video></svg><div id="mct-result">waiting</div>'

@[heap]
struct MediaCanPlayTypeOwnerFetch {
mut:
	urls []string
}

fn media_can_play_type_owner_fixture(markup string, source string) !(&BrowserApp, &dom.Document, &browserjs.Runtime) {
	mut owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time(markup, dom.URL{
		value: 'https://media-can-play-type-owner.example.test/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	runtime := browserjs.Runtime.create()
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [source], runtime, mut messages)
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

fn media_can_play_type_owner_take_task(document &dom.Document) ?&html.Task {
	mut queue := html.main_thread_event_loop().task_queue()
	return queue.take_first_runnable_matching(fn [document] (task &html.Task) bool {
		owner := task.document() or { return false }
		return task.source() == .media_element && voidptr(owner) == voidptr(document)
	})
}

fn media_can_play_type_owner_drain(document &dom.Document) {
	mut count := 0
	for {
		task := media_can_play_type_owner_take_task(document) or { break }
		count++
		assert count < 100
		task.execute()
	}
}

fn media_can_play_type_owner_context(mut runtime browserjs.Runtime, document &dom.Document) ! {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	handle := voidptr(&runtime)
	actual_true := runtime.evaluate_host_value('true')!
	runtime.define_value_host_function('__mediaCanPlayTypeOwnerContext', fn [settings, handle, actual_true] (_ voidptr, args []voidptr) !voidptr {
		owner := unsafe { &browserjs.Runtime(handle) }
		assert args.len == 0
		assert settings.realm().script_execution_depth > 0 && settings.realm().callback_execution_depth > 0
		assert owner.libjs_vm().has_running_execution_context()
		assert voidptr(html.current_principal_settings_object()) == voidptr(settings)
		assert voidptr(html.incumbent_settings_object()) == voidptr(settings)
		return actual_true
	})!
}

fn media_can_play_type_owner_balance(runtime &browserjs.Runtime, document &dom.Document) {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
	assert runtime.libjs_vm().execution_context_stack().len == 0
	assert runtime.libjs_vm().interpreter_stack().depth() == 0
}

fn test_native_can_play_type_parsed_created_inheritance_and_conversion_dom_replay_without_media_selection() {
	$if !darwin {
		return
	}
	mut app, mut document, mut runtime := media_can_play_type_owner_fixture(media_can_play_type_owner_markup, r'
globalThis.mctVideo=document.getElementById("mct-video");globalThis.mctOrdinary=document.getElementById("mct-ordinary");globalThis.mctSVG=document.getElementById("mct-svg-video");globalThis.mctResult=document.getElementById("mct-result");globalThis.mctAudio=document.createElement("audio");mctAudio.id="mct-audio";document.body.appendChild(mctAudio);void mctAudio.paused;globalThis.mctConversions=0;globalThis.mctHints=[];globalThis.mctReason={original:true};0
')!
	defer {
		runtime.close()
		document.finalize()
	}
	video := html.html_media_element_for_dom_element(document.get_element_by_id('mct-video')?)?
	audio := html.html_media_element_for_dom_element(document.get_element_by_id('mct-audio')?)?
	assert !document.get_element_by_id('mct-svg-video')?.is_html_element()
	assert runtime.evaluate_host(r'globalThis.mctNative=HTMLMediaElement.prototype.canPlayType;typeof mctNative==="function"&&mctNative.name==="canPlayType"&&mctNative.length===1&&mctVideo.canPlayType===mctNative&&mctAudio.canPlayType===mctNative&&!Object.hasOwn(mctVideo,"canPlayType")&&!Object.hasOwn(mctAudio,"canPlayType")&&!("canPlayType" in mctOrdinary)&&!("canPlayType" in mctSVG)&&mctVideo.canPlayType("video/mp4")==="maybe"&&mctAudio.canPlayType("audio/webm")==="maybe"&&mctAudio.canPlayType("audio/mp4")===""')! == 'true'
	// The unchanged V heuristic checks MIME essence and the codecs= substring;
	// a probably result is not evidence of real codec/decoder availability.
	assert runtime.evaluate_host(r'mctVideo.canPlayType({[Symbol.toPrimitive](hint){mctConversions++;mctHints.push(hint);mctResult.setAttribute("data-capability","converted");mctResult.textContent="native capability conversion painted";mctVideo.style.color="rgb(0,128,0)";return " VIDEO/MP4; codecs=🎬\u0000"}})==="probably"&&mctConversions===1&&mctHints.join(",")==="string"')! == 'true'
	// No poll or state getter intervenes: the native method itself must replay
	// the DOM side effects after its single DOMString conversion succeeds.
	assert document.get_element_by_id('mct-result')?.get_attribute('data-capability')? == 'converted'
	assert document.get_element_by_id('mct-result')?.text_content()? == 'native capability conversion painted'
	assert document.get_element_by_id('mct-video')?.get_attribute_value('style').contains('color')
	assert runtime.evaluate_host(r'(()=>{try{mctAudio.canPlayType({[Symbol.toPrimitive](){mctResult.setAttribute("data-pending","conversion-threw");throw mctReason}});return false}catch(error){return error===mctReason}})()')! == 'true'
	assert document.get_element_by_id('mct-result')?.get_attribute('data-pending') == none
	assert runtime.evaluate_host('mctAudio.canPlayType("audio/webm")==="maybe"')! == 'true'
	assert document.get_element_by_id('mct-result')?.get_attribute('data-pending')? == 'conversion-threw'
	for media in [video, audio] {
		assert media.network_state() == .empty && media.ready_state() == .have_nothing
		assert media.error() == none && media.current_src() == '' && media.paused()
		assert media.event_count('loadstart') == 0 && media.event_count('play') == 0
	}
	assert media_can_play_type_owner_take_task(document) == none
	app.relayout(320, 240 + app.chrome_height())
	assert app.paint_commands.filter(it.kind == 'draw_text' && it.text == 'native capability conversion painted').len > 0
	assert app.js_messages == []
	media_can_play_type_owner_balance(runtime, document)
}

fn test_native_can_play_type_raw_load_callbacks_use_the_owner_scope_without_changing_load_state_or_fetches() {
	$if !darwin {
		return
	}
	body := r'const state=[networkState,readyState,currentSrc,currentTime,paused,duration,error];mctOrder.push(this.id+":"+event.type);mctChecks.push(arguments.length===1&&event===arguments[0]&&event.target===this&&event.currentTarget===this&&event.isTrusted&&!event.bubbles&&!event.cancelable&&window.event===event&&canPlayType===mctNative&&canPlayType("video/mp4")==="maybe"&&canPlayType("audio/webm")==="maybe"&&canPlayType("audio/mp4")===""&&canPlayType("video/mp4; codecs=unsupported")==="probably"&&canPlayType("application/octet-stream")===""&&networkState===state[0]&&readyState===state[1]&&currentSrc===state[2]&&currentTime===state[3]&&paused===state[4]&&Object.is(duration,state[5])&&error===state[6]&&error===null&&__mediaCanPlayTypeOwnerContext()&&(event.type==="loadstart"?networkState===2&&readyState===0&&currentSrc==="":networkState===1&&readyState>=1&&duration===mctExpectedDuration));document.getElementById("mct-result").textContent="native capability load callbacks painted";return false;'
	attribute := body.replace('"', '&quot;')
	markup := media_can_play_type_owner_markup.replace('<video id="mct-video">', '<video id="mct-video" onloadstart="${attribute}" onloadedmetadata="${attribute}">')
	mut app, mut document, mut runtime := media_can_play_type_owner_fixture(markup, r'
globalThis.mctVideo=document.getElementById("mct-video");globalThis.mctNative=HTMLMediaElement.prototype.canPlayType;globalThis.mctOrder=[];globalThis.mctChecks=[];globalThis.mctExpectedDuration=20;globalThis.canPlayType=function(){throw "global fake"};document.canPlayType=function(){throw "document fake"};globalThis.mctAudio=document.createElement("audio");mctAudio.id="mct-audio";mctAudio.setAttribute("onloadstart",mctVideo.getAttribute("onloadstart"));mctAudio.setAttribute("onloadedmetadata",mctVideo.getAttribute("onloadedmetadata"));document.body.appendChild(mctAudio);void mctAudio.paused;0
')!
	defer {
		runtime.close()
		document.finalize()
	}
	media_can_play_type_owner_context(mut runtime, document)!
	mut video := html.html_media_element_for_dom_element(document.get_element_by_id('mct-video')?)?
	mut audio := html.html_media_element_for_dom_element(document.get_element_by_id('mct-audio')?)?
	video_fetch := &MediaCanPlayTypeOwnerFetch{}
	audio_fetch := &MediaCanPlayTypeOwnerFetch{}
	for index, media in [video, audio] {
		state := if index == 0 { video_fetch } else { audio_fetch }
		mime_type := if index == 0 { 'video/mp4' } else { 'audio/webm' }
		duration := if index == 0 { 20.0 } else { 7.0 }
		source_path := if index == 0 { '/video.mp4' } else { '/audio.webm' }
		mut current := unsafe { &html.HTMLMediaElement(media) }
		current.set_source(source_path)
		current.set_fetch_hook(fn [state, media, mime_type, duration, source_path] (url dom.URL, offset u64) !html.MediaResourceResponse {
			mut saved := unsafe { &MediaCanPlayTypeOwnerFetch(state) }
			assert url.serialize() == 'https://media-can-play-type-owner.example.test${source_path}' && offset == 0
			assert media.event_count('loadstart') == saved.urls.len + 1
			saved.urls << url.serialize()
			return html.MediaResourceResponse{ mime_type: mime_type, duration: duration, buffered_end: 3 }
		})
	}
	// Compile the real raw slots through IDL before invoking the public loads.
	assert runtime.evaluate_host('typeof mctVideo.onloadstart==="function"&&typeof mctVideo.onloadedmetadata==="function"&&typeof mctAudio.onloadstart==="function"&&typeof mctAudio.onloadedmetadata==="function"&&mctOrder.length===0')! == 'true'
	assert runtime.evaluate_host('mctVideo.load();mctOrder.join(",")==="mct-video:loadstart"&&mctVideo.duration===20')! == 'true'
	media_can_play_type_owner_drain(document)
	assert runtime.evaluate_host('mctExpectedDuration=7;mctAudio.load();mctAudio.duration===7')! == 'true'
	media_can_play_type_owner_drain(document)
	assert video_fetch.urls == ['https://media-can-play-type-owner.example.test/video.mp4']
	assert audio_fetch.urls == ['https://media-can-play-type-owner.example.test/audio.webm']
	assert runtime.evaluate_host('mctOrder.join(",")==="mct-video:loadstart,mct-video:loadedmetadata,mct-audio:loadstart,mct-audio:loadedmetadata"&&mctChecks.length===4&&mctChecks.every(Boolean)&&mctVideo.canPlayType===mctNative&&mctAudio.canPlayType===mctNative&&window.event===undefined')! == 'true'
	for media in [video, audio] {
		assert media.error() == none && media.network_state() == .idle && media.paused()
		assert media.event_count('loadstart') == 1 && media.event_count('loadedmetadata') == 1
		assert media.event_count('play') == 0
	}
	app.poll_javascript_tasks()
	assert app.paint_commands.filter(it.kind == 'draw_text' && it.text == 'native capability load callbacks painted').len > 0
	assert app.js_messages == []
	media_can_play_type_owner_balance(runtime, document)
}
