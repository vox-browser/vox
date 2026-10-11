module browserjs

import dom
import html
import webidl

@[heap]
struct NativePlayObservation {
mut:
	replays int
	fetches int
	starts  int
}

fn native_play_fixture(replay ?MediaElementReplayHook) !(&Runtime, &html.HTMLMediaElement) {
	url := dom.URL{ value: 'https://native-play.example.test/' }
	document := html.parse_navigation_document('<video id="video"></video><audio id="audio"></audio>',
		url, url.origin(), none)!
	mut runtime := Runtime.create()
	mut host := MediaElementHost.create(document, replay)!
	host.install(mut runtime)!
	for key, element in host.elements_for_binding() {
		if element.local_name() in ['video', 'audio'] {
			name := element.local_name()
			runtime.evaluate_host('globalThis.${name}={};__ladybirdMediaElementBind(${name},"${key}","${name}")')!
		}
	}
	element := document.get_element_by_id('video') or { return error('missing video') }
	media := html.html_media_element_for_dom_element(element) or { return error('missing media owner') }
	return runtime, media
}

fn native_play_take_task(media &html.HTMLMediaElement) ?&html.Task {
	document := media.document() or { return none }
	source := media.media_element_event_task_source()
	mut queue := html.main_thread_event_loop().task_queue()
	return queue.take_first_runnable_matching(fn [document, source] (task &html.Task) bool {
		owner := task.document() or { return false }
		return task.source() == source && voidptr(owner) == voidptr(document)
	})
}

fn native_play_drain_tasks(media &html.HTMLMediaElement) {
	mut count := 0
	for {
		task := native_play_take_task(media) or { break }
		count++
		assert count < 100
		task.execute()
	}
}

fn native_play_checkpoint() {
	mut loop := html.main_thread_event_loop()
	loop.perform_a_microtask_checkpoint()
}

fn native_play_capability(runtime &Runtime, name string) !&webidl.Promise {
	mut owner := unsafe { &Runtime(runtime) }
	actual := owner.evaluate_host_value(name)!
	for _, bridge in runtime.webidl_promise_bridges_ {
		if bridge.capability.promise == actual { return bridge.native }
	}
	return error('missing actual native play capability')
}

fn native_play_waiting_owner(mut media html.HTMLMediaElement, state &NativePlayObservation) ! {
	media.set_fetch_hook(fn [state] (_ dom.URL, _ u64) !html.MediaResourceResponse {
		mut observation := unsafe { &NativePlayObservation(state) }
		observation.fetches++
		return html.MediaResourceResponse{ mime_type: 'video/mp4', duration: 20 }
	})
	media.set_source('/waiting.mp4')
	media.load()!
	native_play_drain_tasks(&media)
	media.set_show_poster(false)
	media.set_playback_manager_hooks(html.MediaPlaybackManagerHooks{
		play: fn [state] () {
			mut observation := unsafe { &NativePlayObservation(state) }
			observation.starts++
		}
	})
	assert media.paused() && media.ready_state() == .have_metadata
}

