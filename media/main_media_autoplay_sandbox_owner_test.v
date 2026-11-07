module main

import browserjs
import dom
import html
import page
import time

fn test_native_load_fetches_sandboxed_autoplay_media_without_automatically_playing_it() {
	// This task/state regression exercises a permitted explicit play request.
	mut playback_policy := html.AutoplaySettings.the()
	previous_policy := playback_policy.policy()
	previous_allowlist := playback_policy.allowlist().map(it.serialize())
	defer { playback_policy.set_policy(previous_policy, previous_allowlist) }
	playback_policy.set_policy(.allow_audio_and_video, [])
	$if !darwin { return }
	owner := page.Page.create(1)!
	mut document := parse_browser_navigation_document_for_page_with_response_time('<video id="video" autoplay preload="none"></video><audio id="audio" autoplay preload="none"></audio>', dom.URL{
		value: 'https://native-autoplay-sandbox.example.test/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	document.set_active_sandboxing_flag_bits(u32(html.SandboxingFlag.sandboxed_automatic_features))
	for name in ['video', 'audio'] {
		mut media := html.html_media_element_for_dom_element(document.get_element_by_id(name)?)?
		media.set_fetch_hook(fn (_ dom.URL, _ u64) !html.MediaResourceResponse {
			return html.MediaResourceResponse{
				mime_type:    'video/mp4'
				duration:     20
				buffered_end: 20
			}
		})
		media.set_source('/movie.mp4')
	}
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'https://native-autoplay-sandbox.example.test/', [
		r'globalThis.autoplayEvents=[];for(const player of [video,audio])for(const type of ["play","playing"])EventTarget.prototype.addEventListener.call(player,type,()=>autoplayEvents.push(type));video.load();audio.load();',
	], runtime, mut messages)
	assert messages == []
	assert runtime.evaluate_host('video.paused&&audio.paused&&video.readyState===4&&audio.readyState===4&&video.duration===20&&audio.duration===20')! == 'true'
	mut loop := html.main_thread_event_loop()
	for _ in 0 .. 100 {
		loop.process()
	}
	assert runtime.evaluate_host('autoplayEvents.length===0&&video.paused&&audio.paused')! == 'true'
	// The automatic-features flag blocks autoplay, not an explicit play request.
	for name in ['video', 'audio'] {
		mut media := html.html_media_element_for_dom_element(document.get_element_by_id(name)?)?
		promise := media.play()
		for _ in 0 .. 100 {
			loop.process()
		}
		assert promise.state() == .fulfilled && !media.paused()
	}
	assert runtime.evaluate_host('autoplayEvents.join(",")==="play,playing,play,playing"')! == 'true'
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().script_execution_depth == 0
		&& settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
}
