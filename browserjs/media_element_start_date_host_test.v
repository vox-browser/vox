module browserjs

import dom
import html
import math

@[heap]
struct NativeStartDateObservation {
mut:
	replays int
	offset  ?i64
}

fn native_start_date_fixture(replay ?MediaElementReplayHook) !(&Runtime, &html.HTMLMediaElement) {
	url := dom.URL{ value: 'https://native-start-date.example.test/' }
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
	media := html.html_media_element_for_dom_element(element) or { return error('missing media') }
	return runtime, media
}

fn test_native_start_date_descriptor_and_brand_precede_replay_without_proxy_traps() {
	$if !darwin { return }
	state := &NativeStartDateObservation{}
	mut runtime, _ := native_start_date_fixture(fn [state] (_ &Runtime) ! {
		mut observation := unsafe { &NativeStartDateObservation(state) }
		observation.replays++
	})!
	defer { runtime.close() }
	assert runtime.evaluate_host(r'(()=>{
 const d=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"getStartDate");
 if(!d||!d.writable||!d.enumerable||!d.configurable||d.value.name!=="getStartDate"||d.value.length!==0||!Function.prototype.toString.call(d.value).includes("[native code]")||Object.hasOwn(video,"getStartDate"))return false;
 let traps=0;const proxy=new Proxy(video,{get(){traps++;throw "proxy"},getPrototypeOf(){traps++;throw "proxy"}});
 const invalid=[Object.create(HTMLMediaElement.prototype),proxy,null,undefined,1];
 return invalid.every(receiver=>{try{d.value.call(receiver);return false}catch(error){return error instanceof TypeError&&error.message==="Not an object of type HTMLMediaElement"}})&&traps===0;
})()')! == 'true'
	assert state.replays == 0
	assert runtime.evaluate_host(r'(()=>{let conversions=0;const ignored={[Symbol.toPrimitive](){conversions++;throw "extra argument"}};
 const a=video.getStartDate(ignored),b=video.getStartDate(),c=audio.getStartDate();
 return a instanceof Date&&b instanceof Date&&c instanceof Date&&a!==b&&Number.isNaN(a.getTime())&&Number.isNaN(b.getTime())&&Number.isNaN(c.getTime())&&conversions===0;})()')! == 'true'
	assert state.replays == 3
}

fn test_native_start_date_reads_live_metadata_and_load_reset_with_builtin_date_identity() {
	$if !darwin { return }
	mut runtime, mut media := native_start_date_fixture(none)!
	defer { runtime.close() }
	assert runtime.evaluate_host(r'globalThis.originalDate=Date;globalThis.dateTime=Date.prototype.getTime;
 globalThis.originalDatePrototype=Date.prototype;globalThis.dateApply=Reflect.apply;
 globalThis.savedInvalidDate=typeof video.getStartDate==="function"?video.getStartDate():null;
 globalThis.Date=function(){throw "author Date"};
 originalDate.prototype.getTime=function(){throw "author getTime"};savedInvalidDate!==null')! == 'true'
	state := &NativeStartDateObservation{ offset: i64(1_725_084_800_987_654) }
	media.set_playback_manager_hooks(html.MediaPlaybackManagerHooks{
		start_time_realtime: fn [state] () ?i64 { return state.offset }
	})
	media.on_metadata_parsed(10)
	assert runtime.evaluate_host(r'globalThis.savedStartDate=video.getStartDate();(()=>{
 const next=video.getStartDate();return savedStartDate instanceof originalDate&&Object.getPrototypeOf(savedStartDate)===originalDatePrototype&&next!==savedStartDate&&dateApply(dateTime,savedStartDate,[])===1725084800988&&dateApply(dateTime,next,[])===1725084800988&&Number.isNaN(dateApply(dateTime,savedInvalidDate,[]))&&Number.isNaN(dateApply(dateTime,audio.getStartDate(),[]));})()')! == 'true'
	mut observation := unsafe { &NativeStartDateObservation(state) }
	observation.offset = i64(-1_234_567)
	media.on_metadata_parsed(10)
	assert runtime.evaluate_host('dateApply(dateTime,video.getStartDate(),[])===-1235&&dateApply(dateTime,savedStartDate,[])===1725084800988')! == 'true'
	observation.offset = i64(-999)
	media.on_metadata_parsed(10)
	assert runtime.evaluate_host('dateApply(dateTime,video.getStartDate(),[])===-1')! == 'true'
	media.set_source(none)
	media.set_source_candidates([])
	media.load()!
	assert math.is_nan(media.get_start_date().get_time())
	assert runtime.evaluate_host('Number.isNaN(dateApply(dateTime,video.getStartDate(),[]))&&dateApply(dateTime,savedStartDate,[])===1725084800988')! == 'true'
}

