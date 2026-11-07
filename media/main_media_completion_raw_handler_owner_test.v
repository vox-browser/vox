module main

import browserjs
import dom
import html
import json2
import page
import time

const media_completion_raw_owner_markup = '<!doctype html><style>
html,body{margin:0}#mcp-video{display:block;width:180px;height:60px}
#mcp-result{position:absolute;top:100px;left:0}
</style><form id="mcp-form"><video id="mcp-video"></video></form><div id="mcp-result">waiting</div>'

@[heap]
struct MediaCompletionRawOwnerObservation {
mut:
	events []&dom.Event
	targets []voidptr
}

fn media_completion_raw_owner_fixture(markup string, source string) !(&BrowserApp, &dom.Document, &browserjs.Runtime) {
	mut owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time(markup, dom.URL{
		value: 'https://media-completion-raw-owner.example.test/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	runtime := browserjs.Runtime.create()
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [source], runtime, mut messages)
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

fn media_completion_raw_owner_take_task(document &dom.Document) ?&html.Task {
	mut queue := html.main_thread_event_loop().task_queue()
	return queue.take_first_runnable_matching(fn [document] (task &html.Task) bool {
		owner := task.document() or { return false }
		return task.source() == .media_element && voidptr(owner) == voidptr(document)
	})
}

fn media_completion_raw_owner_drain(document &dom.Document) {
	mut count := 0
	for {
		task := media_completion_raw_owner_take_task(document) or { break }
		count++
		assert count < 100
		task.execute()
	}
}

fn media_completion_raw_owner_probe(mut runtime browserjs.Runtime, document &dom.Document) ! {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	handle := voidptr(&runtime)
	actual_true := runtime.evaluate_host_value('true')!
	runtime.define_value_host_function('__mediaCompletionRawOwnerContext', fn [settings, handle, actual_true] (_ voidptr, args []voidptr) !voidptr {
		owner := unsafe { &browserjs.Runtime(handle) }
		assert args.len == 0
		assert settings.realm().script_execution_depth > 0 && settings.realm().callback_execution_depth > 0
		assert owner.libjs_vm().has_running_execution_context()
		assert voidptr(html.current_principal_settings_object()) == voidptr(settings)
		assert voidptr(html.incumbent_settings_object()) == voidptr(settings)
		return actual_true
	})!
}

fn media_completion_raw_owner_dimensions_probe(mut runtime browserjs.Runtime, model &html.HTMLVideoElementModel, name string, width u32, height u32) ! {
	actual_true := runtime.evaluate_host_value('true')!
	runtime.define_value_host_function(name, fn [model, width, height, actual_true] (_ voidptr, args []voidptr) !voidptr {
		assert args.len == 0
		intrinsic := model.natural_media_size() or { panic('Native resize needs intrinsic dimensions') }
		natural := model.natural_element_size() or { panic('Native resize needs natural dimensions') }
		assert intrinsic.width == width && intrinsic.height == height
		assert natural == intrinsic && model.video_width() == width && model.video_height() == height
		return actual_true
	})!
}

fn media_completion_raw_owner_observe(element &dom.Element, observation &MediaCompletionRawOwnerObservation) {
	handle := voidptr(observation)
	callback := &dom.CallbackType{
		handle_event: fn [handle] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut saved := unsafe { &MediaCompletionRawOwnerObservation(handle) }
			assert event.type_name() in ['resize', 'ended']
			assert event.interface_ == .event && event.is_trusted()
			// Exact false cancels these native Events even with cancelable=false.
			assert !event.bubbles() && !event.cancelable() && event.default_prevented()
			saved.events << event
			saved.targets << voidptr(event.target() or { panic('Native completion event needs its owner') })
			return dom.js_undefined()
		}
	}
	for name in ['resize', 'ended'] {
		unsafe { &dom.EventTarget(element) }.add_event_listener_without_options(name, dom.IDLEventListener.create(callback))
	}
}

fn media_completion_raw_owner_event(mut runtime browserjs.Runtime, event &dom.Event, expression string) ! {
	wrapper := runtime.evaluate_host_value(expression)!
	assert voidptr(runtime.native_event(wrapper)!) == voidptr(event)
	assert runtime.javascript_event(event)! == wrapper
	assert event.is_trusted() && event.current_target() == none && event.event_phase() == 0
	assert runtime.evaluate_host('${expression}.currentTarget===null&&${expression}.eventPhase===Event.NONE&&window.event===undefined')! == 'true'
}

fn media_completion_raw_owner_balance(runtime &browserjs.Runtime, document &dom.Document, exceptions int) {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == exceptions
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
	assert runtime.libjs_vm().execution_context_stack().len == 0
	assert runtime.libjs_vm().interpreter_stack().depth() == 0
}

fn media_completion_raw_owner_seed(document &dom.Document, element &dom.Element) &html.HTMLMediaElement {
	mut media := html.html_media_element_for_dom_element(element) or { panic('Missing completion media owner') }
	media.set_ready_state(.have_metadata)
	media.set_duration(1)
	media_completion_raw_owner_drain(document)
	return media
}

fn media_completion_raw_owner_endpoint(mut media html.HTMLMediaElement) {
	// This is a controlled translated-model endpoint. V uses position==duration;
	// pinned upstream uses PlaybackManager's Ended state after consuming data.
	// No decoder, backend playback, pending promise, or policy parity is claimed.
	media.set_current_playback_position(1)
	media.set_official_playback_position(1)
	media.set_paused(false)
	assert media.has_ended_playback() && !media.ended()
}

fn media_completion_raw_owner_bridge(mut runtime browserjs.Runtime, model &html.HTMLVideoElementModel, media &html.HTMLMediaElement) ! {
	model_handle := voidptr(model)
	media_handle := voidptr(media)
	actual_true := runtime.evaluate_host_value('true')!
	runtime.define_value_host_function('__mediaCompletionRawQueueResize', fn [model_handle, actual_true] (_ voidptr, args []voidptr) !voidptr {
		assert args.len == 0
		mut current_model := unsafe { &html.HTMLVideoElementModel(model_handle) }
		current_model.set_video_dimensions(200, 100)
		return actual_true
	})!
	runtime.define_value_host_function('__mediaCompletionRawQueueEnd', fn [media_handle, actual_true] (_ voidptr, args []voidptr) !voidptr {
		assert args.len == 0
		mut current_media := unsafe { &html.HTMLMediaElement(media_handle) }
		current_media.reached_end_of_media_playback()
		return actual_true
	})!
}

fn test_media_raw_completion_parsed_created_scopes_native_resize_suppression_and_end_task_order() {
	$if !darwin { return }
	body := r'mcpRuns++;mcpOrder.push(this.id+":"+event.type);mcpScopes.push(scopeKey);delete this.scopeKey;mcpScopes.push(scopeKey);delete document.scopeKey;mcpScopes.push(scopeKey);document.scopeKey="document";this.scopeKey=this.id==="mcp-video"?"parsed element":"created element";mcpSaved.push(event);mcpChecks.push(arguments.length===1&&event===arguments[0]&&(this===mcpVideo||this===mcpAudio)&&event.target===this&&event.currentTarget===this&&event instanceof Event&&event.isTrusted&&!event.bubbles&&!event.cancelable&&window.event===event&&document===mcpDocument&&getElementById("mcp-result")===mcpResult&&ended===true&&readyState===1&&networkState===0&&duration===1&&currentTime===1&&paused===(event.type==="ended")&&__mediaCompletionRawOwnerContext()&&(event.type!=="resize"||__mediaCompletionRawDimensions320()));getElementById("mcp-result").textContent="raw native completion painted";this.style.color="rgb(0,128,0)";return false;'
	attribute_body := body.replace('"', '&quot;')
	markup := media_completion_raw_owner_markup.replace('<video id="mcp-video">',
		'<video id="mcp-video" onended="${attribute_body}" onresize="${attribute_body}">')
	mut app, mut document, mut runtime := media_completion_raw_owner_fixture(markup, r'
globalThis.mcpVideo=document.getElementById("mcp-video");globalThis.mcpDocument=document;globalThis.mcpResult=document.getElementById("mcp-result");globalThis.mcpForm=document.getElementById("mcp-form");
globalThis.mcpRuns=0;globalThis.mcpOrder=[];globalThis.mcpScopes=[];globalThis.mcpSaved=[];globalThis.mcpChecks=[];globalThis.scopeKey="global";
document.scopeKey="document";mcpForm.scopeKey="nearest form";mcpVideo.scopeKey="parsed element";mcpVideo.event={sentinel:true};document.event={sentinel:true};
globalThis.mcpAudio=document.createElement("audio");mcpAudio.id="mcp-audio";mcpAudio.setAttribute("onended",mcpVideo.getAttribute("onended"));document.body.appendChild(mcpAudio);mcpAudio.scopeKey="created element";void mcpAudio.paused;0
')!
	defer {
		runtime.close()
		document.finalize()
	}
	media_completion_raw_owner_probe(mut runtime, document)!
	video := document.get_element_by_id('mcp-video')?
	audio := document.get_element_by_id('mcp-audio')?
	native_video := unsafe { &dom.EventTarget(video) }
	native_audio := unsafe { &dom.EventTarget(audio) }
	for name in ['resize', 'ended'] {
		slot := native_video.data.event_handler(name) or { panic('Raw completion slot missing') }
		assert slot.value.kind == .string && slot.value.string_data == body
	}
	assert runtime.evaluate_host('globalThis.mcpVideoResize=mcpVideo.onresize;globalThis.mcpVideoEnd=mcpVideo.onended;globalThis.mcpAudioEnd=mcpAudio.onended;typeof mcpVideoResize==="function"&&typeof mcpVideoEnd==="function"&&typeof mcpAudioEnd==="function"&&mcpVideoResize!==mcpVideoEnd&&mcpVideoEnd!==mcpAudioEnd&&mcpVideoResize.name==="onresize"&&mcpVideoEnd.name==="onended"&&mcpAudioEnd.name==="onended"&&[mcpVideoResize,mcpVideoEnd,mcpAudioEnd].every(fn=>fn.length===1)&&mcpVideo.onresize===mcpVideoResize&&mcpVideo.onended===mcpVideoEnd&&mcpAudio.onended===mcpAudioEnd&&!Object.hasOwn(mcpVideo,"onended")&&!Object.hasOwn(mcpVideo,"onresize")&&mcpRuns===0')! == 'true'
	for name in ['resize', 'ended'] {
		callback := native_video.get_current_value_of_event_handler(name) or { panic('Cached completion callback missing') }
		assert callback.compiled_source_text_ == 'function on${name}(event) {\n${body}\n}'
		assert runtime.javascript_event_handler(native_video, name)! == runtime.evaluate_host_value('mcpVideo.on${name}')!
	}
	mut video_media := media_completion_raw_owner_seed(document, video)
	mut audio_media := media_completion_raw_owner_seed(document, audio)
	media_completion_raw_owner_endpoint(mut video_media)
	media_completion_raw_owner_endpoint(mut audio_media)
	assert runtime.evaluate_host('!mcpVideo.ended&&!mcpAudio.ended&&mcpRuns===0')! == 'true'
	mut loop := html.main_thread_event_loop()
	loop.perform_a_microtask_checkpoint()
	assert runtime.evaluate_host('!mcpVideo.ended&&!mcpAudio.ended&&mcpRuns===0')! == 'true'
	assert media_completion_raw_owner_take_task(document) == none
	loop.process()
	assert runtime.evaluate_host('mcpVideo.ended&&mcpAudio.ended&&mcpRuns===0')! == 'true'
	mut model := html.html_video_element_model_for_dom_element(unsafe { &dom.HTMLVideoElement(video) })
	media_completion_raw_owner_dimensions_probe(mut runtime, model, '__mediaCompletionRawDimensions320', 320, 180)!
	observation := &MediaCompletionRawOwnerObservation{}
	media_completion_raw_owner_observe(video, observation)
	media_completion_raw_owner_observe(audio, observation)
	assert runtime.evaluate_host(r'for(const target of [mcpVideo,mcpAudio])for(const name of ["timeupdate","pause"])target.addEventListener(name,function(event){mcpOrder.push(this.id+":"+event.type);mcpChecks.push(this===event.target&&this===event.currentTarget&&event.isTrusted&&!event.bubbles&&!event.cancelable&&window.event===event&&this.ended&&this.paused===(name==="pause")&&this.currentTime===1&&__mediaCompletionRawOwnerContext())});mcpOrder.length===0')! == 'true'
	model.set_video_dimensions(320, 180)
	model.set_video_dimensions(320, 180)
	model.set_intrinsic_video_dimensions(none)
	model.set_intrinsic_video_dimensions(none)
	model.set_video_dimensions(320, 180)
	video_media.reached_end_of_media_playback()
	audio_media.reached_end_of_media_playback()
	assert runtime.evaluate_host('mcpRuns===0&&mcpOrder.length===0&&!mcpVideo.paused&&!mcpAudio.paused')! == 'true'
	// Two changed nonempty dimensions produce two tasks; equal and none do not.
	for _ in 0 .. 2 {
		(media_completion_raw_owner_take_task(document) or { panic('Missing native resize task') }).execute()
	}
	assert video_media.event_count('resize') == 2 && audio_media.event_count('resize') == 0
	assert runtime.evaluate_host('mcpOrder.join(",")==="mcp-video:resize,mcp-video:resize"&&mcpRuns===2')! == 'true'
	(media_completion_raw_owner_take_task(document) or { panic('Missing native video end task') }).execute()
	assert runtime.evaluate_host('mcpOrder.join(",")==="mcp-video:resize,mcp-video:resize,mcp-video:timeupdate,mcp-video:pause,mcp-video:ended"&&mcpVideo.paused&&!mcpAudio.paused')! == 'true'
	(media_completion_raw_owner_take_task(document) or { panic('Missing native audio end task') }).execute()
	assert media_completion_raw_owner_take_task(document) == none
	assert runtime.evaluate_host('mcpOrder.join(",")==="mcp-video:resize,mcp-video:resize,mcp-video:timeupdate,mcp-video:pause,mcp-video:ended,mcp-audio:timeupdate,mcp-audio:pause,mcp-audio:ended"&&mcpRuns===4&&mcpChecks.length===8&&mcpChecks.every(Boolean)&&mcpScopes.join(",")==="parsed element,document,global,parsed element,document,global,parsed element,document,global,created element,document,global"&&mcpSaved.length===4&&mcpSaved.every(event=>event.defaultPrevented)&&mcpVideo.onresize===mcpVideoResize&&mcpVideo.onended===mcpVideoEnd&&mcpAudio.onended===mcpAudioEnd&&mcpForm.scopeKey==="nearest form"&&window.event===undefined')! == 'true'
	assert observation.events.len == 4 && observation.targets == [voidptr(video), voidptr(video), voidptr(video), voidptr(audio)]
	for index, event in observation.events {
		media_completion_raw_owner_event(mut runtime, event, 'mcpSaved[${index}]')!
	}
	for media in [video_media, audio_media] {
		assert media.event_count('timeupdate') == 1 && media.event_count('pause') == 1 && media.event_count('ended') == 1
	}
	app.poll_javascript_tasks()
	assert document.get_element_by_id('mcp-result')?.text_content()? == 'raw native completion painted'
	assert video.get_attribute_value('style').contains('color') && audio.get_attribute_value('style').contains('color')
	assert app.paint_commands.filter(it.kind == 'draw_text' && it.text == 'raw native completion painted').len > 0
	assert app.js_messages == []
	media_completion_raw_owner_balance(runtime, document, 0)
}

fn test_media_raw_completion_equal_attributes_latest_prequeued_handlers_reentrant_resize_and_removal() {
	$if !darwin { return }
	body := r'mcpOrder.push("original-"+event.type);mcpSaved.push(event);return false;'
	attribute_body := body.replace('"', '&quot;')
	markup := media_completion_raw_owner_markup.replace('<video id="mcp-video">',
		'<video id="mcp-video" onended="${attribute_body}" onresize="${attribute_body}">')
	mut app, mut document, mut runtime := media_completion_raw_owner_fixture(markup, r'
globalThis.mcpVideo=document.getElementById("mcp-video");globalThis.mcpOrder=[];globalThis.mcpSaved=[];globalThis.mcpChecks=[];globalThis.mcpSource=mcpVideo.getAttribute("onended");globalThis.mcpFirstResize=mcpVideo.onresize;globalThis.mcpFirstEnd=mcpVideo.onended;
globalThis.mcpResizeIDL=function(event){mcpOrder.push("idl-resize");mcpSaved.push(event);mcpChecks.push(this===mcpVideo&&event.type==="resize"&&event.isTrusted&&event.target===this&&event.currentTarget===this&&window.event===event&&this.readyState===1&&this.currentTime===1&&this.ended&&this.paused&&__mediaCompletionRawOwnerContext());return false};
globalThis.mcpEndIDL=function(event){mcpOrder.push("idl-ended");mcpSaved.push(event);mcpChecks.push(this===mcpVideo&&event.type==="ended"&&event.isTrusted&&event.target===this&&event.currentTarget===this&&window.event===event&&this.readyState===1&&this.currentTime===1&&this.ended&&this.paused&&__mediaCompletionRawOwnerContext());return false};0
')!
	defer {
		runtime.close()
		document.finalize()
	}
	media_completion_raw_owner_probe(mut runtime, document)!
	video := document.get_element_by_id('mcp-video')?
	native_video := unsafe { &dom.EventTarget(video) }
	resize_slot := native_video.data.event_handler('resize') or { panic('Resize slot missing') }
	end_slot := native_video.data.event_handler('ended') or { panic('Ended slot missing') }
	resize_listener := resize_slot.listener or { panic('Resize listener missing') }
	end_listener := end_slot.listener or { panic('Ended listener missing') }
	first_resize := native_video.get_current_value_of_event_handler('resize') or { panic('First resize callback missing') }
	first_end := native_video.get_current_value_of_event_handler('ended') or { panic('First ended callback missing') }
	assert runtime.evaluate_host('mcpVideo.onresize=mcpResizeIDL;mcpVideo.onended=mcpEndIDL;mcpVideo.setAttribute("onresize",mcpSource);mcpVideo.setAttribute("onended",mcpSource);globalThis.mcpSecondResize=mcpVideo.onresize;globalThis.mcpSecondEnd=mcpVideo.onended;mcpSecondResize!==mcpFirstResize&&mcpSecondResize!==mcpResizeIDL&&mcpSecondEnd!==mcpFirstEnd&&mcpSecondEnd!==mcpEndIDL&&mcpVideo.onresize===mcpSecondResize&&mcpVideo.onended===mcpSecondEnd&&mcpOrder.length===0')! == 'true'
	second_resize := native_video.get_current_value_of_event_handler('resize') or { panic('Second resize callback missing') }
	second_end := native_video.get_current_value_of_event_handler('ended') or { panic('Second ended callback missing') }
	assert voidptr(second_resize) != voidptr(first_resize) && second_resize.compiled_source_text_ == first_resize.compiled_source_text_
	assert voidptr(second_end) != voidptr(first_end) && second_end.compiled_source_text_ == first_end.compiled_source_text_
	assert voidptr(native_video.data.event_handler('resize') or { panic('Preserved resize slot missing') }) == voidptr(resize_slot)
	assert voidptr(native_video.data.event_handler('ended') or { panic('Preserved ended slot missing') }) == voidptr(end_slot)
	assert voidptr(resize_slot.listener or { panic('Preserved resize listener missing') }) == voidptr(resize_listener)
	assert voidptr(end_slot.listener or { panic('Preserved ended listener missing') }) == voidptr(end_listener)
	mut media := media_completion_raw_owner_seed(document, video)
	media_completion_raw_owner_endpoint(mut media)
	mut loop := html.main_thread_event_loop()
	loop.process()
	assert media.ended()
	mut model := html.html_video_element_model_for_dom_element(unsafe { &dom.HTMLVideoElement(video) })
	media_completion_raw_owner_dimensions_probe(mut runtime, model, '__mediaCompletionRawDimensions100', 100, 50)!
	media_completion_raw_owner_dimensions_probe(mut runtime, model, '__mediaCompletionRawDimensions200', 200, 100)!
	media_completion_raw_owner_bridge(mut runtime, model, media)!
	end_body := r'mcpOrder.push("replacement-ended");mcpSaved.push(event);mcpChecks.push(this===mcpVideo&&event.isTrusted&&event.target===this&&event.currentTarget===this&&window.event===event&&this.ended&&this.paused&&this.currentTime===1&&__mediaCompletionRawOwnerContext()&&__mediaCompletionRawDimensions200());this.onended=mcpEndIDL;__mediaCompletionRawQueueEnd();return false;'
	resize_body := r'mcpOrder.push("replacement-resize");mcpSaved.push(event);mcpChecks.push(this===mcpVideo&&event.isTrusted&&event.target===this&&event.currentTarget===this&&window.event===event&&this.ended&&!this.paused&&this.currentTime===1&&__mediaCompletionRawOwnerContext()&&__mediaCompletionRawDimensions100());this.setAttribute("onended",mcpNextEnd);void this.paused;__mediaCompletionRawQueueResize();this.onresize=mcpResizeIDL;document.getElementById("mcp-result").textContent="reentrant native completion painted";return false;'
	superseded_resize_body := 'mcpOrder.push("superseded-resize");'
	superseded_end_body := 'mcpOrder.push("superseded-ended");'
	model.set_video_dimensions(100, 50)
	media.reached_end_of_media_playback()
	assert runtime.evaluate_host('globalThis.mcpNextEnd=${json2.encode(end_body)};mcpVideo.setAttribute("onresize",${json2.encode(superseded_resize_body)});mcpVideo.setAttribute("onended",${json2.encode(superseded_end_body)});mcpVideo.setAttribute("onresize",${json2.encode(resize_body)});mcpVideo.paused===false&&mcpOrder.length===0')! == 'true'
	assert resize_slot.value.kind == .string && resize_slot.value.string_data == resize_body
	(media_completion_raw_owner_take_task(document) or { panic('Missing prequeued resize task') }).execute()
	assert runtime.evaluate_host('mcpOrder.join(",")==="replacement-resize"&&mcpVideo.onresize===mcpResizeIDL&&mcpSaved.length===1')! == 'true'
	assert end_slot.value.kind == .string && end_slot.value.string_data == end_body
	(media_completion_raw_owner_take_task(document) or { panic('Missing prequeued end task') }).execute()
	assert runtime.evaluate_host('mcpOrder.join(",")==="replacement-resize,replacement-ended"&&mcpVideo.onended===mcpEndIDL&&mcpVideo.paused')! == 'true'
	(media_completion_raw_owner_take_task(document) or { panic('Missing reentrant native resize task') }).execute()
	(media_completion_raw_owner_take_task(document) or { panic('Missing reentrant native end task') }).execute()
	assert media_completion_raw_owner_take_task(document) == none
	assert runtime.evaluate_host('mcpOrder.join(",")==="replacement-resize,replacement-ended,idl-resize,idl-ended"&&mcpSaved.length===4&&mcpSaved.every(event=>event.isTrusted&&event.defaultPrevented)&&mcpChecks.length===4&&mcpChecks.every(Boolean)&&window.event===undefined')! == 'true'
	assert voidptr(resize_slot.listener or { panic('Reentrant resize listener missing') }) == voidptr(resize_listener)
	assert voidptr(end_slot.listener or { panic('Reentrant ended listener missing') }) == voidptr(end_listener)
	assert media.event_count('resize') == 2 && media.event_count('ended') == 2 && media.event_count('timeupdate') == 2 && media.event_count('pause') == 1
	model.set_video_dimensions(300, 150)
	media.reached_end_of_media_playback()
	assert runtime.evaluate_host('mcpVideo.removeAttribute("onresize");mcpVideo.removeAttribute("onended");mcpVideo.onresize===null&&mcpVideo.onended===null&&mcpOrder.length===4')! == 'true'
	assert !native_video.data.has_event_handler('resize') && !native_video.data.has_event_handler('ended')
	assert video.get_attribute('onresize') == none && video.get_attribute('onended') == none
	media_completion_raw_owner_drain(document)
	assert runtime.evaluate_host('mcpOrder.length===4&&mcpSaved.length===4')! == 'true'
	assert runtime.evaluate_host('mcpVideo.onresize=mcpResizeIDL;mcpVideo.onended=mcpEndIDL;mcpVideo.removeAttribute("onresize");mcpVideo.removeAttribute("onended");mcpVideo.onresize===mcpResizeIDL&&mcpVideo.onended===mcpEndIDL')! == 'true'
	model.set_video_dimensions(400, 200)
	media.reached_end_of_media_playback()
	media_completion_raw_owner_drain(document)
	assert runtime.evaluate_host('mcpOrder.join(",")==="replacement-resize,replacement-ended,idl-resize,idl-ended,idl-resize,idl-ended"&&mcpSaved.length===6&&mcpSaved.every(event=>event.isTrusted&&event.defaultPrevented)&&mcpChecks.length===6&&mcpChecks.every(Boolean)&&window.event===undefined')! == 'true'
	assert native_video.event_listener_list().len == 2
	assert media.event_count('resize') == 4 && media.event_count('ended') == 4 && media.event_count('timeupdate') == 4 && media.event_count('pause') == 1
	for index in 0 .. 6 {
		event := runtime.native_event(runtime.evaluate_host_value('mcpSaved[${index}]')!)!
		media_completion_raw_owner_event(mut runtime, event, 'mcpSaved[${index}]')!
	}
	app.poll_javascript_tasks()
	assert document.get_element_by_id('mcp-result')?.text_content()? == 'reentrant native completion painted'
	assert app.paint_commands.filter(it.kind == 'draw_text' && it.text == 'reentrant native completion painted').len > 0
	assert app.js_messages == []
	media_completion_raw_owner_balance(runtime, document, 0)
}

fn test_media_raw_completion_scripting_gate_strict_ended_exception_later_listener_and_resize_paint() {
	$if !darwin { return }
	mut app, mut document, mut runtime := media_completion_raw_owner_fixture(media_completion_raw_owner_markup, r'
globalThis.mcpVideo=document.getElementById("mcp-video");globalThis.mcpOrder=[];globalThis.mcpSaved=[];globalThis.mcpChecks=[];globalThis.mcpReason={original:true};mcpVideo.event={sentinel:true};document.event={sentinel:true};0
')!
	defer {
		runtime.close()
		document.finalize()
	}
	media_completion_raw_owner_probe(mut runtime, document)!
	video := document.get_element_by_id('mcp-video')?
	native_video := unsafe { &dom.EventTarget(video) }
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut media := media_completion_raw_owner_seed(document, video)
	media_completion_raw_owner_endpoint(mut media)
	mut loop := html.main_thread_event_loop()
	loop.process()
	assert media.ended()
	mut model := html.html_video_element_model_for_dom_element(unsafe { &dom.HTMLVideoElement(video) })
	media_completion_raw_owner_dimensions_probe(mut runtime, model, '__mediaCompletionRawDimensions200', 200, 100)!
	end_body := r'"use strict";mcpOrder.push("strict-ended");mcpSaved.push(event);mcpChecks.push(arguments.length===1&&event===arguments[0]&&this===mcpVideo&&event.target===this&&event.currentTarget===this&&event instanceof Event&&event.isTrusted&&!event.bubbles&&!event.cancelable&&window.event===event&&this.ended&&this.paused&&this.readyState===1&&this.currentTime===1&&this.duration===1&&__mediaCompletionRawOwnerContext());try{void arguments.callee;mcpChecks.push(false)}catch(error){mcpChecks.push(error instanceof TypeError)}this.onended=null;globalThis.mcpLiveName=onended;throw mcpReason;'
	resize_body := r'mcpOrder.push("raw-resize");mcpSaved.push(event);mcpChecks.push(this===mcpVideo&&event.isTrusted&&event.target===this&&event.currentTarget===this&&window.event===event&&this.ended&&this.paused&&this.readyState===1&&this.currentTime===1&&__mediaCompletionRawOwnerContext()&&__mediaCompletionRawDimensions200());document.getElementById("mcp-result").textContent="native resize after throwing ended";return false;'
	assert runtime.evaluate_host('mcpVideo.setAttribute("onended",${json2.encode(end_body)});mcpVideo.setAttribute("onresize",${json2.encode(resize_body)});mcpVideo.paused===false')! == 'true'
	end_slot := native_video.data.event_handler('ended') or { panic('Strict ended slot missing') }
	resize_slot := native_video.data.event_handler('resize') or { panic('Gated resize slot missing') }
	mut owner := app.page_model
	owner.set_is_scripting_enabled(false)
	model.set_video_dimensions(100, 50)
	media.reached_end_of_media_playback()
	assert runtime.evaluate_host('mcpVideo.onended===null&&mcpVideo.onresize===null&&mcpOrder.length===0')! == 'true'
	media_completion_raw_owner_drain(document)
	assert end_slot.value.kind == .string && end_slot.value.string_data == end_body
	assert resize_slot.value.kind == .string && resize_slot.value.string_data == resize_body
	assert media.event_count('resize') == 1 && media.event_count('ended') == 1 && media.event_count('pause') == 1 && media.paused()
	assert runtime.evaluate_host('mcpOrder.length===0&&mcpSaved.length===0&&mcpChecks.length===0')! == 'true'
	media_completion_raw_owner_balance(runtime, document, 0)
	owner.set_is_scripting_enabled(true)
	assert runtime.evaluate_host(r'
globalThis.mcpStrict=mcpVideo.onended;globalThis.mcpResize=mcpVideo.onresize;
mcpVideo.addEventListener("ended",function(event){mcpOrder.push("later-ended");globalThis.mcpLater=this===mcpVideo&&event.currentTarget===this&&event.isTrusted&&!event.defaultPrevented&&window.event===event&&this.ended&&this.paused;document.getElementById("mcp-result").textContent="later native ended listener"});typeof mcpStrict==="function"&&mcpStrict.name==="onended"&&mcpStrict.length===1&&mcpVideo.onended===mcpStrict&&typeof mcpResize==="function"&&mcpResize.name==="onresize"&&mcpVideo.onresize===mcpResize&&mcpOrder.length===0
')! == 'true'
	strict_callback := native_video.get_current_value_of_event_handler('ended') or { panic('Strict ended callback missing') }
	assert strict_callback.compiled_source_text_ == 'function onended(event) {\n${end_body}\n}'
	assert runtime.javascript_event_handler(native_video, 'ended')! == runtime.evaluate_host_value('mcpStrict')!
	media.reached_end_of_media_playback()
	model.set_video_dimensions(200, 100)
	(media_completion_raw_owner_take_task(document) or { panic('Missing strict native end task') }).execute()
	assert runtime.evaluate_host('mcpOrder.join(",")==="strict-ended,later-ended"&&mcpLiveName===null&&mcpVideo.onended===null&&mcpLater&&mcpChecks.length===2&&mcpChecks.every(Boolean)&&mcpSaved.length===1&&!mcpSaved[0].defaultPrevented&&window.event===undefined')! == 'true'
	(media_completion_raw_owner_take_task(document) or { panic('Missing subsequent native resize task') }).execute()
	assert media_completion_raw_owner_take_task(document) == none
	assert runtime.evaluate_host('mcpOrder.join(",")==="strict-ended,later-ended,raw-resize"&&mcpVideo.onresize===mcpResize&&mcpChecks.length===3&&mcpChecks.every(Boolean)&&mcpSaved.length===2&&!mcpSaved[0].defaultPrevented&&mcpSaved[1].defaultPrevented&&window.event===undefined')! == 'true'
	assert !native_video.data.has_event_handler('ended') && native_video.data.has_event_handler('resize')
	assert video.get_attribute_value('onended') == end_body && video.get_attribute_value('onresize') == resize_body
	assert settings.realm().reported_exceptions.len == 1
	reported := settings.realm().reported_exceptions[0].value.as_webidl_value()!
	assert runtime.actual_webidl_value(reported)! == runtime.evaluate_host_value('mcpReason')!
	assert media.event_count('resize') == 2 && media.event_count('ended') == 2 && media.event_count('timeupdate') == 2 && media.event_count('pause') == 1
	for index in 0 .. 2 {
		event := runtime.native_event(runtime.evaluate_host_value('mcpSaved[${index}]')!)!
		media_completion_raw_owner_event(mut runtime, event, 'mcpSaved[${index}]')!
	}
	app.poll_javascript_tasks()
	assert document.get_element_by_id('mcp-result')?.text_content()? == 'native resize after throwing ended'
	assert app.paint_commands.filter(it.kind == 'draw_text' && it.text == 'native resize after throwing ended').len > 0
	assert app.js_messages == []
	media_completion_raw_owner_balance(runtime, document, 1)
}
