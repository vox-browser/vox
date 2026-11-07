module main

import browserjs
import dom
import html
import page
import time

fn test_native_canplaythrough_events_wait_for_tasks_follow_first_data_and_are_canceled_by_reload() {
	$if !darwin { return }
	owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time('<video id="video" src="/movie.mp4"></video><audio id="audio" src="/sound.mp3"></audio>', dom.URL{
		value: 'https://native-canplaythrough-task.example.test/'
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
	run_document_javascript(document, 'https://native-canplaythrough-task.example.test/', [
		r'globalThis.canplaythroughEvents=[];globalThis.canplaythroughChecks=[];globalThis.savedCanPlayEvent=null;
 for(const [name,player] of [["video",video],["audio",audio]])for(const type of ["loadeddata","canplay","canplaythrough"])EventTarget.prototype.addEventListener.call(player,type,function(event){
 canplaythroughEvents.push(name+":"+event.type);canplaythroughChecks.push(this===player&&event.target===player&&event.currentTarget===player&&event.isTrusted&&!event.bubbles&&!event.cancelable&&player.readyState>=2&&player.duration===20);savedCanPlayEvent=event;
 });video.load();audio.load();',
	], runtime, mut messages)
	assert messages == []
	assert runtime.evaluate_host('canplaythroughEvents.length===0&&video.readyState===1&&audio.readyState===1')! == 'true'
	mut loop := html.main_thread_event_loop()
	for _ in 0 .. 100 {
		loop.process()
	}
	for model in models {
		mut media := unsafe { &html.HTMLMediaElement(model) }
		media.set_ready_state(.have_enough_data)
		media.set_ready_state(.have_metadata)
		media.set_ready_state(.have_current_data)
	}
	loop.perform_a_microtask_checkpoint()
	assert runtime.evaluate_host('canplaythroughEvents.length===0')! == 'true'
	for _ in 0 .. 100 {
		loop.process()
	}
	assert runtime.evaluate_host('canplaythroughEvents.join(",")==="video:loadeddata,video:canplay,video:canplaythrough,audio:loadeddata,audio:canplay,audio:canplaythrough"&&canplaythroughChecks.every(Boolean)&&savedCanPlayEvent.currentTarget===null')! == 'true'
	assert runtime.evaluate_host('video.load()===undefined&&canplaythroughEvents.length===6&&video.readyState===1')! == 'true'
	mut video := unsafe { &html.HTMLMediaElement(models[0]) }
	video.set_ready_state(.have_enough_data)
	assert runtime.evaluate_host('video.load()===undefined&&canplaythroughEvents.length===6')! == 'true'
	video.set_ready_state(.have_enough_data)
	for _ in 0 .. 100 {
		loop.process()
	}
	assert runtime.evaluate_host('canplaythroughEvents.slice(6).join(",")==="video:loadeddata,video:canplay,video:canplaythrough"&&canplaythroughChecks.every(Boolean)')! == 'true'
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().script_execution_depth == 0
		&& settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
}
