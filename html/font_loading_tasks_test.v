module html

import css
import dom
import webidl

fn font_task_fixture() (&dom.Document, &EventLoop, &css.FontComputer, &css.FontFaceSet) {
	mut document := parse_document_with_url('<!doctype html><body>font task fixture</body>', dom.URL{value: 'https://font-tasks.example/'})
	window := WindowModel.create_top_level(document, none, 'font-task') or { panic(err) }
	mut settings := window.environment_settings_.settings
	owner := EventLoop.create(.window)
	settings.responsible_event_loop_ = owner
	computer := css.FontComputer.create_for_document(document)
	set := css.FontFaceSet.create_for_font_computer(computer)
	return document, owner, computer, set
}

fn execute_next_font_task(owner &EventLoop, expected_document ?&dom.Document) {
	mut queue := owner.task_queue()
	task := queue.take_first_runnable() or { panic('font task not queued') }
	assert task.source() == .font_loading
	assert task.document() == expected_document
	task.execute()
}

fn test_url_font_face_failure_completes_on_its_document_font_loading_task() {
	document, owner, _, mut set := font_task_fixture()
	mut face := css.FontFaceObject.construct_impl('Missing task font', css.FontFaceSource.from_string('url("missing.woff2")'), css.FontFaceDescriptors{})
	set.add(face)!
	set.set_is_pending_on_the_environment(false)
	execute_next_font_task(owner, none)
	set.fired_events.clear()
	promise := face.load()
	assert promise == face.loaded()
	assert promise.state == .pending
	assert face.status() == .loading
	assert set.loading_fonts().len == 1
	assert set.fired_events.len == 0
	execute_next_font_task(owner, none)
	assert set.fired_events.map(it.name) == ['loading']
	assert face.status() == .loading
	execute_next_font_task(owner, document)
	assert face.status() == .error
	assert promise.state == .rejected
	assert set.loading_fonts().len == 0
	assert set.failed_fonts().len == 1
	assert set.ready().state == .fulfilled
	assert set.fired_events.map(it.name) == ['loading']
	execute_next_font_task(owner, none)
	assert set.fired_events.map(it.name) == ['loading', 'loadingdone', 'loadingerror']
	assert set.failed_fonts().len == 0
	assert owner.task_queue().is_empty()
}

fn test_font_set_event_task_collects_lists_when_the_task_runs_and_filters_membership() {
	_, owner, _, mut set := font_task_fixture()
	set.set_is_pending_on_the_environment(false)
	assert set.ready().state == webidl.PromiseState.fulfilled
	assert set.fired_events.len == 0
	face := css.FontFaceObject.construct_impl('Finished', css.FontFaceSource.from_string('url("unused.woff2")'), css.FontFaceDescriptors{})
	set.add(face)!
	set.loaded_fonts_ << face
	execute_next_font_task(owner, none)
	assert set.fired_events.len == 1
	assert set.fired_events[0].name == 'loadingdone'
	assert set.fired_events[0].fontfaces == [face]
	assert set.loaded_fonts().len == 0
	set.loaded_fonts_ << face
	set.switch_to_loaded()
	assert set.delete_(face)
	execute_next_font_task(owner, none)
	assert set.fired_events[1].fontfaces.len == 0
}

fn test_decoded_url_font_keeps_loading_status_until_its_completion_task() {
	$if macos {
		document, owner, _, mut set := font_task_fixture()
		mut face := css.FontFaceObject.construct_impl('Native task font', css.FontFaceSource.from_string('url("file:///System/Library/Fonts/Supplemental/Arial.ttf")'), css.FontFaceDescriptors{})
		set.add(face)!
		promise := face.load()
		assert face.status() == .loading
		assert promise.state == .pending
		execute_next_font_task(owner, none)
		assert face.status() == .loading
		execute_next_font_task(owner, document)
		assert face.status() == .loaded
		assert promise.state == .fulfilled
		assert face.parsed_font != unsafe { nil }
	}
}
