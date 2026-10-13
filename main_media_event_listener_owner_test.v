module main

import browserjs
import dom
import html
import page
import time

fn media_listener_document(markup string, address string) !&dom.Document {
	owner := page.Page.create(1)!
	return parse_browser_navigation_document_for_page_with_response_time(markup, dom.URL{
		value: address
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
}

fn media_listener_drain(document &dom.Document) {
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

fn media_listener_checkpoint() {
	mut loop := html.main_thread_event_loop()
	loop.perform_a_microtask_checkpoint()
}

fn test_ordinary_parsed_media_listeners_observe_trusted_playing_before_promise_fulfillment() {
	$if !darwin {
		return
	}
	mut policy := html.AutoplaySettings.the()
	previous_policy := policy.policy()
	previous_allowlist := policy.allowlist().map(it.serialize())
	defer { policy.set_policy(previous_policy, previous_allowlist) }
	policy.set_policy(.allow_audio_and_video, [])
	document := media_listener_document('<video id="video" preload="none"></video><audio id="audio"></audio>',
		'https://ordinary-media-play.example.test/')!
	mut media := html.html_media_element_for_dom_element(document.get_element_by_id('video')?)?
	media.set_fetch_hook(fn (url dom.URL, _ u64) !html.MediaResourceResponse {
		assert url.serialize() == 'https://ordinary-media-play.example.test/selected.mp4'
		return html.MediaResourceResponse{ mime_type: 'video/mp4', duration: 20, buffered_end: 20 }
	})
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [
		r'globalThis.ordinaryPlayOrder=[];globalThis.ordinaryPlayChecks=[];globalThis.ordinarySavedPlaying=null;
 for(const type of ["play","playing"])video.addEventListener(type,function(event){
 ordinaryPlayOrder.push(type);ordinaryPlayChecks.push(this===video&&event.target===video&&event.currentTarget===video&&event instanceof Event&&event.isTrusted&&!event.bubbles&&!event.cancelable&&event.eventPhase===Event.AT_TARGET);ordinarySavedPlaying=event;
 });audio.addEventListener("playing",()=>ordinaryPlayChecks.push(false));
 video.src="/selected.mp4";globalThis.ordinaryFirstPlay=video.play();globalThis.ordinarySecondPlay=video.play();
 globalThis.ordinaryPlayImmediate=ordinaryFirstPlay instanceof Promise&&ordinarySecondPlay instanceof Promise&&ordinaryFirstPlay!==ordinarySecondPlay&&!video.paused&&ordinaryPlayOrder.length===0;
 ordinaryFirstPlay.then(value=>{ordinaryPlayChecks.push(value===undefined);ordinaryPlayOrder.push("first")});ordinarySecondPlay.then(value=>{ordinaryPlayChecks.push(value===undefined);ordinaryPlayOrder.push("second")});',
	], runtime, mut messages)
	assert messages == []
	assert runtime.evaluate_host('ordinaryPlayImmediate')! == 'true'
	media_listener_checkpoint()
	assert runtime.evaluate_host('ordinaryPlayOrder.length===0')! == 'true'
	media_listener_drain(document)
	media_listener_checkpoint()
	assert runtime.evaluate_host(r'ordinaryPlayOrder.join(",")==="play,playing,first,second"&&ordinaryPlayChecks.length===4&&ordinaryPlayChecks.every(Boolean)&&ordinarySavedPlaying.target===video&&ordinarySavedPlaying.currentTarget===null&&ordinarySavedPlaying.eventPhase===Event.NONE')! == 'true'
	assert voidptr(runtime.native_event_target(runtime.evaluate_host_value('video')!)!) == voidptr(media.event_target())
	assert media.event_count('play') == 1 && media.event_count('playing') == 1
	media.set_source('')
	media.load()!
	media_listener_drain(document)
}

fn test_ordinary_created_audio_listeners_follow_the_dom_owner_and_pause_rejection_batch() {
	$if !darwin {
		return
	}
	mut policy := html.AutoplaySettings.the()
	previous_policy := policy.policy()
	previous_allowlist := policy.allowlist().map(it.serialize())
	defer { policy.set_policy(previous_policy, previous_allowlist) }
	policy.set_policy(.allow_audio_and_video, [])
	document := media_listener_document('<body></body>',
		'https://ordinary-created-audio.example.test/')!
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [
		r'globalThis.ordinaryCreated=document.createElement("audio");ordinaryCreated.id="created-audio";
 globalThis.ordinaryCreatedOrder=[];globalThis.ordinaryCreatedReasons=[];globalThis.ordinaryCreatedChecks=[];globalThis.ordinaryCreatedEvent=null;
 for(const type of ["play","waiting","timeupdate","pause"])ordinaryCreated.addEventListener(type,function(event){ordinaryCreatedOrder.push(type);ordinaryCreatedChecks.push(this===ordinaryCreated&&event.target===ordinaryCreated&&event.currentTarget===ordinaryCreated&&event instanceof Event&&event.isTrusted&&!event.bubbles&&!event.cancelable&&ordinaryCreatedReasons.length===0);ordinaryCreatedEvent=event});
 const first=ordinaryCreated.play();document.body.appendChild(ordinaryCreated);const second=ordinaryCreated.play();ordinaryCreated.pause();
 globalThis.ordinaryCreatedImmediate=first instanceof Promise&&second instanceof Promise&&first!==second&&ordinaryCreated.paused&&ordinaryCreatedOrder.length===0;
 for(const request of [first,second])request.catch(reason=>{ordinaryCreatedReasons.push(reason);ordinaryCreatedOrder.push("rejected")});',
	], runtime, mut messages)
	assert messages == []
	assert runtime.evaluate_host('ordinaryCreatedImmediate')! == 'true'
	created := document.get_element_by_id('created-audio')?
	media := html.html_media_element_for_dom_element(created)?
	assert voidptr(media.document()?) == voidptr(document) && media.paused()
	assert voidptr(runtime.native_event_target(runtime.evaluate_host_value('ordinaryCreated')!)!) == voidptr(created)
	media_listener_checkpoint()
	assert runtime.evaluate_host('ordinaryCreatedOrder.length===0&&ordinaryCreatedReasons.length===0')! == 'true'
	media_listener_drain(document)
	media_listener_checkpoint()
	assert runtime.evaluate_host('ordinaryCreatedOrder.join(",")')! == 'timeupdate,play,waiting,timeupdate,pause,rejected,rejected'
	assert runtime.evaluate_host(r'ordinaryCreatedChecks.length===5&&ordinaryCreatedChecks.every(Boolean)&&ordinaryCreatedEvent.target===ordinaryCreated&&ordinaryCreatedEvent.currentTarget===null&&ordinaryCreatedReasons.length===2&&ordinaryCreatedReasons[0]===ordinaryCreatedReasons[1]&&ordinaryCreatedReasons[0] instanceof DOMException&&ordinaryCreatedReasons[0].name==="AbortError"&&ordinaryCreatedReasons[0].code===20&&ordinaryCreatedReasons[0].message==="Media playback was paused"')! == 'true'
	assert media.event_count('play') == 1 && media.event_count('waiting') == 1 && media.event_count('pause') == 1
}

fn test_ordinary_media_readiness_listeners_use_the_actual_queued_audio_and_video_transitions() {
	$if !darwin {
		return
	}
	document := media_listener_document('<video id="video" src="/movie.mp4"></video><audio id="audio" src="/sound.mp3"></audio>',
		'https://ordinary-media-readiness.example.test/')!
	mut models := []&html.HTMLMediaElement{}
	for name in ['video', 'audio'] {
		mut media := html.html_media_element_for_dom_element(document.get_element_by_id(name)?)?
		media.set_fetch_hook(fn (_ dom.URL, _ u64) !html.MediaResourceResponse {
			return html.MediaResourceResponse{ mime_type: 'video/mp4', duration: 20 }
		})
		models << media
	}
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [
		r'globalThis.ordinaryReadyOrder=[];globalThis.ordinaryReadyChecks=[];globalThis.ordinaryReadyEvent=null;
 for(const [name,player] of [["video",video],["audio",audio]])for(const type of ["loadedmetadata","loadeddata","canplay"])player.addEventListener(type,function(event){ordinaryReadyOrder.push(name+":"+type);ordinaryReadyChecks.push(this===player&&event.target===player&&event.currentTarget===player&&event instanceof Event&&event.isTrusted&&!event.bubbles&&!event.cancelable&&player.duration===20&&player.readyState===(type==="loadedmetadata"?1:3));ordinaryReadyEvent=event});video.load();audio.load();',
	], runtime, mut messages)
	assert messages == []
	assert runtime.evaluate_host('ordinaryReadyOrder.length===0&&video.readyState===1&&audio.readyState===1')! == 'true'
	media_listener_checkpoint()
	assert runtime.evaluate_host('ordinaryReadyOrder.length===0')! == 'true'
	media_listener_drain(document)
	assert runtime.evaluate_host('ordinaryReadyOrder.join(",")')! == 'video:loadedmetadata,audio:loadedmetadata'
	for model in models {
		mut media := unsafe { &html.HTMLMediaElement(model) }
		media.set_ready_state(.have_future_data)
	}
	media_listener_checkpoint()
	assert runtime.evaluate_host('ordinaryReadyOrder.length===2')! == 'true'
	media_listener_drain(document)
	assert runtime.evaluate_host(r'ordinaryReadyOrder.join(",")==="video:loadedmetadata,audio:loadedmetadata,video:loadeddata,video:canplay,audio:loadeddata,audio:canplay"&&ordinaryReadyChecks.length===6&&ordinaryReadyChecks.every(Boolean)&&ordinaryReadyEvent.target===audio&&ordinaryReadyEvent.currentTarget===null')! == 'true'
	for model in models {
		mut media := unsafe { &html.HTMLMediaElement(model) }
		media.set_source('')
		media.load()!
	}
	media_listener_drain(document)
}

