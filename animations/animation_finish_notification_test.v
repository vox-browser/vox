module animations

import dom
import html

fn take_finish_task(animation &Animation) &html.Task {
	id := animation.pending_finish_microtask_id_ or { panic('missing notification task') }
	mut queue := html.main_thread_event_loop().task_queue()
	return queue.take_first_runnable_matching(fn [id] (task &html.Task) bool {
		return task.id() == id
	}) or { panic('missing runnable notification task') }
}

fn test_seek_away_aborts_a_deferred_finish_notification() {
	mut timeline := AnimationTimeline.new()
	timeline.current_time_ = TimeValue.milliseconds(150)
	mut effect := AnimationEffect.new()
	effect.update_timing(OptionalEffectTiming{duration: IterationDuration(100.0)})!
	mut animation := Animation.create(effect, timeline)
	animation.start_time_ = TimeValue.milliseconds(0)
	animation.update_finished_state(false)
	promise := animation.finished()
	assert promise.state() == .pending
	assert !animation.is_finished()
	assert animation.emitted_events().len == 0
	task := take_finish_task(animation)
	assert task.source() == .dom_manipulation
	animation.set_current_time(TimeValue.milliseconds(50))!
	task.execute()
	assert animation.play_state() == .running
	assert promise.state() == .pending
	assert animation.emitted_events().len == 0
}

fn test_synchronous_finish_removes_a_duplicate_queued_notification() {
	mut timeline := AnimationTimeline.new()
	timeline.current_time_ = TimeValue.milliseconds(150)
	mut effect := AnimationEffect.new()
	effect.update_timing(OptionalEffectTiming{duration: IterationDuration(100.0)})!
	mut animation := Animation.create(effect, timeline)
	animation.start_time_ = TimeValue.milliseconds(0)
	animation.update_finished_state(false)
	first_id := animation.pending_finish_microtask_id_ or { panic('no first task') }
	animation.update_finished_state(false)
	assert (animation.pending_finish_microtask_id_ or { panic('no second task') }) == first_id
	animation.finish()!
	assert animation.finished().state() == .fulfilled
	assert animation.emitted_events().len == 1
	mut queue := html.main_thread_event_loop().task_queue()
	assert queue.take_first_runnable_matching(fn [first_id] (task &html.Task) bool {
		return task.id() == first_id
	}) == none
	// The no-document event delivery is a separate DOM task.
	delivery := take_finish_task(animation)
	assert delivery.id() != first_id
	delivery.execute()
	assert animation.emitted_events().len == 1
}

fn test_finish_event_schedules_the_converted_effect_end_on_late_samples() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut navigable := &dom.Navigable{
		active_document_: document
		is_top_level_traversable_: true
	}
	navigable.traversable_navigable_ = navigable
	document.set_cached_navigable(navigable)
	mut timeline := new_document_timeline(document, 7, 0)
	timeline.set_document_active(true)
	timeline.current_time_ = TimeValue.milliseconds(500)
	mut effect := AnimationEffect.new()
	effect.update_timing(OptionalEffectTiming{duration: IterationDuration(100.0)})!
	mut animation := Animation.create(effect, timeline)
	animation.start_time_ = TimeValue.milliseconds(20)
	animation.playback_rate_ = 2
	animation.update_finished_state(false)
	assert document.pending_animation_event_queue.len == 0
	task := take_finish_task(animation)
	task.execute()
	assert animation.finished().state() == .fulfilled
	assert document.pending_animation_event_queue.len == 1
	pending_event := document.pending_animation_event_queue[0]
	assert (pending_event.scheduled_event_time or { panic('missing scheduled time') }) == 77
	event := animation.emitted_events()[0]
	assert (event.current_time() or { panic('missing current time') }) == CSSNumberish(f64(100))
	assert (event.timeline_time() or { panic('missing timeline time') }) == CSSNumberish(f64(500))
}

@[heap]
struct DeferredPlaybackEventCount {
mut:
	count int
}

fn test_cancel_without_a_timing_document_dispatches_on_a_dom_task() {
	mut timeline := AnimationTimeline.new()
	timeline.current_time_ = TimeValue.milliseconds(0)
	mut effect := AnimationEffect.new()
	effect.update_timing(OptionalEffectTiming{duration: IterationDuration(100.0)})!
	mut animation := Animation.create(effect, timeline)
	animation.play()!
	animation.update()
	mut count := &DeferredPlaybackEventCount{}
	animation.set_oncancel(&dom.CallbackType{
		handle_event: fn [mut count] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			count.count++
			return dom.js_undefined()
		}
	})
	animation.cancel()
	assert count.count == 0
	mut queue := html.main_thread_event_loop().task_queue()
	task := queue.take_first_runnable_matching(fn (task &html.Task) bool {
		return task.source() == .dom_manipulation
	}) or { panic('missing cancellation task') }
	task.execute()
	assert count.count == 1
}
