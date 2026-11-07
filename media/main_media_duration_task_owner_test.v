module main

import browserjs
import dom
import html
import page
import time

fn test_native_media_source_duration_events_are_tasks_and_read_the_live_dom_owner() {
	$if !darwin { return }
	owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time('<video id="player"></video><audio id="other"></audio>', dom.URL{
		value: 'https://native-media-duration-task.example.test/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut runtime := browserjs.Runtime.create()
	defer {
		html.run_blob_url_unloading_cleanup_steps(document)
		runtime.close()
	}
	mut messages := []string{}
	run_document_javascript(document, 'https://native-media-duration-task.example.test/', [
		r'globalThis.durationEvents=[];globalThis.durationChecks=[];globalThis.durationOpened=false;globalThis.microtaskDurationCount=-1;
EventTarget.prototype.addEventListener.call(player,"durationchange",function(event){
 durationEvents.push(player.duration);durationChecks.push(this===player&&event.target===player&&event.currentTarget===player&&event.isTrusted&&!event.bubbles&&!event.cancelable);globalThis.savedDurationEvent=event;
});EventTarget.prototype.addEventListener.call(other,"durationchange",()=>durationChecks.push(false));
globalThis.durationSource=new MediaSource();globalThis.durationURL=URL.createObjectURL(durationSource);
durationSource.onsourceopen=function(){durationSource.duration=10;durationSource.duration=10;durationSource.duration=20;globalThis.synchronousDurationCount=durationEvents.length;Promise.resolve().then(()=>globalThis.microtaskDurationCount=durationEvents.length);durationOpened=true;};
player.setAttribute("src",durationURL);globalThis.durationAttachedSrc=player.currentSrc;',
	], runtime, mut messages)
	assert messages == []
	mut loop := html.main_thread_event_loop()
	for _ in 0 .. 100 {
		if runtime.evaluate_host('durationOpened')! == 'true' { break
		 }
		loop.process()
	}
	loop.perform_a_microtask_checkpoint()
	assert runtime.evaluate_host('durationOpened&&synchronousDurationCount===0&&microtaskDurationCount===0&&durationEvents.length===0&&player.duration===20')! == 'true'
	for _ in 0 .. 100 {
		if runtime.evaluate_host('durationEvents.length===2')! == 'true' { break
		 }
		loop.process()
	}
	assert runtime.evaluate_host('durationEvents.length===2&&durationEvents.every(value=>value===20)&&durationChecks.length===2&&durationChecks.every(Boolean)&&savedDurationEvent.currentTarget===null&&durationAttachedSrc===durationURL&&Number.isNaN(other.duration)')! == 'true'
	source := runtime.native_media_source(runtime.evaluate_host_value('durationSource')!)!
	media := html.html_media_element_for_dom_element(document.get_element_by_id('player')?)?
	assert voidptr(source.media_element_assigned_to()?) == voidptr(media)
	assert media.duration() == 20
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().script_execution_depth == 0
		&& settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
}