fn test_ordinary_media_listener_identity_once_capture_removal_and_dispatch_share_the_native_list() {
	$if !darwin {
		return
	}
	document := media_listener_document('<video id="video"></video>',
		'https://ordinary-media-listener-options.example.test/')!
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [
		r'globalThis.ordinaryOptionsOrder=[];globalThis.ordinaryOptionsChecks=[];
 const shared=function(event){ordinaryOptionsOrder.push("shared");ordinaryOptionsChecks.push(this===video&&event.target===video&&event.currentTarget===video&&event instanceof Event&&!event.isTrusted&&event.eventPhase===Event.AT_TARGET)};
 const capture=function(event){ordinaryOptionsOrder.push("capture");ordinaryOptionsChecks.push(this===video&&event.target===video&&event.currentTarget===video&&event instanceof Event&&!event.isTrusted)};
 const removed=()=>ordinaryOptionsOrder.push("removed");
 const object={handleEvent(event){ordinaryOptionsOrder.push("object");ordinaryOptionsChecks.push(this===object&&event.target===video&&event.currentTarget===video&&event instanceof Event&&!event.isTrusted)}};
 video.addEventListener("pause",shared);video.addEventListener("pause",shared);
 video.addEventListener("pause",capture,true);video.removeEventListener("pause",capture,false);
 video.addEventListener("pause",removed,{capture:true});video.removeEventListener("pause",removed,{capture:true});
 video.addEventListener("pause",object,{once:true});
 globalThis.ordinarySyntheticFirst=new Event("pause");globalThis.ordinarySyntheticSecond=new Event("pause");
 globalThis.ordinarySyntheticReturns=video.dispatchEvent(ordinarySyntheticFirst)&&video.dispatchEvent(ordinarySyntheticSecond);
 video.removeEventListener("pause",shared);video.dispatchEvent(new Event("pause"));',
	], runtime, mut messages)
	assert messages == []
	assert runtime.evaluate_host('ordinaryOptionsOrder.join(",")')! == 'capture,shared,object,capture,shared,capture'
	assert runtime.evaluate_host('ordinarySyntheticReturns&&ordinaryOptionsChecks.length===6&&ordinaryOptionsChecks.every(Boolean)&&ordinarySyntheticFirst.target===video&&ordinarySyntheticFirst.currentTarget===null&&ordinarySyntheticSecond.currentTarget===null')! == 'true'
	actual_target := runtime.native_event_target(runtime.evaluate_host_value('video')!)!
	assert voidptr(actual_target) == voidptr(document.get_element_by_id('video')?)
	assert actual_target.event_listener_list().len == 1
}

