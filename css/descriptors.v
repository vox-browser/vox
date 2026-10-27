module css

import dom

pub enum AtRuleID {
	font_face
	page
	counter_style
	function_rule
}

fn descriptor_id_to_string(descriptor_id DescriptorID) string {
	return match descriptor_id {
		.unknown { '' }
		.custom { '' }
		.result { 'result' }
		.margin { 'margin' }
		.margin_top { 'margin-top' }
		.margin_right { 'margin-right' }
		.margin_bottom { 'margin-bottom' }
		.margin_left { 'margin-left' }
		.size { 'size' }
		.page_orientation { 'page-orientation' }
		.marks { 'marks' }
		.bleed { 'bleed' }
	}
}

fn descriptor_id_from_string(at_rule_id AtRuleID, property string) ?DescriptorID {
	lower := property.to_lower()
	return match at_rule_id {
		.function_rule {
			match lower {
				'result' { DescriptorID.result }
				else { none }
			}
		}
		.page {
			match lower {
				'margin' { DescriptorID.margin }
				'margin-top' { DescriptorID.margin_top }
				'margin-right' { DescriptorID.margin_right }
				'margin-bottom' { DescriptorID.margin_bottom }
				'margin-left' { DescriptorID.margin_left }
				'size' { DescriptorID.size }
				'page-orientation' { DescriptorID.page_orientation }
				'marks' { DescriptorID.marks }
				'bleed' { DescriptorID.bleed }
				else { none }
			}
		}
		else {
			// Boundary: @font-face descriptors are represented by CSSFontFaceDescriptors in font_face_values.v, and
			// @counter-style descriptor parsing is represented by counter_values.v.
			none
		}
	}
}

fn descriptor_style_value_to_string(value &dom.StyleValue) string {
	return value.css_text
}

struct ParsedCSSDescriptorValue {
	value       &dom.StyleValue = unsafe { nil }
	style_value StyleValue
	serialized  string
}

fn parse_css_descriptor_value_for_cssom(at_rule_id AtRuleID, descriptor_id DescriptorID, value string) ?ParsedCSSDescriptorValue {
	parsed_value := parse_css_descriptor_value_logic(at_rule_id, descriptor_id, value) or {
		return none
	}
	return ParsedCSSDescriptorValue{
		value:       dom_style_value_from_value_logic(parsed_value)
		style_value: parsed_value
		serialized:  parsed_value.serialize(.normal)
	}
}

fn parse_css_descriptor_for_cssom(at_rule_id AtRuleID, descriptor_id DescriptorID, value string) ?&dom.StyleValue {
	return (parse_css_descriptor_value_for_cssom(at_rule_id, descriptor_id, value) or {
		return none
	}).value
}

pub fn (mut parser Parser) convert_to_descriptor(at_rule_id AtRuleID, declaration Declaration) ?Descriptor {
	descriptor_name_and_id := DescriptorNameAndID.from_name(at_rule_id, declaration.name) or {
		return none
	}
	mut tokens := ComponentValueStream.new(declaration.value)
	style_value := parser.parse_descriptor_value_tokens(at_rule_id, descriptor_name_and_id.id(), mut tokens) or {
		return none
	}
	return Descriptor{
		descriptor_name_and_id: descriptor_name_and_id
		value: dom_style_value_from_value_logic(style_value)
		serialized_value: style_value.serialize(.normal)
	}
}

// A non-spec base class for descriptor-list classes.
@[heap]
pub struct CSSDescriptors {
pub mut:
	at_rule_id  AtRuleID
	descriptors []Descriptor
	readonly    bool
	computed    bool
	parent_rule ?&CSSRule
}

pub fn CSSDescriptors.create(at_rule_id AtRuleID, descriptors []Descriptor) &CSSDescriptors {
	return &CSSDescriptors{
		at_rule_id:  at_rule_id
		descriptors: descriptors.clone()
	}
}

pub fn (mut descriptors CSSDescriptors) set_parent_rule(rule ?&CSSRule) {
	descriptors.parent_rule = rule
}

