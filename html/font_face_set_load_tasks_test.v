module html

import css
import dom
import platform
import webidl

fn font_set_load_fixture() (&EventLoop, &css.FontFaceSet) {
	document := parse_document_with_url('<!doctype html><body>fonts</body>', dom.URL{
		value: 'https://font-load.example/'
	})
	window := WindowModel.create_top_level(document, none, 'font-load') or { panic(err) }
	mut settings := window.environment_settings_.settings
	owner := EventLoop.create(.window)
	settings.responsible_event_loop_ = owner
	return owner, css.FontFaceSet.create_for_font_computer(css.FontComputer.create_for_document(document))
}

fn settled_font_for_set_load(family string, range string) &css.FontFaceObject {
	mut face := css.FontFaceObject.construct_impl(family,
		css.FontFaceSource.from_string('url("unused.ttf")'), css.FontFaceDescriptors{
		unicode_range: range
	})
	face.status_ = .loaded
	face.font_status_promise.resolve(webidl.platform_object_value())
	return face
}

fn run_font_set_deferred_step() {
	mut plugin := platform.EventLoopPlugin.the()
	assert plugin.run_one_deferred()
}

fn run_font_set_load_task(owner &EventLoop) {
	mut queue := owner.task_queue()
	task := queue.take_first_runnable() or { panic('missing font-loading task') }
	assert task.source() == .font_loading
	assert task.document() == none
	task.execute()
}

fn test_font_set_load_matches_after_deferred_invoke_and_retains_the_matched_list() {
	owner, mut set := font_set_load_fixture()
	first := settled_font_for_set_load('Deferred', 'U+41')
	second := settled_font_for_set_load('Deferred', 'U+42')
	set.add(first)!
	promise := set.load('16px Deferred', 'AB')!
	assert promise.state == .pending
	assert owner.task_queue().is_empty()
	set.add(second)!
	run_font_set_deferred_step()
	assert promise.state == .pending
	// Matching retains its list across the subsequent font-loading task.
	assert set.delete_(first)
	run_font_set_load_task(owner)
	assert promise.state == .fulfilled
	assert promise.result.sequence_value.map(it.opaque_id) == [u64(voidptr(first)),
		u64(voidptr(second))]
	assert owner.task_queue().is_empty()
}

fn test_font_set_load_rejects_bad_shorthand_during_deferred_invoke() {
	owner, mut set := font_set_load_fixture()
	promise := set.load('invalid-font-shorthand')!
	assert promise.state == .pending
	assert owner.task_queue().is_empty()
	run_font_set_deferred_step()
	assert promise.state == .rejected
	exception := webidl.dom_exception_from_object(promise.result) or {
		panic('missing SyntaxError')
	}
	assert exception.name() == 'SyntaxError'
	assert owner.task_queue().is_empty()
}

fn test_font_set_load_empty_result_settles_in_its_font_task_and_reacts_on_its_own_microtask_queue() {
	owner, mut set := font_set_load_fixture()
	mut promise := set.load('16px Unavailable')!
	assert webidl.promise_realm(promise) != 0
	reaction := webidl.react_to_promise(mut promise, fn (value webidl.Value) !webidl.Value {
		assert value.kind == .sequence
		assert value.sequence_value.len == 0
		return webidl.string_value('delivered')
	}, fn (reason webidl.Value) !webidl.Value {
		return reason
	})
	run_font_set_deferred_step()
	assert promise.state == .pending
	run_font_set_load_task(owner)
	assert promise.state == .fulfilled
	assert reaction.state == .pending
	assert !owner.microtask_queue_empty()
	assert main_thread_event_loop().microtask_queue_empty()
	mut mutable_owner := unsafe { &EventLoop(owner) }
	mutable_owner.perform_a_microtask_checkpoint()
	assert reaction.result.string_value == 'delivered'
}

fn test_font_set_load_filters_unicode_ranges_when_deferred_matching_runs() {
	owner, mut set := font_set_load_fixture()
	first := settled_font_for_set_load('RangeFace', 'U+41')
	second := settled_font_for_set_load('RangeFace', 'U+42')
	set.add(first)!
	set.add(second)!
	promise := set.load('16px RangeFace', 'A')!
	run_font_set_deferred_step()
	run_font_set_load_task(owner)
	assert promise.result.sequence_value.map(it.opaque_id) == [u64(voidptr(first))]
}
