module main

import browserjs
import dom
import html
import page
import time

fn test_native_page_play_replays_source_mutation_and_fulfills_after_trusted_playing() {
	$if !darwin {
		return
	}
	mut policy := html.AutoplaySettings.the()
	previous_policy := policy.policy()
	previous_allowlist := policy.allowlist().map(it.serialize())
	defer { policy.set_policy(previous_policy, previous_allowlist) }
	policy.set_policy(.allow_audio_and_video, [])
	owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time('<video id="player" preload="none"></video><div id="ordinary"></div>', dom.URL{
		value: 'https://native-play-promise.example.test/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut media := html.html_media_element_for_dom_element(document.get_element_by_id('player')?)?
	media.set_fetch_hook(fn (url dom.URL, _ u64) !html.MediaResourceResponse {
		assert url.serialize() == 'https://native-play-promise.example.test/selected.mp4'
		return html.MediaResourceResponse{ mime_type: 'video/mp4', duration: 20, buffered_end: 20 }
	})
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [
		r'globalThis.playOrder=[];globalThis.playChecks=[];
 for(const name of ["play","playing"])EventTarget.prototype.addEventListener.call(player,name,function(event){
 playOrder.push(name);playChecks.push(this===player&&event.target===player&&event.currentTarget===player&&event.isTrusted);
 });player.src="/selected.mp4";globalThis.firstPlay=player.play();globalThis.secondPlay=player.play();
 globalThis.playImmediate=firstPlay instanceof Promise&&secondPlay instanceof Promise&&firstPlay!==secondPlay&&!player.paused&&playOrder.length===0&&!Object.hasOwn(player,"play")&&!("play" in ordinary);
 firstPlay.then(value=>{playChecks.push(value===undefined);playOrder.push("first")});secondPlay.then(value=>{playChecks.push(value===undefined);playOrder.push("second")});',
	], runtime, mut messages)
	assert messages == []
	assert runtime.evaluate_host('playImmediate')! == 'true'
	assert media.current_src() == 'https://native-play-promise.example.test/selected.mp4'
	assert document.get_element_by_id('player')?.get_attribute('src')? == '/selected.mp4'
	mut loop := html.main_thread_event_loop()
	loop.perform_a_microtask_checkpoint()
	assert runtime.evaluate_host('playOrder.length===0')! == 'true'
	for _ in 0 .. 100 {
		loop.process()
		if runtime.evaluate_host('playOrder.includes("second")')! == 'true' { break }
	}
	assert runtime.evaluate_host('playOrder.join(",")==="play,playing,first,second"&&playChecks.every(Boolean)')! == 'true'
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
}

fn test_native_page_created_media_play_keeps_dom_owner_and_pause_rejection_batch() {
	$if !darwin {
		return
	}
	mut policy := html.AutoplaySettings.the()
	previous_policy := policy.policy()
	previous_allowlist := policy.allowlist().map(it.serialize())
	defer { policy.set_policy(previous_policy, previous_allowlist) }
	policy.set_policy(.allow_audio_and_video, [])
	owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time('<div id="ordinary"></div>', dom.URL{
		value: 'https://native-created-play.example.test/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [
		r'globalThis.createdPlay=document.createElement("audio");createdPlay.id="created-play";
 globalThis.createdOrder=[];globalThis.createdReasons=[];globalThis.createdChecks=[];
 for(const name of ["play","waiting","timeupdate","pause"])EventTarget.prototype.addEventListener.call(createdPlay,name,function(event){createdOrder.push(name);createdChecks.push(this===createdPlay&&event.target===createdPlay&&event.isTrusted)});
 const first=createdPlay.play();document.body.appendChild(createdPlay);const second=createdPlay.play();createdPlay.pause();
 globalThis.createdImmediate=first instanceof Promise&&second instanceof Promise&&first!==second&&createdPlay.paused&&createdOrder.length===0&&!Object.hasOwn(createdPlay,"play");
 for(const request of [first,second])request.catch(reason=>{createdReasons.push(reason);createdOrder.push("rejected")});',
	], runtime, mut messages)
	assert messages == []
	assert runtime.evaluate_host('createdImmediate')! == 'true'
	created := document.get_element_by_id('created-play')?
	media := html.html_media_element_for_dom_element(created)?
	assert media.paused() && media.document()? == document
	assert voidptr(runtime.native_event_target(runtime.evaluate_host_value('createdPlay')!)!) == voidptr(created)
	mut loop := html.main_thread_event_loop()
	for _ in 0 .. 100 {
		loop.process()
		if runtime.evaluate_host('createdReasons.length===2')! == 'true' { break }
	}
	assert runtime.evaluate_host('createdOrder.join(",")')! == 'timeupdate,play,waiting,timeupdate,pause,rejected,rejected'
	assert runtime.evaluate_host(r'createdChecks.every(Boolean)&&createdReasons[0]===createdReasons[1]&&createdReasons[0] instanceof DOMException&&createdReasons[0].name==="AbortError"&&createdReasons[0].code===20&&createdReasons[0].message==="Media playback was paused"')! == 'true'
}