fn test_native_start_date_preserves_replay_exception_and_samples_after_replay() {
	$if !darwin { return }
	state := &NativeStartDateObservation{}
	mut runtime, mut media := native_start_date_fixture(fn [state] (runtime &Runtime) ! {
		mut observation := unsafe { &NativeStartDateObservation(state) }
		observation.replays++
		mut owner := unsafe { &Runtime(runtime) }
		_ = owner.evaluate_host_value('if(startDateShouldThrow)throw startDateReplayReason')!
		mut actual := owner.native_event_target(owner.evaluate_host_value('video')!)!
		mut model := html.html_media_element_for_dom_element(unsafe { &dom.Element(actual) }) or {
			return error('missing actual media owner')
		}
		model.on_metadata_parsed(10)
	})!
	defer { runtime.close() }
	media.set_playback_manager_hooks(html.MediaPlaybackManagerHooks{
		start_time_realtime: fn [state] () ?i64 { return state.offset }
	})
	assert runtime.evaluate_host(r'globalThis.startDateShouldThrow=true;globalThis.startDateReplayReason={};(()=>{
 if(typeof video.getStartDate!=="function")return false;
 try{video.getStartDate({valueOf(){throw "ignored"}});return false}catch(error){return error===startDateReplayReason}})()')! == 'true'
	assert state.replays == 1 && math.is_nan(media.get_start_date().get_time())
	mut observation := unsafe { &NativeStartDateObservation(state) }
	observation.offset = i64(123_456)
	assert runtime.evaluate_host('startDateShouldThrow=false;video.getStartDate().getTime()===124')! == 'true'
	assert state.replays == 2 && media.get_start_date().get_time() == 124
	media.set_source(none)
	media.load()!
}

fn test_native_start_date_keeps_date_limits_exact_and_rejects_unrepresentable_source_values() {
	$if !darwin { return }
	mut runtime, mut media := native_start_date_fixture(none)!
	defer { runtime.close() }
	assert runtime.evaluate_host('typeof video.getStartDate==="function"')! == 'true'
	state := &NativeStartDateObservation{}
	media.set_playback_manager_hooks(html.MediaPlaybackManagerHooks{
		start_time_realtime: fn [state] () ?i64 { return state.offset }
	})
	mut observation := unsafe { &NativeStartDateObservation(state) }
	for offset in [i64(8_640_000_000_000_000_000), i64(-8_640_000_000_000_000_000)] {
		observation.offset = offset
		media.on_metadata_parsed(10)
		assert runtime.evaluate_host('video.getStartDate().getTime()===${offset / 1000}')! == 'true'
	}
	for offset in [i64(8_640_000_000_000_001_000), i64(-8_640_000_000_000_001_000)] {
		observation.offset = offset
		media.on_metadata_parsed(10)
		assert media.get_start_date().get_time() == f64(offset / 1000)
		assert runtime.evaluate_host(r'(()=>{try{video.getStartDate();return false}catch(error){return error.message==="Source media Date value cannot be installed exactly by JavaScriptCore"}})()')! == 'true'
	}
	media.set_source(none)
	media.load()!
}
