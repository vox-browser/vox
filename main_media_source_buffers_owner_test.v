module main

import browserjs
import dom
import html
import page
import time

fn test_native_page_sourceopen_callback_adds_and_appends_to_the_actual_media_buffer() {
	$if !darwin { return }
	owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time('<video id="player"></video>', dom.URL{
		value: 'https://native-buffer-page.example.test/page.html'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut runtime := browserjs.Runtime.create()
	defer {
		html.run_blob_url_unloading_cleanup_steps(document)
		runtime.close()
	}
	mut messages := []string{}
	run_document_javascript(document, 'https://native-buffer-page.example.test/page.html', [
		r'globalThis.actualSource=new MediaSource();globalThis.bufferEvents=[];actualSource.onsourceopen=function(event){globalThis.actualList=actualSource.sourceBuffers;actualList.onaddsourcebuffer=function(event){bufferEvents.push("list:"+(this===actualList&&event.target===actualList))};globalThis.actualBuffer=actualSource.addSourceBuffer("video/webm; codecs=vp9");for(const name of ["updatestart","update","updateend"])actualBuffer.addEventListener(name,function(event){bufferEvents.push(event.type+":"+(this===actualBuffer&&event.target===actualBuffer&&event.currentTarget===actualBuffer))});actualBuffer.appendBuffer(new Uint8Array([0x1a,0x45]));};player.setAttribute("src",URL.createObjectURL(actualSource));',
	], runtime, mut messages)
	assert messages == []
	source := runtime.native_media_source(runtime.evaluate_host_value('actualSource')!)!
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	media := html.html_media_element_for_dom_element(document.get_element_by_id('player')?)?
	assert source.media_element_assigned_to()? == media
	assert source.relevant_global_impl() == settings.global_object()
	assert source.source_buffers().length() == 0
	mut loop := html.main_thread_event_loop()
	queue := loop.task_queue()
	loop.spin_until(fn [queue] () bool {
		return !queue.has_runnable_tasks()
	})
	assert runtime.evaluate_host('actualList===actualSource.sourceBuffers&&actualList.length===1&&actualList[0]===actualBuffer&&!actualBuffer.updating&&bufferEvents.join(",")==="list:true,updatestart:true,update:true,updateend:true"')! == 'true'
	buffer := source.source_buffers().item(0)?
	assert buffer.input_buffer_length() == 2
	assert voidptr(runtime.native_event_target(runtime.evaluate_host_value('actualBuffer')!)!) == voidptr(&buffer.EventTarget)
	assert !runtime.libjs_vm().has_running_execution_context()
	assert settings.realm().script_execution_depth == 0
}
