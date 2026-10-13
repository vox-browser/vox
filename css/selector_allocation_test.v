module css

import dom

fn allocation_test_matches(text string, element &dom.Element) bool {
	mut context := MatchContext{subject: unsafe { &dom.Element(element) }}
	selectors := parse_selector_with_parser(text, map[string]bool{}) or { panic('invalid selector') }
	return matches(selectors.selectors[0], element, none, mut context, none, none, .normal, none)
}

fn test_attribute_case_lookup_preserves_html_defaults_and_explicit_flags() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_document_type(.html)
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }
	element.set_attribute_value('type', 'TeXT')
	element.set_attribute_value('class', 'foo')
	assert allocation_test_matches('[type=text]', element)
	assert allocation_test_matches('[type=text i]', element)
	assert !allocation_test_matches('[type=text s]', element)
	assert !allocation_test_matches('[class=FOO]', element)
	assert allocation_test_matches('[class=FOO i]', element)
	mut svg := document.create_element_ns('http://www.w3.org/2000/svg', 'svg') or { panic('${err}') }
	svg.set_attribute_value('type', 'TeXT')
	assert !allocation_test_matches('[type=text]', svg)
	assert allocation_test_matches('[type=text i]', svg)
}

fn test_structural_selector_metadata_uses_subject_identity_without_context_copy() {
	document := dom.Document.create(dom.url_about_blank())
	mut parent := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }
	mut first := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or { panic('${err}') }
	second := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or { panic('${err}') }
	first.set_attribute_value('class', 'leaf')
	mut parent_node := parent.as_node()
	parent_node.append_child(first.as_node()) or { panic('${err}') }
	parent_node.append_child(second.as_node()) or { panic('${err}') }
	mut context := MatchContext{
		subject: first
		collect_per_element_selector_involvement_metadata: true
	}
	assert matches(selector_from_text('div:first-child .leaf:first-child'), first, none, mut context, none, none, .normal, none)
	assert parent.affected_by_structural_pseudo_class_in_non_subject_position
	assert !first.affected_by_structural_pseudo_class_in_non_subject_position
	assert allocation_test_matches(':nth-child(2)', second)
	assert !allocation_test_matches(':nth-child(2)', first)
}
