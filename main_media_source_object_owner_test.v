module main

import browserjs
import dom
import fileapi
import html
import page
import time
import url as liburl

fn test_native_page_media_source_object_url_reaches_actual_document_attachment_owner() {
	$if !darwin { return }
	owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time('<video id="player"></video><div id="result">pending</div>', dom.URL{
		value: 'https://native-media-page.example.test/page.html'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	assert document.is_fully_active()
	mut runtime := browserjs.Runtime.create()
	defer {
		html.run_blob_url_unloading_cleanup_steps(document)
		runtime.close()
	}
	mut messages := []string{}
	run_document_javascript(document, 'https://native-media-page.example.test/page.html', [
		'globalThis.actualSource=new MediaSource();globalThis.sourceAddress=URL.createObjectURL(actualSource);player.setAttribute("src",sourceAddress);result.textContent=actualSource.readyState+" "+new URL(sourceAddress).origin;globalThis.opens=0;actualSource.onsourceopen=function(event){if(this===actualSource&&event.target===actualSource)opens++};',
	], runtime, mut messages)
	assert messages == []
	assert document.get_element_by_id('result')?.as_node().text_content()? == 'closed https://native-media-page.example.test'
	actual := runtime.evaluate_host_value('actualSource')!
	source := runtime.native_media_source(actual)!
	value := runtime.native_utf16_string(runtime.evaluate_host_value('sourceAddress')!)!.str()
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	entry := fileapi.resolve_a_blob_url(liburl.parse(value)?)?
	assert entry.object.media_source_handle == voidptr(source)
	assert entry.environment.blob_url_settings_identity() == voidptr(settings)
	assert source.relevant_global_impl() == settings.global_object()
	element := document.get_element_by_id('player')?
	assert element.get_attribute('src')? == value
	mut media := html.html_media_element_for_dom_element(element)?
	assert source.ready_state() == .open
	assert source.media_element_assigned_to()? == media
	mut event_loop := html.main_thread_event_loop()
	queue := event_loop.task_queue()
	event_loop.spin_until(fn [queue] () bool {
		return !queue.has_runnable_tasks()
	})
	assert runtime.evaluate_host('actualSource.readyState==="open"&&opens===1')! == 'true'
	assert runtime.evaluate_host('URL.revokeObjectURL(sourceAddress)===undefined')! == 'true'
	assert fileapi.resolve_a_blob_url(liburl.parse(value)?) == none
	assert source.media_element_assigned_to()? == media
	media.set_source(none)
	media.load()!
	assert source.ready_state() == .closed
	assert source.media_element_assigned_to() == none
	assert !runtime.libjs_vm().has_running_execution_context()
	assert settings.realm().script_execution_depth == 0
}
