module browserjs

import dom
import html

@[heap]
struct MediaRangesProbe {
mut:
	reads  int
	ranges []html.MediaBufferedRange
}

fn media_ranges_fixture(replay ?MediaElementReplayHook) !(&Runtime, &MediaElementHost, &html.HTMLMediaElement) {
	address := dom.URL{
		value: 'https://media-element-host.example.test/'
	}
	document := html.parse_navigation_document('<!doctype html><video id="video"></video><audio id="audio"></audio><div id="ordinary"></div>',
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
	element := document.get_element_by_id('video') or { return error('missing video') }
	media := html.html_media_element_for_dom_element(element) or {
		return error('missing actual media owner')
	}
	return runtime, host, media
}

fn test_native_media_buffered_metadata_and_brands_precede_document_replay() {
	$if !darwin { return }
	mut probe := &MediaRangesProbe{}
	mut runtime, host, media := media_ranges_fixture(fn [probe] (_ &Runtime) ! {
		mut state := unsafe { &MediaRangesProbe(probe) }
		state.reads++
	})!
	defer { runtime.close() }
	assert runtime.evaluate_host(r'(()=>{
 const p=HTMLMediaElement.prototype,d=Object.getOwnPropertyDescriptor(p,"buffered");let reads=0;
 const fake=Object.create(p),proxy=new Proxy(video,{get(){reads++;throw "proxy"},getPrototypeOf(){reads++;throw "proxy"}});
 const rejected=[()=>d.get.call(fake),()=>d.get.call(proxy),()=>d.get.call(null)].every(call=>{try{call();return false}catch(error){return error instanceof TypeError}});
 const illegal=[()=>HTMLMediaElement(),()=>new HTMLMediaElement()].every(call=>{try{call();return false}catch(error){return error instanceof TypeError}});
 const constants={NETWORK_EMPTY:0,NETWORK_IDLE:1,NETWORK_LOADING:2,NETWORK_NO_SOURCE:3,HAVE_NOTHING:0,HAVE_METADATA:1,HAVE_CURRENT_DATA:2,HAVE_FUTURE_DATA:3,HAVE_ENOUGH_DATA:4};
 const flags=Object.keys(constants).every(name=>[HTMLMediaElement,p].every(object=>{const c=Object.getOwnPropertyDescriptor(object,name);return c.value===constants[name]&&c.enumerable&&!c.writable&&!c.configurable}));
 return rejected&&reads===0&&illegal&&flags&&d.enumerable&&d.configurable&&d.set===undefined&&d.get.name==="get buffered"&&d.get.length===0&&Function.prototype.toString.call(d.get).includes("[native code]")&&video instanceof HTMLMediaElement&&audio instanceof HTMLMediaElement&&!Object.hasOwn(video,"buffered")&&!Reflect.set(video,"buffered",null);
})()')! == 'true'
	assert probe.reads == 0
	assert host.media_element_for_binding(runtime.evaluate_host_value('video')!)! == media
	assert runtime.native_event_target(runtime.evaluate_host_value('video')!)! == unsafe { &dom.EventTarget(host.document.get_element_by_id('video')?) }
	assert runtime.evaluate_host('globalThis.first=video.buffered;first instanceof TimeRanges&&first.length===0&&first!==video.buffered&&audio.buffered.length===0')! == 'true'
	assert probe.reads == 3
}

fn test_native_media_buffered_reads_actual_playback_hooks_and_preserves_static_snapshots() {
	$if !darwin { return }
	mut runtime, _, mut media := media_ranges_fixture(none)!
	defer { runtime.close() }
	media.media_source_update_buffered_ranges([html.MediaBufferedRange{1, 2}])
	assert runtime.evaluate_host('globalThis.fallback=video.buffered;fallback.length===1&&fallback.start(0)===1&&fallback.end(0)===2')! == 'true'
	mut probe := &MediaRangesProbe{
		ranges: [html.MediaBufferedRange{3, 5}, html.MediaBufferedRange{6, 7}]
	}
	media.set_playback_manager_hooks(html.MediaPlaybackManagerHooks{
		buffered_ranges: fn [probe] () []html.MediaBufferedRange {
			return probe.ranges.clone()
		}
	})
	assert runtime.evaluate_host('globalThis.saved=video.buffered;saved.length===2&&saved.start(0)===3&&saved.end(0)===5&&saved.start(1)===6&&saved.end(1)===7&&fallback.end(0)===2')! == 'true'
	probe.ranges = [html.MediaBufferedRange{9, 10}]
	runtime.evaluate_host('globalThis.rangePrototype=TimeRanges.prototype;globalThis.mediaPrototype=HTMLMediaElement.prototype;globalThis.videoPrototype=HTMLVideoElement.prototype;globalThis.authorReads=0;globalThis.TimeRanges=function(){authorReads++;throw "author TimeRanges"};globalThis.HTMLMediaElement=function(){authorReads++;throw "author media constructor"}')!
	assert runtime.evaluate_host('globalThis.latest=video.buffered;Object.getPrototypeOf(latest)===rangePrototype&&Object.getPrototypeOf(video)===videoPrototype&&Object.getPrototypeOf(videoPrototype)===mediaPrototype&&latest.start(0)===9&&latest.end(0)===10&&saved.start(0)===3&&saved.end(0)===5&&saved.start(1)===6&&saved.end(1)===7&&fallback.end(0)===2&&authorReads===0')! == 'true'
	assert runtime.native_time_ranges(runtime.evaluate_host_value('latest')!)!.start(0)! == 9
}

fn test_native_media_buffered_preserves_original_replay_exception() {
	$if !darwin { return }
	mut runtime, _, _ := media_ranges_fixture(fn (runtime &Runtime) ! {
		mut owner := unsafe { &Runtime(runtime) }
		_ = owner.evaluate_host_value('throw mediaReplayReason')!
	})!
	defer { runtime.close() }
	assert runtime.evaluate_host('globalThis.mediaReplayReason={};(()=>{try{video.buffered;return false}catch(error){return error===mediaReplayReason}})()')! == 'true'
}

fn test_native_media_buffered_independent_runtime_brands_and_closed_owner_cleanup() {
	$if !darwin { return }
	mut first, first_host, _ := media_ranges_fixture(none)!
	defer { first.close() }
	mut second, second_host, _ := media_ranges_fixture(none)!
	defer { second.close() }
	object := first.evaluate_host_value('video')!
	if _ := second_host.media_element_for_binding(object) {
		assert false
	} else {
		assert err.msg() == 'TypeError: Not an object of type HTMLMediaElement'
	}
	first.close()
	if _ := first_host.media_element_for_binding(object) {
		assert false
	} else {
		assert err.msg() == 'Media element binding is closed'
	}
	assert first_host.elements_for_binding().len == 0
	assert second.evaluate_host('video.buffered instanceof TimeRanges&&audio.buffered.length===0')! == 'true'
}
