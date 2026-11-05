module css

import dom

struct CompletedTransitionFrames {
mut:
	count int
}

fn completed_transition_fixture() (&dom.Document, &StyleComputer, &CSSTransition, &CompletedTransitionFrames) {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{active_document_: document})
	document.set_navigable(&dom.Navigable{active_document_: document})
	mut element := document.create_element('div') or { panic(err) }
	document.as_node().append_child(element.as_node()) or { panic(err) }
	frames := &CompletedTransitionFrames{}
	document.set_page(&dom.Page{target:frames,request_frame_callback:fn (target voidptr) {
		mut observed := unsafe { &CompletedTransitionFrames(target) }
		observed.count++
	}})
	computer := css_style_computer_for(document)
	subject := dom.AbstractElement.new(element, none)
	from := parse_css_value(ParsingParams{}, '8', .tab_size) or { panic('from') }
	to := parse_css_value(ParsingParams{}, '4', .tab_size) or { panic('to') }
	transition := CSSTransition.start_a_transition(subject, .tab_size, 1, 0, 0, 1, from, to, from, 1)
	return document, computer, transition, frames
}

fn test_completed_transition_does_not_request_repeated_animated_style_frames() {
	mut document, mut computer, mut transition, mut frames := completed_transition_fixture()
	defer { document.finalize() }
	assert transition.sample_at(2)? == 1
	assert transition.is_finished()
	document.needs_animated_style_update = false
	frames.count = 0
	for time in [3.0, 10.0, 250.0] { computer.set_animation_time_ms(time) }
	assert !document.needs_animated_style_update
	assert frames.count == 0
	assert computer.animation_time_ms_ == 250
	assert computer.css_transition_storage_.associated_transitions.len == 1
}

fn test_transition_requests_its_final_sample_after_an_earlier_progress_is_resampled() {
	mut document, mut computer, mut transition, mut frames := completed_transition_fixture()
	defer { document.finalize() }
	document.needs_animated_style_update = false
	frames.count = 0
	computer.set_animation_time_ms(2)
	assert document.needs_animated_style_update
	assert frames.count == 1
	assert transition.sample_at(2)? == 1
	// DocumentTimeline is monotonic. Direct effect sampling can still revisit
	// earlier progress, which must keep the subsequent final sample eligible.
	assert transition.needs_style_sample_at(0.5)
	assert transition.sample_at(0.5)? == 0.5
	document.needs_animated_style_update = false
	frames.count = 0
	computer.set_animation_time_ms(3)
	assert document.needs_animated_style_update
	assert frames.count == 1
	assert transition.sample_at(2)? == 1
}
