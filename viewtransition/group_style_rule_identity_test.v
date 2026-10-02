module viewtransition

fn test_group_style_update_retains_rule_and_only_updates_selector() {
	mut document := &TransitionDocument{}
	mut transition := ViewTransition.create(document)
	capture := &CapturedElement{
		old_width:  10
		old_height: 20
	}
	transition.named_elements['before'] = capture
	transition.update_pseudo_element_styles()!
	rule := capture.group_styles_rule?
	declarations := rule.declarations
	assert document.dynamic_style_rules.len == 1
	assert rule.selector_text == ':root::view-transition-group(before)'
	transition.named_elements.delete('before')
	transition.named_elements['after'] = capture
	transition.update_pseudo_element_styles()!
	assert capture.group_styles_rule? == rule
	assert rule.selector_text == ':root::view-transition-group(after)'
	assert rule.declarations == declarations
	assert document.dynamic_style_rules == [rule.css_text()]
	assert capture.style_rules == [rule.css_text()]
}
