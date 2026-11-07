module main

import browserjs
import dom
import html
import page
import time

fn test_model_unsupported_play_reaches_native_typed_exception_identity_with_its_original_message() {
	$if !darwin { return }
	mut policy := html.AutoplaySettings.the()
	previous_policy := policy.policy()
	previous_allowlist := policy.allowlist().map(it.serialize())
	defer { policy.set_policy(previous_policy, previous_allowlist) }
	policy.set_policy(.allow_audio_and_video, [])
	owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time('<video id="video"></video><audio id="audio"></audio>', dom.URL{
		value: 'https://native-play-source-error.example.test/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [
		r'globalThis.sourceErrorEvents=[];globalThis.sourceErrorChecks=[];for(const player of [video,audio])for(const type of ["error","play","playing"])EventTarget.prototype.addEventListener.call(player,type,function(event){sourceErrorEvents.push(type);sourceErrorChecks.push(this===player&&event.target===player&&event.currentTarget===player&&event.isTrusted)});',
	], runtime, mut messages)
	assert messages == []
	for kind in ['video', 'audio'] {
		mut media := html.html_media_element_for_dom_element(document.get_element_by_id(kind)?)?
		media.handle_media_source_failure([], 'Decoder \x00 🎬 failed')
		// Exercise the V convenience caller and native exception wrapper identity.
		first := media.play()
		second := media.play()
		assert first.state() == .rejected && second.state() == .rejected
		assert first.result().kind == .runtime_value
		reason := first.result().as_webidl_value()!
		assert reason.dom_exception_?.name() == 'NotSupportedError'
		assert voidptr(reason.dom_exception_?) != voidptr(second.result().as_webidl_value()!.dom_exception_?)
		actual := runtime.javascript_dom_exception(reason)!
		assert actual == runtime.javascript_dom_exception(reason)!
		install := runtime.evaluate_host_value('(function(reason){globalThis.sourceErrorReason=reason})')!
		_ = runtime.call_javascript_function(install, runtime.evaluate_host_value('undefined')!, [actual])!
		runtime.release_javascript_value(install)
		assert runtime.evaluate_host(r'sourceErrorReason instanceof DOMException&&sourceErrorReason.name==="NotSupportedError"&&sourceErrorReason.code===9&&sourceErrorReason.message==="Decoder \u0000 🎬 failed"&&video.paused&&audio.paused&&sourceErrorEvents.every(type=>type==="error")&&sourceErrorChecks.every(Boolean)')! == 'true'
	}
	mut loop := html.main_thread_event_loop()
	for _ in 0 .. 100 { loop.process() }
	assert runtime.evaluate_host('sourceErrorEvents.join(",")==="error,error"&&video.paused&&audio.paused')! == 'true'
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
}
