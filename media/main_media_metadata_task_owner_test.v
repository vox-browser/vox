module main

import browserjs
import dom
import html
import page
import time

fn test_native_metadata_events_are_deferred_and_precede_first_data_for_audio_and_video() {
	$if !darwin { return }
	owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time('<video id="video" src="/movie.mp4"></video><audio id="audio" src="/sound.mp3"></audio>', dom.URL{
		value: 'https://native-metadata-task.example.test/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut models := []&html.HTMLMediaElement{}
	for name in ['video', 'audio'] {
		mut media := html.html_media_element_for_dom_element(document.get_element_by_id(name)?)?
		media.set_fetch_hook(fn (_ dom.URL, _ u64) !html.MediaResourceResponse {
			return html.MediaResourceResponse{ mime_type: 'video/mp4', duration: 20 }
		})
		models << media
	}
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'https://native-metadata-task.example.test/', [
		r'globalThis.metadataEvents=[];globalThis.metadataChecks=[];globalThis.savedMetadataEvent=null;
 for(const [name,player] of [["video",video],["audio",audio]])for(const type of ["loadedmetadata","loadeddata"])EventTarget.prototype.addEventListener.call(player,type,function(event){
 metadataEvents.push(name+":"+event.type);metadataChecks.push(this===player&&event.target===player&&event.currentTarget===player&&event.isTrusted&&!event.bubbles&&!event.cancelable&&player.readyState===2&&player.duration===20);savedMetadataEvent=event;
 });video.load();audio.load();',
	], runtime, mut messages)
	assert messages == []
	assert runtime.evaluate_host('metadataEvents.length===0&&video.readyState===1&&audio.readyState===1')! == 'true'
	for model in models {
		mut media := unsafe { &html.HTMLMediaElement(model) }
		media.set_ready_state(.have_current_data)
	}
	mut loop := html.main_thread_event_loop()
	loop.perform_a_microtask_checkpoint()
	assert runtime.evaluate_host('metadataEvents.length===0')! == 'true'
	for _ in 0 .. 100 {
		loop.process()
	}
	assert runtime.evaluate_host('metadataEvents.join(",")==="video:loadedmetadata,audio:loadedmetadata,video:loadeddata,audio:loadeddata"&&metadataChecks.every(Boolean)&&savedMetadataEvent.currentTarget===null')! == 'true'
	assert runtime.evaluate_host('video.load()===undefined&&metadataEvents.length===4&&video.readyState===1')! == 'true'
	mut video := unsafe { &html.HTMLMediaElement(models[0]) }
	video.set_ready_state(.have_current_data)
	for _ in 0 .. 100 {
		loop.process()
	}
	assert runtime.evaluate_host('metadataEvents.slice(4).join(",")==="video:loadedmetadata,video:loadeddata"&&metadataChecks.every(Boolean)')! == 'true'
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().script_execution_depth == 0
		&& settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
}
