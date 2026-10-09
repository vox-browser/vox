module main

import browserjs
import dom
import html
import page
import time

fn test_model_play_permission_rejection_reaches_native_exception_identity_without_media_events() {
	$if !darwin { return }
	mut policy := html.AutoplaySettings.the()
	old_policy := policy.policy()
	old_allowlist := policy.allowlist().map(it.serialize())
	defer { policy.set_policy(old_policy, old_allowlist) }
	policy.set_policy(.block_audio_and_video, [])
	owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time('<video id="player" src="/movie.mp4"></video><audio id="other"></audio>', dom.URL{
		value: 'https://native-play-permission.example.test/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut media := html.html_media_element_for_dom_element(document.get_element_by_id('player')?)?
	media.set_fetch_hook(fn (_ dom.URL, _ u64) !html.MediaResourceResponse {
		return html.MediaResourceResponse{ mime_type: 'video/mp4', duration: 20, buffered_end: 20 }
	})
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [
		r'globalThis.permissionEvents=[];globalThis.permissionChecks=[];for(const type of ["play","playing"])EventTarget.prototype.addEventListener.call(player,type,function(event){permissionEvents.push(type);permissionChecks.push(this===player&&event.target===player&&event.currentTarget===player&&event.isTrusted)});',
	], runtime, mut messages)
	assert messages == []
	// Enter the actual V caller; native JavaScript play() promises remain separate.
	denied := media.play()
	assert denied.state() == .rejected && media.paused()
	reason := denied.result().as_webidl_value()!
	assert reason.dom_exception_?.name() == 'NotAllowedError'
	actual := runtime.javascript_dom_exception(reason)!
	assert actual == runtime.javascript_dom_exception(reason)!
	install := runtime.evaluate_host_value('(function(reason){globalThis.playDenied=reason})')!
	defer { runtime.release_javascript_value(install) }
	_ = runtime.call_javascript_function(install, runtime.evaluate_host_value('undefined')!, [actual])!
	assert runtime.evaluate_host('playDenied instanceof DOMException&&playDenied.name==="NotAllowedError"&&playDenied.code===0&&playDenied.message==="Media playback is not allowed without user interaction"&&player.paused&&permissionEvents.length===0')! == 'true'
	mut loop := html.main_thread_event_loop()
	for _ in 0 .. 100 { loop.process() }
	assert runtime.evaluate_host('permissionEvents.length===0&&player.paused')! == 'true'
	policy.set_policy(.allow_audio_and_video, [])
	allowed := media.play()
	assert allowed.state() == .pending && !media.paused()
	for _ in 0 .. 100 { loop.process() }
	assert allowed.state() == .fulfilled
	assert runtime.evaluate_host('permissionEvents.join(",")==="play,playing"&&permissionChecks.every(Boolean)&&!player.paused&&other.paused')! == 'true'
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
}
