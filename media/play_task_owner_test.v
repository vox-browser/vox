module main

import browserjs
import dom
import html
import page
import time

@[heap]
struct NativePlayTaskClock {
mut:
	position f64
	starts   int
}

fn test_actual_media_play_tasks_reach_native_event_listeners_with_the_captured_start_position() {
	// This task/state regression exercises a permitted explicit play request.
	mut playback_policy := html.AutoplaySettings.the()
	previous_policy := playback_policy.policy()
	previous_allowlist := playback_policy.allowlist().map(it.serialize())
	defer { playback_policy.set_policy(previous_policy, previous_allowlist) }
	playback_policy.set_policy(.allow_audio_and_video, [])
	$if !darwin { return }
	owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time('<video id="player"></video><audio id="other"></audio>', dom.URL{
		value: 'https://native-play-task.example.test/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut media := html.html_media_element_for_dom_element(document.get_element_by_id('player')?)?
	media.set_fetch_hook(fn (_ dom.URL, _ u64) !html.MediaResourceResponse {
		return html.MediaResourceResponse{ mime_type: 'video/mp4', duration: 20, buffered_end: 20 }
	})
	media.set_source('/movie.mp4')
	media.load()!
	mut loop := html.main_thread_event_loop()
	for _ in 0 .. 100 { loop.process() }
	media.set_show_poster(false)
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'https://native-play-task.example.test/', [
		r'globalThis.playTaskEvents=[];globalThis.playTaskChecks=[];globalThis.playTaskPositions=[];globalThis.savedPlayingEvent=null;
 for(const name of ["play","playing"])EventTarget.prototype.addEventListener.call(player,name,function(event){
 playTaskEvents.push(name);playTaskChecks.push(!player.paused&&this===player&&event.target===player&&event.currentTarget===player&&event.isTrusted&&!event.bubbles&&!event.cancelable);
 if(name==="playing"){playTaskPositions.push(player.currentTime);savedPlayingEvent=event;}
 });EventTarget.prototype.addEventListener.call(other,"playing",()=>playTaskEvents.push("other"));',
	], runtime, mut messages)
	assert messages == []
	clock := &NativePlayTaskClock{ position: 2 }
	media.set_playback_manager_hooks(html.MediaPlaybackManagerHooks{
		current_time: fn [clock] () f64 { return clock.position }
		play: fn [clock] () {
			mut state := unsafe { &NativePlayTaskClock(clock) }
			state.starts++
			state.position = 8
		}
	})
	// Enter through the V convenience caller and observe its native DOM events;
	// the native play promise binding has its own focused caller regressions.
	first := media.play()
	second := media.play()
	assert clock.starts == 1 && first.state() == .pending && second.state() == .pending
	assert runtime.evaluate_host('!player.paused&&playTaskEvents.length===0')! == 'true'
	loop.perform_a_microtask_checkpoint()
	assert runtime.evaluate_host('playTaskEvents.length===0')! == 'true'
	for _ in 0 .. 100 {
		loop.process()
		if second.state() == .fulfilled { break }
	}
	assert first.state() == .fulfilled && second.state() == .fulfilled
	assert runtime.evaluate_host('playTaskEvents.join(",")==="play,playing"&&playTaskChecks.every(Boolean)&&playTaskPositions.join(",")==="2"&&savedPlayingEvent.currentTarget===null&&other.paused')! == 'true'
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
}