fn test_native_play_descriptor_rejects_brand_failures_without_replay_or_argument_conversion() {
	$if !darwin {
		return
	}
	mut policy := html.AutoplaySettings.the()
	previous_policy := policy.policy()
	previous_allowlist := policy.allowlist().map(it.serialize())
	defer { policy.set_policy(previous_policy, previous_allowlist) }
	policy.set_policy(.block_audio_and_video, [])
	state := &NativePlayObservation{}
	mut runtime, media := native_play_fixture(fn [state] (_ &Runtime) ! {
		mut observation := unsafe { &NativePlayObservation(state) }
		observation.replays++
	})!
	defer { runtime.close() }
	assert runtime.evaluate_host(r'(()=>{
 const d=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"play");
 if(!d||!d.writable||!d.enumerable||!d.configurable||d.value.name!=="play"||d.value.length!==0||!Function.prototype.toString.call(d.value).includes("[native code]")||Object.hasOwn(video,"play"))return false;
 globalThis.nativePlayBrandErrors=[];globalThis.nativePlayBrandUnexpected=[];
 let traps=0,conversions=0;const proxy=new Proxy(video,{get(){traps++;throw "proxy"},getPrototypeOf(){traps++;throw "proxy"}}),extra={[Symbol.toPrimitive](){conversions++;throw "extra argument"}};
 for(const receiver of [Object.create(HTMLMediaElement.prototype),proxy,null,undefined,1]){
  let result;try{result=d.value.call(receiver,extra)}catch(error){return false}
  if(!(result instanceof Promise))return false;
  result.then(value=>nativePlayBrandUnexpected.push(value),error=>nativePlayBrandErrors.push(error));
 }
 return traps===0&&conversions===0;
})()')! == 'true'
	assert state.replays == 0 && media.paused() && media.network_state() == .empty
	native_play_checkpoint()
	assert runtime.evaluate_host(r'nativePlayBrandUnexpected.length===0&&nativePlayBrandErrors.length===5&&nativePlayBrandErrors.every(error=>error instanceof TypeError&&error.message==="Not an object of type HTMLMediaElement")&&new Set(nativePlayBrandErrors).size===5')! == 'true'
	assert runtime.evaluate_host(r'(()=>{
 const extra=new Proxy({},{get(){throw "unused extra argument"}});
 const first=video.play(extra,Symbol(),1n),second=audio.play();
 first.catch(()=>{});second.catch(()=>{});
 return first instanceof Promise&&second instanceof Promise&&first!==second;
})()')! == 'true'
	assert state.replays == 2 && media.paused()
	native_play_checkpoint()
}

fn test_native_play_rejects_with_the_original_replay_exception_before_model_mutation() {
	$if !darwin {
		return
	}
	state := &NativePlayObservation{}
	mut runtime, media := native_play_fixture(fn [state] (runtime &Runtime) ! {
		mut observation := unsafe { &NativePlayObservation(state) }
		observation.replays++
		mut owner := unsafe { &Runtime(runtime) }
		_ = owner.evaluate_host_value('throw nativePlayReplayReason')!
	})!
	defer { runtime.close() }
	assert runtime.evaluate_host(r'globalThis.nativePlayReplayReason={};globalThis.nativePlayReplayCaught=null;(()=>{
 let result;try{result=video.play({valueOf(){throw "extra argument"}})}catch(error){return false}
 result.catch(error=>nativePlayReplayCaught=error);
 return result instanceof Promise;
})()')! == 'true'
	assert state.replays == 1 && media.paused() && media.network_state() == .empty
	native_play_checkpoint()
	assert runtime.evaluate_host('nativePlayReplayCaught===nativePlayReplayReason')! == 'true'
}

fn test_native_play_permission_denial_precedes_fresh_exact_unsupported_source_rejections() {
	$if !darwin {
		return
	}
	mut policy := html.AutoplaySettings.the()
	previous_policy := policy.policy()
	previous_allowlist := policy.allowlist().map(it.serialize())
	defer { policy.set_policy(previous_policy, previous_allowlist) }
	for index, message in ['', 'unsupported codec', 'Decoder \x00 🎬 failed\r\n'] {
		policy.set_policy(.allow_audio_and_video, [])
		mut runtime, mut media := native_play_fixture(none)!
		state := &NativePlayObservation{}
		media.set_source('/unsupported.mp4')
		media.set_fetch_hook(fn [state, message] (_ dom.URL, _ u64) !html.MediaResourceResponse {
			mut observation := unsafe { &NativePlayObservation(state) }
			observation.fetches++
			return error(message)
		})
		media.load() or {}
		native_play_drain_tasks(media)
		failure := media.error() or { panic('missing actual source failure') }
		assert failure.code == .src_not_supported && failure.message() == message
		policy.set_policy(.block_audio_and_video, [])
		assert runtime.evaluate_host(r'globalThis.nativePlayDenied=null;globalThis.nativePlayDeniedPromise=video.play();nativePlayDeniedPromise.catch(error=>nativePlayDenied=error);nativePlayDeniedPromise instanceof Promise')! == 'true'
		native_play_checkpoint()
		assert runtime.evaluate_host(r'nativePlayDenied instanceof DOMException&&nativePlayDenied.name==="NotAllowedError"&&nativePlayDenied.code===0&&nativePlayDenied.message==="Media playback is not allowed without user interaction"')! == 'true'
		policy.set_policy(.allow_audio_and_video, [])
		runtime.evaluate_host(r'globalThis.nativePlayExpectedMessages=["","unsupported codec","Decoder \u0000 🎬 failed\r\n"];globalThis.nativePlayReasons=[];globalThis.nativePlayUnexpected=[];globalThis.originalPlayPromise=Promise;globalThis.originalPlayException=DOMException;globalThis.nativePlayAuthorCalls=0;globalThis.Promise=function(){nativePlayAuthorCalls++;throw "author Promise"};globalThis.DOMException=function(){nativePlayAuthorCalls++;throw "author DOMException"}')!
		assert runtime.evaluate_host(r'globalThis.nativePlayFirst=video.play();globalThis.nativePlaySecond=video.play();for(const promise of [nativePlayFirst,nativePlaySecond])promise.then(value=>nativePlayUnexpected.push(value),error=>nativePlayReasons.push(error));nativePlayFirst instanceof originalPlayPromise&&nativePlaySecond instanceof originalPlayPromise&&nativePlayFirst!==nativePlaySecond')! == 'true'
		native_play_checkpoint()
		assert runtime.evaluate_host('nativePlayReasons.length===2&&nativePlayReasons[0]!==nativePlayReasons[1]&&nativePlayReasons.every(error=>error instanceof originalPlayException&&error.name==="NotSupportedError"&&error.code===9&&error.message===nativePlayExpectedMessages[${index}])&&nativePlayUnexpected.length===0&&nativePlayAuthorCalls===0')! == 'true'
		assert state.fetches == 1 && media.paused() && voidptr(media.error()?) == voidptr(failure)
		assert native_play_take_task(media) == none
		runtime.close()
	}
}

