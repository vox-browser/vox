module page

import compositor
import platform

fn test_page_client_identity_focus_and_allocation_defaults() {
	mut client := PageClient.create()
	assert client.id() == 1
	assert client.is_connection_open()
	assert client.has_focus()
	client.set_has_focus(false)
	assert !client.has_focus()
	assert !client.has_active_devtools_client()
	client.active_devtools_client_ = true
	assert client.has_active_devtools_client()
	assert client.maximum_frames_per_second() == 60
	client.set_maximum_frames_per_second(120)
	assert client.maximum_frames_per_second() == 120
	client.set_maximum_frames_per_second(-1)
	assert client.maximum_frames_per_second() == 120

	assert client.allocate_compositor_context_id(.yes)! == compositor.CompositorContextId(1)
	if _ := client.allocate_compositor_context_id(.no) {
		assert false
	} else {
		assert err.msg().contains('presentation registration')
	}
	assert client.allocate_cross_process_id() == 1
	client.set_pending_root_navigable_id(400)
	assert client.allocate_navigable_id() == 400
	assert client.allocate_navigable_id() == 2
}

fn test_page_client_tracks_input_and_manual_rendering_opportunities() {
	mut client := PageClient.create()
	client.did_handle_input_event(7, InputEvent(MouseEvent{
		type_: .mouse_down
		button: 1
	}))
	assert client.events.last() == ClientEvent{
		name: 'did-handle-input-event'
		text: '7:mouse:mouse_down'
	}

	assert client.has_rendering_opportunity()
	client.set_manual_rendering_opportunities(true)
	assert !client.has_rendering_opportunity()
	client.inject_rendering_opportunity(12.5)
	assert client.has_rendering_opportunity()
	assert client.last_rendering_frame_time_nanoseconds() == 12_500_000
	assert client.last_rendering_frame_interval_milliseconds() == 1000.0 / 60.0
	client.will_begin_rendering_update()
	assert client.has_rendering_opportunity()
	client.did_finish_rendering_update()
	assert !client.has_rendering_opportunity()

	// Injection is ignored when no rendering update is pending.
	client.inject_rendering_opportunity(20)
	assert !client.has_rendering_opportunity()
	client.request_frame()
	client.inject_rendering_opportunity(20)
	assert client.has_rendering_opportunity()
	assert client.last_rendering_frame_time_nanoseconds() == 20_000_000
}

fn test_page_client_event_log_owns_payloads_after_document_work_retires() {
	mut client := PageClient.create()
	mut work := platform.new_arena('page client event input')
	entry := work.enter()
	client.record('document-event'.clone(), 'retained event text'.clone())
	$if prealloc { assert !work.contains(client.events.data) }
	work.leave(entry)
	work.release()
	assert client.events[0] == ClientEvent{name: 'document-event', text: 'retained event text'}
	client.will_begin_rendering_update()
	client.did_finish_rendering_update()
	assert client.events.len == 3
	assert client.events[0].text == 'retained event text'
}
