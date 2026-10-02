module html

import css
import dom
import fetch
import os
import time
import webidl

fn font_constructor_fixture() (&EventLoop, &css.FontComputer, &css.FontFaceSet) {
	document := parse_document_with_url('<!doctype html><body>constructor</body>', dom.URL{
		value: 'https://font-constructor.example/'
	})
	window := WindowModel.create_top_level(document, none, 'font-constructor') or { panic(err) }
	mut settings := window.environment_settings_.settings
	owner := EventLoop.create(.window)
	settings.responsible_event_loop_ = owner
	computer := css.FontComputer.create_for_document(document)
	return owner, computer, css.FontFaceSet.create_for_font_computer(computer)
}

fn execute_constructor_font_task(owner &EventLoop) {
	mut queue := owner.task_queue()
	for _ in 0 .. 20 {
		task := queue.take_first_runnable() or { panic('missing constructor font task') }
		assert task.source() == .font_loading
		task.execute()
		if task.document() != none { return }
	}
	panic('missing global constructor font task')
}

fn test_binary_font_constructor_keeps_copied_data_pending_until_two_owning_tasks() {
	$if !darwin { return }
	mut owner, computer, mut set := font_constructor_fixture()
	mut bytes := os.read_bytes('/System/Library/Fonts/Supplemental/Arial.ttf')!
	mut face := css.FontFaceObject.construct_impl_for_font_computer(computer, 'Constructor',
		css.FontFaceSource.from_binary(bytes), css.FontFaceDescriptors{})
	promise := face.loaded()
	assert promise == face.load()
	assert face.status() == .unloaded
	assert promise.state == .pending
	assert webidl.promise_realm(promise) != 0
	// Constructor copies the BufferSource, and observes containing sets at task time.
	bytes[0] = 255
	set.add(face)!
	set.set_is_pending_on_the_environment(false)
	initial_ready := set.ready()
	assert initial_ready.result.opaque_id == u64(voidptr(set))
	execute_constructor_font_task(owner)
	assert face.status() == .loading
	assert set.loading_fonts() == [face]
	assert promise.state == .pending
	assert set.ready() != initial_ready
	assert webidl.promise_realm(set.ready()) == webidl.promise_realm(promise)
	// FontFaceSet events remain separate tasks from the global publication.
	execute_constructor_font_task(owner)
	assert face.status() == .loaded
	assert promise == face.loaded()
	assert promise.state == .fulfilled
	assert promise.result.opaque_id == u64(voidptr(face))
	assert set.ready().result.opaque_id == u64(voidptr(set))
	assert set.loading_fonts().len == 0
	assert set.loaded_fonts() == [face]
}

fn test_constructor_descriptor_failure_is_handled_syntax_error_in_owning_realm() {
	owner, computer, _ := font_constructor_fixture()
	face := css.FontFaceObject.construct_impl_for_font_computer(computer, 'Broken',
		css.FontFaceSource.from_string('url("font.ttf")'), css.FontFaceDescriptors{
		weight: 'invalid'
	})
	promise := face.loaded()
	assert face.status() == .error
	assert promise.state == .rejected
	assert webidl.promise_realm(promise) != 0
	assert promise.is_handled
	exception := webidl.dom_exception_from_object(promise.result) or {
		panic('missing constructor exception')
	}
	assert exception.name() == 'SyntaxError'
	assert exception.message() == 'FontFace constructor: Invalid font-weight'
	assert owner.task_queue().is_empty()
}

fn test_binary_decode_failure_is_published_by_second_task_as_syntax_error() {
	owner, computer, mut set := font_constructor_fixture()
	face := css.FontFaceObject.construct_impl_for_font_computer(computer, 'Truncated', css.FontFaceSource.from_binary([
		u8(0),
		1,
		0,
		0,
	]), css.FontFaceDescriptors{})
	set.add(face)!
	execute_constructor_font_task(owner)
	assert face.status() == .loading
	assert face.loaded().state == .pending
	execute_constructor_font_task(owner)
	assert face.status() == .error
	exception := webidl.dom_exception_from_object(face.loaded().result) or {
		panic('missing decode exception')
	}
	assert exception.name() == 'SyntaxError'
	assert exception.message().starts_with('Failed to load font: ')
	assert face.loaded().is_handled
	assert set.failed_fonts() == [face]
}

fn test_woff2_constructor_returns_to_origin_before_second_publication_task() {
	$if !darwin { return }
	mut owner, computer, _ := font_constructor_fixture()
	bytes := os.read_bytes(os.join_path(os.dir(@FILE), '..', 'gfxfont', 'testdata',
		'variable-font-example.woff2'))!
	face := css.FontFaceObject.construct_impl_for_font_computer(computer, 'Constructor WOFF2',
		css.FontFaceSource.from_binary(bytes), css.FontFaceDescriptors{})
	execute_constructor_font_task(owner)
	assert face.status() == .loading
	assert face.loaded().state == .pending
	deadline := time.sys_mono_now() + 4 * time.second
	owner.spin_until(fn [face, deadline] () bool {
		return face.loaded().state != .pending || time.sys_mono_now() >= deadline
	})
	assert face.status() == .loaded
	assert face.loaded().result.opaque_id == u64(voidptr(face))
}

fn test_css_connected_state_materializes_same_owning_promise_lazily() {
	_, mut computer, mut set := font_constructor_fixture()
	sheet :=
		css.parse_css_stylesheet_with_parser('@font-face { font-family: Lazy; src: url("unused.ttf"); }', none)
	computer.load_fonts_from_css_rules(sheet.css_rules().rules, set)
	face := set.set_entries()[0]
	assert face.font_status_promise == unsafe { nil }
	first := face.loaded()
	assert first.state == .pending
	assert webidl.promise_realm(first) != 0
	assert face.loaded() == first
	assert face.font_status_promise_ref() == first
}

fn test_unattached_owned_url_face_and_unexposed_css_state_keep_relevant_global() {
	owner, mut computer, mut set := font_constructor_fixture()
	computer.set_fetch_host(&fetch.FetchHost{
		perform: fn (_ &fetch.Request) !&fetch.Response {
			return fetch.Response.network_error('fixture font unavailable')
		}
	})
	mut face := css.FontFaceObject.construct_impl_for_font_computer(computer, 'Unattached',
		css.FontFaceSource.from_string('url("font.ttf")'), css.FontFaceDescriptors{})
	promise := face.load()
	assert face.status() == .loading
	assert promise.state == .pending
	sheet :=
		css.parse_css_stylesheet_with_parser('@font-face { font-family: LazyFailure; src: url("missing.ttf"); }', none)
	computer.load_fonts_from_css_rules(sheet.css_rules().rules, set)
	mut connected := set.set_entries()[0]
	connected.load_for_style()
	assert connected.font_status_promise == unsafe { nil }
	mut queue := owner.task_queue()
	for _ in 0 .. 50 {
		task := queue.take_first_runnable() or { break }
		task.execute()
	}
	assert face.status() == .error
	error := webidl.dom_exception_from_object(promise.result) or { panic('missing network error') }
	assert error.name() == 'NetworkError'
	assert connected.status() == .error
	assert connected.font_status_promise == unsafe { nil }
	late_promise := connected.loaded()
	assert late_promise.state == .rejected
	assert late_promise.is_handled
	assert webidl.promise_realm(late_promise) == webidl.promise_realm(promise)
	late_error := webidl.dom_exception_from_object(late_promise.result) or {
		panic('missing retained network error')
	}
	assert late_error.name() == 'NetworkError'
}
