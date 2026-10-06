module main

import browserjs
import dom
import html
import page
import time

fn test_native_page_media_buffered_getter_uses_the_attached_video_in_updateend_callbacks() {
	$if !darwin { return }
	owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time('<video id="player"></video>', dom.URL{
		value: 'https://native-media-ranges.example.test/page.html'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut runtime := browserjs.Runtime.create()
	defer {
		html.run_blob_url_unloading_cleanup_steps(document)
		runtime.close()
	}
	mut messages := []string{}
	run_document_javascript(document, 'https://native-media-ranges.example.test/page.html', [
		r'globalThis.mediaRangesCompleted=false;
if(typeof HTMLMediaElement==="function"&&player.buffered instanceof TimeRanges){
 globalThis.emptyMediaRanges=player.buffered;globalThis.source=new MediaSource();globalThis.steps=[];
 source.onsourceopen=function(){
  globalThis.buffer=source.addSourceBuffer("video/webm; codecs=vp9");let phase=0;
  buffer.onupdateend=function(){
   if(phase++===0){buffer.appendBuffer(new Uint8Array([0x1f,0x43,0xb6,0x75,0x8b,0xe7,0x81,0,0xa3,0x86,0x81,0,0,0x80,1,2]));return}
   if(phase===2){globalThis.savedMediaRanges=player.buffered;globalThis.savedMediaEnd=savedMediaRanges.end(0);steps.push(savedMediaRanges.length===1&&savedMediaRanges.start(0)===0&&savedMediaEnd>0.033&&savedMediaEnd<0.034&&emptyMediaRanges.length===0&&savedMediaRanges!==player.buffered);buffer.remove(0,Infinity);return}
   mediaRangesCompleted=steps.every(Boolean)&&player.buffered.length===0&&savedMediaRanges.length===1&&savedMediaRanges.end(0)===savedMediaEnd&&emptyMediaRanges.length===0;
  };
  buffer.appendBuffer(new Uint8Array([0x1a,0x45,0xdf,0xa3,0x80,0x18,0x53,0x80,0x67,0xff,0x15,0x49,0xa9,0x66,0x92,0x2a,0xd7,0xb1,0x83,0x0f,0x42,0x40,0x44,0x89,0x88,0x40,0x9f,0x40,0,0,0,0,0,0x16,0x54,0xae,0x6b,0x97,0xae,0x95,0xd7,0x81,1,0x83,0x81,1,0x86,0x85,0x56,0x5f,0x56,0x50,0x39,0x23,0xe3,0x83,0x84,1,0xfc,0xa0,0x55]));
 };
 player.setAttribute("src",URL.createObjectURL(source));
 // This read must replay the attribute change into the actual media owner.
 globalThis.beforeSourceOpen=player.buffered;
}',
	], runtime, mut messages)
	assert messages == []
	mut loop := html.main_thread_event_loop()
	queue := loop.task_queue()
	loop.spin_until(fn [queue] () bool {
		return !queue.has_runnable_tasks()
	})
	assert runtime.evaluate_host('mediaRangesCompleted&&beforeSourceOpen.length===0&&steps.length===1')! == 'true'
	source := runtime.native_media_source(runtime.evaluate_host_value('source')!)!
	media := html.html_media_element_for_dom_element(document.get_element_by_id('player')?)?
	assert source.media_element_assigned_to()? == media
	assert media.buffered().length() == 0
	assert runtime.native_time_ranges(runtime.evaluate_host_value('savedMediaRanges')!)!.length() == 1
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert !runtime.libjs_vm().has_running_execution_context()
	assert settings.realm().script_execution_depth == 0
}

fn test_native_page_created_audio_uses_one_dom_owner_and_only_html_media_are_branded() {
	$if !darwin { return }
	owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time('<video id="player"></video><div id="ordinary"></div>', dom.URL{
		value: 'https://created-media-ranges.example.test/page.html'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'https://created-media-ranges.example.test/page.html', [
		r'globalThis.createdMediaPassed=false;
const originalMedia=HTMLMediaElement,originalRanges=TimeRanges,get=Object.getOwnPropertyDescriptor(originalMedia.prototype,"buffered").get;
globalThis.__ladybirdMediaElementBind=function(){throw "author replacement"};
const audio=document.createElement("audio");audio.id="created-audio";document.body.appendChild(audio);
const svg=document.createElementNS("http://www.w3.org/2000/svg","video");
let brands=0;for(const object of [ordinary,svg])try{get.call(object)}catch(error){if(error instanceof TypeError)brands++}
createdMediaPassed=audio instanceof originalMedia&&audio.buffered instanceof originalRanges&&audio.buffered.length===0&&audio.buffered!==audio.buffered&&player===document.getElementById("player")&&brands===2&&!("buffered" in svg)&&!("buffered" in ordinary);',
	], runtime, mut messages)
	assert messages == []
	assert runtime.evaluate_host('createdMediaPassed')! == 'true'
	created := document.get_element_by_id('created-audio')?
	media := html.html_media_element_for_dom_element(created)?
	assert media.document()? == document
	assert media.buffered().length() == 0
	assert runtime.native_event_target(runtime.evaluate_host_value('document.getElementById("created-audio")')!)! == unsafe { &dom.EventTarget(created) }
	mut count := 0
	for _, element in runtime.canvas_elements_for_binding() {
		if element == created { count++ }
	}
	assert count == 1
}
