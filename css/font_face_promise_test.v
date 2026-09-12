module css

import dom
import webidl

__global font_face_set_event_names = []string{}

fn test_font_face_uses_webidl_status_promise() {
	face := FontFaceObject.construct_impl('BrokenFace', FontFaceSource.from_string(''),
		FontFaceDescriptors{})

	assert face.status() == .error
	assert face.loaded().state == .rejected
	assert face.loaded().result.kind == .string_
	assert voidptr(face.loaded()) == voidptr(face.font_status_promise_ref())
}

fn test_font_face_set_load_waits_for_real_font_status_promises() {
	mut set := FontFaceSet.create()
	face := FontFaceObject.construct_impl('BrokenFace',
		FontFaceSource.from_string('url("missing-font.woff2")'), FontFaceDescriptors{})
	set.add(face)!

	promise := set.load('16px BrokenFace', 'A')!
	assert promise.state == .rejected
	assert promise.result.kind == .string_

	empty_result := set.load('16px UnmatchedFace', 'A')!
	assert empty_result.state == .fulfilled
	assert empty_result.result.kind == .sequence
	assert empty_result.result.sequence_value.len == 0
}

fn test_font_face_set_ready_promise_is_replaced_after_loading_restarts() {
	mut set := FontFaceSet.create()
	initial_ready := set.ready()
	assert initial_ready.state == .pending

	set.set_is_pending_on_the_environment(false)
	assert initial_ready.state == .fulfilled
	assert initial_ready.result.kind == .platform_object

	set.switch_to_loading()
	restarted_ready := set.ready()
	assert voidptr(restarted_ready) != voidptr(initial_ready)
	assert restarted_ready.state == webidl.PromiseState.pending
}

fn test_font_face_set_event_handler_attributes_receive_load_events() {
	font_face_set_event_names = []string{}
	callback := &dom.CallbackType{
		handle_event: fn (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			font_face_set_event_names << event.type_name()
			return dom.js_undefined()
		}
	}
	mut set := FontFaceSet.create()
	set.set_onloading(callback)
	assert voidptr(set.onloading() or { panic('missing loading handler') }) == voidptr(callback)
	assert set.event_target().has_event_listener('loading')

	set.switch_to_loading()
	assert set.fired_events.len == 1
	assert font_face_set_event_names == ['loading']
	set.set_onloading(none)
	assert set.onloading() == none
}

fn test_font_face_load_switches_containing_set_to_loading() {
	mut set := FontFaceSet.create()
	face := FontFaceObject.construct_impl('MissingFace', FontFaceSource.from_string('url("missing-font.woff2")'), FontFaceDescriptors{})
	set.add(face)!

	mut mutable_face := unsafe { &FontFaceObject(face) }
	mutable_face.load()

	assert face.status() == .error
	assert set.status() == .loading
	assert set.loading_fonts().len == 0
	assert set.failed_fonts().len == 1
	assert set.fired_events.map(it.name) == ['loading']
	assert set.is_stuck_on_the_environment
}

fn test_font_face_set_ready_settles_when_all_faces_are_deferred() {
	mut set := FontFaceSet.create()
	face := FontFaceObject.construct_impl('DeferredFace', FontFaceSource.from_string('url("missing-font.woff2")'), FontFaceDescriptors{
		unicode_range: 'U+41'
	})
	set.add(face)!

	set.set_is_pending_on_the_environment(false)
	assert face.status() == .unloaded
	assert set.status() == .loaded
	assert set.ready().state == .fulfilled
}
