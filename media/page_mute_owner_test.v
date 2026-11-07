module main

import browserjs
import dom
import html
import page
import time

fn test_native_media_properties_and_events_preserve_page_mute_ownership() {
	// This task/state regression exercises a permitted explicit play request.
	mut playback_policy := html.AutoplaySettings.the()
	previous_policy := playback_policy.policy()
	previous_allowlist := playback_policy.allowlist().map(it.serialize())
	defer { playback_policy.set_policy(previous_policy, previous_allowlist) }
	playback_policy.set_policy(.allow_audio_and_video, [])
	$if !darwin { return }
	mut owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time('<video id="player"></video><audio id="other"></audio>', dom.URL{
		value: 'https://native-page-mute.example.test/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut media := html.html_media_element_for_dom_element(document.get_element_by_id('player')?)?
	media.set_fetch_hook(fn (_ dom.URL, _ u64) !html.MediaResourceResponse {
		return html.MediaResourceResponse{
			mime_type: 'video/mp4'
			duration: 20
			audio_tracks: [html.MediaTrackMetadata{ identifier: 1, name: 'Audio' }]
			video_tracks: [html.MediaTrackMetadata{ identifier: 2, name: 'Video', pixel_width: 320, pixel_height: 180 }]
		}
	})
	media.set_source('/movie.mp4')
	media.load()!
	mut loop := html.main_thread_event_loop()
	for _ in 0 .. 100 { loop.process() }
	media.set_ready_state(.have_future_data)
	media.set_show_poster(false)
	for _ in 0 .. 100 { loop.process() }
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [
		r'globalThis.muteEvents=[];globalThis.muteChecks=[];globalThis.savedMuteEvent=null;
 for(const name of ["volumechange","pause"])EventTarget.prototype.addEventListener.call(player,name,function(event){muteEvents.push(name);muteChecks.push(this===player&&event.target===player&&event.currentTarget===player&&event.isTrusted&&!event.bubbles&&!event.cancelable);savedMuteEvent=event;});
 EventTarget.prototype.addEventListener.call(other,"volumechange",()=>muteEvents.push("other"));',
	], runtime, mut messages)
	assert messages == []
	media.play()
	for _ in 0 .. 100 { loop.process() }
	assert document.is_playing_audio() && owner.is_screen_wake_lock_active()
	owner.set_page_mute_state(.muted)
	assert media.effective_media_volume() == 0 && !document.is_playing_audio()
	assert runtime.evaluate_host('!player.paused&&!player.muted&&player.volume===1&&muteEvents.length===0')! == 'true'
	assert runtime.evaluate_host('player.volume=0.5;player.volume===0.5&&!player.muted&&muteEvents.length===0')! == 'true'
	assert media.effective_media_volume() == 0 && !document.is_playing_audio()
	for _ in 0 .. 100 { loop.process() }
	assert runtime.evaluate_host('muteEvents.join(",")==="volumechange"&&muteChecks.every(Boolean)&&savedMuteEvent.currentTarget===null')! == 'true'
	owner.set_page_mute_state(.unmuted)
	assert media.effective_media_volume() == 0.5 && document.is_playing_audio()
	assert owner.is_screen_wake_lock_active()
	assert runtime.evaluate_host('player.pause();player.paused&&other.paused&&muteEvents.length===1')! == 'true'
	assert !document.is_playing_audio() && !owner.is_screen_wake_lock_active()
	for _ in 0 .. 100 { loop.process() }
	assert runtime.evaluate_host('muteEvents.join(",")==="volumechange,pause"&&muteChecks.every(Boolean)')! == 'true'
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
}
