module css

fn register_property_accepts_initial_value(syntax string, initial_value string) bool {
	register_property(PropertyDefinition{
		name: '--test'
		syntax: syntax
		inherits: false
		initial_value: initial_value
	}) or { return false }
	return true
}

fn test_register_property_exempts_universal_syntax_and_string_contents() {
	assert register_property_accepts_initial_value('*', '10em')
	assert register_property_accepts_initial_value('<string>', '"10em"')
}

fn test_register_property_rejects_computationally_dependent_lengths() {
	assert register_property_accepts_initial_value('<length>', '10px')
	assert register_property_accepts_initial_value('<length>', '10vw')
	assert !register_property_accepts_initial_value('<length>', '10em')
	assert !register_property_accepts_initial_value('<length>', '10cqw')
	assert !register_property_accepts_initial_value('<length>', 'calc(4px + 3em)')
	assert !register_property_accepts_initial_value('<length>+', '10px calc(20px + 4rem)')
}

fn test_register_property_checks_relative_lengths_inside_transforms() {
	assert register_property_accepts_initial_value('<transform-function>', 'rotate(10deg)')
	assert register_property_accepts_initial_value('<transform-function>', 'translateX(10px)')
	assert !register_property_accepts_initial_value('<transform-function>', 'translateX(1em)')
	assert !register_property_accepts_initial_value('<transform-function>', 'translateY(1lh)')
	assert !register_property_accepts_initial_value('<transform-list>', 'rotate(10deg) translateX(1em)')
}

fn test_property_rule_ignores_computationally_dependent_initial_value() {
	sheet := parse_css_stylesheet_with_parser('@property --bad { syntax: "<length>"; inherits: false; initial-value: 3em; }
		@property --good { syntax: "<length>"; inherits: false; initial-value: 3px; }', none)
	assert sheet.css_rules().length() == 1
	rule := sheet.css_rules().item(0) or { panic('missing property rule') }
	assert rule.property_rule_name() == '--good'
}
