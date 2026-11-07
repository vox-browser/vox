module main

import browserjs
import dom
import html
import page
import time

fn test_native_page_fast_seek_uses_actual_media_owner_and_preserves_default_start() {
	$if !darwin { return }
	owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time('<video id="player"></video><audio id="other"></audio>', dom.URL{
		value: 'https://native-page-fast-seek.example.test/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'https://native-page-fast-seek.example.test/', [
		r'globalThis.pageFastSeekPassed=false;const fastSeekDescriptor=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"fastSeek");
 if(fastSeekDescriptor){player.currentTime=6;other.currentTime=-2;let hints=[];const value={[Symbol.toPrimitive](hint){hints.push(hint);return 8}};
 const result=player.fastSeek(value,{valueOf(){throw "extra argument"}});other.fastSeek(3);let invalid=0,missing=false;
 for(const value of [NaN,Infinity,1n,Symbol()])try{player.fastSeek(value)}catch(error){if(error instanceof TypeError)invalid++}
 try{player.fastSeek()}catch(error){missing=error instanceof TypeError&&error.message==="fastSeek() needs one argument"}
 globalThis.pageFastSeekPassed=result===undefined&&hints.join(",")==="number"&&player.currentTime===6&&other.currentTime===-2&&player.readyState===0&&!player.seeking&&invalid===4&&missing&&!Object.hasOwn(player,"fastSeek")&&Function.prototype.toString.call(fastSeekDescriptor.value).includes("[native code]");}',
	], runtime, mut messages)
	assert messages == []
	assert runtime.evaluate_host('pageFastSeekPassed')! == 'true'
	media := html.html_media_element_for_dom_element(document.get_element_by_id('player')?)?
	other := html.html_media_element_for_dom_element(document.get_element_by_id('other')?)?
	assert !media.show_poster() && !other.show_poster()
	assert media.current_time() == 6 && other.current_time() == -2
	assert voidptr(runtime.native_event_target(runtime.evaluate_host_value('player')!)!) == voidptr(media.event_target())
}

fn test_native_page_created_audio_fast_seek_keeps_owner_across_insertion_and_rejects_nonmedia() {
	$if !darwin { return }
	owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time('<div id="ordinary"></div>', dom.URL{
		value: 'https://native-created-fast-seek.example.test/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'https://native-created-fast-seek.example.test/', [
		r'globalThis.pageCreatedFastSeekPassed=false;globalThis.fastSeekAudio=document.createElement("audio");fastSeekAudio.id="fast-audio";
 const d=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"fastSeek");if(d){fastSeekAudio.currentTime=3.25;
 const before=fastSeekAudio.fastSeek(7);document.body.appendChild(fastSeekAudio);const after=fastSeekAudio.fastSeek(-2);
 const svg=document.createElementNS("http://www.w3.org/2000/svg","video");let brands=0,conversions=0;
 for(const receiver of [ordinary,svg])try{d.value.call(receiver,{valueOf(){conversions++;throw "must not convert"}})}catch(error){if(error instanceof TypeError)brands++}
 globalThis.pageCreatedFastSeekPassed=before===undefined&&after===undefined&&fastSeekAudio.currentTime===3.25&&!Object.hasOwn(fastSeekAudio,"fastSeek")&&brands===2&&conversions===0&&!("fastSeek" in ordinary)&&!("fastSeek" in svg);}',
	], runtime, mut messages)
	assert messages == []
	assert runtime.evaluate_host('pageCreatedFastSeekPassed')! == 'true'
	created := document.get_element_by_id('fast-audio')?
	media := html.html_media_element_for_dom_element(created)?
	assert !media.show_poster() && media.current_time() == 3.25 && media.document()? == document
	assert voidptr(runtime.native_event_target(runtime.evaluate_host_value('fastSeekAudio')!)!) == voidptr(created)
	mut count := 0
	for _, element in runtime.canvas_elements_for_binding() {
		if element == created { count++ }
	}
	assert count == 1
}
