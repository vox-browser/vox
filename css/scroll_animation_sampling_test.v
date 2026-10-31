module css

import dom

fn scroll_sampling_animation(duration f64, timeline &AnimationTimeline) &CSSAnimation {
	mut animation := CSSAnimation.create()
	mut effect := KeyframeEffect.create()
	effect.set_specified_iteration_duration(duration)
	effect.set_fill_mode(.both)
	animation.set_effect(effect)
	animation.set_timeline(timeline)
	animation.play() or { panic(err) }
	return animation
}

fn test_inactive_scroll_animation_does_not_fill_from_the_document_clock() {
	for duration in [0.0, 1000.0] {
		mut animation := scroll_sampling_animation(duration, &AnimationTimeline{kind: .scroll})
		for document_time in [0.0, 500.0, 10000.0] {
			assert animation.sample_at(document_time) == none
			assert animation.effect_.output_progress == none
			assert animation.effect_.current_phase == .idle
			assert animation.last_sample_time_ == none
			assert animation.play_state() == .running
		}
	}
}

fn test_scroll_animation_samples_its_clock_and_clears_an_inactive_effect() {
	mut timeline := &AnimationTimeline{kind: .scroll}
	mut animation := scroll_sampling_animation(1000, timeline)
	timeline.update_current_time(250)
	assert animation.sample_at(10000) or { -1 } == 0.25
	assert animation.last_sample_time_ or { -1 } == 250
	timeline.update_current_time(750)
	assert animation.sample_at(20000) or { -1 } == 0.75
	timeline.current_time_ms_ = none
	assert animation.sample_at(30000) == none
	assert animation.effect_.output_progress == none
	assert animation.effect_.current_phase == .idle
	timeline.update_current_time(500)
	assert animation.sample_at(40000) or { -1 } == 0.5
}

fn test_paused_scroll_animation_preserves_its_hold_time() {
	mut timeline := &AnimationTimeline{kind: .scroll}
	mut animation := scroll_sampling_animation(1000, timeline)
	timeline.update_current_time(250)
	assert animation.sample_at(10000) or { -1 } == 0.25
	animation.pause() or { panic(err) }
	timeline.current_time_ms_ = none
	assert animation.sample_at(20000) or { -1 } == 0.25
	timeline.update_current_time(700)
	animation.play() or { panic(err) }
	assert animation.sample_at(30000) or { -1 } == 0.25
	timeline.update_current_time(800)
	assert animation.sample_at(40000) or { -1 } == 0.35
}

fn test_inactive_scroll_animation_preserves_cascaded_sidebar_geometry() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	add_document_author_style_sheet(document, '
		@keyframes sidebar { from { width: 260px; } to { width: 56px; } }
		.target { width: 260px; animation-name: sidebar;
			animation-duration: auto; animation-fill-mode: both;
			animation-timeline: scroll(root inline); }
	')
	mut element := document.create_element('div') or { panic(err) }
	element.set_attribute_value('class', 'target')
	mut computer := StyleComputer.new(document)
	mut target := dom.AbstractElement.new(element, none)
	initial := computer.compute_style(target)
	target.set_computed_properties(computed_properties_to_dom(initial))
	assert (initial.property(.width, .yes) or { panic('missing width') }).css_text == '260px'
	computer.set_animation_time_ms(10000)
	updated := computer.compute_style(target)
	assert (updated.property(.width, .yes) or { panic('missing width') }).css_text == '260px'
}
