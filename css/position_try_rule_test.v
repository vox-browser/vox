module css

fn test_position_try_rule_parsing_filters_descriptors_and_keeps_escaped_names() {
	mut rule := parse_css_rule_with_params(ParsingParams{},'@position-try --foo {top:anchor(bottom);color:red;--x:1px;width:20px!important;left:3px;@media all {height:4px}}') or { panic('position-try') }
	assert rule.type_ == .position_try && rule.type_for_bindings() == 0 && rule.class_name() == 'CSSPositionTryRule'
	assert rule.position_try_name() == '--foo'
	assert rule.css_text() == '@position-try --foo { top: anchor(bottom); left: 3px; }',rule.css_text()
	mut style := rule.style()?
	style.set_property('color','green','')!
	style.set_property('--x','10px','')!
	style.set_property('top','11px','important')!
	assert style.length() == 2 && style.get_property_value('top') == 'anchor(bottom)'
	style.set_property('top','11px','')!
	assert style.get_property_value('top') == '11px'
	style.set_css_text('color:blue;margin:2px;position-anchor:--a')!
	assert style.get_property_value('color') == '' && style.get_property_value('margin') == '2px'
	assert style.get_property_value('position-anchor') == '--a'
	escaped := parse_css_rule_with_params(ParsingParams{},r'@position-try --\{ {}') or { panic('escaped name') }
	assert escaped.position_try_name() == r'--\{' && escaped.css_text() == r'@position-try --\{ { }'
	for text in ['@position-try {}','@position-try foo {}','@position-try --a --b {}','@position-try --a, --b {}','@position-try --a;'] {
		assert parse_css_rule_with_params(ParsingParams{},text) == none,text
	}
}
