@[has_globals]
module dom

#include "style_completion_queue_test.h"

$if gcboehm ? {
	fn C.vox_style_completion_watch(index u32, owner voidptr)
	fn C.vox_style_completion_collect(depth u32)
	fn C.vox_style_completion_run_worker(work fn ())
	fn C.vox_style_completion_owners_alive() u32
}

__global (
	style_completion_load_count = 0
	style_completion_error_count = 0
)

fn style_completion_unqueued_owner(has_empty_hook bool) {
	mut document := Document.create(url_about_blank())
	document.set_scripting_enabled_by_embedder(false)
	assert document.lifecycle_hook_ == none
	if has_empty_hook {
		document.set_lifecycle_hook(DocumentLifecycleHook{})
		hook := document.lifecycle_hook_ or { panic('missing lifecycle hook') }
		assert hook.queue_an_element_task == unsafe { nil }
	}
	style := document.create_element_ns('http://www.w3.org/1999/xhtml', 'style') or { panic(err) }
	mut base := style.style_element_base() or { panic('missing style base') }
	base.document_load_event_delayer_ = DocumentLoadEventDelayer.new(mut document)
	assert document.anything_is_delaying_the_load_event()
	base.finished_loading_critical_subresources(.no)
	assert !document.anything_is_delaying_the_load_event()
	assert base.document_load_event_delayer_ == none
	$if gcboehm ? {
		C.vox_style_completion_watch(0, voidptr(document))
		C.vox_style_completion_watch(1, voidptr(style))
	}
	document.finalize()
}

fn style_completion_no_hook_owner() {
	style_completion_unqueued_owner(false)
}

fn style_completion_nil_queue_owner() {
	style_completion_unqueued_owner(true)
}

fn test_style_completion_without_lifecycle_hook_releases_its_owners_and_delayer() {
	$if gcboehm ? {
		C.vox_style_completion_run_worker(style_completion_no_hook_owner)
		C.vox_style_completion_collect(8)
		C.vox_style_completion_collect(8)
		assert C.vox_style_completion_owners_alive() == 0
	} $else {
		style_completion_no_hook_owner()
	}
}

fn test_style_completion_with_nil_queue_hook_releases_its_owners_and_delayer() {
	$if gcboehm ? {
		C.vox_style_completion_run_worker(style_completion_nil_queue_owner)
		C.vox_style_completion_collect(8)
		C.vox_style_completion_collect(8)
		assert C.vox_style_completion_owners_alive() == 0
	} $else {
		style_completion_nil_queue_owner()
	}
}

@[heap]
struct StyleCompletionQueueProbe {
mut:
	steps []fn ()
	elements []&Element
	sources []TaskSource
}

fn style_completion_queue_step(target voidptr, element &Element, source TaskSource, steps fn ()) {
	mut probe := unsafe { &StyleCompletionQueueProbe(target) }
	probe.steps << steps
	probe.elements << element
	probe.sources << source
}

fn style_completion_record_event(event &Event, _ ?&EventTarget) JSValue {
	assert !event.bubbles()
	if event.type_name() == 'load' {
		style_completion_load_count++
	} else {
		assert event.type_name() == 'error'
		style_completion_error_count++
	}
	return js_undefined()
}

fn test_callable_style_completion_queue_preserves_events_generation_and_delayer_timing() {
	style_completion_load_count = 0
	style_completion_error_count = 0
	mut document := Document.create(url_about_blank())
	mut probe := &StyleCompletionQueueProbe{}
	document.set_lifecycle_hook(DocumentLifecycleHook{
		target: voidptr(probe)
		queue_an_element_task: style_completion_queue_step
	})
	style := document.create_element_ns('http://www.w3.org/1999/xhtml', 'style') or { panic(err) }
	mut base := style.style_element_base() or { panic('missing style base') }
	listener := IDLEventListener.create(&CallbackType{handle_event: style_completion_record_event})
	mut target := unsafe { &EventTarget(style.as_node()) }
	target.add_event_listener_without_options('load', listener)
	target.add_event_listener_without_options('error', listener)
	base.style_sheet_update_generation_ = 7
	base.document_load_event_delayer_ = DocumentLoadEventDelayer.new(mut document)
	base.finished_loading_critical_subresources(.no)
	assert probe.steps.len == 1
	assert probe.elements[0] == style
	assert probe.sources[0] == .user_interaction
	assert !document.anything_is_delaying_the_load_event()
	assert base.document_load_event_delayer_ == none
	assert style_completion_load_count == 0 && style_completion_error_count == 0
	base.style_sheet_update_generation_++
	probe.steps[0]()
	assert style_completion_load_count == 0 && style_completion_error_count == 0
	base.finished_loading_critical_subresources(.no)
	base.finished_loading_critical_subresources(.yes)
	assert probe.steps.len == 3
	assert style_completion_load_count == 0 && style_completion_error_count == 0
	probe.steps[1]()
	assert style_completion_load_count == 1 && style_completion_error_count == 0
	probe.steps[2]()
	assert style_completion_load_count == 1 && style_completion_error_count == 1
	document.finalize()
}
