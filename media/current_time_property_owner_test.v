module main

import browserjs
import dom
import html
import page
import time

fn test_native_page_current_time_writes_default_positions_on_the_actual_dom_models() {
	$if !darwin { return }
	owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time('<video id="player"></video><audio id="other"></audio>', dom.URL{
		value: 'https://native-page-current-time.example.test/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'https://native-page-current-time.example.test/', [
		r'const timeDescriptor=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"currentTime");
 globalThis.pageTimePassed=false;
 if(timeDescriptor){let hints=[];const value={[Symbol.toPrimitive](hint){hints.push(hint);return -2}};
 const assigned=(player.currentTime=other.currentTime=value);let invalid=0;
 for(const value of [NaN,Infinity,1n,Symbol()])try{player.currentTime=value}catch(error){if(error instanceof TypeError)invalid++}
 globalThis.pageTimePassed=assigned===value&&hints.join(",")==="number,number"&&player.currentTime===-2&&other.currentTime===-2&&player.readyState===0&&invalid===4&&!Object.hasOwn(player,"currentTime")&&!Object.hasOwn(other,"currentTime")&&Function.prototype.toString.call(timeDescriptor.get).includes("[native code]");}',
	], runtime, mut messages)
	assert messages == []
	assert runtime.evaluate_host('pageTimePassed')! == 'true'
	media := html.html_media_element_for_dom_element(document.get_element_by_id('player')?)?
	other := html.html_media_element_for_dom_element(document.get_element_by_id('other')?)?
	assert media.current_time() == -2 && other.current_time() == -2
	assert media.document()? == document
	assert voidptr(runtime.native_event_target(runtime.evaluate_host_value('player')!)!) == voidptr(media.event_target())
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().script_execution_depth == 0
		&& settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
}

fn test_native_page_created_audio_current_time_keeps_one_owner_and_no_non_media_accessor() {
	$if !darwin { return }
	owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time('<div id="ordinary"></div>', dom.URL{
		value: 'https://native-created-current-time.example.test/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'https://native-created-current-time.example.test/', [
		r'globalThis.createdTimeAudio=document.createElement("audio");createdTimeAudio.id="time-audio";
 createdTimeAudio.currentTime=3.25;document.body.appendChild(createdTimeAudio);
 const svg=document.createElementNS("http://www.w3.org/2000/svg","video");let brands=0,conversions=0;
 const d=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"currentTime");
 if(d)for(const receiver of [ordinary,svg])try{d.set.call(receiver,{valueOf(){conversions++;throw "coercion must not run"}})}catch(error){if(error instanceof TypeError)brands++}
 globalThis.createdTimePassed=createdTimeAudio instanceof HTMLMediaElement&&createdTimeAudio.currentTime===3.25&&!Object.hasOwn(createdTimeAudio,"currentTime")&&brands===2&&conversions===0&&!("currentTime" in ordinary)&&!("currentTime" in svg);',
	], runtime, mut messages)
	assert messages == []
	assert runtime.evaluate_host('createdTimePassed')! == 'true'
	created := document.get_element_by_id('time-audio')?
	media := html.html_media_element_for_dom_element(created)?
	assert media.current_time() == 3.25 && media.document()? == document
	assert voidptr(runtime.native_event_target(runtime.evaluate_host_value('createdTimeAudio')!)!) == voidptr(created)
	mut count := 0
	for _, element in runtime.canvas_elements_for_binding() {
		if element == created { count++ }
	}
	assert count == 1
}
