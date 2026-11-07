module main

import browserjs
import dom
import html
import page
import time

fn media_handler_document(markup string, address string) !&dom.Document {
	owner := page.Page.create(1)!
	return parse_browser_navigation_document_for_page_with_response_time(markup, dom.URL{
		value: address
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
}

fn media_handler_drain(document &dom.Document) {
	mut queue := html.main_thread_event_loop().task_queue()
	mut count := 0
	for {
		task := queue.take_first_runnable_matching(fn [document] (task &html.Task) bool {
			owner := task.document() or { return false }
			return task.source() == .media_element && voidptr(owner) == voidptr(document)
		}) or { break }
		count++
		assert count < 100
		task.execute()
	}
}

fn media_handler_checkpoint() {
	mut loop := html.main_thread_event_loop()
	loop.perform_a_microtask_checkpoint()
}

fn test_ordinary_parsed_media_handlers_run_before_their_play_promise_batch_fulfills() {
	$if !darwin {
		return
	}
	mut policy := html.AutoplaySettings.the()
	previous_policy := policy.policy()
	previous_allowlist := policy.allowlist().map(it.serialize())
	defer { policy.set_policy(previous_policy, previous_allowlist) }
	policy.set_policy(.allow_audio_and_video, [])
	mut document := media_handler_document('<video id="video" preload="none"></video><audio id="other"></audio>',
		'https://ordinary-media-handlers-play.example.test/')!
	mut media := html.html_media_element_for_dom_element(document.get_element_by_id('video')?)?
	media.set_fetch_hook(fn (url dom.URL, _ u64) !html.MediaResourceResponse {
		assert url.serialize() == 'https://ordinary-media-handlers-play.example.test/selected.mp4'
		return html.MediaResourceResponse{ mime_type: 'video/mp4', duration: 20, buffered_end: 20 }
	})
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [], runtime, mut messages)
	assert messages == []
	assert runtime.evaluate_host(r'["onplay","onplaying"].every(name=>{const descriptor=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,name);return !!descriptor&&typeof descriptor.get==="function"&&typeof descriptor.set==="function"&&video[name]===null})')! == 'true'
	runtime.evaluate_host(r'
globalThis.mediaHandlerPlayOrder=[];globalThis.mediaHandlerPlayChecks=[];globalThis.mediaHandlerPlayingEvent=null;
globalThis.mediaHandlerPlay=function(event){mediaHandlerPlayOrder.push("play");mediaHandlerPlayChecks.push(this===video&&event.target===video&&event.currentTarget===video&&event instanceof Event&&event.isTrusted&&!event.bubbles&&!event.cancelable&&window.event===event)};
globalThis.mediaHandlerPlaying=function(event){mediaHandlerPlayOrder.push("playing");mediaHandlerPlayChecks.push(this===video&&event.target===video&&event.currentTarget===video&&event instanceof Event&&event.isTrusted&&!event.bubbles&&!event.cancelable&&window.event===event);mediaHandlerPlayingEvent=event};
video.onplay=mediaHandlerPlay;video.onplaying=mediaHandlerPlaying;other.onplaying=()=>mediaHandlerPlayChecks.push(false);
video.src="/selected.mp4";globalThis.mediaHandlerFirst=video.play();globalThis.mediaHandlerSecond=video.play();
globalThis.mediaHandlerPlayImmediate=video.onplay===mediaHandlerPlay&&video.onplaying===mediaHandlerPlaying&&!Object.hasOwn(video,"onplay")&&!Object.hasOwn(video,"onplaying")&&mediaHandlerFirst instanceof Promise&&mediaHandlerSecond instanceof Promise&&mediaHandlerFirst!==mediaHandlerSecond&&!video.paused&&mediaHandlerPlayOrder.length===0;
mediaHandlerFirst.then(value=>{mediaHandlerPlayChecks.push(value===undefined);mediaHandlerPlayOrder.push("first")});mediaHandlerSecond.then(value=>{mediaHandlerPlayChecks.push(value===undefined);mediaHandlerPlayOrder.push("second")});
')!
	assert runtime.evaluate_host('mediaHandlerPlayImmediate')! == 'true'
	media_handler_checkpoint()
	assert runtime.evaluate_host('mediaHandlerPlayOrder.length===0')! == 'true'
	media_handler_drain(document)
	media_handler_checkpoint()
	assert runtime.evaluate_host(r'mediaHandlerPlayOrder.join(",")==="play,playing,first,second"&&mediaHandlerPlayChecks.length===4&&mediaHandlerPlayChecks.every(Boolean)&&mediaHandlerPlayingEvent.target===video&&mediaHandlerPlayingEvent.currentTarget===null&&window.event===undefined')! == 'true'
	assert voidptr(runtime.native_event_target(runtime.evaluate_host_value('video')!)!) == voidptr(media.event_target())
	assert media.event_count('play') == 1 && media.event_count('playing') == 1
	media.set_source('')
	media.load()!
	media_handler_drain(document)
	assert !runtime.libjs_vm().has_running_execution_context()
}

fn test_ordinary_created_audio_pause_handler_replacement_keeps_owner_and_rejection_order() {
	$if !darwin {
		return
	}
	mut policy := html.AutoplaySettings.the()
	previous_policy := policy.policy()
	previous_allowlist := policy.allowlist().map(it.serialize())
	defer { policy.set_policy(previous_policy, previous_allowlist) }
	policy.set_policy(.allow_audio_and_video, [])
	mut document := media_handler_document('<body></body>',
		'https://ordinary-created-audio-handlers.example.test/')!
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [
		r'globalThis.handlerAudio=document.createElement("audio");handlerAudio.id="handler-audio";',
	], runtime, mut messages)
	assert messages == []
	assert runtime.evaluate_host(r'["onplay","onwaiting","ontimeupdate","onpause"].every(name=>{const descriptor=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,name);return !!descriptor&&typeof descriptor.get==="function"&&typeof descriptor.set==="function"&&handlerAudio[name]===null})')! == 'true'
	runtime.evaluate_host(r'
globalThis.createdHandlerOrder=[];globalThis.createdHandlerChecks=[];globalThis.createdHandlerReasons=[];globalThis.createdHandlerPause=null;
for(const name of ["play","waiting","timeupdate"])handlerAudio["on"+name]=function(event){createdHandlerOrder.push(name);createdHandlerChecks.push(this===handlerAudio&&event.target===handlerAudio&&event.currentTarget===handlerAudio&&event instanceof Event&&event.isTrusted&&createdHandlerReasons.length===0)};
globalThis.createdOldPause=function(){createdHandlerOrder.push("old-pause")};handlerAudio.onpause=createdOldPause;
handlerAudio.addEventListener("pause",function(event){createdHandlerOrder.push("listener");createdHandlerChecks.push(this===handlerAudio&&event.target===handlerAudio&&event.currentTarget===handlerAudio&&createdHandlerReasons.length===0)});
globalThis.createdNewPause=function(event){createdHandlerOrder.push("pause");createdHandlerChecks.push(this===handlerAudio&&event.target===handlerAudio&&event.currentTarget===handlerAudio&&event instanceof Event&&event.isTrusted&&!event.bubbles&&!event.cancelable&&handlerAudio.paused&&createdHandlerReasons.length===0&&window.event===event);createdHandlerPause=event};
const first=handlerAudio.play();document.body.appendChild(handlerAudio);const second=handlerAudio.play();handlerAudio.pause();handlerAudio.onpause=createdNewPause;
globalThis.createdHandlerImmediate=first instanceof Promise&&second instanceof Promise&&first!==second&&handlerAudio.paused&&handlerAudio.onpause===createdNewPause&&!Object.hasOwn(handlerAudio,"onpause")&&createdHandlerOrder.length===0;
for(const request of [first,second])request.catch(reason=>{createdHandlerReasons.push(reason);createdHandlerOrder.push("rejected")});
')!
	assert runtime.evaluate_host('createdHandlerImmediate')! == 'true'
	created := document.get_element_by_id('handler-audio')?
	media := html.html_media_element_for_dom_element(created)?
	assert voidptr(media.document()?) == voidptr(document) && media.paused()
	assert voidptr(runtime.native_event_target(runtime.evaluate_host_value('handlerAudio')!)!) == voidptr(created)
	media_handler_checkpoint()
	assert runtime.evaluate_host('createdHandlerOrder.length===0&&createdHandlerReasons.length===0')! == 'true'
	media_handler_drain(document)
	media_handler_checkpoint()
	assert runtime.evaluate_host('createdHandlerOrder.join(",")')! == 'timeupdate,play,waiting,timeupdate,pause,listener,rejected,rejected'
	assert runtime.evaluate_host(r'createdHandlerChecks.length===6&&createdHandlerChecks.every(Boolean)&&createdHandlerPause.currentTarget===null&&createdHandlerReasons.length===2&&createdHandlerReasons[0]===createdHandlerReasons[1]&&createdHandlerReasons[0] instanceof DOMException&&createdHandlerReasons[0].name==="AbortError"&&createdHandlerReasons[0].code===20&&createdHandlerReasons[0].message==="Media playback was paused"&&window.event===undefined')! == 'true'
	assert media.event_count('pause') == 1
}

fn test_ordinary_parsed_and_created_media_readiness_handlers_wait_for_actual_owner_tasks() {
	$if !darwin {
		return
	}
	mut document := media_handler_document('<video id="video" src="/movie.mp4"></video>',
		'https://ordinary-media-readiness-handlers.example.test/')!
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [
		r'globalThis.readyAudio=document.createElement("audio");readyAudio.id="ready-audio";document.body.appendChild(readyAudio);',
	], runtime, mut messages)
	assert messages == []
	assert runtime.evaluate_host(r'["onloadedmetadata","onloadeddata","oncanplay"].every(name=>{const descriptor=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,name);return !!descriptor&&typeof descriptor.get==="function"&&typeof descriptor.set==="function"&&video[name]===null&&readyAudio[name]===null})')! == 'true'
	mut models := []&html.HTMLMediaElement{}
	for name in ['video', 'ready-audio'] {
		mut media := html.html_media_element_for_dom_element(document.get_element_by_id(name)?)?
		media.set_fetch_hook(fn (_ dom.URL, _ u64) !html.MediaResourceResponse {
			return html.MediaResourceResponse{ mime_type: 'video/mp4', duration: 20 }
		})
		models << media
	}
	runtime.evaluate_host(r'
globalThis.readyHandlerOrder=[];globalThis.readyHandlerChecks=[];globalThis.savedReadyHandlerEvent=null;
for(const [name,player] of [["video",video],["audio",readyAudio]])for(const type of ["loadedmetadata","loadeddata","canplay"])player["on"+type]=function(event){readyHandlerOrder.push(name+":"+type);readyHandlerChecks.push(this===player&&event.target===player&&event.currentTarget===player&&event instanceof Event&&event.isTrusted&&!event.bubbles&&!event.cancelable&&player.duration===20&&player.readyState===(type==="loadedmetadata"?1:3)&&window.event===event);savedReadyHandlerEvent=event};
readyAudio.src="/sound.mp3";video.load();readyAudio.load();
')!
	assert runtime.evaluate_host('readyHandlerOrder.length===0&&video.readyState===1&&readyAudio.readyState===1')! == 'true'
	media_handler_checkpoint()
	assert runtime.evaluate_host('readyHandlerOrder.length===0')! == 'true'
	media_handler_drain(document)
	assert runtime.evaluate_host('readyHandlerOrder.join(",")')! == 'video:loadedmetadata,audio:loadedmetadata'
	for model in models {
		mut media := unsafe { &html.HTMLMediaElement(model) }
		media.set_ready_state(.have_future_data)
	}
	media_handler_checkpoint()
	assert runtime.evaluate_host('readyHandlerOrder.length===2')! == 'true'
	media_handler_drain(document)
	assert runtime.evaluate_host(r'readyHandlerOrder.join(",")==="video:loadedmetadata,audio:loadedmetadata,video:loadeddata,video:canplay,audio:loadeddata,audio:canplay"&&readyHandlerChecks.length===6&&readyHandlerChecks.every(Boolean)&&savedReadyHandlerEvent.target===readyAudio&&savedReadyHandlerEvent.currentTarget===null&&window.event===undefined')! == 'true'
	created := document.get_element_by_id('ready-audio')?
	assert voidptr(runtime.native_event_target(runtime.evaluate_host_value('readyAudio')!)!) == voidptr(created)
	for model in models {
		mut media := unsafe { &html.HTMLMediaElement(model) }
		media.set_source('')
		media.load()!
	}
	media_handler_drain(document)
}

fn test_raw_media_onstalled_stays_uncompiled_and_idl_replacement_preserves_content_attribute() {
	$if !darwin {
		return
	}
	raw_source := 'globalThis.rawMediaHandlerRuns++'
	mut document := media_handler_document('<video id="raw" onstalled="${raw_source}"></video>',
		'https://ordinary-raw-media-handler.example.test/')!
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [
		r'globalThis.rawMediaHandlerRuns=0;globalThis.rawReplacementCalls=0;globalThis.rawReplacementChecks=[];globalThis.rawContentSource=raw.getAttribute("onstalled");',
	], runtime, mut messages)
	assert messages == []
	assert runtime.evaluate_host(r'(()=>{const descriptor=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"onstalled");return !!descriptor&&typeof descriptor.get==="function"&&typeof descriptor.set==="function"&&raw.onstalled===null})()')! == 'true'
	element := document.get_element_by_id('raw')?
	target := runtime.native_event_target(runtime.evaluate_host_value('raw')!)!
	raw_handler := target.data.event_handler('stalled') or {
		assert false, 'missing raw media handler'
		return
	}
	assert raw_handler.value.kind == .string && raw_handler.value.string_data == raw_source
	assert target.event_listener_list().len == 1
	assert runtime.evaluate_host('raw.dispatchEvent(new Event("stalled"));rawMediaHandlerRuns===0&&raw.onstalled===null&&raw.getAttribute("onstalled")===rawContentSource')! == 'true'
	assert raw_handler.value.kind == .string && raw_handler.value.string_data == raw_source
	runtime.evaluate_host(r'
globalThis.rawReplacement=function(event){rawReplacementCalls++;rawReplacementChecks.push(this===raw&&event.target===raw&&event.currentTarget===raw&&event instanceof Event&&!event.isTrusted&&window.event===event)};
raw.onstalled=rawReplacement;raw.dispatchEvent(new Event("stalled"));
')!
	assert runtime.evaluate_host('raw.onstalled===rawReplacement&&!Object.hasOwn(raw,"onstalled")&&rawReplacementCalls===1&&rawReplacementChecks.every(Boolean)&&rawMediaHandlerRuns===0&&raw.getAttribute("onstalled")===rawContentSource&&window.event===undefined')! == 'true'
	assigned_handler := target.data.event_handler('stalled') or {
		assert false, 'missing assigned media handler'
		return
	}
	assert voidptr(assigned_handler) == voidptr(raw_handler)
	assert assigned_handler.value.kind == .object
	assert target.event_listener_list().len == 1
	assert element.get_attribute('onstalled')? == raw_source
	assert runtime.evaluate_host('raw.onstalled=null;raw.dispatchEvent(new Event("stalled"));raw.onstalled===null&&rawReplacementCalls===1&&rawMediaHandlerRuns===0&&raw.getAttribute("onstalled")===rawContentSource')! == 'true'
	assert !target.data.has_event_handler('stalled')
	assert target.event_listener_list().len == 0
	assert element.get_attribute('onstalled')? == raw_source
	assert !runtime.libjs_vm().has_running_execution_context()
}
