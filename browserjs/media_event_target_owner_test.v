module browserjs

import dom
import html

fn test_native_media_events_reach_the_same_dom_target_as_the_bound_wrapper() {
	$if !darwin { return }
	address := dom.URL{
		value: 'https://media-event-target.example.test/'
	}
	document := html.parse_navigation_document('<!doctype html><video id="player"></video><audio id="other"></audio>',
		address, address.origin(), none)!
	assert document.is_fully_active()
	window := document.get_window()?
	assert voidptr(window.associated_document()?) == voidptr(document)
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
	runtime.evaluate_host(r'
globalThis.mediaTargetEvents=[];globalThis.savedMediaTargetEvent=null;
player.addEventListener("volumechange",function(event){
 savedMediaTargetEvent=event;
 mediaTargetEvents.push(this===player&&event.target===player&&event.currentTarget===player&&event instanceof Event&&event.isTrusted&&!event.bubbles&&!event.cancelable);
});other.addEventListener("volumechange",()=>mediaTargetEvents.push("other"));')!
	mut media := html.html_media_element_for_dom_element(document.get_element_by_id('player')?)?
	media.set_volume(0.5)!
	assert runtime.evaluate_host('mediaTargetEvents.length===0')! == 'true'
	mut loop := html.main_thread_event_loop()
	loop.perform_a_microtask_checkpoint()
	assert runtime.evaluate_host('mediaTargetEvents.length===0')! == 'true'
	for _ in 0 .. 100 {
		if runtime.evaluate_host('mediaTargetEvents.length===1')! == 'true' { break }
		loop.process()
	}
	assert runtime.evaluate_host('mediaTargetEvents.length===1&&mediaTargetEvents[0]===true&&savedMediaTargetEvent.target===player&&savedMediaTargetEvent.currentTarget===null')! == 'true'
	assert voidptr(runtime.native_event_target(runtime.evaluate_host_value('player')!)!) == voidptr(media.event_target())
	assert !runtime.libjs_vm().has_running_execution_context()
}
