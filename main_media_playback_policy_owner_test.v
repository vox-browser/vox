module main

import browserjs
import dom
import html
import page
import time

fn test_native_load_autoplay_uses_document_policy_and_muting_before_queuing_play_events() {
	$if !darwin { return }
	mut settings := html.AutoplaySettings.the()
	settings.set_policy(.block_audio, [])
	defer { settings.set_policy(.block_audio, []) }
	owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time('<video id="video" autoplay preload="none" src="/movie.mp4"></video><audio id="audio" autoplay preload="none" src="/sound.mp3"></audio>', dom.URL{
		value: 'https://native-playback-policy.example.test/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	for name in ['video', 'audio'] {
		mut media := html.html_media_element_for_dom_element(document.get_element_by_id(name)?)?
		media.set_fetch_hook(fn (_ dom.URL, _ u64) !html.MediaResourceResponse {
			return html.MediaResourceResponse{
				mime_type:    'video/mp4'
				duration:     20
				buffered_end: 20
			}
		})
	}
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'https://native-playback-policy.example.test/', [
		r'globalThis.policyEvents=[];for(const [name,player] of [["video",video],["audio",audio]])for(const type of ["play","playing"])EventTarget.prototype.addEventListener.call(player,type,function(event){if(this!==player||event.target!==player||event.currentTarget!==player||!event.isTrusted)throw new Error("identity");policyEvents.push(name+":"+type)});audio.muted=true;video.load();audio.load();',
	], runtime, mut messages)
	assert messages == []
	assert runtime.evaluate_host('video.paused&&!audio.paused&&audio.muted&&video.readyState===4&&audio.readyState===4&&policyEvents.length===0')! == 'true'
	mut loop := html.main_thread_event_loop()
	for _ in 0 .. 100 {
		loop.process()
	}
	assert runtime.evaluate_host('policyEvents.join(",")==="audio:play,audio:playing"')! == 'true'
	settings.set_policy(.block_audio_and_video, [
		'https://native-playback-policy.example.test',
	])
	assert runtime.evaluate_host('video.load()===undefined&&!video.paused')! == 'true'
	for _ in 0 .. 100 {
		loop.process()
	}
	assert runtime.evaluate_host('policyEvents.slice(2).join(",")==="video:play,video:playing"')! == 'true'
	execution := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert execution.realm().script_execution_depth == 0
		&& execution.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
}
