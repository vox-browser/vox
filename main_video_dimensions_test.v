module main

import browserjs
import dom
import html
import page
import time

@[heap]
struct VideoDimensionsProbe {
mut:
	replays int
}

fn video_dimensions_fixture(replay ?browserjs.MediaElementReplayHook) !(&browserjs.Runtime, &browserjs.MediaElementHost, &dom.Document, &html.HTMLVideoElementModel) {
	address := dom.URL{ value: 'https://video-dimensions.example/page.html' }
	mut document := html.parse_navigation_document('<!doctype html><video id="vd-video" width="900" height="500"></video><audio id="vd-audio"></audio>', address, address.origin(), none)!
	mut runtime := browserjs.Runtime.create()
	mut host := browserjs.MediaElementHost.create(document, replay)!
	host.install(mut runtime)!
	for key, element in host.elements_for_binding() {
		if element.local_name() in ['audio', 'video'] {
			name := if element.local_name() == 'video' { 'vdVideo' } else { 'vdAudio' }
			_ = runtime.evaluate_host('globalThis.${name}={};__ladybirdMediaElementBind(${name},"${key}","${element.local_name()}");0')!
		}
	}
	element := document.get_element_by_id('vd-video') or { return error('missing dimension video') }
	video := html.html_video_element_model_for_dom_element(unsafe { &dom.HTMLVideoElement(element) })
	return runtime, host, document, video
}

fn test_video_dimensions_native_readonly_metadata_and_brand_precede_replay() {
	$if !darwin { return }
	probe := &VideoDimensionsProbe{}
	mut runtime, _, mut document, _ := video_dimensions_fixture(fn [probe] (_ &browserjs.Runtime) ! {
		mut observed := unsafe { &VideoDimensionsProbe(probe) }
		observed.replays++
	})!
	defer { runtime.close(); document.finalize() }
	assert runtime.evaluate_host(r'(()=>{
 let traps=0;const proxy=new Proxy(vdVideo,{get(){traps++;throw "get"},getPrototypeOf(){traps++;throw "prototype"}}),revoked=Proxy.revocable(vdVideo,{});revoked.revoke();
 for(const name of ["videoWidth","videoHeight"]){
  const d=Object.getOwnPropertyDescriptor(HTMLVideoElement.prototype,name);
  if(!d||d.set!==undefined||!d.enumerable||!d.configurable||d.get.name!=="get "+name||d.get.length!==0||!Function.prototype.toString.call(d.get).includes("[native code]")||Object.hasOwn(vdVideo,name)||name in vdAudio)return false;
  for(const receiver of [vdAudio,{},Object.create(vdVideo),Object.create(HTMLVideoElement.prototype),proxy,revoked.proxy,null,undefined,1]){try{d.get.call(receiver);return false}catch(error){if(!(error instanceof TypeError)||error.message!=="Not an object of type HTMLVideoElement")return false}}
  if(Reflect.set(vdVideo,name,{valueOf(){throw "conversion"}}))return false;
  try{(function(){"use strict";vdVideo[name]=1})();return false}catch(error){if(!(error instanceof TypeError))return false}
 }
 return traps===0;
})()')! == 'true'
	assert probe.replays == 0
	assert runtime.evaluate_host('vdVideo.videoWidth===0&&vdVideo.videoHeight===0')! == 'true'
	assert probe.replays == 2
}