fn test_native_play_waiting_promises_fulfill_after_the_queued_playing_event() {
	$if !darwin {
		return
	}
	mut policy := html.AutoplaySettings.the()
	previous_policy := policy.policy()
	previous_allowlist := policy.allowlist().map(it.serialize())
	defer { policy.set_policy(previous_policy, previous_allowlist) }
	policy.set_policy(.allow_audio_and_video, [])
	mut runtime, mut media := native_play_fixture(none)!
	defer { runtime.close() }
	state := &NativePlayObservation{}
	native_play_waiting_owner(mut media, state)!
	assert runtime.evaluate_host(r'globalThis.nativePlayEvents=[];globalThis.nativePlayValues=[];globalThis.nativePlayErrors=[];globalThis.nativePlayEventChecks=[];
 for(const name of ["play","waiting","loadeddata","canplay","playing"])video.addEventListener(name,function(event){nativePlayEvents.push(name);nativePlayEventChecks.push(nativePlayValues.length===0&&this===video&&event.target===video&&event.currentTarget===video&&event.isTrusted&&!event.bubbles&&!event.cancelable)});
 globalThis.nativePlayFirst=video.play();globalThis.nativePlaySecond=video.play();
 nativePlayFirst.then(value=>nativePlayValues.push(value),error=>nativePlayErrors.push(error));nativePlaySecond.then(value=>nativePlayValues.push(value),error=>nativePlayErrors.push(error));
 nativePlayFirst instanceof Promise&&nativePlaySecond instanceof Promise&&nativePlayFirst!==nativePlaySecond&&!video.paused&&nativePlayEvents.length===0')! == 'true'
	first := native_play_capability(runtime, 'nativePlayFirst')!
	second := native_play_capability(runtime, 'nativePlaySecond')!
	assert first.state == .pending && second.state == .pending && state.starts == 0
	native_play_checkpoint()
	assert runtime.evaluate_host('nativePlayValues.length===0&&nativePlayEvents.length===0')! == 'true'
	for name in ['play', 'waiting'] {
		(native_play_take_task(media) or { panic('missing play/waiting task') }).execute()
		assert runtime.evaluate_host('nativePlayEvents.at(-1)==="${name}"&&nativePlayValues.length===0')! == 'true'
		assert first.state == .pending && second.state == .pending
	}
	media.set_ready_state(.have_future_data)
	assert first.state == .pending && second.state == .pending && state.starts == 1
	for name in ['loadeddata', 'canplay', 'playing'] {
		(native_play_take_task(media) or { panic('missing readiness task') }).execute()
		assert runtime.evaluate_host('nativePlayEvents.at(-1)')! == name
		if name != 'playing' {
			assert runtime.evaluate_host('nativePlayValues.length===0')! == 'true'
			assert first.state == .pending && second.state == .pending
		}
	}
	assert first.state == .fulfilled && second.state == .fulfilled
	assert first.result.kind == .undefined && second.result.kind == .undefined
	native_play_checkpoint()
	assert runtime.evaluate_host(r'nativePlayEvents.join(",")==="play,waiting,loadeddata,canplay,playing"&&nativePlayEventChecks.every(Boolean)&&nativePlayValues.length===2&&nativePlayValues.every(value=>value===undefined)&&nativePlayErrors.length===0')! == 'true'
	assert state.fetches == 1 && state.starts == 1
	media.set_source('')
	media.load()!
	native_play_drain_tasks(media)
	native_play_checkpoint()
}

fn test_native_pause_rejects_its_waiting_play_batch_with_one_actual_abort_error() {
	$if !darwin {
		return
	}
	mut policy := html.AutoplaySettings.the()
	previous_policy := policy.policy()
	previous_allowlist := policy.allowlist().map(it.serialize())
	defer { policy.set_policy(previous_policy, previous_allowlist) }
	policy.set_policy(.allow_audio_and_video, [])
	mut runtime, mut media := native_play_fixture(none)!
	defer { runtime.close() }
	state := &NativePlayObservation{}
	native_play_waiting_owner(mut media, state)!
	runtime.evaluate_host(r'globalThis.nativePausePlayReasons=[];globalThis.nativePausePlayValues=[];globalThis.nativePausePlayChecks=[];globalThis.nativePauseResumed=false;
 globalThis.nativePausePlayFirst=video.play();globalThis.nativePausePlaySecond=video.play();
 nativePausePlayFirst.then(value=>nativePausePlayValues.push(value),error=>nativePausePlayReasons.push(error));nativePausePlaySecond.then(value=>nativePausePlayValues.push(value),error=>nativePausePlayReasons.push(error));
 video.addEventListener("timeupdate",()=>nativePausePlayChecks.push(nativePausePlayReasons.length===0));
 video.addEventListener("pause",()=>{nativePausePlayChecks.push(nativePausePlayReasons.length===0);globalThis.nativePauseResumedPromise=video.play();nativePauseResumedPromise.then(()=>nativePauseResumed=true)});')!
	native_play_drain_tasks(media)
	assert runtime.evaluate_host('video.pause()===undefined&&video.paused&&nativePausePlayReasons.length===0')! == 'true'
	first := native_play_capability(runtime, 'nativePausePlayFirst')!
	second := native_play_capability(runtime, 'nativePausePlaySecond')!
	assert first.state == .pending && second.state == .pending
	(native_play_take_task(media) or { panic('missing pause task') }).execute()
	assert first.state == .rejected && second.state == .rejected && !media.paused()
	assert voidptr(first.result.dom_exception_?) == voidptr(second.result.dom_exception_?)
	resumed := native_play_capability(runtime, 'nativePauseResumedPromise')!
	assert resumed.state == .pending
	native_play_checkpoint()
	assert runtime.evaluate_host(r'nativePausePlayReasons.length===2&&nativePausePlayReasons[0]===nativePausePlayReasons[1]&&nativePausePlayReasons[0] instanceof DOMException&&nativePausePlayReasons[0].name==="AbortError"&&nativePausePlayReasons[0].code===20&&nativePausePlayReasons[0].message==="Media playback was paused"&&nativePausePlayValues.length===0&&nativePausePlayChecks.length===2&&nativePausePlayChecks.every(Boolean)&&!nativePauseResumed')! == 'true'
	media.set_ready_state(.have_future_data)
	native_play_drain_tasks(media)
	native_play_checkpoint()
	assert resumed.state == .fulfilled
	assert runtime.evaluate_host('nativePauseResumed')! == 'true'
	media.set_source('')
	media.load()!
	native_play_drain_tasks(media)
	native_play_checkpoint()
}

fn test_native_load_immediately_rejects_waiting_play_promises_with_a_typed_abort_error() {
	$if !darwin {
		return
	}
	mut policy := html.AutoplaySettings.the()
	previous_policy := policy.policy()
	previous_allowlist := policy.allowlist().map(it.serialize())
	defer { policy.set_policy(previous_policy, previous_allowlist) }
	policy.set_policy(.allow_audio_and_video, [])
	mut runtime, mut media := native_play_fixture(none)!
	defer { runtime.close() }
	state := &NativePlayObservation{}
	native_play_waiting_owner(mut media, state)!
	runtime.evaluate_host(r'globalThis.nativeLoadPlayReasons=[];globalThis.nativeLoadPlayFirst=video.play();globalThis.nativeLoadPlaySecond=video.play();nativeLoadPlayFirst.catch(error=>nativeLoadPlayReasons.push(error));nativeLoadPlaySecond.catch(error=>nativeLoadPlayReasons.push(error));')!
	first := native_play_capability(runtime, 'nativeLoadPlayFirst')!
	second := native_play_capability(runtime, 'nativeLoadPlaySecond')!
	assert first.state == .pending && second.state == .pending
	assert runtime.evaluate_host('video.load()===undefined&&video.paused')! == 'true'
	assert first.state == .rejected && second.state == .rejected
	assert first.result.dom_exception_?.name() == 'AbortError'
	assert first.result.dom_exception_?.message() == 'Media playback was aborted'
	assert voidptr(first.result.dom_exception_?) == voidptr(second.result.dom_exception_?)
	native_play_checkpoint()
	assert runtime.evaluate_host(r'nativeLoadPlayReasons.length===2&&nativeLoadPlayReasons[0]===nativeLoadPlayReasons[1]&&nativeLoadPlayReasons[0] instanceof DOMException&&nativeLoadPlayReasons[0].name==="AbortError"&&nativeLoadPlayReasons[0].code===20&&nativeLoadPlayReasons[0].message==="Media playback was aborted"')! == 'true'
	native_play_drain_tasks(media)
	assert media.event_count('play') == 0 && media.event_count('waiting') == 0
	assert state.fetches == 2 && media.paused()
	media.set_source('')
	media.load()!
	native_play_drain_tasks(media)
	native_play_checkpoint()
}

fn test_native_pause_leaves_an_earlier_queued_playing_batch_fulfillable() {
	$if !darwin {
		return
	}
	mut policy := html.AutoplaySettings.the()
	previous_policy := policy.policy()
	previous_allowlist := policy.allowlist().map(it.serialize())
	defer { policy.set_policy(previous_policy, previous_allowlist) }
	policy.set_policy(.allow_audio_and_video, [])
	mut runtime, mut media := native_play_fixture(none)!
	defer { runtime.close() }
	state := &NativePlayObservation{}
	native_play_waiting_owner(mut media, state)!
	runtime.evaluate_host(r'globalThis.nativeCapturedPlayingFulfilled=false;globalThis.nativeCapturedPlayingReasons=[];globalThis.nativeCapturedPlayingEvents=[];globalThis.nativeCapturedPlaying=video.play();nativeCapturedPlaying.then(()=>nativeCapturedPlayingFulfilled=true,error=>nativeCapturedPlayingReasons.push(error));')!
	native := native_play_capability(runtime, 'nativeCapturedPlaying')!
	native_play_drain_tasks(media)
	media.set_ready_state(.have_future_data)
	assert native.state == .pending && state.starts == 1
	assert runtime.evaluate_host(r'for(const name of ["playing","timeupdate","pause"])video.addEventListener(name,()=>nativeCapturedPlayingEvents.push(name));video.pause()===undefined&&video.paused&&!nativeCapturedPlayingFulfilled')! == 'true'
	assert native.state == .pending
	native_play_drain_tasks(media)
	assert native.state == .fulfilled && native.result.kind == .undefined && media.paused()
	native_play_checkpoint()
	assert runtime.evaluate_host(r'nativeCapturedPlayingFulfilled&&nativeCapturedPlayingReasons.length===0&&nativeCapturedPlayingEvents.join(",")==="playing,timeupdate,pause"')! == 'true'
	media.set_source('')
	media.load()!
	native_play_drain_tasks(media)
	native_play_checkpoint()
}

fn test_native_play_waiting_capability_can_finish_after_its_javascript_runtime_closes() {
	$if !darwin {
		return
	}
	mut policy := html.AutoplaySettings.the()
	previous_policy := policy.policy()
	previous_allowlist := policy.allowlist().map(it.serialize())
	defer { policy.set_policy(previous_policy, previous_allowlist) }
	policy.set_policy(.allow_audio_and_video, [])
	mut runtime, mut media := native_play_fixture(none)!
	defer { runtime.close() }
	state := &NativePlayObservation{}
	native_play_waiting_owner(mut media, state)!
	assert runtime.evaluate_host('globalThis.nativeClosingPlay=video.play();nativeClosingPlay instanceof Promise')! == 'true'
	native := native_play_capability(runtime, 'nativeClosingPlay')!
	native_play_drain_tasks(media)
	assert native.state == .pending
	runtime.close()
	assert runtime.closed && runtime.context == unsafe { nil } && runtime.protected_values_.len == 0
	media.set_ready_state(.have_future_data)
	native_play_drain_tasks(media)
	assert native.state == .fulfilled && native.result.kind == .undefined
	native_play_checkpoint()
	assert runtime.closed && runtime.context == unsafe { nil } && runtime.protected_values_.len == 0
	media.set_source('')
	media.load()!
	native_play_drain_tasks(media)
	native_play_checkpoint()
}

fn test_native_play_fetch_failure_rejects_with_the_actual_typed_source_error() {
	$if !darwin {
		return
	}
	mut policy := html.AutoplaySettings.the()
	previous_policy := policy.policy()
	previous_allowlist := policy.allowlist().map(it.serialize())
	defer { policy.set_policy(previous_policy, previous_allowlist) }
	policy.set_policy(.allow_audio_and_video, [])
	mut runtime, mut media := native_play_fixture(none)!
	defer { runtime.close() }
	state := &NativePlayObservation{}
	media.set_source('/failing.mp4')
	media.set_fetch_hook(fn [state] (_ dom.URL, _ u64) !html.MediaResourceResponse {
		mut observation := unsafe { &NativePlayObservation(state) }
		observation.fetches++
		return error('Selected decoder \x00 🎬 unavailable')
	})
	assert runtime.evaluate_host(r'globalThis.nativeFetchedPlayReason=null;globalThis.nativeFetchedPlay=video.play();nativeFetchedPlay.catch(error=>nativeFetchedPlayReason=error);nativeFetchedPlay instanceof Promise')! == 'true'
	assert native_play_capability(runtime, 'nativeFetchedPlay')!.state == .rejected
	native_play_checkpoint()
	assert runtime.evaluate_host(r'nativeFetchedPlayReason instanceof DOMException&&nativeFetchedPlayReason.name==="NotSupportedError"&&nativeFetchedPlayReason.code===9&&nativeFetchedPlayReason.message==="Selected decoder \u0000 🎬 unavailable"')! == 'true'
	assert state.fetches == 1 && media.error()?.message() == 'Selected decoder \x00 🎬 unavailable'
	native_play_drain_tasks(media)
	media.set_source('')
	media.load()!
	native_play_drain_tasks(media)
	native_play_checkpoint()
}

fn test_native_ended_task_rejects_waiting_play_with_a_typed_abort_error() {
	$if !darwin {
		return
	}
	mut policy := html.AutoplaySettings.the()
	previous_policy := policy.policy()
	previous_allowlist := policy.allowlist().map(it.serialize())
	defer { policy.set_policy(previous_policy, previous_allowlist) }
	policy.set_policy(.allow_audio_and_video, [])
	mut runtime, mut media := native_play_fixture(none)!
	defer { runtime.close() }
	state := &NativePlayObservation{}
	native_play_waiting_owner(mut media, state)!
	runtime.evaluate_host(r'globalThis.nativeEndedPlayReason=null;globalThis.nativeEndedPlay=video.play();nativeEndedPlay.catch(error=>nativeEndedPlayReason=error);')!
	native := native_play_capability(runtime, 'nativeEndedPlay')!
	native_play_drain_tasks(media)
	media.set_current_playback_position(media.duration())
	media.reached_end_of_media_playback()
	assert native.state == .pending
	(native_play_take_task(media) or { panic('missing ended task') }).execute()
	assert native.state == .rejected && media.paused()
	native_play_checkpoint()
	assert runtime.evaluate_host(r'nativeEndedPlayReason instanceof DOMException&&nativeEndedPlayReason.name==="AbortError"&&nativeEndedPlayReason.code===20&&nativeEndedPlayReason.message==="Media playback has ended"')! == 'true'
	assert media.event_count('ended') == 1
	media.set_source('')
	media.load()!
	native_play_drain_tasks(media)
	native_play_checkpoint()
}
