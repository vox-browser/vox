module main

import browserjs
import dom
import html
import page
import time

fn test_native_pause_releases_only_its_video_owner_screen_wake_lock() {
	// This task/state regression exercises a permitted explicit play request.
	mut playback_policy := html.AutoplaySettings.the()
	previous_policy := playback_policy.policy()
	previous_allowlist := playback_policy.allowlist().map(it.serialize())
	defer { playback_policy.set_policy(previous_policy, previous_allowlist) }
	playback_policy.set_policy(.allow_audio_and_video, [])
	$if !darwin { return }
	owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time('<video id="first"></video><video id="second"></video>', dom.URL{
		value: 'https://native-media-wake.example.test/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut media := []&html.HTMLMediaElement{}
	for name in ['first', 'second'] {
		mut player := html.html_media_element_for_dom_element(document.get_element_by_id(name)?)?
		player.set_fetch_hook(fn (_ dom.URL, _ u64) !html.MediaResourceResponse {
			return html.MediaResourceResponse{
				mime_type: 'video/mp4'
				duration: 20
				buffered_end: 20
				audio_tracks: [html.MediaTrackMetadata{ identifier: 1, name: 'Audio' }]
				video_tracks: [html.MediaTrackMetadata{ identifier: 2, name: 'Video', pixel_width: 320, pixel_height: 180 }]
			}
		})
		player.set_source('/movie.mp4')
		player.load()!
		media << player
	}
	mut loop := html.main_thread_event_loop()
	for _ in 0 .. 100 { loop.process() }
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [
		r'globalThis.wakeEvents=[];globalThis.wakeChecks=[];for(const player of [first,second])EventTarget.prototype.addEventListener.call(player,"pause",function(event){wakeEvents.push(this.id);wakeChecks.push(this===player&&event.target===player&&event.currentTarget===player&&event.isTrusted&&!event.bubbles&&!event.cancelable);});',
	], runtime, mut messages)
	assert messages == []
	mut first := media[0]
	mut second := media[1]
	first.play()
	second.play()
	assert owner.is_screen_wake_lock_active()
	assert owner.client().events.filter(it.name == 'change-screen-wake-lock-state').map(it.text) == ['acquired']
	assert runtime.evaluate_host('first.muted=true;first.volume=0;!first.paused&&!second.paused')! == 'true'
	assert owner.is_screen_wake_lock_active()
	assert runtime.evaluate_host('first.pause();first.paused&&!second.paused&&wakeEvents.length===0')! == 'true'
	assert owner.is_screen_wake_lock_active()
	assert owner.client().events.filter(it.name == 'change-screen-wake-lock-state').map(it.text) == ['acquired']
	assert runtime.evaluate_host('second.pause();first.paused&&second.paused&&wakeEvents.length===0')! == 'true'
	assert !owner.is_screen_wake_lock_active()
	assert owner.client().events.filter(it.name == 'change-screen-wake-lock-state').map(it.text) == ['acquired', 'released']
	for _ in 0 .. 100 { loop.process() }
	assert runtime.evaluate_host('wakeEvents.join(",")==="first,second"&&wakeChecks.every(Boolean)')! == 'true'
	assert !owner.is_screen_wake_lock_active()
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
}