// https://drafts.csswg.org/cssom/#dom-cssstyledeclaration-length
pub fn (descriptors &CSSDescriptors) length() uint {
	// The length attribute must return the number of CSS declarations in the declarations.
	return uint(descriptors.descriptors.len)
}

// https://drafts.csswg.org/cssom/#dom-cssstyledeclaration-item
pub fn (descriptors &CSSDescriptors) item(index uint) string {
	// The item(index) method must return the property name of the CSS declaration at position index.
	// If there is no indexth object in the collection, then the method must return the empty string.
	if index >= descriptors.length() {
		return ''
	}

	return descriptors.descriptors[index].descriptor_name_and_id.name()
}

// https://drafts.csswg.org/cssom/#set-a-css-declaration
fn (mut descriptors CSSDescriptors) set_a_css_declaration(descriptor_name_and_id DescriptorNameAndID, value &dom.StyleValue, important Important, serialized_value string) bool {
	_ = important
	if descriptors.computed {
		panic('Cannot set computed CSSDescriptors')
	}

	for i, descriptor in descriptors.descriptors {
		if descriptor.descriptor_name_and_id == descriptor_name_and_id {
			if serialized_value.len != 0 && descriptor.serialized_value == serialized_value {
				return false
			}
			if descriptor.value == value {
				return false
			}
			unsafe {
				descriptors.descriptors[i].value = value
				descriptors.descriptors[i].serialized_value = serialized_value
			}
			return true
		}
	}

	unsafe {
		descriptors.descriptors << Descriptor{
			descriptor_name_and_id: descriptor_name_and_id
			value: value
			serialized_value: serialized_value
		}
	}
	return true
}

// https://drafts.csswg.org/cssom/#dom-cssstyledeclaration-setproperty
pub fn (mut descriptors CSSDescriptors) set_property(property string, value string, priority string) ! {
	// 1. If the readonly flag is set, then throw a NoModificationAllowedError exception.
	if descriptors.readonly {
		return error('NoModificationAllowedError: Cannot modify properties of readonly CSSStyleDeclaration')
	}

	// 2. If property is not a custom property, follow these substeps:
	// 1. Let property be property converted to ASCII lowercase.
	// 2. If property is not a case-sensitive match for a supported CSS property, then return.
	descriptor_name_and_id := DescriptorNameAndID.from_name(descriptors.at_rule_id, property) or {
		return
	}
	descriptor_id := descriptor_name_and_id.id()

	// 3. If value is the empty string, invoke removeProperty() with property as argument and return.
	if value.len == 0 {
		descriptors.remove_property(property)!
		return
	}

	// 4. If priority is not the empty string and is not an ASCII case-insensitive match for the string "important", then return.
	if priority.len != 0 && priority.to_lower() != 'important' {
		return
	}

	// 5. Let component value list be the result of parsing value for property property.
	component_value_list := parse_css_descriptor_value_for_cssom(descriptors.at_rule_id,
		descriptor_id, value) or {
		// 6. If component value list is null, then return.
		return
	}

	// 7. Let updated be false.
	mut updated := false

	// 8. If property is a shorthand property, then for each longhand property longhand that property maps to, in canonical order, follow these substeps:
	if descriptors.at_rule_id == .page && descriptor_id == .margin {
		for expanded_value in expand_page_margin_shorthand_descriptor_value(component_value_list.style_value) {
			longhand_value := parse_css_descriptor_value_for_cssom(descriptors.at_rule_id,
				expanded_value.descriptor_id, expanded_value.serialized_value) or { continue }
			longhand_result := descriptors.set_a_css_declaration(DescriptorNameAndID.from_id(expanded_value.descriptor_id),
				longhand_value.value, if priority.len == 0 {
				Important.no
			} else {
				Important.yes
			}, longhand_value.serialized)
			if longhand_result {
				updated = true
			}
		}
	} else if is_descriptor_shorthand(descriptors.at_rule_id, descriptor_id) {
		// The only translated descriptor shorthand is @page margin, handled above from the parsed CSS-side value.
		// Other descriptor shorthands should be expanded here once their typed StyleValue representation exists.
	} else {
		// 9. Otherwise, let updated be the result of set the CSS declaration property with value component value list,
		//    with the important flag set if priority is not the empty string, and unset otherwise, and with the list of
		//    declarations being the declarations.
		updated = descriptors.set_a_css_declaration(descriptor_name_and_id, component_value_list.value, if priority.len != 0 {
			Important.yes
		} else {
			Important.no
		}, component_value_list.serialized)
	}

	// 10. If updated is true, update style attribute for the CSS declaration block.
	if updated {
		descriptors.update_style_attribute()
	}
}

