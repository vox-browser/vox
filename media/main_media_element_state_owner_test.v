module main

import browserjs
import dom
import html
import page
import time

fn test_native_page_media_state_follows_actual_source_callbacks_and_attribute_replay() {
	$if !darwin { return }
	owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time('<video id="player"></video><audio id="other"></audio>', dom.URL{
		value: 'https://native-media-state.example.test/page.html'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut runtime := browserjs.Runtime.create()
	defer {
		html.run_blob_url_unloading_cleanup_steps(document)
		runtime.close()
	}
	mut messages := []string{}
	run_document_javascript(document, 'https://native-media-state.example.test/page.html', [
		r'globalThis.mediaStateCompleted=false;
if(Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"duration")){
 globalThis.states=[];
 states.push(player.currentSrc===""&&player.networkState===0&&player.readyState===0&&Number.isNaN(player.duration)&&player.paused&&!player.seeking&&!player.ended&&!Object.hasOwn(player,"readyState"));
 globalThis.source=new MediaSource();globalThis.sourceURL=URL.createObjectURL(source);
 source.onsourceopen=function(){
  states.push(player.currentSrc===sourceURL&&player.networkState===2&&player.readyState===0&&Number.isNaN(player.duration));
  source.duration=Infinity;states.push(player.duration===Infinity);
  globalThis.buffer=source.addSourceBuffer("video/webm; codecs=vp9");let phase=0;
  buffer.onupdateend=function(){
   if(phase++===0){states.push(player.readyState===1);source.duration=2;states.push(player.duration===2);buffer.appendBuffer(new Uint8Array([0x1f,0x43,0xb6,0x75,0x8b,0xe7,0x81,0,0xa3,0x86,0x81,0,0,0x80,1,2]));return}
   if(phase===2){states.push(player.readyState===3&&player.duration===2&&player.paused&&!player.seeking&&!player.ended);buffer.remove(0,Infinity);return}
   states.push(player.readyState===1&&player.buffered.length===0&&player.duration===2&&other.currentSrc===""&&other.networkState===0&&other.readyState===0&&Number.isNaN(other.duration));
   mediaStateCompleted=states.every(Boolean);
  };
  buffer.appendBuffer(new Uint8Array([0x1a,0x45,0xdf,0xa3,0x80,0x18,0x53,0x80,0x67,0xff,0x15,0x49,0xa9,0x66,0x92,0x2a,0xd7,0xb1,0x83,0x0f,0x42,0x40,0x44,0x89,0x88,0x40,0x9f,0x40,0,0,0,0,0,0x16,0x54,0xae,0x6b,0x97,0xae,0x95,0xd7,0x81,1,0x83,0x81,1,0x86,0x85,0x56,0x5f,0x56,0x50,0x39,0x23,0xe3,0x83,0x84,1,0xfc,0xa0,0x55]));
 };
 player.setAttribute("src",sourceURL);
 // currentSrc must replay attachment before sourceopen, without a buffered read.
 globalThis.attachedCurrentSrc=player.currentSrc;
}',
	], runtime, mut messages)
	assert messages == []
	mut loop := html.main_thread_event_loop()
	queue := loop.task_queue()
	loop.spin_until(fn [queue] () bool {
		return !queue.has_runnable_tasks()
	})
	assert runtime.evaluate_host('mediaStateCompleted&&states.length===7&&attachedCurrentSrc===sourceURL')! == 'true'
	source := runtime.native_media_source(runtime.evaluate_host_value('source')!)!
	media := html.html_media_element_for_dom_element(document.get_element_by_id('player')?)?
	assert source.media_element_assigned_to()? == media
	assert media.current_src() == runtime.evaluate_host('sourceURL')!
	assert media.ready_state() == .have_metadata
	assert media.duration() == 2
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert !runtime.libjs_vm().has_running_execution_context()
	assert settings.realm().script_execution_depth == 0
}

fn test_native_page_media_state_preserves_decoded_frames_and_created_audio_ownership() {
	$if !darwin { return }
	owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time('<video id="player"></video>', dom.URL{
		value: 'https://native-media-frame-state.example.test/page.html'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	element := document.get_element_by_id('player')?
	mut video :=
		html.html_video_element_model_for_dom_element(unsafe { &dom.HTMLVideoElement(element) })
	mut media := video.media
	// The browser's local decoder supplies its actual model through this boundary.
	media.set_ready_state(.have_current_data)
	video.set_video_dimensions(2, 1)
	video.set_current_frame(&dom.Bitmap_{
		width:  2
		height: 1
		pitch:  8
		data:   [u8(0), 0, 255, 255, 0, 0, 255, 255]
	})
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'https://native-media-frame-state.example.test/page.html', [
		r'const audio=document.createElement("audio");audio.id="created-audio";document.body.appendChild(audio);
globalThis.frameStatePassed=player.readyState===2&&player.videoWidth===2&&player.videoHeight===1&&!Object.hasOwn(player,"readyState")&&audio instanceof HTMLMediaElement&&audio.readyState===0&&audio.networkState===0&&audio.currentSrc===""&&Number.isNaN(audio.duration)&&audio.paused&&!audio.seeking&&!audio.ended;',
	], runtime, mut messages)
	assert messages == []
	assert runtime.evaluate_host('frameStatePassed')! == 'true'
	created := document.get_element_by_id('created-audio')?
	created_media := html.html_media_element_for_dom_element(created)?
	assert created_media.document()? == document
	assert created_media.ready_state() == .have_nothing
	assert runtime.native_event_target(runtime.evaluate_host_value('document.getElementById("created-audio")')!)! == unsafe { &dom.EventTarget(created) }
	media.set_ready_state(.have_enough_data)
	assert runtime.evaluate_host('player.readyState===4&&document.getElementById("created-audio").readyState===0')! == 'true'
}
