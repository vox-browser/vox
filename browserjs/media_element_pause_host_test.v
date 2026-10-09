module browserjs

import dom
import html

@[heap]
struct NativePauseObservation {
mut:
	position f64
	replays  int
	fetches  int
	pauses   int
}

fn native_pause_fixture(replay ?MediaElementReplayHook) !(&Runtime, &html.HTMLMediaElement) {
	url := dom.URL{ value: 'https://native-pause.example.test/' }
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

fn test_native_pause_descriptor_brand_precedes_replay_and_ignores_extra_arguments() {
	$if !darwin { return }
	state := &NativePauseObservation{}
	mut runtime, media := native_pause_fixture(fn [state] (_ &Runtime) ! {
		mut observation := unsafe { &NativePauseObservation(state) }
		observation.replays++
	})!
	defer { runtime.close() }
	assert runtime.evaluate_host(r'(()=>{
 const d=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"pause");
 if(!d||!d.writable||!d.enumerable||!d.configurable||d.value.name!=="pause"||d.value.length!==0||!Function.prototype.toString.call(d.value).includes("[native code]")||Object.hasOwn(video,"pause"))return false;
 let traps=0,conversions=0;const proxy=new Proxy(video,{get(){traps++;throw "proxy"},getPrototypeOf(){traps++;throw "proxy"}}),extra={[Symbol.toPrimitive](){conversions++;throw "extra argument"}};
 for(const receiver of [Object.create(HTMLMediaElement.prototype),proxy,null,undefined,1]){
  try{d.value.call(receiver,extra);return false}catch(error){if(!(error instanceof TypeError)||error.message!=="Not an object of type HTMLMediaElement")return false}
 }
 return traps===0&&conversions===0;
})()')! == 'true'
	assert state.replays == 0
	assert runtime.evaluate_host(r'(()=>{
 const extra=new Proxy({},{get(){throw "unused extra argument"}});
 return video.pause(extra,Symbol(),1n)===undefined&&audio.pause()===undefined;
})()')! == 'true'
	assert state.replays == 2 && media.paused()
}

fn test_native_pause_loaded_owner_commits_the_live_clock_and_does_not_refetch() {
	// This task/state regression exercises a permitted explicit play request.
	mut playback_policy := html.AutoplaySettings.the()
	previous_policy := playback_policy.policy()
	previous_allowlist := playback_policy.allowlist().map(it.serialize())
	defer { playback_policy.set_policy(previous_policy, previous_allowlist) }
	playback_policy.set_policy(.allow_audio_and_video, [])
	$if !darwin { return }
	mut runtime, mut media := native_pause_fixture(none)!
	defer { runtime.close() }
	state := &NativePauseObservation{ position: 3 }
	media.set_fetch_hook(fn [state] (_ dom.URL, _ u64) !html.MediaResourceResponse {
		mut observation := unsafe { &NativePauseObservation(state) }
		observation.fetches++
		return html.MediaResourceResponse{ mime_type: 'video/mp4', duration: 10, buffered_end: 10 }
	})
	media.set_source('/movie.mp4')
	media.load()!
	media.set_playback_manager_hooks(html.MediaPlaybackManagerHooks{
		current_time: fn [state] () f64 { return state.position }
		pause: fn [state] () {
			mut observation := unsafe { &NativePauseObservation(state) }
			observation.pauses++
		}
	})
	media.play()
	assert !media.paused()
	previous := media.current_time()
	mut clock := unsafe { &NativePauseObservation(state) }
	clock.position = 9
	assert media.current_time() == previous
	assert runtime.evaluate_host(r'(()=>{
 if(typeof video.pause!=="function")return false;
 const result=video.pause();video.pause();
 return result===undefined&&video.paused&&video.currentTime===9&&audio.paused&&audio.currentTime===0;
})()')! == 'true'
	assert state.fetches == 1 && state.pauses == 1 && media.current_time() == 9
	media.set_source('')
	media.load()!
}

fn test_native_pause_selects_the_actual_empty_dom_resource() {
	$if !darwin { return }
	mut runtime, mut media := native_pause_fixture(none)!
	defer { runtime.close() }
	state := &NativePauseObservation{}
	media.set_source('/selected.mp4')
	media.set_fetch_hook(fn [state] (_ dom.URL, _ u64) !html.MediaResourceResponse {
		mut observation := unsafe { &NativePauseObservation(state) }
		observation.fetches++
		return html.MediaResourceResponse{ mime_type: 'video/mp4', duration: 10, buffered_end: 10 }
	})
	assert runtime.evaluate_host(r'(()=>{
 if(typeof video.pause!=="function")return false;
 return video.pause()===undefined&&video.paused&&video.readyState===4&&video.currentSrc==="https://native-pause.example.test/selected.mp4"&&audio.networkState===0;
})()')! == 'true'
	assert state.fetches == 1 && media.paused()
	media.set_source('')
	media.load()!
}

fn test_native_pause_preserves_original_replay_exception_before_model_mutation() {
	$if !darwin { return }
	state := &NativePauseObservation{}
	mut runtime, mut media := native_pause_fixture(fn [state] (runtime &Runtime) ! {
		mut observation := unsafe { &NativePauseObservation(state) }
		observation.replays++
		mut owner := unsafe { &Runtime(runtime) }
		_ = owner.evaluate_host_value('throw pauseReplayReason')!
	})!
	defer { runtime.close() }
	media.set_paused(false)
	assert runtime.evaluate_host(r'globalThis.pauseReplayReason={};(()=>{
 if(typeof video.pause!=="function")return false;
 try{video.pause({valueOf(){throw "extra argument"}});return false}catch(error){return error===pauseReplayReason}
})()')! == 'true'
	assert state.replays == 1 && !media.paused()
}
