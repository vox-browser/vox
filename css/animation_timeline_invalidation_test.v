module css

import dom

struct TimelineInvalidationObservation {
mut:
	frames  int
	targets []dom.AbstractElement
}

fn timeline_invalidation_document() (&dom.Document, &StyleComputer, &TimelineInvalidationObservation) {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{ active_document_: document })
	document.set_navigable(&dom.Navigable{ active_document_: document })
	observation := &TimelineInvalidationObservation{}
	document.set_page(&dom.Page{
		target:                 observation
		request_frame_callback: fn (target voidptr) {
			mut state := unsafe { &TimelineInvalidationObservation(target) }
			state.frames++
		}
	})
	computer := css_style_computer_for(document)
	document.needs_animated_style_update = false
	return document, computer, observation
}

fn test_static_document_clock_advances_without_requesting_another_frame() {
	mut document, computer, mut observation := timeline_invalidation_document()
	defer { document.finalize() }
	observation.frames = 0
	document.update_animations_and_send_events(125)
	document.update_animations_and_send_events(250)
	assert computer.animation_time_ms_ == 250
	assert computer.document_timeline_.current_time_ms() or { -1.0 } == 250
	assert !document.needs_animated_style_update
	assert observation.frames == 0
}

fn test_animation_hook_without_targets_stays_idle_and_new_targets_request_style() {
	mut document, mut computer, mut observation := timeline_invalidation_document()
	defer { document.finalize() }
	document.set_animations_hook(dom.DocumentAnimationsHook{
		target:         observation
		effect_targets: fn (target voidptr) []dom.AbstractElement {
			state := unsafe { &TimelineInvalidationObservation(target) }
			return state.targets.clone()
		}
	})
	observation.frames = 0
	computer.set_animation_time_ms(20)
	assert !document.needs_animated_style_update
	assert observation.frames == 0
	target := document.create_element('div')!
	observation.targets << dom.AbstractElement.new(target, none)
	computer.set_animation_time_ms(40)
	assert document.needs_animated_style_update
	assert observation.frames == 1
	assert computer.document_timeline_.current_time_ms() or { -1.0 } == 40
}

fn test_css_animation_targets_including_retained_end_states_request_style() {
	mut document, mut computer, mut observation := timeline_invalidation_document()
	defer { document.finalize() }
	target := document.create_element('div')!
	abstract_target := dom.AbstractElement.new(target, none)
	mut effect := KeyframeEffect.create()
	effect.set_target(abstract_target)
	effect.set_specified_iteration_duration(100)
	effect.set_fill_mode(.forwards)
	mut animation := CSSAnimation.create()
	animation.set_animation_name('fade')
	animation.set_owning_element(abstract_target)
	animation.set_effect(effect)
	animation.set_timeline(computer.document_timeline_)
	animation.play()!
	computer.css_animation_storage_.set(abstract_target, 'fade', animation)
	observation.frames = 0
	computer.set_animation_time_ms(50)
	assert document.needs_animated_style_update
	assert observation.frames == 1
	document.needs_animated_style_update = false
	computer.set_animation_time_ms(150)
	assert document.needs_animated_style_update
	assert observation.frames == 2
}

fn animation_demand_fixture(extra string) !(&dom.Document, &StyleComputer, &TimelineInvalidationObservation, &dom.Element, &dom.Element) {
	mut document, computer, observation := timeline_invalidation_document()
	mut root := document.create_element('html')!
	mut parent := document.create_element('section')!
	parent.set_attribute_value('id', 'parent')
	mut target := document.create_element('div')!
	target.set_attribute_value('id', 'target')
	mut node := unsafe { &dom.Node(document) }
	node.append_child(root.as_node())!
	mut root_node := root.as_node()
	root_node.append_child(parent.as_node())!
	mut parent_node := parent.as_node()
	parent_node.append_child(target.as_node())!
	add_document_author_style_sheet(document, '@keyframes pulse{from{opacity:.2}to{opacity:.8}}#target{animation:pulse 2s infinite}${extra}')
	document.update_style()
	return document, computer, observation, parent, target
}

