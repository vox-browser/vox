module main

import browserjs
import dom
import html
import page
import time

fn test_native_audio_and_video_data_events_wait_for_tasks_and_native_load_rearms_them() {
	$if !darwin { return }
	owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time('<video id="video" src="/movie.mp4"></video><audio id="audio" src="/sound.mp3"></audio>', dom.URL{
		value: 'https://native-loaded-data.example.test/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut models := []&html.HTMLMediaElement{}
	for name in ['video', 'audio'] {
		mut media := html.html_media_element_for_dom_element(document.get_element_by_id(name)?)?
		media.set_fetch_hook(fn (_ dom.URL, _ u64) !html.MediaResourceResponse {
			return html.MediaResourceResponse{ mime_type: 'video/mp4', duration: 20 }
		})
		models << media
	}
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'https://native-loaded-data.example.test/', [
		r'globalThis.dataEvents=[];globalThis.dataChecks=[];globalThis.savedDataEvent=null;
 for(const [name,player] of [["video",video],["audio",audio]])EventTarget.prototype.addEventListener.call(player,"loadeddata",function(event){
 dataEvents.push(name);dataChecks.push(this===player&&event.target===player&&event.currentTarget===player&&event.isTrusted&&!event.bubbles&&!event.cancelable&&player.readyState===2);savedDataEvent=event;
 });video.load();audio.load();',
	], runtime, mut messages)
	assert messages == []
	mut loop := html.main_thread_event_loop()
	for _ in 0 .. 100 { loop.process() }
	for model in models {
		mut media := unsafe { &html.HTMLMediaElement(model) }
		assert media.ready_state() == .have_metadata
		media.set_ready_state(.have_current_data)
		media.set_ready_state(.have_metadata)
		media.set_ready_state(.have_current_data)
	}
	assert runtime.evaluate_host('dataEvents.length===0&&video.readyState===2&&audio.readyState===2')! == 'true'
	loop.perform_a_microtask_checkpoint()
	assert runtime.evaluate_host('dataEvents.length===0')! == 'true'
	for _ in 0 .. 100 { loop.process() }
	assert runtime.evaluate_host('dataEvents.join(",")==="video,audio"&&dataChecks.every(Boolean)&&savedDataEvent.currentTarget===null')! == 'true'
	assert runtime.evaluate_host('video.load()===undefined&&video.readyState===1&&audio.readyState===2')! == 'true'
	mut video := unsafe { &html.HTMLMediaElement(models[0]) }
	video.set_ready_state(.have_current_data)
	assert runtime.evaluate_host('dataEvents.length===2')! == 'true'
	for _ in 0 .. 100 { loop.process() }
	assert runtime.evaluate_host('dataEvents.join(",")==="video,audio,video"&&dataChecks.every(Boolean)')! == 'true'
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
}
