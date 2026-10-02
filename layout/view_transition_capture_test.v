module layout

import dom
import html
import css
import webidl

struct LiveTransitionObservation {
mut:
	calls int
}

fn test_live_named_transition_captures_committed_geometry_frames_and_owned_pseudo_tree() {
	mut document :=
		html.parse_document('<!doctype html><style>:root {view-transition-name:none} #hero {view-transition-name:hero;width:20px;height:10px;writing-mode:vertical-rl;direction:rtl;mix-blend-mode:multiply;backdrop-filter:blur(2px);color-scheme:dark}</style><div id="hero"></div>')
	_ = html.WindowModel.create_top_level(document, none, 'view-transition-live')!
	run_document_layout(document, 160, 120) or { panic('layout') }
	hero := document.get_element_by_id('hero') or { panic('hero') }
	mut sheet := css.dynamic_view_transition_style_sheet_for_document(document)
	sheet.insert_rule(':root::view-transition-group(hero) { width:40px;height:20px }', 0)!
	preexisting := sheet.rules.rules[0]
	observation := &LiveTransitionObservation{}
	callback := &dom.CallbackType{
		call_no_args: fn [hero, observation] () dom.JSValue {
			assert !hero.captured_in_a_view_transition()
			mut mutable_observation := unsafe { &LiveTransitionObservation(observation) }
			mutable_observation.calls++
			mut element := unsafe { &dom.Element(hero) }
			element.set_attribute_value('style', 'width:40px;height:20px')
			return dom.js_undefined()
		}
	}
	transition := document.start_view_transition(callback)
	document.perform_pending_transition_operations()
	assert observation.calls == 0
	assert transition.phase() == .pending_capture
	assert document.document_rendering_suppression_for_view_transitions()
	capture := transition.captured_element('hero') or { panic('old capture') }
	assert capture.old_width == 20
	assert capture.old_height == 10
	assert capture.old_writing_mode == 'vertical-rl'
	assert capture.old_direction == 'rtl'
	assert capture.old_mix_blend_mode == 'multiply'
	assert capture.old_backdrop_filter.contains('blur')
	assert capture.old_color_scheme == 'dark'
	old := capture.old_image or { panic('old image') }
	old_frame := unsafe { &dom.DecodedImageFrame_(old.handle) }
	assert old_frame.width() == 1
	assert old_frame.height() == 1
	assert old_frame.bitmap().pitch == 4
	assert old_frame.bitmap().alpha_type == 2
	assert old_frame.bitmap().data == [u8(0), 0, 0, 0]
	mut event_loop := html.main_thread_event_loop()
	assert event_loop.task_queue().has_runnable_tasks()
	for _ in 0 .. 8 {
		if transition.phase() != .pending_capture { break
		 }
		event_loop.process()
	}
	assert observation.calls == 1
	assert transition.phase() == .animating
	assert hero.captured_in_a_view_transition()
	new := capture.new_element or { panic('new capture') }
	assert new.width == 40
	assert new.height == 20
	assert new.target == voidptr(hero)
	assert sheet.rules.length() == 6
	group_style := capture.group_styles_rule or { panic('group style') }
	actual_group_rule := unsafe { &css.CSSRule(group_style.handle) }
	assert actual_group_rule.css_text().contains('width: 40')
	root := transition.transition_root_pseudo_element()
	assert root.children_.len == 1
	group := root.children_[0]
	assert group.view_transition_name_ or { '' } == 'hero'
	assert group.children_.len == 1
	images := group.children_[0].children_
	assert images.len == 2
	assert images[0].view_transition_type_ or { panic('old type') } == .view_transition_old
	assert images[1].view_transition_type_ or { panic('new type') } == .view_transition_new
	assert images[0].replaced_content_ or { panic('old pseudo frame') } == old_frame
	new_frame := images[1].replaced_content_ or { panic('new pseudo frame') }
	assert voidptr(new_frame) != voidptr(old_frame)
	assert new_frame.bitmap().data == old_frame.bitmap().data
	mut mutable_hero := unsafe { &dom.Element(hero) }
	mutable_hero.set_attribute_value('style', 'width:60px;height:30px')
	transition.update_pseudo_element_styles()!
	assert (capture.group_styles_rule or { panic('updated group') }).handle == voidptr(actual_group_rule)
	assert actual_group_rule.css_text().contains('width: 40')
	assert !actual_group_rule.css_text().contains('width: 60')
	document.perform_pending_transition_operations()
	assert transition.phase() == .done
	assert !hero.captured_in_a_view_transition()
	assert !document.show_view_transition_tree
	assert sheet.rules.length() == 1
	assert voidptr(sheet.rules.rules[0]) == voidptr(preexisting)
	document.finalize()
}

