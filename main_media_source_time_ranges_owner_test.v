module main

import browserjs
import dom
import html
import page
import time

fn test_native_page_buffered_getter_observes_append_remove_snapshots_in_updateend_callbacks() {
	$if !darwin { return }
	owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time('<video id="player"></video>', dom.URL{
		value: 'https://native-ranges-page.example.test/page.html'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut runtime := browserjs.Runtime.create()
	defer {
		html.run_blob_url_unloading_cleanup_steps(document)
		runtime.close()
	}
	mut messages := []string{}
	run_document_javascript(document, 'https://native-ranges-page.example.test/page.html', [
		r'globalThis.source=new MediaSource();globalThis.rangesCompleted=false;globalThis.steps=[];source.onsourceopen=function(){
 globalThis.buffer=source.addSourceBuffer("video/webm; codecs=vp9");globalThis.empty=buffer.buffered;let phase=0;
 buffer.onupdateend=function(event){
  steps.push(this===buffer&&event.target===buffer);
  if(phase++===0){buffer.appendBuffer(new Uint8Array([0x1f,0x43,0xb6,0x75,0x8b,0xe7,0x81,0,0xa3,0x86,0x81,0,0,0x80,1,2]));return}
  if(phase===2){globalThis.saved=buffer.buffered;globalThis.savedEnd=saved.end(0);steps.push(saved instanceof TimeRanges&&saved.length===1&&saved.start(0)===0&&savedEnd>0.033&&savedEnd<0.034&&empty.length===0);buffer.remove(0,Infinity);return}
  rangesCompleted=steps.every(Boolean)&&buffer.buffered instanceof TimeRanges&&buffer.buffered.length===0&&saved.length===1&&saved.end(0)===savedEnd&&empty.length===0;
 };
 buffer.appendBuffer(new Uint8Array([0x1a,0x45,0xdf,0xa3,0x80,0x18,0x53,0x80,0x67,0xff,0x15,0x49,0xa9,0x66,0x92,0x2a,0xd7,0xb1,0x83,0x0f,0x42,0x40,0x44,0x89,0x88,0x40,0x9f,0x40,0,0,0,0,0,0x16,0x54,0xae,0x6b,0x97,0xae,0x95,0xd7,0x81,1,0x83,0x81,1,0x86,0x85,0x56,0x5f,0x56,0x50,0x39,0x23,0xe3,0x83,0x84,1,0xfc,0xa0,0x55]));
};player.setAttribute("src",URL.createObjectURL(source));',
	], runtime, mut messages)
	assert messages == []
	mut loop := html.main_thread_event_loop()
	queue := loop.task_queue()
	loop.spin_until(fn [queue] () bool {
		return !queue.has_runnable_tasks()
	})
	assert runtime.evaluate_host('rangesCompleted&&steps.length===4')! == 'true'
	source := runtime.native_media_source(runtime.evaluate_host_value('source')!)!
	media := html.html_media_element_for_dom_element(document.get_element_by_id('player')?)?
	assert source.media_element_assigned_to()? == media
	assert source.source_buffers().item(0)?.buffered()!.length() == 0
	assert runtime.native_time_ranges(runtime.evaluate_host_value('saved')!)!.length() == 1
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert !runtime.libjs_vm().has_running_execution_context()
	assert settings.realm().script_execution_depth == 0
}
