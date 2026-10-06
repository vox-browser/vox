module main

import browserjs
import dom
import html
import page
import time

fn test_native_media_ended_getter_preserves_the_cached_value_until_step_one() {
	$if !darwin { return }
	owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time('<video id="player"></video><audio id="other"></audio>', dom.URL{
		value: 'https://media-ended-boundary.example.test/page.html'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut media := html.html_media_element_for_dom_element(document.get_element_by_id('player')?)?
	media.set_ready_state(.have_metadata)
	media.set_duration(1)
	media.set_current_playback_position(1)
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'https://media-ended-boundary.example.test/page.html', [
		r'globalThis.beforeEnded=player.ended;globalThis.otherBeforeEnded=other.ended;
Promise.resolve().then(()=>globalThis.microtaskEnded=player.ended);',
	], runtime, mut messages)
	assert messages == []
	assert runtime.evaluate_host('beforeEnded===false&&otherBeforeEnded===false&&microtaskEnded===false&&player.ended===false')! == 'true'
	mut loop := html.main_thread_event_loop()
	html.queue_a_task(.dom_manipulation, loop, document, fn [runtime] () {
		runtime.evaluate_host('globalThis.taskEnded=player.ended') or { panic(err) }
	})
	loop.process()
	assert runtime.evaluate_host('player.ended===true&&other.ended===false')! == 'true'
	for _ in 0 .. 100 {
		if runtime.evaluate_host('typeof taskEnded!=="undefined"')! == 'true' {
			break
		}
		loop.process()
	}
	assert runtime.evaluate_host('taskEnded===true&&player.ended===true&&other.ended===false')! == 'true'
	media.set_ready_state(.have_nothing)
	assert runtime.evaluate_host('player.ended===true')! == 'true'
	loop.perform_a_microtask_checkpoint()
	assert runtime.evaluate_host('player.ended===true')! == 'true'
	loop.process()
	assert runtime.evaluate_host('player.ended===false&&other.ended===false')! == 'true'
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert !runtime.libjs_vm().has_running_execution_context()
	assert settings.realm().script_execution_depth == 0
}
