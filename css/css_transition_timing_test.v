module css

import dom

fn transition_timing_test_target() dom.AbstractElement {
	mut document := dom.Document.create(dom.url_about_blank())
	mut target := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic(err)
	}
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(target.as_node()) or { panic(err) }
	_ = css_style_computer_for(document)
	return dom.AbstractElement.new(target, none)
}

fn test_css_transition_applies_backwards_fill_during_delay() {
	target := transition_timing_test_target()
	start_value := &dom.StyleValue{ css_text: '0' }
	end_value := &dom.StyleValue{ css_text: '1' }
	transition := CSSTransition.start_a_transition(target, .opacity, 1, 100.0, 0.0, 200.0, start_value, end_value, start_value, 1.0)

	effect := transition.effect() or { panic('CSS transition must have an effect') }
	assert effect.fill_mode == .backwards
}

fn test_css_transition_timing_output_avoids_zero_duration_nan() {
	target := transition_timing_test_target()
	start_value := &dom.StyleValue{ css_text: '0' }
	end_value := &dom.StyleValue{ css_text: '1' }
	transition := CSSTransition.start_a_transition(target, .opacity, 1, 50.0, 25.0, 25.0, start_value, end_value, start_value, 1.0)

	assert transition.timing_function_output_at_time(25.0) == 1.0
}

fn test_css_transition_timing_output_uses_nonzero_duration_progress() {
	target := transition_timing_test_target()
	start_value := &dom.StyleValue{ css_text: '0' }
	end_value := &dom.StyleValue{ css_text: '1' }
	transition := CSSTransition.start_a_transition(target, .opacity, 1, 0.0, 0.0, 100.0, start_value, end_value, start_value, 1.0)

	assert transition.timing_function_output_at_time(25.0) == 0.25
}

fn test_provisional_css_transition_is_published_only_when_committed() {
	target := transition_timing_test_target()
	start_value := &dom.StyleValue{ css_text: '0' }
	end_value := &dom.StyleValue{ css_text: '1' }
	mut transition := CSSTransition.start_a_provisional_transition(target, .opacity, 1, 0.0, 0.0, 100.0, start_value, end_value, start_value, 1.0)
	computer := css_style_computer_for(target.document())

	assert transition.is_provisional()
	assert transition.effect() != none
	assert computer.css_transition_storage_.property_transition(target, .opacity) == none

	transition.commit_provisional_transition()
	published := computer.css_transition_storage_.property_transition(target, .opacity) or {
		panic('committed transition was not published')
	}
	assert voidptr(published) == voidptr(transition)
	assert !transition.is_provisional()
	assert transition.effect() != none
}

fn test_discarded_provisional_css_transition_releases_effect_and_timeline() {
	target := transition_timing_test_target()
	start_value := &dom.StyleValue{ css_text: '0' }
	end_value := &dom.StyleValue{ css_text: '1' }
	mut transition := CSSTransition.start_a_provisional_transition(target, .opacity, 1, 0.0, 0.0, 100.0, start_value, end_value, start_value, 1.0)
	computer := css_style_computer_for(target.document())

	transition.discard_provisional_transition()

	assert !transition.is_provisional()
	assert transition.effect() == none
	assert transition.timeline_ == none
	assert computer.css_transition_storage_.property_transition(target, .opacity) == none
}
