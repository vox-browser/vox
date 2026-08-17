module css

// Completion-focused coverage for translated CSS interfaces whose algorithms are
// not reached by the parser and style-computer regression suites.

fn test_typed_om_numeric_construction_arithmetic_and_conversion() {
	degrees := CSSUnitValue.construct_impl(180, 'DEG')!
	assert degrees.unit() == 'deg'
	turns := CSSNumericValue(degrees).to('turn')!
	assert turns.unit() == 'turn'
	assert turns.value() > 0.499999 && turns.value() < 0.500001

	more := CSSUnitValue.construct_impl(45, 'deg')!
	sum := CSSNumericValue(degrees).add([CSSNumberish(more)])!
	assert sum is CSSUnitValue
	assert (sum as CSSUnitValue).value() == 225

	centimetres := CSSNumericValue.parse('2.54cm')!
	pixels := centimetres.to('px')!
	assert pixels.value() > 95.999999 && pixels.value() < 96.000001
	if _ := CSSUnitValue.construct_impl(1, 'definitely-not-a-unit') {
		assert false
	}
	if _ := CSSNumericValue.parse('red') {
		assert false
	}
}

fn test_typed_om_style_value_parse_and_serialization() {
	width := CSSStyleValue.parse('WIDTH', '12px')!
	assert width.to_string()! == '12px'
	values := CSSStyleValue.parse_all('margin', '1px 2px')!
	assert values.len > 0
	if _ := CSSStyleValue.parse('not-a-property', '12px') {
		assert false
	}
}

fn test_constructed_stylesheet_mutation_and_css_namespace_helpers() {
	mut sheet := css_style_sheet_construct(none, none)!
	sheet.replace_sync('@import "ignored.css"; a { color: red }')!
	assert sheet.css_rules().length() == 1
	assert sheet.css_rules().item(0)?.selector_text() == 'a'

	index := sheet.insert_rule('b { width: 2px }', 1)!
	assert index == 1
	assert sheet.css_rules().length() == 2
	sheet.delete_rule(0)!
	assert sheet.css_rules().length() == 1
	if _ := sheet.insert_rule('@import "blocked.css";', 0) {
		assert false
	}

	assert escape('0a') == '\\30 a'
	assert supports_property('width', '12px')
	assert supports_property('--audit', 'anything')
	assert !supports_property('width', 'red')
	assert supports_condition('(display: block)')
	assert !supports_condition('(unknown-property: value)')

	registration := register_property(PropertyDefinition{
		name:          '--audit-length'
		syntax:        '<length>'
		inherits:      false
		initial_value: '1px'
	})!
	assert registration.property_name == '--audit-length'
	if _ := register_property(PropertyDefinition{
		name:     'not-custom'
		syntax:   '*'
		inherits: false
	})
	{
		assert false
	}
}

fn test_cssstyleproperties_reappends_cross_mapped_logical_declarations() {
	mut properties := CSSStyleProperties.create()
	properties.set_property('margin-inline-start', '1px', '')!
	properties.set_property('margin-left', '2px', '')!

	// Updating the logical declaration must move it after the later physical
	// declaration, because both can map to the same used property.
	properties.set_property('margin-inline-start', '3px', '')!
	assert properties.length() == 2
	assert properties.item(0) == 'margin-left'
	assert properties.item(1) == 'margin-inline-start'
	assert properties.css_text() == 'margin-left: 2px; margin-inline-start: 3px;'
}

fn test_parsed_declaration_blocks_use_cssom_specified_order() {
	properties :=
		parse_css_property_declaration_block_with_parser('color: red; color: blue; width: red; margin: 1px 2px')

	// Duplicate declarations collapse to the last declaration, invalid values
	// are discarded, and shorthands occupy their canonical longhand slots.
	assert properties.length() == 5
	assert properties.get_property_value('color') == 'blue'
	assert properties.get_property_value('width') == ''
	assert properties.item(0) == 'color'
	assert properties.item(1) == 'margin-top'
	assert properties.item(2) == 'margin-right'
	assert properties.item(3) == 'margin-bottom'
	assert properties.item(4) == 'margin-left'
}

fn test_events_retain_webidl_initializer_values_and_real_font_faces() {
	animation := AnimationEvent.construct_impl('animationend', AnimationEventInit{
		animation_name: 'fade'
		elapsed_time:   1.5
		pseudo_element: '::before'
	})!
	assert animation.animation_name() == 'fade'
	assert animation.elapsed_time() == 1.5
	assert animation.pseudo_element() == '::before'

	transition := TransitionEvent.construct_impl('transitionend', TransitionEventInit{
		property_name:  'opacity'
		elapsed_time:   0.25
		pseudo_element: '::after'
	})
	assert transition.property_name() == 'opacity'
	assert transition.elapsed_time() == 0.25

	face := FontFaceObject.construct_impl('AuditFace',
		FontFaceSource.from_string('local(AuditFace)'), FontFaceDescriptors{})
	event := FontFaceSetLoadEvent.construct_impl('loadingdone', FontFaceSetLoadEventInit{
		fontfaces: [face]
	})!
	faces := event.fontfaces()
	assert faces.len == 1
	assert voidptr(faces[0]) == voidptr(face)
	assert faces[0].family() == 'AuditFace'
}

fn test_screen_and_orientation_observable_defaults() {
	mut screen := Screen.create()
	assert screen.width() == 800
	assert screen.height() == 600
	assert screen.avail_width() == 800
	assert screen.avail_height() == 600
	assert screen.color_depth() == 24
	assert screen.pixel_depth() == 24
	assert !screen.is_extended()

	orientation := screen.orientation()
	assert orientation.type_() == .landscape_primary
	assert orientation.angle() == 0
	if _ := orientation.lock(.portrait) {
		assert false
	}
}
