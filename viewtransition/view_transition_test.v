module viewtransition

import webidl

fn resolved_update() !&webidl.Promise {
	return webidl.create_resolved_promise(webidl.undefined_value())
}

fn rejected_update() !&webidl.Promise {
	return webidl.create_rejected_promise(webidl.string_value('callback failed'))
}

fn test_setup_uses_dom_task_then_activates_and_finishes() {
	old_element := &TransitionElement{
		id:                   'hero-old'
		view_transition_name: 'hero'
		width:                100
		height:               50
		image:                'old pixels'
	}
	mut document := &TransitionDocument{
		elements:        [old_element]
		snapshot_width:  800
		snapshot_height: 600
	}
	mut transition := ViewTransition.create(document)
	transition.set_update_callback(resolved_update)
	transition.setup_view_transition()
	assert document.rendering_suppression
	assert transition.phase == .pending_capture
	assert document.update_callback_queue.len == 0
	assert document.dom_tasks.len == 1

	new_element := &TransitionElement{
		id:                   'hero-new'
		view_transition_name: 'hero'
		width:                120
		height:               60
		image:                'new pixels'
	}
	document.elements = [new_element]
	assert document.run_next_dom_task()
	assert transition.phase == .animating
	assert transition.ready_promise.is_fulfilled()
	assert transition.update_callback_done_promise.is_fulfilled()
	assert document.show_view_transition_tree
	assert transition.pseudo_elements.len == 4
	assert transition.pseudo_elements[0].type_ == .group
	assert transition.pseudo_elements[1].type_ == .image_pair
	assert transition.pseudo_elements[1].parent_index or { -1 } == 0
	assert transition.pseudo_elements[2].parent_index or { -1 } == 1
	assert transition.pseudo_elements[3].parent_index or { -1 } == 1
	assert transition.pseudo_elements[3].content or { '' } == 'new pixels'
	assert new_element.captured
	// Scheduling also left the deliberately redundant upstream flush task.
	assert document.dom_tasks.len == 1
	document.drain_dom_tasks()
	transition.handle_transition_frame(false)
	assert transition.phase == .done
	assert transition.finished_promise.is_fulfilled()
	assert !new_element.captured
	assert !document.show_view_transition_tree
}

fn test_old_capture_checks_size_duplicates_ancestry_and_root_geometry() {
	mut oversized_document := &TransitionDocument{
		snapshot_width:  f64(0x80000000)
		snapshot_height: 1
	}
	mut oversized := ViewTransition.create(oversized_document)
	mut oversized_failed := false
	oversized.capture_the_old_state() or { oversized_failed = true }
	assert oversized_failed
	assert oversized.initial_snapshot_width == none

	a := &TransitionElement{
		id:                   'a'
		view_transition_name: 'same'
	}
	b := &TransitionElement{
		id:                   'b'
		view_transition_name: 'same'
	}
	mut duplicate_document := &TransitionDocument{
		elements:        [a, b]
		snapshot_width:  10
		snapshot_height: 10
	}
	mut duplicate := ViewTransition.create(duplicate_document)
	mut duplicate_failed := false
	duplicate.capture_the_old_state() or { duplicate_failed = true }
	assert duplicate_failed
	assert duplicate.named_elements.len == 0
	assert !a.captured
	assert !b.captured

	root := &TransitionElement{
		id:                   'root'
		view_transition_name: 'root'
		width:                7
		height:               8
		transform:            'translate(22px, 33px)'
		is_document_element:  true
		skips_contents:       true
	}
	child := &TransitionElement{
		id:                   'child'
		view_transition_name: 'child'
		ancestor_skips:       true
	}
	mut root_document := &TransitionDocument{
		elements:        [root, child]
		snapshot_width:  640
		snapshot_height: 480
	}
	mut root_transition := ViewTransition.create(root_document)
	root_transition.capture_the_old_state() or { assert false, err.msg() }
	assert root_transition.named_elements.len == 1
	capture := root_transition.named_elements['root'] or { panic('missing root capture') }
	assert capture.old_width == 640
	assert capture.old_height == 480
	assert capture.old_transform == 'translate(0px, 0px)'
	assert capture.old_image == none
	assert !root.captured
}

fn test_capture_failure_skips_but_callback_still_runs() {
	a := &TransitionElement{
		id:                   'a'
		view_transition_name: 'same'
	}
	b := &TransitionElement{
		id:                   'b'
		view_transition_name: 'same'
	}
	mut document := &TransitionDocument{
		elements:        [a, b]
		snapshot_width:  10
		snapshot_height: 10
	}
	mut transition := ViewTransition.create(document)
	transition.setup_view_transition()
	assert transition.phase == .done
	assert transition.ready_promise.is_rejected()
	assert document.update_callback_queue.len == 1
	document.drain_dom_tasks()
	assert transition.update_callback_done_promise.is_fulfilled()
	assert transition.finished_promise.is_fulfilled()
}

fn test_callback_rejection_and_snapshot_change_reject_transition() {
	element := &TransitionElement{
		id:                   'x'
		view_transition_name: 'x'
	}
	mut document := &TransitionDocument{
		elements:        [element]
		snapshot_width:  20
		snapshot_height: 20
	}
	mut transition := ViewTransition.create(document)
	transition.set_update_callback(rejected_update)
	transition.setup_view_transition()
	document.run_next_dom_task()
	assert transition.phase == .done
	assert transition.update_callback_done_promise.is_rejected()
	assert transition.update_callback_done_promise.is_handled
	assert transition.ready_promise.is_rejected()
	assert transition.finished_promise.is_rejected()

	mut second_document := &TransitionDocument{
		elements:        [element]
		snapshot_width:  20
		snapshot_height: 20
	}
	mut second := ViewTransition.create(second_document)
	second.setup_view_transition()
	second_document.snapshot_width = 21
	second_document.run_next_dom_task()
	assert second.phase == .done
	assert second.ready_promise.is_rejected()
}