fn test_hidden_css_animation_targets_keep_their_clock_without_requesting_frames() {
	mut document, mut computer, mut observation, mut parent, target := animation_demand_fixture('')!
	defer { document.finalize() }
	assert document_has_running_css_animations(document)
	animation := computer.css_animation_for(dom.AbstractElement.new(target, none), 'pulse')?
	parent.set_attribute_value('style', 'display:none')
	document.update_style()
	document.needs_animated_style_update = false
	observation.frames = 0
	document.update_animations_and_send_events(125)
	assert !document_has_running_css_animations(document)
	assert !document.needs_animated_style_update && observation.frames == 0
	assert computer.animation_time_ms_ == 125
	assert animation.play_state() == .idle
	assert animation.last_sample_time_ == none
	// The source effect is retained. Revealing the subtree restores demand.
	parent.set_attribute_value('style', 'display:block')
	document.update_style()
	document.needs_animated_style_update = false
	observation.frames = 0
	computer.set_animation_time_ms(250)
	assert document_has_running_css_animations(document)
	assert document.needs_animated_style_update && observation.frames == 1
}

fn test_hidden_pseudo_animation_targets_do_not_request_frames() {
	mut document, mut computer, mut observation, mut parent, target := animation_demand_fixture('#target{animation:none}#target::before{content:"x";animation:pulse 2s infinite}')!
	defer { document.finalize() }
	assert computer.css_animation_for(dom.AbstractElement.new(target, .before), 'pulse') != none
	parent.set_attribute_value('style', 'display:none')
	document.update_style()
	document.needs_animated_style_update = false
	observation.frames = 0
	computer.set_animation_time_ms(250)
	assert !document_has_running_css_animations(document)
	assert !document.needs_animated_style_update && observation.frames == 0
}

fn test_visibility_and_opacity_do_not_suppress_animation_frame_demand() {
	for declarations in ['visibility:hidden', 'opacity:0', 'display:contents'] {
		mut document, mut computer, mut observation, mut parent, _ := animation_demand_fixture('')!
		defer { document.finalize() }
		parent.set_attribute_value('style', declarations)
		document.update_style()
		document.needs_animated_style_update = false
		observation.frames = 0
		computer.set_animation_time_ms(250)
		assert document_has_running_css_animations(document), declarations
		assert document.needs_animated_style_update && observation.frames == 1, declarations
	}
}

fn test_display_animation_can_request_a_frame_to_reveal_its_hidden_target() {
	mut document, mut computer, mut observation, _, target := animation_demand_fixture('@keyframes reveal{from{display:none}to{display:block}}#target{display:none;animation:reveal 2s infinite}')!
	defer { document.finalize() }
	assert is_in_display_none_subtree_ignoring_animations(dom.AbstractElement.new(target, none))
	document.needs_animated_style_update = false
	observation.frames = 0
	computer.set_animation_time_ms(250)
	assert document_has_running_css_animations(document)
	assert document.needs_animated_style_update && observation.frames == 1
}

fn test_hidden_css_transition_targets_do_not_request_frames() {
	mut document, mut computer, mut observation, mut parent, target := animation_demand_fixture('#target{animation:none}')!
	defer { document.finalize() }
	parent.set_attribute_value('style', 'display:none')
	document.update_style()
	// Exercise a retained transition entry after committing the hidden style.
	computer.css_transition_storage_.set_transition(dom.AbstractElement.new(target, none),
		.opacity, &CSSTransition{ play_state_: .running, transition_property_: .opacity })
	document.needs_animated_style_update = false
	observation.frames = 0
	computer.set_animation_time_ms(250)
	assert !document_has_running_css_animations(document)
	assert !document.needs_animated_style_update && observation.frames == 0
}

fn test_initially_hidden_running_animation_does_not_schedule_rendering() {
	mut document, mut computer, mut observation, _, target := animation_demand_fixture('#target{display:none}')!
	defer { document.finalize() }
	animation := computer.css_animation_for(dom.AbstractElement.new(target, none), 'pulse')?
	assert animation.play_state() == .running
	document.needs_animated_style_update = false
	observation.frames = 0
	document.update_animations_and_send_events(125)
	assert animation.last_sample_time_? == 125
	assert computer.animation_time_ms_ == 125
	assert !document_has_running_css_animations(document)
	assert !document.needs_animated_style_update && observation.frames == 0
}
