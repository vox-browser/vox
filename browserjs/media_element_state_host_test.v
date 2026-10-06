module browserjs

import dom
import html
import math

@[heap]
struct MediaStateReplayProbe {
mut:
	reads int
}

fn media_state_fixture(replay ?MediaElementReplayHook) !(&Runtime, &MediaElementHost, &html.HTMLMediaElement) {
	address := dom.URL{
		value: 'https://media-state-host.example.test/'
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
	element := document.get_element_by_id('video') or { return error('missing video') }
	media := html.html_media_element_for_dom_element(element) or {
		return error('missing media owner')
	}
	return runtime, host, media
}

fn test_native_media_state_getters_have_readonly_metadata_and_reject_before_replay() {
	$if !darwin { return }
	mut probe := &MediaStateReplayProbe{}
	mut runtime, _, _ := media_state_fixture(fn [probe] (_ &Runtime) ! {
		mut state := unsafe { &MediaStateReplayProbe(probe) }
		state.reads++
	})!
	defer { runtime.close() }
	assert runtime.evaluate_host(r'(()=>{
 const p=HTMLMediaElement.prototype,names=["currentSrc","networkState","readyState","seeking","duration","paused","ended"];
 let traps=0;const proxy=new Proxy(video,{get(){traps++;throw "proxy"},getPrototypeOf(){traps++;throw "proxy"}});
 return names.every(name=>{const d=Object.getOwnPropertyDescriptor(p,name);if(!d)return false;
  const receivers=[Object.create(p),proxy,null,undefined,1];
  const rejected=receivers.every(receiver=>{try{d.get.call(receiver);return false}catch(error){return error instanceof TypeError}});
  return rejected&&d.enumerable&&d.configurable&&d.set===undefined&&d.get.length===0&&d.get.name==="get "+name&&Function.prototype.toString.call(d.get).includes("[native code]")&&!Object.hasOwn(video,name)&&!Reflect.set(video,name,123);
 })&&traps===0;
})()')! == 'true'
	assert probe.reads == 0
	assert runtime.evaluate_host('video.currentSrc===""&&video.networkState===0&&video.readyState===0&&video.seeking===false&&Number.isNaN(video.duration)&&video.paused===true&&video.ended===false')! == 'true'
	assert probe.reads == 7
}

fn test_native_media_state_reads_resource_callbacks_and_live_playback_fields() {
	$if !darwin { return }
	mut runtime, _, mut media := media_state_fixture(none)!
	defer { runtime.close() }
	media.set_fetch_hook(fn (_ dom.URL, _ u64) !html.MediaResourceResponse {
		return html.MediaResourceResponse{
			mime_type:    'video/webm'
			duration:     12.5
			buffered_end: 12.5
			video_tracks: [html.MediaTrackMetadata{ identifier: 1, name: 'video' }]
		}
	})
	media.load_url_resource(dom.URL{ value: 'https://media-state-host.example.test/movie.webm' },
		none)!
	assert runtime.evaluate_host('video.currentSrc==="https://media-state-host.example.test/movie.webm"&&video.networkState===1&&video.readyState===4&&video.duration===12.5&&audio.currentSrc===""&&audio.networkState===0&&audio.readyState===0&&Number.isNaN(audio.duration)')! == 'true'
	media.set_duration(math.inf(1))
	media.set_ready_state(.have_current_data)
	media.set_paused(false)
	media.set_seeking(true)
	media.set_ended(true)
	assert runtime.evaluate_host('video.duration===Infinity&&video.readyState===2&&video.paused===false&&video.seeking===true&&video.ended===true')! == 'true'
	media.set_duration(-0.0)
	media.set_paused(true)
	media.set_seeking(false)
	media.set_ended(false)
	assert runtime.evaluate_host('Object.is(video.duration,-0)&&video.paused===true&&video.seeking===false&&video.ended===false')! == 'true'
	media.set_duration(math.nan())
	assert runtime.evaluate_host('Number.isNaN(video.duration)')! == 'true'
}

fn test_native_media_state_getters_preserve_actual_replay_exceptions() {
	$if !darwin { return }
	mut runtime, _, _ := media_state_fixture(fn (runtime &Runtime) ! {
		mut owner := unsafe { &Runtime(runtime) }
		_ = owner.evaluate_host_value('throw mediaStateReason')!
	})!
	defer { runtime.close() }
	assert runtime.evaluate_host(r'globalThis.mediaStateReason={};["currentSrc","networkState","readyState","seeking","duration","paused","ended"].every(name=>{try{video[name];return false}catch(error){return error===mediaStateReason}})')! == 'true'
}