fn test_pending_callback_resumes_at_explicit_promise_boundary() {
	element := &TransitionElement{
		id:                   'pending'
		view_transition_name: 'pending'
		image:                'old'
	}
	mut document := &TransitionDocument{
		elements:        [element]
		snapshot_width:  20
		snapshot_height: 20
	}
	mut pending := webidl.create_promise()
	mut transition := ViewTransition.create(document)
	transition.set_update_callback(fn [pending] () !&webidl.Promise {
		return pending
	})
	transition.setup_view_transition()
	document.run_next_dom_task()
	assert transition.phase == .update_callback_called
	assert transition.update_callback_done_promise.state == .pending
	pending.resolve(webidl.undefined_value())
	transition.process_update_callback_promise()
	assert transition.phase == .animating
	assert transition.update_callback_done_promise.is_fulfilled()
	assert transition.ready_promise.is_fulfilled()
}

fn test_pseudo_rules_update_in_place_and_clear_only_owned_rules() {
	preexisting_group_rule := ':root::view-transition-group(card) { width: 30.0px; height: 40.0px; transform: transform; writing-mode: writing_mode; direction: direction; text-orientation: text_orientation; mix-blend-mode: mix_blend_mode; backdrop-filter: backdrop_filter; color-scheme: color_scheme; }'
	old_element := &TransitionElement{
		id:                   'old'
		view_transition_name: 'card'
		width:                10
		height:               20
		image:                'old image'
	}
	mut document := &TransitionDocument{
		elements:            [old_element]
		snapshot_width:      200
		snapshot_height:     100
		dynamic_style_rules: ['unrelated author/platform rule', preexisting_group_rule]
	}
	mut transition := ViewTransition.create(document)
	transition.setup_view_transition()
	mut new_element := &TransitionElement{
		id:                   'new'
		view_transition_name: 'card'
		width:                30
		height:               40
		image:                'new image'
	}
	document.elements = [new_element]
	document.run_next_dom_task()
	capture := transition.named_elements['card'] or { panic('missing card capture') }
	assert capture.group_keyframes != none
	assert capture.group_animation_name_rule != none
	assert capture.group_styles_rule != none
	assert capture.image_pair_isolation_rule != none
	assert capture.image_animation_name_rule != none
	assert capture.style_rules.len == 5
	assert document.dynamic_style_rules.len == 7
	first_group_rule := capture.group_styles_rule or { '' }
	assert first_group_rule.contains('width: 30.0px')

	new_element.width = 55
	new_element.height = 66
	transition.handle_transition_frame(true)
	assert capture.style_rules.len == 5
	assert document.dynamic_style_rules.len == 7
	second_group_rule := capture.group_styles_rule or { '' }
	assert second_group_rule != first_group_rule
	assert second_group_rule.contains('width: 55.0px')
	assert document.dynamic_style_rules.filter(it == first_group_rule).len == 1

	transition.handle_transition_frame(false)
	assert document.dynamic_style_rules == ['unrelated author/platform rule', preexisting_group_rule]
}

fn test_new_only_and_old_only_animation_rules() {
	new_only_element := &TransitionElement{
		id:                   'new-only'
		view_transition_name: 'new-only'
		image:                none
	}
	mut new_only_document := &TransitionDocument{
		elements:        [new_only_element]
		snapshot_width:  1
		snapshot_height: 1
	}
	mut new_only := ViewTransition.create(new_only_document)
	new_only.setup_view_transition()
	new_only_document.run_next_dom_task()
	new_capture := new_only.named_elements['new-only'] or { panic('missing new-only capture') }
	assert (new_capture.image_animation_name_rule or { '' }).contains('fade-in')

	old_only_element := &TransitionElement{
		id:                   'old-only'
		view_transition_name: 'old-only'
		image:                'old image'
	}
	mut old_only_document := &TransitionDocument{
		elements:        [old_only_element]
		snapshot_width:  1
		snapshot_height: 1
	}
	mut old_only := ViewTransition.create(old_only_document)
	old_only.setup_view_transition()
	old_only_document.elements = []
	old_only_document.run_next_dom_task()
	old_capture := old_only.named_elements['old-only'] or { panic('missing old-only capture') }
	assert (old_capture.image_animation_name_rule or { '' }).contains('fade-out')
}

fn test_skip_and_replacement_are_idempotent_and_preserve_active_transition() {
	mut document := &TransitionDocument{
		snapshot_width:  1
		snapshot_height: 1
	}
	mut first := ViewTransition.create(document)
	first.setup_view_transition()
	first.skip_transition()
	first.skip_transition()
	assert first.phase == .done
	assert !document.rendering_suppression
	assert first.ready_promise.is_rejected()
	document.drain_dom_tasks()
	assert first.finished_promise.is_fulfilled()

	mut second := ViewTransition.create(document)
	mut third := ViewTransition.create(document)
	assert second.phase == .done
	assert second.ready_promise.is_rejected()
	assert document.active_transition or { panic('missing active transition') } == third
	second.clear_view_transition()
	assert document.active_transition or { panic('missing active transition') } == third
}
