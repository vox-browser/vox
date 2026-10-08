module main

import browserjs
import dom
import html
import page
import time

fn test_native_page_pause_uses_actual_parsed_media_owners() {
	$if !darwin { return }
	owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time('<video id="player"></video><audio id="other"></audio>', dom.URL{
		value: 'https://native-page-pause.example.test/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'https://native-page-pause.example.test/', [
		r'globalThis.pagePausePassed=false;const d=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"pause");
 if(d){player.currentTime=6;other.currentTime=-2;let conversions=0;
 const extra={[Symbol.toPrimitive](){conversions++;throw "extra argument"}};
 const result=player.pause(extra);const second=other.pause();
 globalThis.pagePausePassed=result===undefined&&second===undefined&&conversions===0&&player.paused&&other.paused&&player.currentTime===6&&other.currentTime===-2&&player.networkState===0&&player.readyState===0&&!Object.hasOwn(player,"pause")&&d.value.name==="pause"&&d.value.length===0&&d.writable&&d.enumerable&&d.configurable&&Function.prototype.toString.call(d.value).includes("[native code]");}',
	], runtime, mut messages)
	assert messages == []
	assert runtime.evaluate_host('pagePausePassed')! == 'true'
	media := html.html_media_element_for_dom_element(document.get_element_by_id('player')?)?
	other := html.html_media_element_for_dom_element(document.get_element_by_id('other')?)?
	assert media.paused() && other.paused() && media.current_time() == 6 && other.current_time() == -2
	assert voidptr(runtime.native_event_target(runtime.evaluate_host_value('player')!)!) == voidptr(media.event_target())
}

fn test_native_page_created_audio_pause_keeps_owner_across_insertion_and_rejects_nonmedia() {
	$if !darwin { return }
	owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time('<div id="ordinary"></div>', dom.URL{
		value: 'https://native-created-pause.example.test/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'https://native-created-pause.example.test/', [
		r'globalThis.pageCreatedPausePassed=false;globalThis.pauseAudio=document.createElement("audio");pauseAudio.id="pause-audio";
 const d=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"pause");if(d){pauseAudio.currentTime=3.25;
 const before=pauseAudio.pause();document.body.appendChild(pauseAudio);const after=pauseAudio.pause();
 const svg=document.createElementNS("http://www.w3.org/2000/svg","video");let brands=0,conversions=0;
 for(const receiver of [ordinary,svg])try{d.value.call(receiver,{valueOf(){conversions++;throw "unused argument"}})}catch(error){if(error instanceof TypeError)brands++}
 globalThis.pageCreatedPausePassed=before===undefined&&after===undefined&&pauseAudio.paused&&pauseAudio.currentTime===3.25&&!Object.hasOwn(pauseAudio,"pause")&&brands===2&&conversions===0&&!("pause" in ordinary)&&!("pause" in svg);}',
	], runtime, mut messages)
	assert messages == []
	assert runtime.evaluate_host('pageCreatedPausePassed')! == 'true'
	created := document.get_element_by_id('pause-audio')?
	media := html.html_media_element_for_dom_element(created)?
	assert media.paused() && media.current_time() == 3.25 && media.document()? == document
	assert voidptr(runtime.native_event_target(runtime.evaluate_host_value('pauseAudio')!)!) == voidptr(created)
	mut count := 0
	for _, element in runtime.canvas_elements_for_binding() {
		if element == created { count++ }
	}
	assert count == 1
}
