module main

import dom

fn test_dirty_font_completion_waits_for_rendering_without_forcing_an_extra_layout() {
	mut document, mut fonts, event_loop := font_environment_fixture()
	defer { document.finalize() }
	document.update_readiness(.complete)
	event_loop.update_font_face_sets_pending_on_the_environment([document])
	assert fonts.ready().state == .fulfilled
	fonts.switch_to_loading()
	ready := fonts.ready()
	previous_layout := document.layout_engine_handle()
	mut element := document.body()?.as_node().as_element()?
	element.set_attribute_value('style', 'width:27px')
	fonts.switch_to_loaded()
	assert ready.state == .pending
	assert fonts.is_pending_on_the_environment && fonts.is_stuck_on_the_environment
	assert document.layout_engine_handle() == previous_layout
	document.update_layout(.html_event_loop_rendering_update)
	event_loop.update_font_face_sets_pending_on_the_environment([document])
	assert ready.state == .fulfilled
	assert fonts.status() == .loaded
	assert document.layout_engine_handle() != previous_layout
	completed_layout := document.layout_engine_handle()
	assert element.client_width() == 27
	assert document.layout_engine_handle() == completed_layout
}

fn test_forced_geometry_still_flushes_while_font_readiness_waits_for_rendering() {
	mut document, mut fonts, event_loop := font_environment_fixture()
	defer { document.finalize() }
	document.update_readiness(.complete)
	event_loop.update_font_face_sets_pending_on_the_environment([document])
	fonts.switch_to_loading()
	ready := fonts.ready()
	mut element := document.body()?.as_node().as_element()?
	element.set_attribute_value('style', 'width:39px')
	fonts.switch_to_loaded()
	assert ready.state == .pending
	assert element.client_width() == 39
	assert document.layout_is_up_to_date()
	event_loop.update_font_face_sets_pending_on_the_environment([document])
	assert ready.state == .fulfilled
}

fn test_clean_font_completion_settles_without_another_layout_pass() {
	mut document, mut fonts, event_loop := font_environment_fixture()
	defer { document.finalize() }
	document.update_readiness(.complete)
	event_loop.update_font_face_sets_pending_on_the_environment([document])
	fonts.switch_to_loading()
	ready := fonts.ready()
	previous_layout := document.layout_engine_handle()
	fonts.switch_to_loaded()
	assert ready.state == .fulfilled
	assert fonts.status() == .loaded
	assert document.layout_engine_handle() == previous_layout
}