// https://drafts.csswg.org/cssom/#dom-cssstyledeclaration-removeproperty
pub fn (mut descriptors CSSDescriptors) remove_property(property string) !string {
	// 1. If the readonly flag is set, then throw a NoModificationAllowedError exception.
	if descriptors.readonly {
		return error('NoModificationAllowedError: Cannot modify properties of readonly CSSStyleDeclaration')
	}

	// 2. If property is not a custom property, let property be property converted to ASCII lowercase.
	// AD-HOC: We compare names case-insensitively instead.

	// 3. Let value be the return value of invoking getPropertyValue() with property as argument.
	value := descriptors.get_property_value(property)

	// 4. Let removed be false.
	mut removed := false
	descriptor_name_and_id := DescriptorNameAndID.from_name(descriptors.at_rule_id, property)

	// 5. If property is a shorthand property, for each longhand property longhand that property maps to:
	if name_and_id := descriptor_name_and_id {
		id := name_and_id.id()
		if descriptors.at_rule_id == .page && id == .margin {
			mut kept := []Descriptor{}
			for descriptor in descriptors.descriptors {
				if descriptor.descriptor_name_and_id.id() in [.margin, .margin_top, .margin_right, .margin_bottom,
					.margin_left] {
					removed = true
					continue
				}
				kept << descriptor
			}
			descriptors.descriptors = kept
		} else if is_descriptor_shorthand(descriptors.at_rule_id, id) {
			// The only translated descriptor shorthand is @page margin, handled above.
		} else {
			// 6. Otherwise, if property is a case-sensitive match for a property name of a CSS declaration in the
			//    declarations, remove that CSS declaration and let removed be true.
			mut kept := []Descriptor{}
			for descriptor in descriptors.descriptors {
				if descriptor.descriptor_name_and_id == name_and_id {
					removed = true
					continue
				}
				kept << descriptor
			}
			descriptors.descriptors = kept
		}
	}

	// 7. If removed is true, Update style attribute for the CSS declaration block.
	if removed {
		descriptors.update_style_attribute()
	}

	// 8. Return value.
	return value
}

// https://drafts.csswg.org/cssom/#dom-cssstyledeclaration-getpropertyvalue
pub fn (descriptors &CSSDescriptors) get_property_value(property string) string {
	// 1. If property is not a custom property, follow these substeps: ...
	// NB: These substeps only apply to shorthands, and descriptors cannot be shorthands.

	// 2. If property is a case-sensitive match for a property name of a CSS declaration in the declarations, then
	//    return the result of invoking serialize a CSS value of that declaration.
	descriptor_name_and_id := DescriptorNameAndID.from_name(descriptors.at_rule_id, property) or {
		return ''
	}
	for descriptor in descriptors.descriptors {
		if descriptor.descriptor_name_and_id == descriptor_name_and_id {
			if descriptor.serialized_value.len != 0 {
				return descriptor.serialized_value
			}
			return descriptor_style_value_to_string(descriptor.value)
		}
	}

	// 3. Return the empty string.
	return ''
}

// https://drafts.csswg.org/cssom/#dom-cssstyledeclaration-getpropertypriority
pub fn (descriptors &CSSDescriptors) get_property_priority(property string) string {
	_ = descriptors
	_ = property
	// AD-HOC: It's not valid for descriptors to be !important.
	return ''
}

