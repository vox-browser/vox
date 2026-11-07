module main

import browserjs
import dom
import html
import page
import time

fn test_native_volume_setter_pauses_the_actual_owner_before_ordered_events_and_model_rejection() {
	$if !darwin { return }
	mut policy := html.AutoplaySettings.the()
	old_policy := policy.policy()
	old_allowlist := policy.allowlist().map(it.serialize())
	defer { policy.set_policy(old_policy, old_allowlist) }
	policy.set_policy(.block_audio, [])
	owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time('<video id="player"></video><audio id="other"></audio>', dom.URL{
		value: 'https://native-volume-policy.example.test/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut media := html.html_media_element_for_dom_element(document.get_element_by_id('player')?)?
	media.set_fetch_hook(fn (_ dom.URL, _ u64) !html.MediaResourceResponse {
		return html.MediaResourceResponse{ mime_type: 'video/mp4', duration: 20 }
	})
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	media.set_volume(0)!
	media.set_source('/pending.mp4')
	media.load()!
	mut loop := html.main_thread_event_loop()
	for _ in 0 .. 100 { loop.process() }
	media.set_show_poster(false)
	// Pending promises belong to the actual model caller; JS play bindings remain separate.
	first := media.play()
	second := media.play()
	for _ in 0 .. 100 { loop.process() }
	assert !media.paused() && first.state() == .pending && second.state() == .pending
	run_document_javascript(document, document.url.serialize(), [
		r'globalThis.volumePolicyEvents=[];globalThis.volumePolicyChecks=[];globalThis.volumePolicyEvent=null;for(const type of ["volumechange","timeupdate","pause"])EventTarget.prototype.addEventListener.call(player,type,function(event){volumePolicyEvents.push(type);volumePolicyChecks.push(this===player&&event.target===player&&event.currentTarget===player&&event.isTrusted&&!event.bubbles&&!event.cancelable&&player.paused);volumePolicyEvent=event});EventTarget.prototype.addEventListener.call(other,"pause",()=>volumePolicyEvents.push("other"));',
	], runtime, mut messages)
	assert messages == []
	assert runtime.evaluate_host('player.volume=0.5;player.paused&&player.volume===0.5&&volumePolicyEvents.length===0')! == 'true'
	assert media.paused() && first.state() == .pending && second.state() == .pending
	for _ in 0 .. 100 { loop.process() }
	assert first.state() == .rejected && second.state() == .rejected
	assert runtime.evaluate_host('volumePolicyEvents.join(",")==="volumechange,timeupdate,pause"&&volumePolicyChecks.every(Boolean)&&volumePolicyEvent.currentTarget===null&&other.paused')! == 'true'
	reason := first.result().as_webidl_value()!
	assert voidptr(reason.dom_exception_?) == voidptr(second.result().as_webidl_value()!.dom_exception_?)
	actual := runtime.javascript_dom_exception(reason)!
	assert actual == runtime.javascript_dom_exception(reason)!
	install := runtime.evaluate_host_value('(function(reason){globalThis.volumePolicyReason=reason})')!
	defer { runtime.release_javascript_value(install) }
	_ = runtime.call_javascript_function(install, runtime.evaluate_host_value('undefined')!, [actual])!
	assert runtime.evaluate_host('volumePolicyReason instanceof DOMException&&volumePolicyReason.name==="AbortError"&&volumePolicyReason.code===20&&volumePolicyReason.message==="Media playback was paused"')! == 'true'
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
}