fn test_video_dimensions_read_live_intrinsics_and_readiness_without_using_poster_or_attributes() {
	$if !darwin { return }
	mut runtime, _, mut document, mut video := video_dimensions_fixture(none)!
	defer { runtime.close(); document.finalize() }
	mut media := video.media
	media.set_ready_state(.have_metadata)
	assert runtime.evaluate_host('vdVideo.videoWidth===0&&vdVideo.videoHeight===0')! == 'true'
	video.set_video_dimensions(640, 360)
	video.set_poster_fetch_hook(fn (_ dom.URL) !&dom.Bitmap_ {
		return &dom.Bitmap_{ width: 17, height: 9, pitch: 68, data: []u8{len: 17 * 9 * 4} }
	})
	video.set_poster('poster.png')
	assert video.natural_element_size()? == html.VideoDimensions{17, 9}
	assert runtime.evaluate_host('vdVideo.videoWidth===640&&vdVideo.videoHeight===360')! == 'true'
	video.set_video_dimensions(u32(4294967295), u32(2147483648))
	assert runtime.evaluate_host('vdVideo.videoWidth===4294967295&&vdVideo.videoHeight===2147483648')! == 'true'
	media.set_ready_state(.have_nothing)
	assert runtime.evaluate_host('vdVideo.videoWidth===0&&vdVideo.videoHeight===0')! == 'true'
	media.set_ready_state(.have_current_data)
	video.set_video_dimensions(321, 123)
	assert runtime.evaluate_host('vdVideo.videoWidth===321&&vdVideo.videoHeight===123')! == 'true'
	assert media.paused() && media.current_src() == '' && media.network_state() == .empty
}

fn test_video_dimensions_keep_original_replay_exceptions_and_closed_runtime_guards() {
	$if !darwin { return }
	mut runtime, host, mut document, _ := video_dimensions_fixture(fn (runtime &browserjs.Runtime) ! {
		mut owner := unsafe { &browserjs.Runtime(runtime) }
		_ = owner.evaluate_host_value('throw vdReason')!
	})!
	defer { runtime.close(); document.finalize() }
	assert runtime.evaluate_host(r'globalThis.vdReason={};(()=>{for(const name of ["videoWidth","videoHeight"]){try{vdVideo[name];return false}catch(error){if(error!==vdReason)return false}}return true})()')! == 'true'
	value := runtime.evaluate_host_value('vdVideo')!
	runtime.close()
	if _ := runtime.evaluate_host('vdVideo.videoWidth') { assert false } else { assert err.msg() == 'JavaScript runtime is closed' }
	if _ := host.media_element_for_binding(value) { assert false } else { assert err.msg() == 'Media element binding is closed' }
	assert host.elements_for_binding().len == 0
}

fn test_compact_parsed_and_created_videos_use_actual_track_dimensions_instead_of_cached_script_fields() {
	$if !darwin { return }
	owner := page.Page.create(1)!
	mut document := parse_browser_navigation_document_for_page_with_response_time(
		'<!doctype html><video id="vd-parsed" preload="none" width="900" height="500"></video>',
		dom.URL{ value: 'https://video-dimensions.example/page.html' }, none, none,
		unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'globalThis.vdPlayers=[document.getElementById("vd-parsed")];const created=document.createElement("video");created.id="vd-created";created.preload="none";document.body.appendChild(created);vdPlayers.push(created);0'], runtime, mut messages)
	assert messages == []
	for index, id in ['vd-parsed', 'vd-created'] {
		element := document.get_element_by_id(id) or { panic('missing video dimension owner') }
		mut video := html.html_video_element_model_for_dom_element(unsafe { &dom.HTMLVideoElement(element) })
		mut media := video.media
		_ = media.on_video_track_added(html.MediaTrackMetadata{identifier: 1, name: 'actual', pixel_width: 333, pixel_height: 111})
		assert runtime.evaluate_host('vdPlayers[${index}].__state.videoWidth=888;vdPlayers[${index}].__state.videoHeight=999;vdPlayers[${index}].videoWidth===0&&vdPlayers[${index}].videoHeight===0')! == 'true'
		media.set_ready_state(.have_metadata)
		assert runtime.evaluate_host('vdPlayers[${index}].videoWidth===333&&vdPlayers[${index}].videoHeight===111&&!Object.hasOwn(vdPlayers[${index}],"videoWidth")&&!Object.hasOwn(vdPlayers[${index}],"videoHeight")')! == 'true'
		video.set_video_dimensions(444, 222)
		assert runtime.evaluate_host('vdPlayers[${index}].videoWidth===444&&vdPlayers[${index}].videoHeight===222&&Reflect.set(vdPlayers[${index}],"videoWidth",1000)===false')! == 'true'
		media.set_ready_state(.have_nothing)
		assert runtime.evaluate_host('vdPlayers[${index}].videoWidth===0&&vdPlayers[${index}].videoHeight===0')! == 'true'
	}
}