pub fn (descriptors &CSSDescriptors) descriptor(descriptor_name_and_id DescriptorNameAndID) ?&dom.StyleValue {
	for descriptor in descriptors.descriptors {
		if descriptor.descriptor_name_and_id == descriptor_name_and_id {
			return descriptor.value
		}
	}
	return none
}

pub fn (descriptors &CSSDescriptors) descriptor_or_initial_value(descriptor_name_and_id DescriptorNameAndID) ?&dom.StyleValue {
	if value := descriptors.descriptor(descriptor_name_and_id) {
		return value
	}
	return descriptor_initial_value(descriptors.at_rule_id, descriptor_name_and_id.id())
}

fn descriptor_initial_value(at_rule_id AtRuleID, descriptor_id DescriptorID) ?&dom.StyleValue {
	initial_value := descriptor_initial_value_text(at_rule_id, descriptor_id) or { return none }
	return parse_css_descriptor_for_cssom(at_rule_id, descriptor_id, initial_value)
}

fn descriptor_initial_value_text(at_rule_id AtRuleID, descriptor_id DescriptorID) ?string {
	return match at_rule_id {
		.page {
			match descriptor_id {
				.margin, .margin_top, .margin_right, .margin_bottom, .margin_left { '0' }
				.size { 'auto' }
				.page_orientation { 'upright' }
				.marks { 'none' }
				.bleed { 'auto' }
				.unknown, .custom, .result { none }
			}
		}
		.function_rule {
			none
		}
		else {
			none
		}
	}
}

// https://drafts.csswg.org/cssom/#serialize-a-css-declaration-block
pub fn (descriptors &CSSDescriptors) serialized() string {
	// 1. Let list be an empty array.
	mut list := []string{cap: descriptors.descriptors.len}

	// 2. Let already serialized be an empty array.
	// AD-HOC: Not needed as we don't have shorthands.

	// 3. Declaration loop: For each CSS declaration declaration in declaration block's declarations, follow these substeps:
	for descriptor in descriptors.descriptors {
		// 1. Let property be declaration's property name.
		property := descriptor.descriptor_name_and_id.name()

		// 2. If property is in already serialized, continue with the steps labeled declaration loop.
		// AD-HOC: Not needed as we don't have shorthands.

		// 3. If property maps to one or more shorthand properties, let shorthands be an array of those shorthand properties, in preferred order.
		// 4. Shorthand loop: For each shorthand in shorthands, follow these substeps: ...
		// NB: Descriptors can't be shorthands.

		// 5. Let value be the result of invoking serialize a CSS value of declaration.
		value := if descriptor.serialized_value.len != 0 {
			descriptor.serialized_value
		} else {
			descriptor_style_value_to_string(descriptor.value)
		}

		// 6. Let serialized declaration be the result of invoking serialize a CSS declaration with property name property, value value, and the important flag set if declaration has its important flag set.
		serialized_declaration := serialize_a_css_declaration(property, value, .no)

		// 7. Append serialized declaration to list.
		list << serialized_declaration

		// 8. Append property to already serialized.
		// AD-HOC: Not needed as we don't have shorthands.
	}

	// 4. Return list joined with " " (U+0020).
	return list.join(' ')
}

// https://drafts.csswg.org/cssom/#dom-cssstyledeclaration-csstext
pub fn (mut descriptors CSSDescriptors) set_css_text(value string) ! {
	// 1. If the readonly flag is set, then throw a NoModificationAllowedError exception.
	if descriptors.readonly {
		return error('NoModificationAllowedError: Cannot modify properties of readonly CSSStyleDeclaration')
	}

	descriptors.descriptors = parse_css_descriptor_declaration_block(ParsingParams{},
		descriptors.at_rule_id, value)
	descriptors.update_style_attribute()
}

fn (mut descriptors CSSDescriptors) update_style_attribute() {
	// Boundary: CSS descriptors are not reflected into an owner style attribute.
}

pub fn is_descriptor_shorthand(at_rule_id AtRuleID, descriptor_id DescriptorID) bool {
	if at_rule_id == .page && descriptor_id == .margin {
		return true
	}
	return false
}

