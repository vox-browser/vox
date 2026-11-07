module main

import browserjs
import dom
import html
import page
import time

fn test_native_load_replays_source_removal_resets_actual_owner_and_defers_ordered_events() {
	// This task/state regression exercises a permitted explicit play request.
	mut playback_policy := html.AutoplaySettings.the()
	previous_policy := playback_policy.policy()
	previous_allowlist := playback_policy.allowlist().map(it.serialize())
	defer { playback_policy.set_policy(previous_policy, previous_allowlist) }
	playback_policy.set_policy(.allow_audio_and_video, [])
	$if !darwin { return }
	owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time('<video id="player" src="/pending.mp4"></video><audio id="other"></audio>', dom.URL{
		value: 'https://native-load-task.example.test/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut media := html.html_media_element_for_dom_element(document.get_element_by_id('player')?)?
	media.set_fetch_hook(fn (_ dom.URL, _ u64) !html.MediaResourceResponse {
		return html.MediaResourceResponse{ mime_type: 'video/mp4', duration: 20 }
	})
	media.load()!
	mut loop := html.main_thread_event_loop()
	for _ in 0 .. 100 { loop.process() }
	media.set_show_poster(false)
	first := media.play()
	second := media.play()
	media.set_current_playback_position(7)
	for _ in 0 .. 100 { loop.process() }
	assert first.state() == .pending && second.state() == .pending && !media.paused() && media.current_time() == 7
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'https://native-load-task.example.test/', [
		r'globalThis.loadTaskEvents=[];globalThis.loadTaskChecks=[];globalThis.savedLoadEvent=null;
 for(const name of ["abort","emptied","timeupdate","ratechange","volumechange"])EventTarget.prototype.addEventListener.call(player,name,function(event){
 loadTaskEvents.push(name);loadTaskChecks.push(player.paused&&player.currentTime===0&&player.playbackRate===2&&this===player&&event.target===player&&event.currentTarget===player&&event.isTrusted&&!event.bubbles&&!event.cancelable);savedLoadEvent=event;
 });EventTarget.prototype.addEventListener.call(other,"volumechange",()=>loadTaskEvents.push("other"));',
	], runtime, mut messages)
	assert messages == []
	assert runtime.evaluate_host(r'(()=>{
 if(typeof player.load!=="function")return false;
 player.volume=.5;other.volume=.5;player.defaultPlaybackRate=2;player.removeAttribute("src");
 return player.load()===undefined&&player.paused&&player.currentTime===0&&player.playbackRate===2&&player.networkState===0&&loadTaskEvents.length===0;
})()')! == 'true'
	assert media.current_src() == '' && document.get_element_by_id('player')?.get_attribute('src') == none
	assert first.state() == .rejected && second.state() == .rejected
	reason := first.result().as_webidl_value()!
	assert voidptr(reason.dom_exception_?) == voidptr(second.result().as_webidl_value()!.dom_exception_?)
	actual := runtime.javascript_dom_exception(reason)!
	install := runtime.evaluate_host_value('(function(reason){globalThis.__loadTaskReason=reason})')!
	defer { runtime.release_javascript_value(install) }
	_ = runtime.call_javascript_function(install, runtime.evaluate_host_value('undefined')!, [actual])!
	assert runtime.evaluate_host('__loadTaskReason instanceof DOMException&&__loadTaskReason.name==="AbortError"&&__loadTaskReason.message==="Media playback was aborted"&&__loadTaskReason.code===20')! == 'true'
	loop.perform_a_microtask_checkpoint()
	assert runtime.evaluate_host('loadTaskEvents.length===0')! == 'true'
	for _ in 0 .. 100 {
		loop.process()
		if runtime.evaluate_host('loadTaskEvents.length===5')! == 'true' { break }
	}
	assert runtime.evaluate_host('loadTaskEvents.join(",")==="other,abort,emptied,timeupdate,ratechange"&&loadTaskChecks.every(Boolean)&&savedLoadEvent.currentTarget===null&&player.paused&&other.paused')! == 'true'
	assert runtime.evaluate_host(r'(()=>{
 const audio=document.createElement("audio");document.body.appendChild(audio);
 return audio.load()===undefined&&audio.networkState===0&&audio.paused&&typeof HTMLMediaElement.prototype.load==="function";
})()')! == 'true'
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
}
