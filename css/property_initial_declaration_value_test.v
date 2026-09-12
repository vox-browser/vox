module css

fn universal_property_registration_succeeds(initial_value string) bool {
	register_property(PropertyDefinition{
		name: '--universal-test'
		syntax: '*'
		inherits: false
		initial_value: initial_value
	}) or { return false }
	return true
}

fn test_register_property_validates_universal_initial_value() {
	assert universal_property_registration_succeeds('')
	assert universal_property_registration_succeeds('plain tokens')
	assert universal_property_registration_succeeds('(;!)')
	assert !universal_property_registration_succeeds('whee!')
	assert !universal_property_registration_succeeds(')')
	assert !universal_property_registration_succeeds('([)]')
}

fn test_property_rule_validates_universal_initial_value_descriptor() {
	sheet := parse_css_stylesheet_with_parser('@property --bad { syntax: "*"; inherits: false; initial-value: whee!; }
		@property --substitution { syntax: "*"; inherits: false; initial-value: var(--other); }
		@property --good { syntax: "*"; inherits: false; initial-value: plain tokens; }', none)
	assert sheet.css_rules().length() == 1
	rule := sheet.css_rules().item(0) or { panic('missing property rule') }
	assert rule.property_rule_name() == '--good'
}
