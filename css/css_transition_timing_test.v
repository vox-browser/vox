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