pub fn for_each_expanded_descriptor_longhand(at_rule_id AtRuleID, descriptor_id DescriptorID, value &dom.StyleValue, callback fn (DescriptorID, &dom.StyleValue)) {
	if at_rule_id == .page && descriptor_id == .margin {
		if isnil(value) {
			callback(.margin_top, unsafe { nil })
			callback(.margin_right, unsafe { nil })
			callback(.margin_bottom, unsafe { nil })
			callback(.margin_left, unsafe { nil })
			return
		}
		// Boundary: non-null DOM StyleValue shorthand expansion needs typed ShorthandStyleValue plumbing.
	}
	callback(descriptor_id, value)
}

struct ExpandedDescriptorValue {
	descriptor_id    DescriptorID
	serialized_value string
}

fn expand_page_margin_shorthand_descriptor_value(value StyleValue) []ExpandedDescriptorValue {
	mut values := []StyleValue{}
	if value is StyleValueList {
		values = value.values()
	} else {
		values << value
	}

	if values.len == 0 {
		return []ExpandedDescriptorValue{}
	}

	top := values[0]
	right := if values.len > 1 { values[1] } else { values[0] }
	bottom := if values.len > 2 { values[2] } else { values[0] }
	left := if values.len > 3 { values[3] } else { right }

	return [
		ExpandedDescriptorValue{
			descriptor_id:    .margin_top
			serialized_value: top.serialize(.normal)
		},
		ExpandedDescriptorValue{
			descriptor_id:    .margin_right
			serialized_value: right.serialize(.normal)
		},
		ExpandedDescriptorValue{
			descriptor_id:    .margin_bottom
			serialized_value: bottom.serialize(.normal)
		},
		ExpandedDescriptorValue{
			descriptor_id:    .margin_left
			serialized_value: left.serialize(.normal)
		},
	]
}

pub fn parse_css_descriptor_declaration_block(parsing_params ParsingParams, at_rule_id AtRuleID, text string) []Descriptor {
	mut block := text.trim_space()
	if block.starts_with('{') && block.ends_with('}') {
		block = block[1..block.len - 1]
	}

	mut parser := RuleSelectorParser.create(parsing_params, block, 'utf-8')
	mut input := parser.token_stream
	mut declarations := []Descriptor{}

	for {
		input.discard_whitespace()
		if !input.has_next_token() {
			break
		}
		if input.next_token().is(.semicolon) {
			input.discard_a_token()
			continue
		}

		declaration := parser.consume_a_declaration(mut input, .no, .yes) or {
			parser.consume_the_remnants_of_a_bad_declaration(mut input, .no)
			continue
		}

		if at_rule_id == .page {
			descriptor_id := descriptor_id_from_string(.page, declaration.name) or { continue }
			value_text := parser_component_values_to_string(declaration.value).trim_space()
			value := parse_css_descriptor_value_for_cssom(.page, descriptor_id, value_text) or {
				continue
			}
			if descriptor_id == .margin {
				for expanded_value in expand_page_margin_shorthand_descriptor_value(value.style_value) {
					longhand_value := parse_css_descriptor_value_for_cssom(.page,
						expanded_value.descriptor_id, expanded_value.serialized_value) or {
						continue
					}
					append_descriptor(mut declarations, Descriptor{
						descriptor_name_and_id: DescriptorNameAndID.from_id(expanded_value.descriptor_id)
						value: longhand_value.value
						serialized_value: longhand_value.serialized
					})
				}
			} else {
				append_descriptor(mut declarations, Descriptor{
					descriptor_name_and_id: DescriptorNameAndID.from_id(descriptor_id)
					value: value.value
					serialized_value: value.serialized
				})
			}
		} else {
			descriptor_name_and_id := DescriptorNameAndID.from_name(at_rule_id, declaration.name) or {
				continue
			}
			value_text := parser_component_values_to_string(declaration.value).trim_space()
			value := parse_css_descriptor_value_for_cssom(at_rule_id, descriptor_name_and_id.id(),
				value_text) or {
				continue
			}
			append_descriptor(mut declarations, Descriptor{
				descriptor_name_and_id: descriptor_name_and_id
				value: value.value
				serialized_value: value.serialized
			})
		}
	}

	return declarations
}

