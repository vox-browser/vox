module browserjs

import dom
import html

@[heap]
struct NativeLoadObservation {
mut:
	replays int
	fetches int
}

fn native_load_fixture(replay ?MediaElementReplayHook) !(&Runtime, &html.HTMLMediaElement) {
	url := dom.URL{ value: 'https://native-load.example.test/' }
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

fn test_native_load_descriptor_brand_precedes_replay_and_ignores_extra_arguments() {
	$if !darwin { return }
	state := &NativeLoadObservation{}
	mut runtime, media := native_load_fixture(fn [state] (_ &Runtime) ! {
		mut observation := unsafe { &NativeLoadObservation(state) }
		observation.replays++
	})!
	defer { runtime.close() }
	assert runtime.evaluate_host(r'(()=>{
 const d=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"load");
 if(!d||!d.writable||!d.enumerable||!d.configurable||d.value.name!=="load"||d.value.length!==0||!Function.prototype.toString.call(d.value).includes("[native code]")||Object.hasOwn(video,"load"))return false;
 let traps=0,conversions=0;const proxy=new Proxy(video,{get(){traps++;throw "proxy"},getPrototypeOf(){traps++;throw "proxy"}}),extra={[Symbol.toPrimitive](){conversions++;throw "extra argument"}};
 for(const receiver of [Object.create(HTMLMediaElement.prototype),proxy,null,undefined,1]){
  try{d.value.call(receiver,extra);return false}catch(error){if(!(error instanceof TypeError)||error.message!=="Not an object of type HTMLMediaElement")return false}
 }
 return traps===0&&conversions===0;
})()')! == 'true'
	assert state.replays == 0
	assert runtime.evaluate_host(r'(()=>{
 if(typeof video.load!=="function")return false;
 const extra=new Proxy({},{get(){throw "unused extra argument"}});
 return video.load(extra,Symbol(),1n)===undefined&&audio.load()===undefined;
})()')! == 'true'
	assert state.replays == 2 && media.paused()
}

fn test_native_load_promotes_the_actual_preload_none_owner_and_resets_its_rate() {
	$if !darwin { return }
	mut runtime, mut media := native_load_fixture(none)!
	defer { runtime.close() }
	state := &NativeLoadObservation{}
	media.set_fetch_hook(fn [state] (_ dom.URL, _ u64) !html.MediaResourceResponse {
		mut observation := unsafe { &NativeLoadObservation(state) }
		observation.fetches++
		return html.MediaResourceResponse{ mime_type: 'video/mp4', duration: 10, buffered_end: 10 }
	})
	media.set_source('/selected.mp4')
	media.set_preload('none')
	media.select_resource()!
	assert state.fetches == 0 && media.network_state() == .idle
	assert runtime.evaluate_host(r'(()=>{
 if(typeof video.load!=="function")return false;
 video.defaultPlaybackRate=2;
 return video.load()===undefined&&video.paused&&video.playbackRate===2&&video.readyState===4&&video.currentSrc==="https://native-load.example.test/selected.mp4"&&audio.networkState===0;
})()')! == 'true'
	assert state.fetches == 1 && media.playback_rate() == 2
	media.set_source('')
	media.load()!
	mut loop := html.main_thread_event_loop()
	for _ in 0 .. 100 { loop.process() }
}

fn test_native_load_preserves_original_replay_exception_before_model_mutation() {
	$if !darwin { return }
	state := &NativeLoadObservation{}
	mut runtime, mut media := native_load_fixture(fn [state] (runtime &Runtime) ! {
		mut observation := unsafe { &NativeLoadObservation(state) }
		observation.replays++
		mut owner := unsafe { &Runtime(runtime) }
		_ = owner.evaluate_host_value('throw loadReplayReason')!
	})!
	defer { runtime.close() }
	media.set_paused(false)
	assert runtime.evaluate_host(r'globalThis.loadReplayReason={};(()=>{
 if(typeof video.load!=="function")return false;
 try{video.load({valueOf(){throw "extra argument"}});return false}catch(error){return error===loadReplayReason}
})()')! == 'true'
	assert state.replays == 1 && !media.paused()
}

fn test_native_load_rate_validation_throws_an_actual_not_supported_dom_exception() {
	$if !darwin { return }
	mut runtime, mut media := native_load_fixture(none)!
	defer { runtime.close() }
	state := &NativeLoadObservation{}
	media.set_source('/not-fetched.mp4')
	media.set_fetch_hook(fn [state] (_ dom.URL, _ u64) !html.MediaResourceResponse {
		mut observation := unsafe { &NativeLoadObservation(state) }
		observation.fetches++
		return html.MediaResourceResponse{ mime_type: 'video/mp4', duration: 10 }
	})
	assert runtime.evaluate_host(r'(()=>{
 if(typeof video.load!=="function")return false;
 video.defaultPlaybackRate=65;
 try{video.load();return false}catch(error){return error instanceof DOMException&&error.name==="NotSupportedError"&&error.code===9&&video.playbackRate===1&&video.currentSrc===""}
})()')! == 'true'
	assert state.fetches == 0
}
