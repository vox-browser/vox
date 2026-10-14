module browserjs

import dom
import html

@[heap]
struct MediaTimelineRangesProbe {
mut:
	replays  int
	fetches  int
	plays    int
	pauses   int
	position f64
}

fn media_timeline_ranges_fixture(replay ?MediaElementReplayHook) !(&Runtime, &MediaElementHost, &dom.Document, &html.HTMLMediaElement) {
	address := dom.URL{ value: 'https://media-timeline-ranges.example.test/' }
	mut document := html.parse_navigation_document('<!doctype html><video id="timeline-video"></video><audio id="timeline-audio"></audio>',
		address, address.origin(), none)!
	mut runtime := Runtime.create()
	mut host := MediaElementHost.create(document, replay)!
	host.install(mut runtime)!
	for key, element in host.elements_for_binding() {
		if element.local_name() == 'video' {
			runtime.evaluate_host('globalThis.mediaTimelineVideo={};__ladybirdMediaElementBind(mediaTimelineVideo,"' + key + '","video");0')!
		} else if element.local_name() == 'audio' {
			runtime.evaluate_host('globalThis.mediaTimelineAudio={};__ladybirdMediaElementBind(mediaTimelineAudio,"' + key + '","audio");0')!
		}
	}
	element := document.get_element_by_id('timeline-video') or { return error('Missing timeline video') }
	media := html.html_media_element_for_dom_element(element) or { return error('Missing timeline media owner') }
	return runtime, host, document, media
}

