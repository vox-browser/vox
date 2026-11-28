module main

import dom
import html

// Observe only an existing native model. Reading an audit must not construct
// a control, initialize its shadow tree or synthesize script/input events.
struct CaptureAuditInput {
	value           string
	selection_start ?u32
	selection_end   ?u32
}

fn capture_audit_input(element &dom.Element, enabled bool) ?CaptureAuditInput {
	if !enabled || !element.is_html_element() || element.local_name() != 'input' {
		return none
	}
	input := unsafe { &dom.HTMLInputElement(element) }
	if input.input_element_model_ == unsafe { nil } { return none }
	model := unsafe { &html.HTMLInputElementModel(input.input_element_model_) }
	return CaptureAuditInput{
		value:           model.value()
		selection_start: model.text_control.selection_start_binding()
		selection_end:   model.text_control.selection_end_binding()
	}
}
