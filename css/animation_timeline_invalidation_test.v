module css

import dom

struct TimelineInvalidationObservation {
mut:
	frames int
	targets []dom.AbstractElement
}

fn timeline_invalidation_document() (&dom.Document, &StyleComputer, &TimelineInvalidationObservation) {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{active_document_: document})
	document.set_navigable(&dom.Navigable{active_document_: document})
	observation := &TimelineInvalidationObservation{}
	document.set_page(&dom.Page{
		target: observation
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
		target: observation
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
