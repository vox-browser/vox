module main

import browserjs
import dom
import html
import page
import time

fn test_native_volume_and_pause_bindings_observe_actual_started_audio_and_owner_notifications() {
	// This task/state regression exercises a permitted explicit play request.
	mut playback_policy := html.AutoplaySettings.the()
	previous_policy := playback_policy.policy()
	previous_allowlist := playback_policy.allowlist().map(it.serialize())
	defer { playback_policy.set_policy(previous_policy, previous_allowlist) }
	playback_policy.set_policy(.allow_audio_and_video, [])
	$if !darwin { return }
	owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time('<audio id="player"></audio><audio id="other"></audio>', dom.URL{
		value: 'https://native-started-audio.example.test/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut media := html.html_media_element_for_dom_element(document.get_element_by_id('player')?)?
	media.set_fetch_hook(fn (_ dom.URL, _ u64) !html.MediaResourceResponse {
		return html.MediaResourceResponse{
			mime_type: 'video/mp4'
			duration: 20
			audio_tracks: [html.MediaTrackMetadata{ identifier: 1, name: 'Audio' }]
		}
	})
	media.set_source('/audio.mp4')
	media.load()!
	mut loop := html.main_thread_event_loop()
	for _ in 0 .. 100 { loop.process() }
	media.set_show_poster(false)
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [
		r'globalThis.audioEvents=[];globalThis.audioChecks=[];globalThis.savedAudioEvent=null;
 for(const name of ["playing","pause"])EventTarget.prototype.addEventListener.call(player,name,function(event){
 audioEvents.push(name);audioChecks.push(player.paused&&this===player&&event.target===player&&event.currentTarget===player&&event.isTrusted&&!event.bubbles&&!event.cancelable);savedAudioEvent=event;
 });EventTarget.prototype.addEventListener.call(other,"playing",()=>audioEvents.push("other"));',
	], runtime, mut messages)
	assert messages == []
	// Public JavaScript play Promise creation remains outside this translation.
	promise := media.play()
	assert !media.paused() && !media.is_playing_audio() && !document.is_playing_audio()
	assert runtime.evaluate_host('player.muted=true;player.muted=false;player.volume=0.5;!player.paused&&audioEvents.length===0')! == 'true'
	assert !document.is_playing_audio()
	assert owner.client().events.filter(it.name == 'change-audio-play-state').len == 0
	media.set_ready_state(.have_future_data)
	assert document.is_playing_audio() && promise.state() == .pending
	assert owner.client().events.filter(it.name == 'change-audio-play-state').map(it.text) == ['playing']
	assert runtime.evaluate_host('player.pause();player.paused&&other.paused&&audioEvents.length===0')! == 'true'
	assert !document.is_playing_audio() && !media.is_playing_audio()
	assert owner.client().events.filter(it.name == 'change-audio-play-state').map(it.text) == ['playing', 'paused']
	for _ in 0 .. 100 { loop.process() }
	assert promise.state() == .fulfilled && !document.is_playing_audio()
	assert runtime.evaluate_host('audioEvents.join(",")==="playing,pause"&&audioChecks.every(Boolean)&&savedAudioEvent.currentTarget===null')! == 'true'
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
}