@[heap]
pub struct CSSFunctionDescriptors {
pub mut:
	base CSSDescriptors
}

pub fn CSSFunctionDescriptors.create(descriptors []Descriptor) &CSSFunctionDescriptors {
	return &CSSFunctionDescriptors{
		base: CSSDescriptors{
			at_rule_id: .function_rule
			descriptors: descriptors.clone()
		}
	}
}

pub fn (descriptors &CSSFunctionDescriptors) result() string {
	return descriptors.base.get_property_value('result')
}

pub fn (mut descriptors CSSFunctionDescriptors) set_result(value string) ! {
	descriptors.base.set_property('result', value, '')!
}

@[heap]
pub struct CSSPageDescriptors {
pub mut:
	base CSSDescriptors
}

pub fn CSSPageDescriptors.create(descriptors []Descriptor) &CSSPageDescriptors {
	return &CSSPageDescriptors{
		base: CSSDescriptors{
			at_rule_id:  .page
			descriptors: descriptors.clone()
		}
	}
}

pub fn (mut page_descriptors CSSPageDescriptors) set_margin(value string) ! {
	page_descriptors.base.set_property('margin', value, '')!
}

pub fn (page_descriptors &CSSPageDescriptors) margin() string {
	return page_descriptors.base.get_property_value('margin')
}

pub fn (mut page_descriptors CSSPageDescriptors) set_margin_top(value string) ! {
	page_descriptors.base.set_property('margin-top', value, '')!
}

pub fn (page_descriptors &CSSPageDescriptors) margin_top() string {
	return page_descriptors.base.get_property_value('margin-top')
}

pub fn (mut page_descriptors CSSPageDescriptors) set_margin_right(value string) ! {
	page_descriptors.base.set_property('margin-right', value, '')!
}

pub fn (page_descriptors &CSSPageDescriptors) margin_right() string {
	return page_descriptors.base.get_property_value('margin-right')
}

pub fn (mut page_descriptors CSSPageDescriptors) set_margin_bottom(value string) ! {
	page_descriptors.base.set_property('margin-bottom', value, '')!
}

pub fn (page_descriptors &CSSPageDescriptors) margin_bottom() string {
	return page_descriptors.base.get_property_value('margin-bottom')
}

pub fn (mut page_descriptors CSSPageDescriptors) set_margin_left(value string) ! {
	page_descriptors.base.set_property('margin-left', value, '')!
}

pub fn (page_descriptors &CSSPageDescriptors) margin_left() string {
	return page_descriptors.base.get_property_value('margin-left')
}

pub fn (mut page_descriptors CSSPageDescriptors) set_size(value string) ! {
	page_descriptors.base.set_property('size', value, '')!
}

pub fn (page_descriptors &CSSPageDescriptors) size() string {
	return page_descriptors.base.get_property_value('size')
}

pub fn (mut page_descriptors CSSPageDescriptors) set_page_orientation(value string) ! {
	page_descriptors.base.set_property('page-orientation', value, '')!
}

pub fn (page_descriptors &CSSPageDescriptors) page_orientation() string {
	return page_descriptors.base.get_property_value('page-orientation')
}

pub fn (mut page_descriptors CSSPageDescriptors) set_marks(value string) ! {
	page_descriptors.base.set_property('marks', value, '')!
}

pub fn (page_descriptors &CSSPageDescriptors) marks() string {
	return page_descriptors.base.get_property_value('marks')
}

pub fn (mut page_descriptors CSSPageDescriptors) set_bleed(value string) ! {
	page_descriptors.base.set_property('bleed', value, '')!
}

pub fn (page_descriptors &CSSPageDescriptors) bleed() string {
	return page_descriptors.base.get_property_value('bleed')
}