fn test_ordinary_ready_video_registration_does_not_fabricate_loadeddata_or_seeked_events() {
	$if !darwin {
		return
	}
	document := media_listener_document('<video id="video"></video>',
		'https://ordinary-ready-video-listener.example.test/')!
	element := document.get_element_by_id('video')?
	mut video := html.html_video_element_model_for_dom_element(unsafe { &dom.HTMLVideoElement(element) })
	mut media := video.media
	media.set_ready_state(.have_current_data)
	video.set_video_dimensions(2, 1)
	video.set_current_frame(&dom.Bitmap_{
		width:  2
		height: 1
		pitch:  8
		data:   [u8(0), 0, 255, 255, 0, 0, 255, 255]
	})
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [
		r'globalThis.ordinaryLateEvents=[];globalThis.ordinaryLateChecks=[];
 for(const type of ["loadeddata","seeked"])video.addEventListener(type,function(event){ordinaryLateEvents.push(type);ordinaryLateChecks.push(this===video&&event.target===video&&event.currentTarget===video&&event instanceof Event&&event.isTrusted&&!event.bubbles&&!event.cancelable)});
 globalThis.ordinaryLateImmediate=video.readyState===2&&video.videoWidth===2&&video.videoHeight===1&&ordinaryLateEvents.length===0;',
	], runtime, mut messages)
	assert messages == []
	assert runtime.evaluate_host('ordinaryLateImmediate')! == 'true'
	media_listener_checkpoint()
	media_listener_drain(document)
	assert runtime.evaluate_host('ordinaryLateEvents.length===0')! == 'true'
	media.set_fetch_hook(fn (_ dom.URL, _ u64) !html.MediaResourceResponse {
		return html.MediaResourceResponse{ mime_type: 'video/mp4', duration: 20 }
	})
	media.set_source('/movie.mp4')
	media.load()!
	media_listener_drain(document)
	assert media.ready_state() == .have_metadata
	media.set_ready_state(.have_current_data)
	assert runtime.evaluate_host('ordinaryLateEvents.length===0')! == 'true'
	media_listener_drain(document)
	assert runtime.evaluate_host(r'ordinaryLateEvents.join(",")==="loadeddata"&&ordinaryLateChecks.length===1&&ordinaryLateChecks[0]')! == 'true'
	media.set_source('')
	media.load()!
	media_listener_drain(document)
}