fn media_timeline_ranges_drain(document &dom.Document) {
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

fn test_native_media_timeline_ranges_are_readonly_branded_fresh_empty_snapshots() {
	$if !darwin { return }
	probe := &MediaTimelineRangesProbe{}
	mut runtime, _, mut document, _ := media_timeline_ranges_fixture(fn [probe] (_ &Runtime) ! {
		mut state := unsafe { &MediaTimelineRangesProbe(probe) }
		state.replays++
	})!
	defer {
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host(r'(()=>{
 const p=HTMLMediaElement.prototype;let traps=0;
 const proxy=new Proxy(mediaTimelineVideo,{get(){traps++;throw "proxy"},getPrototypeOf(){traps++;throw "proxy"}});
 return ["played","seekable"].every(name=>{
  const d=Object.getOwnPropertyDescriptor(p,name);
  return d.enumerable&&d.configurable&&d.set===undefined&&d.get.name==="get "+name&&d.get.length===0&&Function.prototype.toString.call(d.get).includes("[native code]")&&
   [Object.create(p),proxy,null,undefined,1,{}].every(receiver=>{try{d.get.call(receiver);return false}catch(error){return error instanceof TypeError&&error.message==="Not an object of type HTMLMediaElement"}})&&
   !Object.hasOwn(mediaTimelineVideo,name)&&!Object.hasOwn(mediaTimelineAudio,name)&&!Reflect.set(mediaTimelineVideo,name,{});
 })&&traps===0&&Object.getPrototypeOf(p)===EventTarget.prototype;
})()')! == 'true'
	assert probe.replays == 0
	// Appending the two getters must leave every previous getter index intact.
	assert runtime.evaluate_host('mediaTimelineVideo.error===null&&mediaTimelineVideo.currentTime===0&&mediaTimelineVideo.volume===1&&mediaTimelineVideo.buffered.length===0')! == 'true'
	assert probe.replays == 4
	assert runtime.evaluate_host(r'globalThis.mediaTimelineEmptyPlayed=mediaTimelineVideo.played;globalThis.mediaTimelineEmptySeekable=mediaTimelineVideo.seekable;
 mediaTimelineEmptyPlayed instanceof TimeRanges&&mediaTimelineEmptySeekable instanceof TimeRanges&&mediaTimelineEmptyPlayed!==mediaTimelineEmptySeekable&&mediaTimelineEmptyPlayed.length===0&&mediaTimelineEmptySeekable.length===0&&mediaTimelineEmptyPlayed!==mediaTimelineVideo.played&&mediaTimelineEmptySeekable!==mediaTimelineVideo.seekable&&mediaTimelineAudio.played.length===0&&mediaTimelineAudio.seekable.length===0')! == 'true'
	assert probe.replays == 10
	object := runtime.evaluate_host_value('mediaTimelineEmptyPlayed')!
	actual := runtime.native_time_ranges(object)!
	assert actual.length() == 0 && runtime.javascript_time_ranges(actual)! == object
	assert runtime.evaluate_host(r'(()=>{
 try{mediaTimelineEmptySeekable.start(0);return false}catch(error){return error instanceof DOMException&&error.name==="IndexSizeError"&&error.code===1}
})()')! == 'true'
}

fn test_native_media_timeline_ranges_snapshot_actual_resource_and_play_pause_records_then_survive_load() {
	$if !darwin { return }
	mut policy := html.AutoplaySettings.the()
	old_policy := policy.policy()
	old_allowlist := policy.allowlist().map(it.serialize())
	defer { policy.set_policy(old_policy, old_allowlist) }
	policy.set_policy(.allow_audio_and_video, [])
	mut runtime, _, mut document, mut media := media_timeline_ranges_fixture(none)!
	defer {
		runtime.close()
		document.finalize()
	}
	probe := &MediaTimelineRangesProbe{}
	media.set_source('/timeline.mp4')
	media.set_fetch_hook(fn [probe] (url dom.URL, offset u64) !html.MediaResourceResponse {
		assert url.serialize() == 'https://media-timeline-ranges.example.test/timeline.mp4' && offset == 0
		mut state := unsafe { &MediaTimelineRangesProbe(probe) }
		state.fetches++
		return html.MediaResourceResponse{ mime_type: 'video/mp4', duration: 10, buffered_end: 10 }
	})
	media.load()!
	media_timeline_ranges_drain(document)
	assert probe.fetches == 1 && media.seekable().length() == 1 && media.played().length() == 0
	assert runtime.evaluate_host(r'globalThis.mediaTimelineSavedSeekable=mediaTimelineVideo.seekable;globalThis.mediaTimelineBeforePlayed=mediaTimelineVideo.played;
 mediaTimelineSavedSeekable.length===1&&mediaTimelineSavedSeekable.start(0)===0&&mediaTimelineSavedSeekable.end(0)===10&&mediaTimelineSavedSeekable!==mediaTimelineVideo.seekable&&mediaTimelineBeforePlayed.length===0')! == 'true'
	media.set_playback_manager_hooks(html.MediaPlaybackManagerHooks{
		current_time: fn [probe] () f64 { return probe.position }
		play: fn [probe] () {
			mut state := unsafe { &MediaTimelineRangesProbe(probe) }
			state.plays++
		}
		pause: fn [probe] () {
			mut state := unsafe { &MediaTimelineRangesProbe(probe) }
			state.pauses++
		}
	})
	media.set_current_playback_position(0)
	media.set_official_playback_position(0)
	assert runtime.evaluate_host(r'globalThis.mediaTimelinePlayErrors=[];globalThis.mediaTimelinePlayPromise=mediaTimelineVideo.play();mediaTimelinePlayPromise.catch(reason=>mediaTimelinePlayErrors.push(reason));mediaTimelinePlayPromise instanceof Promise&&!mediaTimelineVideo.paused&&mediaTimelineVideo.played.length===0')! == 'true'
	media_timeline_ranges_drain(document)
	mut clock := unsafe { &MediaTimelineRangesProbe(probe) }
	clock.position = 7
	media.set_current_playback_position(7)
	media.set_official_playback_position(7)
	assert runtime.evaluate_host(r'mediaTimelineVideo.pause();globalThis.mediaTimelineSavedPlayed=mediaTimelineVideo.played;
 mediaTimelineVideo.paused&&mediaTimelineSavedPlayed.length===1&&mediaTimelineSavedPlayed.start(0)===0&&mediaTimelineSavedPlayed.end(0)===7&&mediaTimelineSavedPlayed!==mediaTimelineVideo.played&&mediaTimelineBeforePlayed.length===0')! == 'true'
	media_timeline_ranges_drain(document)
	assert probe.plays == 1 && probe.pauses == 1 && probe.fetches == 1
	actual := runtime.native_time_ranges(runtime.evaluate_host_value('mediaTimelineSavedPlayed')!)!
	assert actual.start(0)! == 0 && actual.end(0)! == 7
	// This preserves existing model snapshots, not upstream played normalization.
	runtime.evaluate_host(r'globalThis.mediaTimelineRangePrototype=TimeRanges.prototype;globalThis.mediaTimelineAuthorCalls=0;globalThis.TimeRanges=function(){mediaTimelineAuthorCalls++;throw "author TimeRanges"};0')!
	assert runtime.evaluate_host(r'Object.getPrototypeOf(mediaTimelineVideo.played)===mediaTimelineRangePrototype&&Object.getPrototypeOf(mediaTimelineVideo.seekable)===mediaTimelineRangePrototype&&mediaTimelineVideo.seekable.end(0)===10&&mediaTimelineAuthorCalls===0&&mediaTimelinePlayErrors.length===0')! == 'true'
	media.set_source(none)
	assert runtime.evaluate_host(r'mediaTimelineVideo.load();mediaTimelineVideo.played.length===0&&mediaTimelineVideo.seekable.length===0&&mediaTimelineSavedPlayed.start(0)===0&&mediaTimelineSavedPlayed.end(0)===7&&mediaTimelineSavedSeekable.start(0)===0&&mediaTimelineSavedSeekable.end(0)===10&&mediaTimelineBeforePlayed.length===0&&mediaTimelineAuthorCalls===0')! == 'true'
	media_timeline_ranges_drain(document)
}

fn test_native_media_timeline_ranges_preserve_original_replay_errors_and_public_close_guards() {
	$if !darwin { return }
	mut runtime, _, mut document, _ := media_timeline_ranges_fixture(fn (runtime &Runtime) ! {
		mut owner := unsafe { &Runtime(runtime) }
		_ = owner.evaluate_host_value('throw mediaTimelineReplayReason')!
	})!
	defer {
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host(r'globalThis.mediaTimelineReplayReason={};["played","seekable"].every(name=>{try{void mediaTimelineVideo[name];return false}catch(error){return error===mediaTimelineReplayReason}})')! == 'true'
	mut normal, host, mut normal_document, _ := media_timeline_ranges_fixture(none)!
	defer {
		normal.close()
		normal_document.finalize()
	}
	object := normal.evaluate_host_value('mediaTimelineVideo.seekable')!
	actual := normal.native_time_ranges(object)!
	player := normal.evaluate_host_value('mediaTimelineVideo')!
	normal.close()
	assert normal.closed && normal.context == unsafe { nil } && normal.protected_values_.len == 0
	if _ := normal.native_time_ranges(object) {
		assert false
	} else {
		assert err.msg() == 'JavaScript runtime is closed'
	}
	if _ := normal.javascript_time_ranges(actual) {
		assert false
	} else {
		assert err.msg() == 'JavaScript runtime is closed'
	}
	if _ := host.media_element_for_binding(player) {
		assert false
	} else {
		assert err.msg() == 'Media element binding is closed'
	}
	assert host.elements_for_binding().len == 0
}
