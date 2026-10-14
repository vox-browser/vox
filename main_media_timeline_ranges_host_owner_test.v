module main

import browserjs
import dom
import html
import json2
import page
import time

const media_timeline_ranges_owner_markup = '<!doctype html><style>html,body{margin:0}#mtr-video{display:block;width:180px;height:60px}#mtr-result{position:absolute;top:100px;left:0}</style><video id="mtr-video"></video><div id="mtr-result">waiting</div>'

fn media_timeline_ranges_owner_fixture(markup string, source string) !(&BrowserApp, &dom.Document, &browserjs.Runtime) {
	mut owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time(markup, dom.URL{
		value: 'https://media-timeline-ranges-owner.example.test/'
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

fn media_timeline_ranges_owner_take_task(document &dom.Document) ?&html.Task {
	mut queue := html.main_thread_event_loop().task_queue()
	return queue.take_first_runnable_matching(fn [document] (task &html.Task) bool {
		owner := task.document() or { return false }
		return task.source() == .media_element && voidptr(owner) == voidptr(document)
	})
}

fn media_timeline_ranges_owner_drain(document &dom.Document) {
	mut count := 0
	for {
		task := media_timeline_ranges_owner_take_task(document) or { break }
		count++
		assert count < 100
		task.execute()
	}
}

fn media_timeline_ranges_owner_context(mut runtime browserjs.Runtime, document &dom.Document) ! {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	handle := voidptr(&runtime)
	actual_true := runtime.evaluate_host_value('true')!
	runtime.define_value_host_function('__mediaTimelineRangesOwnerContext', fn [settings, handle, actual_true] (_ voidptr, args []voidptr) !voidptr {
		owner := unsafe { &browserjs.Runtime(handle) }
		assert args.len == 0
		assert settings.realm().script_execution_depth > 0 && settings.realm().callback_execution_depth > 0
		assert owner.libjs_vm().has_running_execution_context()
		assert voidptr(html.current_principal_settings_object()) == voidptr(settings)
		assert voidptr(html.incumbent_settings_object()) == voidptr(settings)
		return actual_true
	})!
}

fn media_timeline_ranges_owner_balance(runtime &browserjs.Runtime, document &dom.Document) {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
	assert runtime.libjs_vm().execution_context_stack().len == 0
	assert runtime.libjs_vm().interpreter_stack().depth() == 0
}

fn test_native_seekable_snapshots_follow_real_parsed_created_loads_and_keep_old_objects_after_reset() {
	$if !darwin {
		return
	}
	body := r'const range=this.seekable;mtrSnapshots.push(range);mtrOrder.push(this.id+":"+event.type);mtrChecks.push(arguments.length===1&&event===arguments[0]&&event.target===this&&event.currentTarget===this&&event.isTrusted&&!event.bubbles&&!event.cancelable&&window.event===event&&range instanceof TimeRanges&&range!==this.seekable&&this.played instanceof TimeRanges&&played.length===0&&__mediaTimelineRangesOwnerContext()&&(event.type==="loadstart"?range.length===0:range.length===1&&range.start(0)===0&&range.end(0)===mtrExpectedEnd));return false;'
	attribute := body.replace('"', '&quot;')
	markup := media_timeline_ranges_owner_markup.replace('<video id="mtr-video">', '<video id="mtr-video" onloadstart="${attribute}" onloadedmetadata="${attribute}">')
	mut app, mut document, mut runtime := media_timeline_ranges_owner_fixture(markup, r'
globalThis.mtrVideo=document.getElementById("mtr-video");globalThis.mtrOrder=[];globalThis.mtrChecks=[];globalThis.mtrSnapshots=[];globalThis.mtrExpectedEnd=10;globalThis.played={length:99};document.played={length:99};
globalThis.mtrAudio=document.createElement("audio");mtrAudio.id="mtr-audio";mtrAudio.setAttribute("onloadstart",mtrVideo.getAttribute("onloadstart"));mtrAudio.setAttribute("onloadedmetadata",mtrVideo.getAttribute("onloadedmetadata"));document.body.appendChild(mtrAudio);void mtrAudio.paused;0
')!
	defer {
		runtime.close()
		document.finalize()
	}
	media_timeline_ranges_owner_context(mut runtime, document)!
	mut video := html.html_media_element_for_dom_element(document.get_element_by_id('mtr-video')?)?
	mut audio := html.html_media_element_for_dom_element(document.get_element_by_id('mtr-audio')?)?
	assert runtime.evaluate_host('globalThis.mtrEmptySeek=mtrVideo.seekable;globalThis.mtrEmptyPlayed=mtrVideo.played;mtrEmptySeek instanceof TimeRanges&&mtrEmptyPlayed instanceof TimeRanges&&mtrEmptySeek.length===0&&mtrEmptyPlayed.length===0&&mtrEmptySeek!==mtrVideo.seekable&&mtrEmptyPlayed!==mtrVideo.played&&typeof mtrVideo.onloadstart==="function"&&typeof mtrAudio.onloadstart==="function"&&typeof mtrVideo.onloadedmetadata==="function"&&typeof mtrAudio.onloadedmetadata==="function"')! == 'true'
	video.set_source('/video-first.mp4')
	video.set_fetch_hook(fn (url dom.URL, offset u64) !html.MediaResourceResponse {
		assert offset == 0
		if url.serialize().ends_with('/video-first.mp4') {
			return html.MediaResourceResponse{ mime_type: 'video/mp4', duration: 10, buffered_end: 4 }
		}
		assert url.serialize().ends_with('/video-second.mp4')
		return html.MediaResourceResponse{ mime_type: 'video/mp4', duration: 20, buffered_end: 6 }
	})
	audio.set_source('/audio-first.webm')
	audio.set_fetch_hook(fn (url dom.URL, offset u64) !html.MediaResourceResponse {
		assert url.serialize().ends_with('/audio-first.webm') && offset == 0
		return html.MediaResourceResponse{ mime_type: 'audio/webm', duration: 7, buffered_end: 3 }
	})
	// A controlled response populates the actual V ranges. No ranges are
	// fabricated in JS, and native loadstart still runs before that fetch.
	assert runtime.evaluate_host('mtrVideo.load();mtrOrder.join(",")==="mtr-video:loadstart"&&mtrVideo.seekable.length===1&&mtrVideo.seekable.start(0)===0&&mtrVideo.seekable.end(0)===10&&mtrVideo.buffered.end(0)===4')! == 'true'
	media_timeline_ranges_owner_drain(document)
	assert runtime.evaluate_host('globalThis.mtrFirstVideo=mtrVideo.seekable;mtrExpectedEnd=7;mtrAudio.load();mtrAudio.seekable.end(0)===7&&mtrAudio.buffered.end(0)===3')! == 'true'
	media_timeline_ranges_owner_drain(document)
	assert runtime.evaluate_host('globalThis.mtrFirstAudio=mtrAudio.seekable;mtrOrder.join(",")==="mtr-video:loadstart,mtr-video:loadedmetadata,mtr-audio:loadstart,mtr-audio:loadedmetadata"&&mtrChecks.length===4&&mtrChecks.every(Boolean)&&mtrSnapshots[0].length===0&&mtrSnapshots[1].end(0)===10&&mtrSnapshots[2].length===0&&mtrSnapshots[3].end(0)===7&&mtrFirstVideo!==mtrVideo.seekable&&mtrFirstAudio!==mtrAudio.seekable&&mtrEmptySeek.length===0&&mtrEmptyPlayed.length===0')! == 'true'
	video.set_source('/video-second.mp4')
	assert runtime.evaluate_host('mtrExpectedEnd=20;mtrVideo.load();mtrVideo.seekable.end(0)===20&&mtrFirstVideo.end(0)===10&&mtrFirstAudio.end(0)===7')! == 'true'
	media_timeline_ranges_owner_drain(document)
	assert runtime.evaluate_host('globalThis.mtrSecondVideo=mtrVideo.seekable;mtrChecks.length===6&&mtrChecks.every(Boolean)&&mtrSnapshots[4].length===0&&mtrSnapshots[5].end(0)===20&&mtrFirstVideo.end(0)===10&&mtrFirstAudio.end(0)===7')! == 'true'
	video.set_source(none)
	assert runtime.evaluate_host(r'mtrVideo.addEventListener("emptied",function(event){mtrOrder.push("reset:emptied");mtrChecks.push(this===mtrVideo&&event.target===this&&event.currentTarget===this&&event.isTrusted&&this.seekable.length===0&&this.played.length===0&&mtrFirstVideo.end(0)===10&&mtrSecondVideo.end(0)===20&&__mediaTimelineRangesOwnerContext());document.getElementById("mtr-result").textContent="native timeline snapshots painted"});mtrVideo.load();mtrVideo.seekable.length===0&&mtrVideo.played.length===0&&mtrSecondVideo.end(0)===20')! == 'true'
	media_timeline_ranges_owner_drain(document)
	assert runtime.evaluate_host('mtrChecks.length===7&&mtrChecks.every(Boolean)&&mtrOrder[mtrOrder.length-1]==="reset:emptied"&&mtrVideo.seekable!==mtrVideo.seekable&&mtrAudio.seekable.end(0)===7&&mtrEmptySeek.length===0&&mtrEmptyPlayed.length===0&&window.event===undefined')! == 'true'
	actual := runtime.native_time_ranges(runtime.evaluate_host_value('mtrFirstVideo')!)!
	assert actual.length() == 1 && actual.start(0)! == 0 && actual.end(0)! == 10
	app.poll_javascript_tasks()
	assert app.paint_commands.filter(it.kind == 'draw_text' && it.text == 'native timeline snapshots painted').len > 0
	assert app.js_messages == []
	media_timeline_ranges_owner_balance(runtime, document)
}

fn test_native_played_snapshots_use_real_play_pause_tasks_and_remain_static_after_load() {
	$if !darwin {
		return
	}
	mut policy := html.AutoplaySettings.the()
	previous_policy := policy.policy()
	previous_allowlist := policy.allowlist().map(it.serialize())
	defer { policy.set_policy(previous_policy, previous_allowlist) }
	policy.set_policy(.allow_audio_and_video, [])
	mut app, mut document, mut runtime := media_timeline_ranges_owner_fixture(media_timeline_ranges_owner_markup, r'
globalThis.mtrVideo=document.getElementById("mtr-video");globalThis.mtrAudio=document.createElement("audio");mtrAudio.id="mtr-audio";document.body.appendChild(mtrAudio);void mtrAudio.paused;globalThis.mtrOrder=[];globalThis.mtrChecks=[];globalThis.mtrPlayed=[];globalThis.mtrEmpty={};globalThis.mtrStart=0;globalThis.mtrEnd=0;0
')!
	defer {
		runtime.close()
		document.finalize()
	}
	media_timeline_ranges_owner_context(mut runtime, document)!
	mut video := html.html_media_element_for_dom_element(document.get_element_by_id('mtr-video')?)?
	mut audio := html.html_media_element_for_dom_element(document.get_element_by_id('mtr-audio')?)?
	body := r'const range=this.played;mtrPlayed.push(range);mtrOrder.push(this.id+":"+event.type);mtrChecks.push(arguments.length===1&&event===arguments[0]&&event.target===this&&event.currentTarget===this&&event.isTrusted&&!event.bubbles&&!event.cancelable&&window.event===event&&this.paused&&range instanceof TimeRanges&&range!==this.played&&played.length===1&&range.length===1&&range.start(0)===mtrStart&&range.end(0)===mtrEnd&&this.seekable.length===1&&this.seekable.end(0)===20&&mtrEmpty[this.id].length===0&&__mediaTimelineRangesOwnerContext());document.getElementById("mtr-result").textContent="native played ranges painted";return false;'
	for index, media in [video, audio] {
		alias := if index == 0 { 'mtrVideo' } else { 'mtrAudio' }
		mut current := unsafe { &html.HTMLMediaElement(media) }
		source_path := if index == 0 { '/played-video.mp4' } else { '/played-audio.webm' }
		current.set_source(source_path)
		mime_type := if index == 0 { 'video/mp4' } else { 'audio/webm' }
		current.set_fetch_hook(fn [mime_type] (_ dom.URL, offset u64) !html.MediaResourceResponse {
			assert offset == 0
			return html.MediaResourceResponse{ mime_type: mime_type, duration: 20, buffered_end: 20 }
		})
		assert runtime.evaluate_host('${alias}.load();${alias}.seekable.length===1&&${alias}.seekable.end(0)===20&&${alias}.played.length===0')! == 'true'
		media_timeline_ranges_owner_drain(document)
		start := if index == 0 { 2.0 } else { 1.0 }
		end := if index == 0 { 6.0 } else { 4.0 }
		current.set_current_playback_position(start)
		current.set_official_playback_position(start)
		media_timeline_ranges_owner_drain(document)
		assert runtime.evaluate_host('mtrEmpty[${alias}.id]=${alias}.played;${alias}.play() instanceof Promise&&!${alias}.paused&&${alias}.played.length===0')! == 'true'
		media_timeline_ranges_owner_drain(document)
		// Preserve the existing translated pause-time range recording. Pinned
		// upstream played() still has a FIXME and returns an empty fresh object.
		// These controlled positions do not claim decoder/normalization parity.
		current.set_current_playback_position(end)
		current.set_official_playback_position(end)
		// Drain periodic readiness/timeupdate work before installing callbacks;
		// the observations below belong to pause's compound native task only.
		media_timeline_ranges_owner_drain(document)
		assert runtime.evaluate_host('mtrStart=${start};mtrEnd=${end};${alias}.setAttribute("ontimeupdate",${json2.encode(body)});${alias}.setAttribute("onpause",${json2.encode(body)});typeof ${alias}.ontimeupdate==="function"&&typeof ${alias}.onpause==="function"')! == 'true'
		before := index * 2
		assert runtime.evaluate_host('${alias}.pause()===undefined&&${alias}.paused&&mtrOrder.length===${before}&&${alias}.played.length===1&&${alias}.played.start(0)===${start}&&${alias}.played.end(0)===${end}')! == 'true'
		mut loop := html.main_thread_event_loop()
		loop.perform_a_microtask_checkpoint()
		assert runtime.evaluate_host('mtrOrder.length===${before}')! == 'true'
		media_timeline_ranges_owner_drain(document)
		assert runtime.evaluate_host('mtrOrder.length===${before + 2}&&mtrChecks.every(Boolean)&&mtrPlayed.length===${before + 2}&&mtrPlayed[${before}]!==mtrPlayed[${before + 1}]&&mtrPlayed[${before}].start(0)===${start}&&mtrPlayed[${before}].end(0)===${end}')! == 'true'
		actual := runtime.native_time_ranges(runtime.evaluate_host_value('mtrPlayed[${before}]')!)!
		assert actual.length() == 1 && actual.start(0)! == start && actual.end(0)! == end
		// Remove these pause-specific handlers before load queues its reset-time
		// timeupdate, then authenticate the saved static objects after clearing.
		assert runtime.evaluate_host('${alias}.removeAttribute("ontimeupdate");${alias}.removeAttribute("onpause");${alias}.ontimeupdate===null&&${alias}.onpause===null')! == 'true'
		current.set_source(none)
		assert runtime.evaluate_host('${alias}.load();${alias}.played.length===0&&${alias}.seekable.length===0&&mtrPlayed[${before}].start(0)===${start}&&mtrPlayed[${before}].end(0)===${end}')! == 'true'
		media_timeline_ranges_owner_drain(document)
	}
	assert runtime.evaluate_host('mtrOrder.join(",")==="mtr-video:timeupdate,mtr-video:pause,mtr-audio:timeupdate,mtr-audio:pause"&&mtrChecks.length===4&&mtrChecks.every(Boolean)&&new Set(mtrPlayed).size===4&&mtrPlayed[0].start(0)===2&&mtrPlayed[0].end(0)===6&&mtrPlayed[2].start(0)===1&&mtrPlayed[2].end(0)===4&&mtrVideo.played.length===0&&mtrAudio.played.length===0&&window.event===undefined')! == 'true'
	app.poll_javascript_tasks()
	assert app.paint_commands.filter(it.kind == 'draw_text' && it.text == 'native played ranges painted').len > 0
	assert app.js_messages == []
	media_timeline_ranges_owner_balance(runtime, document)
}
