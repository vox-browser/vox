module css

import dom

fn scroll_snap_serialization(property_id PropertyID, text string) ?string {
	value := parse_css_value_logic(property_id, text) or { return none }
	return value.serialize(.normal)
}

fn test_scroll_snap_property_metadata() {
	assert number_of_longhand_properties == 360
	assert last_longhand_property_id() == .webkit_font_smoothing
	assert property_id_from_string('scroll-snap-align')? == .scroll_snap_align
	assert property_id_from_string('SCROLL-SNAP-STOP')? == .scroll_snap_stop
	assert property_id_from_string('scroll-snap-type')? == .scroll_snap_type
	assert property_initial_value_string(.scroll_snap_align) == 'none'
	assert property_initial_value_string(.scroll_snap_stop) == 'normal'
	assert property_initial_value_string(.scroll_snap_type) == 'none'
	for property_id in [PropertyID.scroll_snap_align, .scroll_snap_stop, .scroll_snap_type] {
		assert animation_type_from_longhand_property(property_id) == .discrete
		assert is_animatable_property(property_id)
		assert !is_inherited_property(property_id)
		assert !property_affects_layout(property_id)
		assert generated_shorthands_for_longhand(property_id) == [PropertyID.all]
		assert property_id in generated_expanded_longhands_for_shorthand(.all)
	}
	assert keyword_from_string('mandatory')? == .mandatory
	assert keyword_from_string('PROXIMITY')? == .proximity
}

fn test_scroll_snap_align_parsing() {
	valid := {
		'none':        'none'
		'start':       'start'
		'end':         'end'
		'center':      'center'
		'start none':  'start none'
		'center end':  'center end'
		'start start': 'start'
	}
	for input, expected in valid {
		assert scroll_snap_serialization(.scroll_snap_align, input)? == expected, input
	}
	for invalid in ['auto', 'start invalid', 'start end center'] {
		assert scroll_snap_serialization(.scroll_snap_align, invalid) == none, invalid
	}
}

fn test_scroll_snap_stop_parsing() {
	for valid in ['normal', 'always'] {
		assert scroll_snap_serialization(.scroll_snap_stop, valid)? == valid
	}
	for invalid in ['auto', 'normal always'] {
		assert scroll_snap_serialization(.scroll_snap_stop, invalid) == none, invalid
	}
}

fn test_scroll_snap_type_parsing() {
	valid := {
		'none':             'none'
		'x':                'x'
		'y':                'y'
		'block':            'block'
		'inline':           'inline'
		'both':             'both'
		'y mandatory':      'y mandatory'
		'block mandatory':  'block mandatory'
		'both mandatory':   'both mandatory'
		'inline proximity': 'inline'
		'x proximity':      'x'
	}
	for input, expected in valid {
		assert scroll_snap_serialization(.scroll_snap_type, input)? == expected, input
	}
	for invalid in ['auto', 'x y', 'block mandatory inline', 'none both', 'none mandatory',
		'both none', 'mandatory', 'proximity', 'mandatory inline', 'proximity both', 'mandatory x',
		'proximity y', 'mandatory block', 'proximity mandatory'] {
		assert scroll_snap_serialization(.scroll_snap_type, invalid) == none, invalid
	}
}

fn test_scroll_snap_computed_values_are_typed() {
	document := dom.Document.create(dom.url_about_blank())
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic(err)
	}
	element.set_attribute_value('style', 'scroll-snap-align: center end; scroll-snap-stop: always; scroll-snap-type: y mandatory')
	computed := StyleComputer.new(document).compute_style(dom.AbstractElement.new(element, none))
	assert (computed.property(.scroll_snap_align, .no) or { panic('missing align') }).css_text == 'center end'
	assert (computed.property(.scroll_snap_stop, .no) or { panic('missing stop') }).css_text == 'always'
	assert (computed.property(.scroll_snap_type, .no) or { panic('missing type') }).css_text == 'y mandatory'
	align := computed.scroll_snap_align()
	assert align.block_alignment == .center
	assert align.inline_alignment == .end_
	assert computed.scroll_snap_stop() == .always
	type_ := computed.scroll_snap_type()
	assert type_.axis == .y
	assert type_.strictness == .mandatory

	element.set_attribute_value('style', 'scroll-snap-align: start; scroll-snap-type: inline proximity')
	proximity := StyleComputer.new(document).compute_style(dom.AbstractElement.new(element, none))
	assert proximity.scroll_snap_align() == ScrollSnapAlignData{
		block_alignment: .start
		inline_alignment: .start
	}
	assert proximity.scroll_snap_type().axis == .inline_
	assert proximity.scroll_snap_type().strictness == .proximity

	element.set_attribute_value('style', '')
	initial := StyleComputer.new(document).compute_style(dom.AbstractElement.new(element, none))
	assert initial.scroll_snap_align() == ScrollSnapAlignData{}
	assert initial.scroll_snap_stop() == .normal
	assert initial.scroll_snap_type() == ScrollSnapType{}
}
