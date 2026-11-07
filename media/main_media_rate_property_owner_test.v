module main

import browserjs
import dom
import html
import page
import time

fn test_native_page_rate_properties_reach_the_dom_owner_and_deliver_live_tasks() {
	$if !darwin { return }
	owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time('<video id="player"></video><audio id="other"></audio>', dom.URL{
		value: 'https://native-page-rate.example.test/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'https://native-page-rate.example.test/', [
		r'globalThis.pageRateEvents=[];globalThis.pageRateChecks=[];globalThis.pageRateMicrotasks=-1;
 EventTarget.prototype.addEventListener.call(player,"ratechange",function(event){pageRateEvents.push([player.defaultPlaybackRate,player.playbackRate]);pageRateChecks.push(this===player&&event.target===player&&event.currentTarget===player&&event.isTrusted&&!event.bubbles&&!event.cancelable);globalThis.pageSavedRateEvent=event});
 EventTarget.prototype.addEventListener.call(other,"ratechange",()=>pageRateChecks.push(false));
 player.defaultPlaybackRate=2;player.playbackRate="0.5";player.defaultPlaybackRate=3;player.defaultPlaybackRate=3;
 globalThis.pageRateSynchronous=pageRateEvents.length;
 Promise.resolve().then(()=>globalThis.pageRateMicrotasks=pageRateEvents.length);
 globalThis.pageRateRangeRejected=false;try{player.playbackRate=65}catch(error){pageRateRangeRejected=error instanceof DOMException&&error.name==="NotSupportedError"}
 globalThis.pageRateConversionRejected=false;try{player.defaultPlaybackRate=Infinity}catch(error){pageRateConversionRejected=error instanceof TypeError};',
	], runtime, mut messages)
	assert messages == []
	media := html.html_media_element_for_dom_element(document.get_element_by_id('player')?)?
	assert media.default_playback_rate() == 3 && media.playback_rate() == 0.5
	mut loop := html.main_thread_event_loop()
	loop.perform_a_microtask_checkpoint()
	assert runtime.evaluate_host('pageRateSynchronous===0&&pageRateMicrotasks===0&&pageRateEvents.length===0&&pageRateRangeRejected&&pageRateConversionRejected')! == 'true'
	for _ in 0 .. 100 {
		if media.event_count('ratechange') == 3 { break
		 }
		loop.process()
	}
	assert runtime.evaluate_host('pageRateEvents.length===3&&pageRateEvents.every(value=>value[0]===3&&value[1]===0.5)&&pageRateChecks.length===3&&pageRateChecks.every(Boolean)&&pageSavedRateEvent.currentTarget===null&&other.playbackRate===1&&!Object.hasOwn(player,"playbackRate")')! == 'true'
	assert voidptr(runtime.native_event_target(runtime.evaluate_host_value('player')!)!) == voidptr(media.event_target())
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().script_execution_depth == 0
		&& settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
}

fn test_native_page_created_audio_rate_properties_share_one_dom_owner_and_reject_non_html_media() {
	$if !darwin { return }
	owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time('<div id="ordinary"></div>', dom.URL{
		value: 'https://native-created-rate.example.test/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'https://native-created-rate.example.test/', [
		r'globalThis.createdRateAudio=document.createElement("audio");createdRateAudio.id="rate-audio";
 createdRateAudio.defaultPlaybackRate=4;createdRateAudio.playbackRate=0.25;document.body.appendChild(createdRateAudio);
 const svg=document.createElementNS("http://www.w3.org/2000/svg","video");
 const d=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"playbackRate");let brands=0;
 if(d)for(const receiver of [ordinary,svg])try{d.set.call(receiver,{valueOf(){throw "coercion must not run"}})}catch(error){if(error instanceof TypeError)brands++}
 globalThis.createdRatePassed=createdRateAudio instanceof HTMLMediaElement&&createdRateAudio.defaultPlaybackRate===4&&createdRateAudio.playbackRate===0.25&&!Object.hasOwn(createdRateAudio,"playbackRate")&&brands===2&&!("playbackRate" in svg)&&!("playbackRate" in ordinary);',
	], runtime, mut messages)
	assert messages == []
	assert runtime.evaluate_host('createdRatePassed')! == 'true'
	created := document.get_element_by_id('rate-audio')?
	media := html.html_media_element_for_dom_element(created)?
	assert media.default_playback_rate() == 4 && media.playback_rate() == 0.25
	assert media.document()? == document
	assert voidptr(runtime.native_event_target(runtime.evaluate_host_value('createdRateAudio')!)!) == voidptr(created)
	mut count := 0
	for _, element in runtime.canvas_elements_for_binding() {
		if element == created { count++ }
	}
	assert count == 1
}
