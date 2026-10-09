module main

import browserjs
import dom
import html
import page
import time

fn test_native_pause_task_orders_actual_dom_events_before_typed_promise_rejection() {
	// This task/state regression exercises a permitted explicit play request.
	mut playback_policy := html.AutoplaySettings.the()
	previous_policy := playback_policy.policy()
	previous_allowlist := playback_policy.allowlist().map(it.serialize())
	defer { playback_policy.set_policy(previous_policy, previous_allowlist) }
	playback_policy.set_policy(.allow_audio_and_video, [])
	$if !darwin { return }
	owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time('<video id="player"></video><audio id="other"></audio>', dom.URL{
		value: 'https://native-pause-task.example.test/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut media := html.html_media_element_for_dom_element(document.get_element_by_id('player')?)?
	media.set_fetch_hook(fn (_ dom.URL, _ u64) !html.MediaResourceResponse {
		return html.MediaResourceResponse{ mime_type: 'video/mp4', duration: 20 }
	})
	media.set_source('/pending.mp4')
	media.load()!
	mut loop := html.main_thread_event_loop()
	for _ in 0 .. 100 { loop.process() }
	media.set_show_poster(false)
	first := media.play()
	second := media.play()
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'https://native-pause-task.example.test/', [
		r'globalThis.pauseTaskEvents=[];globalThis.pauseTaskChecks=[];globalThis.savedPauseEvent=null;
 for(const name of ["timeupdate","pause"])EventTarget.prototype.addEventListener.call(player,name,function(event){
 pauseTaskEvents.push(name);pauseTaskChecks.push(player.paused&&this===player&&event.target===player&&event.currentTarget===player&&event.isTrusted&&!event.bubbles&&!event.cancelable);savedPauseEvent=event;
 });EventTarget.prototype.addEventListener.call(other,"pause",()=>pauseTaskEvents.push("other"));',
	], runtime, mut messages)
	assert messages == []
	assert runtime.evaluate_host('player.pause()===undefined&&player.paused&&pauseTaskEvents.length===0')! == 'true'
	assert first.state() == .pending && second.state() == .pending
	loop.perform_a_microtask_checkpoint()
	assert runtime.evaluate_host('pauseTaskEvents.length===0')! == 'true'
	for _ in 0 .. 100 {
		loop.process()
		if runtime.evaluate_host('pauseTaskEvents.length===2')! == 'true' { break }
	}
	assert runtime.evaluate_host('pauseTaskEvents.join(",")==="timeupdate,pause"&&pauseTaskChecks.every(Boolean)&&savedPauseEvent.currentTarget===null&&player.paused&&other.paused')! == 'true'
	assert first.state() == .rejected && second.state() == .rejected
	reason := first.result().as_webidl_value()!
	assert voidptr(reason.dom_exception_?) == voidptr(second.result().as_webidl_value()!.dom_exception_?)
	actual := runtime.javascript_dom_exception(reason)!
	install := runtime.evaluate_host_value('(function(reason){globalThis.__pauseTaskReason=reason})')!
	defer { runtime.release_javascript_value(install) }
	_ = runtime.call_javascript_function(install, runtime.evaluate_host_value('undefined')!, [actual])!
	assert runtime.evaluate_host('__pauseTaskReason instanceof DOMException&&__pauseTaskReason.name==="AbortError"&&__pauseTaskReason.message==="Media playback was paused"&&__pauseTaskReason.code===20')! == 'true'
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
}
