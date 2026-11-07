module main

import browserjs
import dom
import html
import page
import time

fn test_native_page_volume_properties_reach_the_dom_owner_and_deliver_live_tasks() {
	$if !darwin { return }
	owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time('<video id="player"></video><audio id="other"></audio>', dom.URL{
		value: 'https://native-page-volume.example.test/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'https://native-page-volume.example.test/', [
		r'globalThis.pageVolumeEvents=[];globalThis.pageVolumeChecks=[];globalThis.pageVolumeMicrotasks=-1;
 EventTarget.prototype.addEventListener.call(player,"volumechange",function(event){pageVolumeEvents.push([player.volume,player.muted]);pageVolumeChecks.push(this===player&&event.target===player&&event.currentTarget===player&&event instanceof Event&&event.isTrusted&&!event.bubbles&&!event.cancelable);globalThis.pageSavedVolumeEvent=event});
 EventTarget.prototype.addEventListener.call(other,"volumechange",()=>pageVolumeChecks.push(false));
 player.volume="0.5";player.muted={valueOf(){throw "boolean conversion must not run"}};player.volume=0.75;player.volume=0.75;player.muted=true;
 globalThis.pageVolumeSynchronous=pageVolumeEvents.length;
 Promise.resolve().then(()=>globalThis.pageVolumeMicrotasks=pageVolumeEvents.length);
 globalThis.pageVolumeRangeRejected=false;try{player.volume=2}catch(error){pageVolumeRangeRejected=error instanceof DOMException&&error.name==="IndexSizeError"&&error.code===1&&error.message==="Volume must be in the range 0.0 to 1.0, inclusive"}
 globalThis.pageVolumeConversionRejected=false;try{player.volume=Infinity}catch(error){pageVolumeConversionRejected=error instanceof TypeError};',
	], runtime, mut messages)
	assert messages == []
	media := html.html_media_element_for_dom_element(document.get_element_by_id('player')?)?
	assert media.volume() == 0.75 && media.muted()
	mut loop := html.main_thread_event_loop()
	loop.perform_a_microtask_checkpoint()
	assert runtime.evaluate_host('pageVolumeSynchronous===0&&pageVolumeMicrotasks===0&&pageVolumeEvents.length===0&&pageVolumeRangeRejected&&pageVolumeConversionRejected')! == 'true'
	for _ in 0 .. 100 {
		if media.event_count('volumechange') == 3 { break
		 }
		loop.process()
	}
	assert runtime.evaluate_host('pageVolumeEvents.length===3&&pageVolumeEvents.every(value=>value[0]===0.75&&value[1]===true)&&pageVolumeChecks.length===3&&pageVolumeChecks.every(Boolean)&&pageSavedVolumeEvent.currentTarget===null&&other.volume===1&&other.muted===false&&!Object.hasOwn(player,"volume")&&!Object.hasOwn(player,"muted")')! == 'true'
	assert voidptr(runtime.native_event_target(runtime.evaluate_host_value('player')!)!) == voidptr(media.event_target())
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().script_execution_depth == 0
		&& settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
}

fn test_native_page_created_audio_volume_properties_keep_one_dom_owner_and_reject_non_html_media() {
	$if !darwin { return }
	owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time('<div id="ordinary"></div>', dom.URL{
		value: 'https://native-created-volume.example.test/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'https://native-created-volume.example.test/', [
		r'globalThis.createdVolumeAudio=document.createElement("audio");createdVolumeAudio.id="volume-audio";
 createdVolumeAudio.volume=0.25;createdVolumeAudio.muted="false";document.body.appendChild(createdVolumeAudio);
 const svg=document.createElementNS("http://www.w3.org/2000/svg","video");let brands=0,conversions=0;
 for(const name of ["volume","muted"]){const d=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,name);
 if(d)for(const receiver of [ordinary,svg])try{d.set.call(receiver,{valueOf(){conversions++;throw "coercion must not run"}})}catch(error){if(error instanceof TypeError)brands++}}
 globalThis.createdVolumePassed=createdVolumeAudio instanceof HTMLMediaElement&&createdVolumeAudio.volume===0.25&&createdVolumeAudio.muted===true&&!Object.hasOwn(createdVolumeAudio,"volume")&&!Object.hasOwn(createdVolumeAudio,"muted")&&brands===4&&conversions===0&&!("volume" in svg)&&!("muted" in ordinary);',
	], runtime, mut messages)
	assert messages == []
	assert runtime.evaluate_host('createdVolumePassed')! == 'true'
	created := document.get_element_by_id('volume-audio')?
	media := html.html_media_element_for_dom_element(created)?
	assert media.volume() == 0.25 && media.muted()
	assert media.document()? == document
	assert voidptr(runtime.native_event_target(runtime.evaluate_host_value('createdVolumeAudio')!)!) == voidptr(created)
	mut count := 0
	for _, element in runtime.canvas_elements_for_binding() {
		if element == created { count++ }
	}
	assert count == 1
}
