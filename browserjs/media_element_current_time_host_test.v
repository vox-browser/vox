module browserjs

import dom
import html

@[heap]
struct NativeMediaTimeObservation {
mut:
	position f64
	reads    int
	replays  int
	seeks    []f64
	modes    []html.MediaPlaybackSeekMode
}

fn native_media_time_fixture(replay ?MediaElementReplayHook) !(&Runtime, &MediaElementHost, &html.HTMLMediaElement, &html.HTMLMediaElement) {
	address := dom.URL{
		value: 'https://native-media-time.example.test/'
	}
	document := html.parse_navigation_document('<video id="video"></video><audio id="audio"></audio>',
		address, address.origin(), none)!
	mut runtime := Runtime.create()
	mut host := MediaElementHost.create(document, replay)!
	host.install(mut runtime)!
	for key, element in host.elements_for_binding() {
		if element.local_name() in ['video', 'audio'] {
			name := element.local_name()
			runtime.evaluate_host('globalThis.${name}={};__ladybirdMediaElementBind(${name},"${key}","${name}")')!
		}
	}
	first_element := document.get_element_by_id('video') or { return error('missing video') }
	second_element := document.get_element_by_id('audio') or { return error('missing audio') }
	first := html.html_media_element_for_dom_element(first_element) or {
		return error('missing video owner')
	}
	second := html.html_media_element_for_dom_element(second_element) or {
		return error('missing audio owner')
	}
	return runtime, host, first, second
}

fn native_media_time_clock(state &NativeMediaTimeObservation) html.MediaPlaybackManagerHooks {
	return html.MediaPlaybackManagerHooks{
		current_time: fn [state] () f64 {
			mut clock := unsafe { &NativeMediaTimeObservation(state) }
			clock.reads++
			return clock.position
		}
	}
}

fn test_native_current_time_descriptor_and_receiver_checks_precede_conversion_and_replay() {
	$if !darwin { return }
	state := &NativeMediaTimeObservation{}
	mut runtime, _, _, _ := native_media_time_fixture(fn [state] (_ &Runtime) ! {
		mut observation := unsafe { &NativeMediaTimeObservation(state) }
		observation.replays++
	})!
	defer { runtime.close() }
	assert runtime.evaluate_host(r'(()=>{
 const p=HTMLMediaElement.prototype,d=Object.getOwnPropertyDescriptor(p,"currentTime");let traps=0,conversions=0;
 if(!d||!d.enumerable||!d.configurable||d.get.name!=="get currentTime"||d.set.name!=="set currentTime"||d.get.length!==0||d.set.length!==1||Object.hasOwn(video,"currentTime"))return false;
 if(![d.get,d.set].every(fn=>Function.prototype.toString.call(fn).includes("[native code]")))return false;
 const proxy=new Proxy(video,{get(){traps++;throw "proxy"},getPrototypeOf(){traps++;throw "proxy"}}),value={[Symbol.toPrimitive](){conversions++;return 2}};
 const passed=[Object.create(p),proxy,null,undefined,1].every(receiver=>{
  let get=false,set=false;try{d.get.call(receiver)}catch(error){get=error instanceof TypeError}
  try{d.set.call(receiver,value)}catch(error){set=error instanceof TypeError}return get&&set;
 });return passed&&traps===0&&conversions===0;
})()')! == 'true'
	assert state.replays == 0
	assert runtime.evaluate_host('video.currentTime===0&&audio.currentTime===0')! == 'true'
	assert state.replays == 2
}

fn test_native_current_time_restricted_double_conversion_and_default_start_use_the_owner() {
	$if !darwin { return }
	mut runtime, _, media, _ := native_media_time_fixture(none)!
	defer { runtime.close() }
	assert runtime.evaluate_host(r'(()=>{
 const d=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"currentTime");if(!d)return false;
 video.currentTime=2;
 const invalid=[undefined,NaN,Infinity,-Infinity,Symbol(),1n,Object(1n),{valueOf(){return NaN}},{[Symbol.toPrimitive](){return 2n}}];
 if(!invalid.every(value=>{try{video.currentTime=value;return false}catch(error){return error instanceof TypeError&&video.currentTime===2}}))return false;
 try{d.set.call(video);return false}catch(error){if(!(error instanceof TypeError))return false}
 const values=[["2.5",2.5],[null,0],[false,0],[true,1],["",0],[{valueOf(){return -2}},-2]];
 if(!values.every(([value,expected])=>{video.currentTime=value;return video.currentTime===expected}))return false;
 globalThis.Number=function(){throw "author Number"};
 let hints=[];const value={[Symbol.toPrimitive](hint){hints.push(hint);return 3}};
 const assigned=(video.currentTime=audio.currentTime=value);
 return assigned===value&&hints.join(",")==="number,number"&&video.currentTime===3&&audio.currentTime===3&&!Object.hasOwn(video,"currentTime")&&!Object.hasOwn(audio,"currentTime")&&d.set.call(video,-2)===undefined&&video.currentTime===-2;
})()')! == 'true'
	assert media.current_time() == -2 && media.ready_state() == .have_nothing
}

