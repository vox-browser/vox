module main

import browserjs
import dom
import html
import page
import time

fn test_native_media_completion_events_follow_the_cache_boundary_and_actual_dom_owner() {
	$if !darwin { return }
	owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time('<video id="player"></video><audio id="other"></audio>', dom.URL{
		value: 'https://native-media-end-task.example.test/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut media := html.html_media_element_for_dom_element(document.get_element_by_id('player')?)?
	media.set_ready_state(.have_metadata)
	media.set_duration(1)
	media.set_current_playback_position(1)
	media.set_paused(false)
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'https://native-media-end-task.example.test/', [
		r'
globalThis.mediaCompletionEvents=[];globalThis.mediaCompletionChecks=[];globalThis.savedCompletionEvent=null;
for(const name of ["timeupdate","pause","ended"]){EventTarget.prototype.addEventListener.call(player,name,function(event){
 mediaCompletionEvents.push(name);mediaCompletionChecks.push(player.ended&&player.paused===(name!=="timeupdate")&&this===player&&event.target===player&&event.currentTarget===player&&event.isTrusted&&!event.bubbles&&!event.cancelable);savedCompletionEvent=event;
});}EventTarget.prototype.addEventListener.call(other,"ended",()=>mediaCompletionEvents.push("other"));',
	], runtime, mut messages)
	assert messages == []
	media.reached_end_of_media_playback()
	assert !media.paused()
	assert runtime.evaluate_host('mediaCompletionEvents.length===0&&player.ended===false')! == 'true'
	mut loop := html.main_thread_event_loop()
	loop.perform_a_microtask_checkpoint()
	assert runtime.evaluate_host('mediaCompletionEvents.length===0&&player.ended===false')! == 'true'
	for _ in 0 .. 100 {
		loop.process()
		if runtime.evaluate_host('mediaCompletionEvents.length===3')! == 'true' { break
		 }
	}
	assert runtime.evaluate_host('mediaCompletionEvents.join(",")==="timeupdate,pause,ended"&&mediaCompletionChecks.every(Boolean)&&savedCompletionEvent.currentTarget===null&&player.paused&&player.ended&&!other.ended')! == 'true'
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().script_execution_depth == 0
		&& settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
}
