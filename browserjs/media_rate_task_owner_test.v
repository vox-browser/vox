module browserjs

import dom
import html

fn test_native_rate_events_wait_for_tasks_and_dispatch_through_the_actual_dom_owner() {
	$if !darwin { return }
	address := dom.URL{
		value: 'https://native-media-rate-task.example.test/'
	}
	document := html.parse_navigation_document('<video id="player"></video><audio id="other"></audio>',
		address, address.origin(), none)!
	assert document.is_fully_active()
	mut runtime := Runtime.create()
	defer { runtime.close() }
	mut host := MediaElementHost.create(document, none)!
	host.install(mut runtime)!
	for key, element in host.elements_for_binding() {
		if element.local_name() in ['audio', 'video'] {
			id := element.get_attribute('id')?
			runtime.evaluate_host('globalThis.${id}={};__ladybirdMediaElementBind(${id},"${key}","${element.local_name()}")')!
		}
	}
	runtime.evaluate_host(r'globalThis.rateEvents=[];globalThis.savedRateEvent=null;
player.addEventListener("ratechange",function(event){savedRateEvent=event;rateEvents.push(this===player&&event.target===player&&event.currentTarget===player&&event instanceof Event&&event.isTrusted&&!event.bubbles&&!event.cancelable);});
other.addEventListener("ratechange",()=>rateEvents.push(false));')!
	mut media := html.html_media_element_for_dom_element(document.get_element_by_id('player')?)?
	media.set_default_playback_rate(2)
	assert runtime.evaluate_host('rateEvents.length===0')! == 'true'
	media.set_playback_rate(0.5)!
	media.set_default_playback_rate(3)
	assert media.default_playback_rate() == 3 && media.playback_rate() == 0.5
	assert runtime.evaluate_host('rateEvents.length===0')! == 'true'
	mut loop := html.main_thread_event_loop()
	loop.perform_a_microtask_checkpoint()
	assert runtime.evaluate_host('rateEvents.length===0')! == 'true'
	for _ in 0 .. 100 {
		if runtime.evaluate_host('rateEvents.length===3')! == 'true' { break
		 }
		loop.process()
	}
	assert runtime.evaluate_host('rateEvents.length===3&&rateEvents.every(Boolean)&&savedRateEvent.currentTarget===null')! == 'true'
	assert voidptr(runtime.native_event_target(runtime.evaluate_host_value('player')!)!) == voidptr(media.event_target())
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().script_execution_depth == 0
		&& settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
}