fn test_native_current_time_keeps_original_conversion_and_replay_exceptions() {
	$if !darwin { return }
	state := &NativeMediaTimeObservation{}
	mut runtime, _, media, _ := native_media_time_fixture(fn [state] (runtime &Runtime) ! {
		mut observation := unsafe { &NativeMediaTimeObservation(state) }
		observation.replays++
		mut owner := unsafe { &Runtime(runtime) }
		_ = owner.evaluate_host_value('throw timeReplayReason')!
	})!
	defer { runtime.close() }
	assert runtime.evaluate_host(r'globalThis.timeReplayReason={};globalThis.timeConversionReason={};(()=>{
 const d=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"currentTime");if(!d)return false;
 let get=false,set=false,conversion=false,finite=false;
 try{d.get.call(video)}catch(error){get=error===timeReplayReason}
 try{d.set.call(video,{[Symbol.toPrimitive](hint){if(hint!=="number")throw "wrong hint";return 2}})}catch(error){set=error===timeReplayReason}
 try{d.set.call(video,{[Symbol.toPrimitive](){throw timeConversionReason}})}catch(error){conversion=error===timeConversionReason}
 try{d.set.call(video,Infinity)}catch(error){finite=error instanceof TypeError}
 return get&&set&&conversion&&finite;
})()')! == 'true'
	assert state.replays == 2 && media.current_time() == 0
}

fn test_native_current_time_samples_each_actual_generation_and_keeps_owner_caches_separate() {
	$if !darwin { return }
	mut runtime, _, mut first, mut second := native_media_time_fixture(none)!
	defer { runtime.close() }
	mut first_clock := &NativeMediaTimeObservation{
		position: 2
	}
	mut second_clock := &NativeMediaTimeObservation{
		position: 9
	}
	first.set_playback_manager_hooks(native_media_time_clock(first_clock))
	second.set_playback_manager_hooks(native_media_time_clock(second_clock))
	mut loop := html.main_thread_event_loop()
	loop.process()
	assert runtime.evaluate_host('video.currentTime===2&&video.currentTime===2&&audio.currentTime===9')! == 'true'
	assert first_clock.reads == 1 && second_clock.reads == 1
	first_clock.position = 3
	second_clock.position = 10
	assert runtime.evaluate_host('globalThis.timeMicrotaskValue=-1;Promise.resolve().then(()=>timeMicrotaskValue=video.currentTime);video.currentTime===2&&audio.currentTime===9')! == 'true'
	generation := loop.task_generation()
	loop.perform_a_microtask_checkpoint()
	assert runtime.evaluate_host('timeMicrotaskValue===2')! == 'true'
	assert loop.task_generation() == generation
	assert first_clock.reads == 1 && second_clock.reads == 1
	loop.process()
	assert runtime.evaluate_host('video.currentTime===3&&audio.currentTime===10')! == 'true'
	assert first_clock.reads == 2 && second_clock.reads == 2
	settings := unsafe { &html.EnvironmentSettingsObject(first.document()?.relevant_settings_object()) }
	assert settings.realm().script_execution_depth == 0
		&& settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
}

fn test_native_current_time_metadata_setter_requests_seek_and_commits_the_adjusted_clock() {
	$if !darwin { return }
	mut runtime, _, mut media, _ := native_media_time_fixture(none)!
	defer { runtime.close() }
	media.set_fetch_hook(fn (_ dom.URL, _ u64) !html.MediaResourceResponse {
		return html.MediaResourceResponse{ mime_type: 'video/mp4', duration: 10, buffered_end: 10 }
	})
	media.set_source('https://native-media-time.example.test/movie.mp4')
	media.load()!
	mut clock := &NativeMediaTimeObservation{
		position: 2
	}
	base_hooks := native_media_time_clock(clock)
	media.set_playback_manager_hooks(html.MediaPlaybackManagerHooks{
		...base_hooks
		seek: fn [clock] (value f64, mode html.MediaPlaybackSeekMode) {
			mut observation := unsafe { &NativeMediaTimeObservation(clock) }
			observation.seeks << value
			observation.modes << mode
			observation.position = if value == 7 { 4.0 } else { value }
		}
	})
	mut loop := html.main_thread_event_loop()
	loop.process()
	assert runtime.evaluate_host('video.currentTime===2')! == 'true'
	reads := clock.reads
	assert runtime.evaluate_host('video.currentTime="7";video.currentTime===4&&video.seeking&&!Object.hasOwn(video,"currentTime")')! == 'true'
	assert clock.seeks == [7.0] && clock.modes == [.accurate]
	assert clock.reads == reads + 1
	clock.position = 8
	assert runtime.evaluate_host('video.currentTime===4')! == 'true'
	loop.process()
	assert runtime.evaluate_host('video.currentTime===8')! == 'true'
	assert runtime.evaluate_host('video.currentTime=Number.MAX_VALUE;video.currentTime===10')! == 'true'
	assert runtime.evaluate_host('video.currentTime=-3;video.currentTime===0')! == 'true'
	assert clock.seeks == [7.0, 10.0, 0.0] && clock.modes == [.accurate, .accurate, .accurate]
	media.set_source('')
	media.load()!
}
