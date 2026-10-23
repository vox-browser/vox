module dom

#include "cursor_timer_lifetime_test.h"

$if gcboehm ? {
	fn C.vox_cursor_watch_owner(owner voidptr)
	fn C.vox_cursor_owner_alive() int
	fn C.vox_cursor_collect(depth u32)
	fn C.vox_cursor_run_worker(work fn ())
	fn C.vox_cursor_timer_is_scanned(timer voidptr) int
}

struct CursorTimerTestCounter {
mut:
	calls int
}

fn cursor_timer_count(context voidptr) {
	mut counter := unsafe { &CursorTimerTestCounter(context) }
	counter.calls++
}

fn test_context_timer_preserves_fire_stop_and_restart_behavior() {
	counter := &CursorTimerTestCounter{}
	mut timer := Timer.create_repeating_with_context(500, voidptr(counter), cursor_timer_count)
	assert timer.interval_ms == 500 && timer.repeating && !timer.is_active()
	timer.fire()
	assert counter.calls == 0
	timer.start()
	timer.fire()
	timer.fire()
	assert counter.calls == 2 && timer.is_active()
	timer.stop()
	timer.fire()
	assert counter.calls == 2 && !timer.is_active()
	timer.restart()
	timer.fire()
	assert counter.calls == 3 && timer.is_active()
}

fn test_legacy_timer_callback_alias_remains_callable_after_stop() {
	mut counter := &CursorTimerTestCounter{}
	callback := fn [mut counter] () { counter.calls++ }
	mut timer := Timer.create_repeating(40, callback)
	timer.start()
	timer.fire()
	timer.stop()
	callback()
	assert counter.calls == 2 && !timer.is_active()
	timer.restart()
	timer.fire()
	assert counter.calls == 3
	mut single := Timer.create_single_shot(1, callback)
	single.start()
	single.fire()
	single.fire()
	assert counter.calls == 4 && !single.is_active()
}

struct CursorBlinkPaintTestState {
mut:
	focused bool = true
	repaints int
	invalidation InvalidateDisplayList = .no
}

fn cursor_blink_test_is_focused(context voidptr) bool {
	return unsafe { &CursorBlinkPaintTestState(context) }.focused
}

fn cursor_blink_test_repaint(context voidptr, _ voidptr, invalidation InvalidateDisplayList) {
	mut state := unsafe { &CursorBlinkPaintTestState(context) }
	state.repaints++
	state.invalidation = invalidation
}

fn test_document_cursor_timer_preserves_focused_caret_paint_invalidation() {
	mut document := Document.create(url_about_blank())
	mut host := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic(err) }
	host.set_attribute_value('contenteditable', 'true')
	text := document.create_text_node('caret')
	mut host_node := host.as_node()
	host_node.append_child(text.as_node()) or { panic(err) }
	mut document_node := document.as_node()
	document_node.append_child(host_node) or { panic(err) }
	document.focused_area = host_node
	mut state := &CursorBlinkPaintTestState{}
	document.set_cached_navigable(&Navigable{
		active_document_: document
		html_model_handle_: voidptr(state)
		is_focused_callback_: cursor_blink_test_is_focused
	})
	mut text_node := text.as_node()
	paintable := &Paintable{
		repaint_callback_target: voidptr(state)
		callbacks: &PaintableCallbacks{ set_needs_repaint_callback: cursor_blink_test_repaint }
	}
	text_node.set_layout_node(&LayoutNode{paintables_: [paintable]})
	text_node.set_paintable(paintable)
	document.selection_.collapse(text_node, 1) or { panic(err) }
	state.repaints = 0
	assert document.cursor_position() != none
	document.reset_cursor_blink_cycle()
	assert document.get_cursor_blink_state() && document.cursor_blink_timer.is_active()
	document.cursor_blink_timer.fire()
	assert !document.get_cursor_blink_state()
	assert state.repaints == 1 && state.invalidation == .paint_commands
	state.focused = false
	document.cursor_blink_timer.fire()
	assert !document.get_cursor_blink_state() && state.repaints == 1
	state.focused = true
	document.cursor_blink_timer.stop()
	document.cursor_blink_timer.fire()
	assert !document.get_cursor_blink_state() && state.repaints == 1
	document.reset_cursor_blink_cycle()
	document.cursor_blink_timer.fire()
	assert !document.get_cursor_blink_state() && state.repaints == 2
	text_node.clear_paintable()
	document.cursor_blink_timer.fire()
	assert !document.get_cursor_blink_state() && state.repaints == 2
	document.finalize()
}

@[noinline]
fn cursor_create_unretained_document() {
	mut document := Document.create(URL{value: 'https://example.test/collectible'})
	assert document.cursor_blink_timer.is_active()
	$if gcboehm ? { C.vox_cursor_watch_owner(voidptr(document)) }
	document.finalize()
}

fn test_initialized_document_cursor_cycle_becomes_collectible() {
	$if gcboehm ? {
		C.vox_cursor_run_worker(cursor_create_unretained_document)
		C.vox_cursor_collect(8)
		C.vox_cursor_collect(8)
		assert C.vox_cursor_owner_alive() == 0
	} $else {
		cursor_create_unretained_document()
	}
}

__global cursor_context_only_timer &Timer

fn cursor_context_update_document(context voidptr) {
	mut document := unsafe { &Document(context) }
	assert document.url.serialize() == 'https://example.test/timer-owner'
	document.cursor_blink_state = !document.cursor_blink_state
}

@[noinline]
fn cursor_create_timer_owned_document() {
	mut document := Document.create(URL{value: 'https://example.test/timer-owner'})
	document.cursor_blink_state = false
	cursor_context_only_timer = Timer.create_repeating_with_context(500, voidptr(document), cursor_context_update_document)
	cursor_context_only_timer.start()
	$if gcboehm ? {
		C.vox_cursor_watch_owner(voidptr(document))
		assert C.vox_cursor_timer_is_scanned(voidptr(cursor_context_only_timer)) == 1
	}
}

fn cursor_fire_timer_owned_document() {
	cursor_context_only_timer.fire()
	assert unsafe { &Document(cursor_context_only_timer.callback_context) }.get_cursor_blink_state()
}

fn cursor_release_timer_owned_document() {
	cursor_context_only_timer = unsafe { nil }
}

fn test_live_timer_alone_retains_its_context_document_until_timer_release() {
	$if gcboehm ? {
		C.vox_cursor_run_worker(cursor_create_timer_owned_document)
		C.vox_cursor_collect(8)
		assert C.vox_cursor_owner_alive() == 1
		C.vox_cursor_run_worker(cursor_fire_timer_owned_document)
		C.vox_cursor_run_worker(cursor_release_timer_owned_document)
		C.vox_cursor_collect(8)
		C.vox_cursor_collect(8)
		assert C.vox_cursor_owner_alive() == 0
	} $else {
		cursor_create_timer_owned_document()
		cursor_fire_timer_owned_document()
		cursor_release_timer_owned_document()
	}
}