fn test_live_transition_duplicate_names_reject_old_capture_and_clear_actual_flags() {
	mut document :=
		html.parse_document('<!doctype html><style>:root {view-transition-name:none} .named {view-transition-name:hero}</style><div id="first" class="named"></div><div id="second" class="named"></div>')
	run_document_layout(document, 160, 120) or { panic('layout') }
	transition := document.start_view_transition(none)
	document.perform_pending_transition_operations()
	assert transition.phase() == .done
	first := document.get_element_by_id('first') or { panic('first') }
	second := document.get_element_by_id('second') or { panic('second') }
	assert !first.captured_in_a_view_transition()
	assert !second.captured_in_a_view_transition()
	assert document.get_active_view_transition() == none
	assert !document.show_view_transition_tree
}

fn test_live_transition_visibility_skip_uses_queued_owner_task() {
	mut document := html.parse_document('<!doctype html><div></div>')
	_ = html.WindowModel.create_top_level(document, none, 'view-transition-visibility')!
	run_document_layout(document, 160, 120) or { panic('layout') }
	transition := document.start_view_transition(none)
	document.view_transition_page_visibility_change_steps()
	// Visibility is read when the queued source task runs, not when it is queued.
	document.visibility_state = .hidden
	assert transition.phase() == .pending_capture
	mut event_loop := html.main_thread_event_loop()
	for _ in 0 .. 8 {
		if transition.phase() == .done { break
		 }
		event_loop.process()
	}
	assert transition.phase() == .done
	assert document.get_active_view_transition() == none
	assert !document.document_rendering_suppression_for_view_transitions()
	document.finalize()
}

fn test_live_async_transition_callback_resumes_on_owning_document_microtask() {
	mut document :=
		html.parse_document('<!doctype html><style>:root {view-transition-name:none} #hero {view-transition-name:hero;width:20px;height:10px}</style><div id="hero"></div>')
	_ = html.WindowModel.create_top_level(document, none, 'view-transition-async')!
	run_document_layout(document, 160, 120) or { panic('layout') }
	hero := document.get_element_by_id('hero') or { panic('hero') }
	mut promise := webidl.create_promise_for(webidl.PromiseContext{
		job_scheduler: fn [document] (job fn ()) {
			html.queue_a_microtask(document, job)
		}
	})
	callback := &dom.CallbackType{
		call_no_args_promise: fn [promise] () !&webidl.Promise {
			return promise
		}
	}
	transition := document.start_view_transition(callback)
	assert webidl.promise_realm(transition.ready()) != 0
	assert webidl.promise_realm(transition.ready()) == webidl.promise_realm(transition.finished())
	document.perform_pending_transition_operations()
	mut event_loop := html.main_thread_event_loop()
	for _ in 0 .. 8 {
		if transition.phase() != .pending_capture { break
		 }
		event_loop.process()
	}
	assert transition.phase() == .update_callback_called
	assert document.document_rendering_suppression_for_view_transitions()
	assert transition.ready().state == .pending
	mut mutable_hero := unsafe { &dom.Element(hero) }
	mutable_hero.set_attribute_value('style', 'width:40px;height:30px')
	promise.resolve(webidl.undefined_value())
	assert transition.phase() == .update_callback_called
	assert transition.update_callback_done().state == .pending
	html.perform_a_microtask_checkpoint()
	assert transition.phase() == .animating
	assert transition.ready().state == .fulfilled
	assert transition.update_callback_done().state == .fulfilled
	assert !document.document_rendering_suppression_for_view_transitions()
	assert document.show_view_transition_tree
	assert hero.captured_in_a_view_transition()
	capture := transition.captured_element('hero') or { panic('capture') }
	assert (capture.new_element or { panic('new') }).width == 40
	assert (capture.new_element or { panic('new') }).height == 30
	document.perform_pending_transition_operations()
	assert transition.phase() == .done
	assert transition.finished().state == .fulfilled
	assert !hero.captured_in_a_view_transition()
	document.finalize()
}

fn test_live_skipped_async_transition_finished_adopts_callback_rejection() {
	mut document := html.parse_document('<!doctype html><div></div>')
	_ = html.WindowModel.create_top_level(document, none, 'view-transition-skipped-async')!
	run_document_layout(document, 160, 120) or { panic('layout') }
	mut promise := webidl.create_promise_for(webidl.PromiseContext{
		job_scheduler: fn [document] (job fn ()) {
			html.queue_a_microtask(document, job)
		}
	})
	callback := &dom.CallbackType{
		call_no_args_promise: fn [promise] () !&webidl.Promise {
			return promise
		}
	}
	transition := document.start_view_transition(callback)
	document.perform_pending_transition_operations()
	mut event_loop := html.main_thread_event_loop()
	for _ in 0 .. 8 {
		if transition.phase() != .pending_capture { break
		 }
		event_loop.process()
	}
	assert transition.phase() == .update_callback_called
	transition.skip_the_view_transition()
	assert transition.phase() == .done
	assert transition.finished().state == .pending
	promise.reject(webidl.string_value('callback rejection'))
	assert transition.finished().state == .pending
	html.perform_a_microtask_checkpoint()
	assert transition.update_callback_done().state == .rejected
	assert transition.finished().state == .rejected
	assert transition.finished().result == webidl.string_value('callback rejection')
	assert document.get_active_view_transition() == none
	assert !document.show_view_transition_tree
	document.finalize()
}
