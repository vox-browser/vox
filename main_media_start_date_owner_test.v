module main

import browserjs
import dom
import html
import page
import time

fn test_native_page_start_date_has_native_descriptor_and_fresh_invalid_dates() {
	$if !darwin { return }
	owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time('<video id="player"></video><audio id="other"></audio><div id="ordinary"></div>', dom.URL{
		value: 'https://native-page-start-date.example.test/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'https://native-page-start-date.example.test/', [
		r'globalThis.pageStartDatePassed=false;const startDateDescriptor=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"getStartDate");
 if(startDateDescriptor){const D=Date,time=Date.prototype.getTime,apply=Reflect.apply,p=Date.prototype;
 globalThis.Date=function(){throw "author Date"};D.prototype.getTime=function(){throw "author getTime"};
 let conversions=0;const ignored={[Symbol.toPrimitive](){conversions++;throw "ignored argument"}};
 const a=player.getStartDate(ignored),b=player.getStartDate(),c=other.getStartDate();
 const svg=document.createElementNS("http://www.w3.org/2000/svg","video");let brands=0;
 for(const receiver of [ordinary,svg])try{startDateDescriptor.value.call(receiver)}catch(error){if(error instanceof TypeError)brands++}
 globalThis.pageStartDatePassed=startDateDescriptor.writable&&startDateDescriptor.enumerable&&startDateDescriptor.configurable&&startDateDescriptor.value.name==="getStartDate"&&startDateDescriptor.value.length===0&&Function.prototype.toString.call(startDateDescriptor.value).includes("[native code]")&&a instanceof D&&Object.getPrototypeOf(a)===p&&a!==b&&Number.isNaN(apply(time,a,[]))&&Number.isNaN(apply(time,b,[]))&&Number.isNaN(apply(time,c,[]))&&conversions===0&&brands===2&&!Object.hasOwn(player,"getStartDate")&&!Object.hasOwn(other,"getStartDate")&&!("getStartDate" in ordinary)&&!("getStartDate" in svg);}',
	], runtime, mut messages)
	assert messages == []
	assert runtime.evaluate_host('pageStartDatePassed')! == 'true'
	media := html.html_media_element_for_dom_element(document.get_element_by_id('player')?)?
	assert voidptr(runtime.native_event_target(runtime.evaluate_host_value('player')!)!) == voidptr(media.event_target())
}

fn test_native_page_created_audio_start_date_keeps_one_owner_across_insertion() {
	$if !darwin { return }
	owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time('<div id="ordinary"></div>', dom.URL{
		value: 'https://native-created-start-date.example.test/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'https://native-created-start-date.example.test/', [
		r'globalThis.pageCreatedStartDatePassed=false;globalThis.startDateAudio=document.createElement("audio");startDateAudio.id="start-date-audio";
 const d=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"getStartDate");if(d){
 const a=startDateAudio.getStartDate();document.body.appendChild(startDateAudio);const b=startDateAudio.getStartDate();
 globalThis.pageCreatedStartDatePassed=startDateAudio instanceof HTMLMediaElement&&a instanceof Date&&b instanceof Date&&a!==b&&Number.isNaN(a.getTime())&&Number.isNaN(b.getTime())&&!Object.hasOwn(startDateAudio,"getStartDate")&&!("getStartDate" in ordinary);}',
	], runtime, mut messages)
	assert messages == []
	assert runtime.evaluate_host('pageCreatedStartDatePassed')! == 'true'
	created := document.get_element_by_id('start-date-audio')?
	media := html.html_media_element_for_dom_element(created)?
	assert media.document()? == document
	assert voidptr(runtime.native_event_target(runtime.evaluate_host_value('startDateAudio')!)!) == voidptr(created)
	mut count := 0
	for _, element in runtime.canvas_elements_for_binding() {
		if element == created { count++ }
	}
	assert count == 1
}

fn test_native_page_start_date_observes_metadata_after_the_compact_snapshot_and_load_reset() {
	$if !darwin { return }
	owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time('<video id="player"></video><audio id="other"></audio>', dom.URL{
		value: 'https://native-live-start-date.example.test/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'https://native-live-start-date.example.test/', [
		r'globalThis.initialPageDate=player.getStartDate();globalThis.initialPageAudioDate=other.getStartDate();',
	], runtime, mut messages)
	assert messages == []
	mut media := html.html_media_element_for_dom_element(document.get_element_by_id('player')?)?
	media.set_playback_manager_hooks(html.MediaPlaybackManagerHooks{
		start_time_realtime: fn () ?i64 { return i64(-1_234_567) }
	})
	media.on_metadata_parsed(10)
	assert runtime.evaluate_host(r'globalThis.livePageDate=player.getStartDate();livePageDate.getTime()===-1235&&Number.isNaN(initialPageDate.getTime())&&Number.isNaN(initialPageAudioDate.getTime())&&Number.isNaN(other.getStartDate().getTime())')! == 'true'
	media.set_source(none)
	media.set_source_candidates([])
	media.load()!
	assert runtime.evaluate_host('Number.isNaN(player.getStartDate().getTime())&&livePageDate.getTime()===-1235')! == 'true'
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
}
