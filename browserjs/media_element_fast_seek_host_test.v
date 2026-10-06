module browserjs

import dom
import html

@[heap]
struct NativeFastSeekObservation {
mut:
	position f64
	replays  int
	seeks    []f64
	modes    []html.MediaPlaybackSeekMode
}

fn native_fast_seek_fixture(replay ?MediaElementReplayHook) !(&Runtime, &html.HTMLMediaElement) {
	url := dom.URL{
		value: 'https://native-fast-seek.example.test/'
	}
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
	media := html.html_media_element_for_dom_element(element) or {
		return error('missing media owner')
	}
	return runtime, media
}

fn test_native_fast_seek_descriptor_receiver_and_required_argument_order() {
	$if !darwin { return }
	state := &NativeFastSeekObservation{}
	mut runtime, _ := native_fast_seek_fixture(fn [state] (_ &Runtime) ! {
		mut observation := unsafe { &NativeFastSeekObservation(state) }
		observation.replays++
	})!
	defer { runtime.close() }
	assert runtime.evaluate_host(r'(()=>{
 const d=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"fastSeek");if(!d||!d.writable||!d.enumerable||!d.configurable||d.value.name!=="fastSeek"||d.value.length!==1||!Function.prototype.toString.call(d.value).includes("[native code]")||Object.hasOwn(video,"fastSeek"))return false;
 let traps=0,conversions=0;const proxy=new Proxy(video,{get(){traps++;throw "proxy"},getPrototypeOf(){traps++;throw "proxy"}}),value={[Symbol.toPrimitive](){conversions++;return 2}};
 if(![Object.create(HTMLMediaElement.prototype),proxy,null,undefined,1].every(receiver=>{
  let brand=false,missing=false;try{d.value.call(receiver,value)}catch(error){brand=error instanceof TypeError&&error.message==="Not an object of type HTMLMediaElement"}
  try{d.value.call(receiver)}catch(error){missing=error instanceof TypeError&&error.message==="Not an object of type HTMLMediaElement"}return brand&&missing;
 }))return false;
 try{video.fastSeek();return false}catch(error){return error instanceof TypeError&&error.message==="fastSeek() needs one argument"&&traps===0&&conversions===0}
})()')! == 'true'
	assert state.replays == 0
}

fn test_native_fast_seek_converts_restricted_double_even_without_metadata() {
	$if !darwin { return }
	state := &NativeFastSeekObservation{}
	mut runtime, mut media := native_fast_seek_fixture(fn [state] (_ &Runtime) ! {
		mut observation := unsafe { &NativeFastSeekObservation(state) }
		observation.replays++
	})!
	defer { runtime.close() }
	media.set_current_time(6)
	assert runtime.evaluate_host(r'(()=>{
 if(typeof video.fastSeek!=="function")return false;
 const invalid=[undefined,NaN,Infinity,-Infinity,Symbol(),1n,Object(1n),{valueOf(){return NaN}},{[Symbol.toPrimitive](){return 2n}}];
 return invalid.every(value=>{try{video.fastSeek(value);return false}catch(error){return error instanceof TypeError}});
})()')! == 'true'
	assert state.replays == 0 && media.show_poster()
	assert runtime.evaluate_host(r'(()=>{
 globalThis.Number=function(){throw "author Number"};let hints=[];
 const values=["2.5",null,false,true,"",-2,{[Symbol.toPrimitive](hint){hints.push(hint);return -0}}];
 const ignored={valueOf(){throw "extra argument"}};
 return values.every(value=>video.fastSeek(value,ignored)===undefined)&&hints.join(",")==="number";
})()')! == 'true'
	assert state.replays == 7 && !media.show_poster()
	assert media.current_time() == 6 && !media.seeking()
}

fn test_native_fast_seek_preserves_original_conversion_and_replay_exceptions() {
	$if !darwin { return }
	state := &NativeFastSeekObservation{}
	mut runtime, media := native_fast_seek_fixture(fn [state] (runtime &Runtime) ! {
		mut observation := unsafe { &NativeFastSeekObservation(state) }
		observation.replays++
		mut owner := unsafe { &Runtime(runtime) }
		_ = owner.evaluate_host_value('throw fastSeekReplayReason')!
	})!
	defer { runtime.close() }
	assert runtime.evaluate_host(r'globalThis.fastSeekReplayReason={};globalThis.fastSeekConversionReason={};(()=>{
 if(typeof video.fastSeek!=="function")return false;let conversion=false,replay=false,finite=false;
 try{video.fastSeek({[Symbol.toPrimitive](){throw fastSeekConversionReason}})}catch(error){conversion=error===fastSeekConversionReason}
 try{video.fastSeek({[Symbol.toPrimitive](hint){if(hint!=="number")throw "wrong hint";return 2}})}catch(error){replay=error===fastSeekReplayReason}
 try{video.fastSeek(Infinity)}catch(error){finite=error instanceof TypeError&&error.message==="Expected time to be a finite floating-point number"}
 return conversion&&replay&&finite;
})()')! == 'true'
	assert state.replays == 1 && media.show_poster() && media.current_time() == 0
}

fn test_native_fast_seek_loaded_owner_uses_live_direction_clamps_and_adjusted_clock() {
	$if !darwin { return }
	mut runtime, mut media := native_fast_seek_fixture(none)!
	defer { runtime.close() }
	media.set_fetch_hook(fn (_ dom.URL, _ u64) !html.MediaResourceResponse {
		return html.MediaResourceResponse{ mime_type: 'video/mp4', duration: 10, buffered_end: 10 }
	})
	media.set_source('https://native-fast-seek.example.test/movie.mp4')
	media.load()!
	state := &NativeFastSeekObservation{
		position: 9
	}
	media.set_playback_manager_hooks(html.MediaPlaybackManagerHooks{
		current_time: fn [state] () f64 {
			return state.position
		}
		seek:         fn [state] (target f64, mode html.MediaPlaybackSeekMode) {
			mut observation := unsafe { &NativeFastSeekObservation(state) }
			observation.seeks << target
			observation.modes << mode
			observation.position = if target == 7 { 4.0 } else { target }
		}
	})
	assert runtime.evaluate_host(r'(()=>{
 if(typeof video.fastSeek!=="function")return false;
 if(video.fastSeek("7")!==undefined||video.currentTime!==4||!video.seeking)return false;
 video.fastSeek(8);video.fastSeek(8);video.fastSeek(Number.MAX_VALUE);video.fastSeek(-3);
 return video.currentTime===0&&audio.currentTime===0&&!Object.hasOwn(video,"fastSeek");
})()')! == 'true'
	assert state.seeks == [7.0, 8.0, 8.0, 10.0, 0.0]
	assert state.modes == [.fast_before, .fast_after, .accurate, .fast_after, .fast_before]
	assert !media.show_poster()
	media.set_source('')
	media.load()!
}
