module css

import dom

pub enum ComputedDeclarationFlag {
	no
	yes
}

pub enum ReadonlyDeclarationFlag {
	no
	yes
}

pub fn PropertyNameAndID.from_id(property_id PropertyID) PropertyNameAndID {
	return PropertyNameAndID{
		name_: string_from_property_id(property_id)
		id_:   property_id
	}
}

pub fn string_from_property_id(property_id PropertyID) string {
	return match property_id {
		.animation_timeline { 'animation-timeline' }
		.color { 'color' }
		.color_scheme { 'color-scheme' }
		.content_visibility { 'content-visibility' }
	}
}

pub fn property_is_shorthand(property_id PropertyID) bool {
	_ = property_id
	return false
}

pub fn property_is_single_valued(property_id PropertyID) bool {
	_ = property_id
	return true
}

pub fn property_is_list_valued(property_id PropertyID) bool {
	_ = property_id
	return false
}

pub const number_of_longhand_properties = 3

pub fn first_longhand_property_id() PropertyID {
	return .color
}

pub fn last_longhand_property_id() PropertyID {
	return .content_visibility
}

fn property_id_from_longhand_index(index int) ?PropertyID {
	return match index {
		0 { PropertyID.color }
		1 { PropertyID.color_scheme }
		2 { PropertyID.content_visibility }
		else { none }
	}
}

fn css_style_declarations_is_valid_css_property(property string) bool {
	return property_id_from_string(property) != none || is_a_custom_property_name_string(property)
}

fn css_style_properties_empty_dom_style_value() &dom.StyleValue {
	return &dom.StyleValue{}
}

fn dom_style_value_to_css_text(value &dom.StyleValue) string {
	_ = value
	// Stub: dom.StyleValue is currently an opaque DOM-side placeholder in this V port.
	return ''
}

// https://drafts.csswg.org/cssom/#dom-cssstylerule-style
pub fn CSSStyleProperties.create_from_declarations(properties []StyleProperty, custom_properties map[string]StyleProperty) &CSSStyleProperties {
	// The style attribute must return a CSSStyleProperties object for the style rule, with the following properties:
	//     computed flag: Unset.
	//     readonly flag: Unset.
	//     declarations: The declared declarations in the rule, in specified order.
	//     parent CSS rule: The context object.
	//     owner node: Null.
	mut declaration := CSSStyleProperties.create()
	declaration.properties =
		css_style_properties_to_cssom_properties(convert_declarations_to_specified_order(properties))
	for name, property in custom_properties {
		declaration.custom_properties[name] = dom_style_value_to_css_text(property.value)
	}
	return declaration
}

// https://drafts.csswg.org/cssom/#dom-window-getcomputedstyle
pub fn CSSStyleProperties.create_resolved_style(element_reference ?dom.AbstractElement) &CSSStyleProperties {
	// 6. Return a live CSSStyleProperties object with the following properties:
	//    computed flag: Set.
	//    readonly flag: Set.
	//    declarations: decls.
	//    parent CSS rule: Null.
	//    owner node: obj.
	// AD-HOC: Rather than instantiate with a list of decls, they're generated on demand.
	mut declaration := CSSStyleProperties.create()
	declaration.computed = true
	declaration.readonly = true
	declaration.owner_node = element_reference
	return declaration
}

// https://drafts.csswg.org/cssom/#dom-elementcssinlinestyle-style
pub fn CSSStyleProperties.create_element_inline_style(element_reference dom.AbstractElement, properties []StyleProperty, custom_properties map[string]StyleProperty) &CSSStyleProperties {
	// The style attribute must return a CSS declaration block object whose readonly flag is unset, whose parent CSS
	// rule is null, and whose owner node is the context object.
	mut declaration := CSSStyleProperties.create_from_declarations(properties, custom_properties)
	declaration.owner_node = element_reference
	return declaration
}

fn css_style_properties_to_cssom_properties(properties []StyleProperty) []CSSStyleProperty {
	mut result := []CSSStyleProperty{}
	for property in properties {
		result << CSSStyleProperty{
			name:        string_from_property_id(property.property_id)
			value:       dom_style_value_to_css_text(property.value)
			important:   property.important == .yes
			style_value: unsafe { property.value }
		}
	}
	return result
}

// https://drafts.csswg.org/cssom/#concept-declarations-specified-order
pub fn convert_declarations_to_specified_order(declarations []StyleProperty) []StyleProperty {
	// The specified order for declarations is the same as specified, but with shorthand properties expanded into their
	// longhand properties, in canonical order. If a property is specified more than once (after shorthand expansion), only
	// the one with greatest cascading order must be represented, at the same relative position as it was specified.
	mut specified_order_declarations := []StyleProperty{}

	for declaration in declarations {
		StyleComputer.for_each_property_expanding_shorthands(declaration.property_id,
			declaration.value, fn [declaration, mut specified_order_declarations] (longhand_id PropertyID, longhand_property_value &dom.StyleValue) {
			mut existing_entry_index := ?int(none)
			for index, existing_declaration in specified_order_declarations {
				if existing_declaration.property_id == longhand_id {
					existing_entry_index = index
					break
				}
			}

			if index := existing_entry_index {
				// If there is an existing entry for this property and it is a higher cascading order than the current entry, skip the current entry.
				if specified_order_declarations[index].important == .yes
					&& declaration.important == .no {
					return
				}

				// Otherwise the existing entry has a lower cascading order and is removed.
				specified_order_declarations.delete(index)
			}

			specified_order_declarations << StyleProperty{
				important:   declaration.important
				property_id: longhand_id
				value:       unsafe { longhand_property_value }
			}
		})
	}

	return specified_order_declarations
}

pub fn (properties &CSSStyleProperties) is_computed() bool {
	return properties.computed
}

pub fn (properties &CSSStyleProperties) is_readonly() bool {
	return properties.readonly
}

pub fn (properties &CSSStyleProperties) owner_node() ?dom.AbstractElement {
	return properties.owner_node
}

pub fn (mut properties CSSStyleProperties) set_owner_node(owner_node ?dom.AbstractElement) {
	properties.owner_node = owner_node
}

pub fn (properties &CSSStyleProperties) is_updating() bool {
	return properties.updating
}

pub fn (mut properties CSSStyleProperties) set_is_updating(updating bool) {
	properties.updating = updating
}

// https://drafts.csswg.org/cssom/#update-style-attribute-for
pub fn (mut properties CSSStyleProperties) update_style_attribute() {
	// 1. Assert: declaration block's computed flag is unset.
	if properties.is_computed() {
		panic('VERIFY(!is_computed())')
	}

	// 2. Let owner node be declaration block's owner node.
	// 3. If owner node is null, then return.
	if properties.owner_node == none {
		return
	}

	// 4. Set declaration block's updating flag.
	properties.set_is_updating(true)

	// 5. Set an attribute value for owner node using "style" and the result of serializing declaration block.
	// Stub: the DOM AbstractElement V surface does not expose set_attribute_value on the contained element yet.

	// 6. Unset declaration block's updating flag.
	properties.set_is_updating(false)
}

// https://drafts.csswg.org/cssom/#dom-cssstyledeclaration-csstext
pub fn (properties &CSSStyleProperties) css_text() string {
	// 1. If the computed flag is set, then return the empty string.
	if properties.is_computed() {
		return ''
	}

	// 2. Return the result of serializing the declarations.
	return properties.serialized()
}

pub fn (properties &CSSStyleProperties) item(index usize) string {
	// The item(index) method must return the property name of the CSS declaration at position index.
	// If there is no indexth object in the collection, then the method must return the empty string.
	custom_properties_count := properties.custom_properties.len

	if int(index) >= properties.length() {
		return ''
	}

	if properties.is_computed() {
		if property_id := property_id_from_longhand_index(int(index)) {
			return string_from_property_id(property_id)
		}
		return ''
	}

	if int(index) < custom_properties_count {
		mut keys := properties.custom_properties.keys()
		keys.sort()
		return keys[index]
	}

	return properties.properties[int(index) - custom_properties_count].name
}

pub fn (properties &CSSStyleProperties) item_value(index usize) ?string {
	value := properties.item(index)
	if value.len == 0 {
		return none
	}
	return value
}

pub fn (properties &CSSStyleProperties) get_property(property_id PropertyID) ?StyleProperty {
	return properties.get_property_internal(PropertyNameAndID.from_id(property_id))
}

pub fn (properties &CSSStyleProperties) custom_property(custom_property_name string) ?StyleProperty {
	if properties.is_computed() {
		// Stub: computed custom property lookup requires DOM::Element custom_property_data().
		return none
	}

	if value := properties.custom_properties[custom_property_name] {
		return StyleProperty{
			property_id: .color
			value:       css_style_properties_empty_dom_style_value()
			important:   if value.to_lower().contains('!important') {
				Important.yes
			} else {
				Important.no
			}
		}
	}
	return none
}

// https://drafts.csswg.org/cssom/#dom-cssstyledeclaration-setproperty
pub fn (mut properties CSSStyleProperties) set_property(property_name string, value string, priority string) ! {
	// 1. If the computed flag is set, then throw a NoModificationAllowedError exception.
	if properties.is_computed() {
		return error('NoModificationAllowedError: Cannot modify properties in result of getComputedStyle()')
	}

	// 2. If property is not a custom property, follow these substeps:
	//    1. Let property be property converted to ASCII lowercase.
	//    2. If property is not a case-sensitive match for a supported CSS property, then return.
	// NB: This is handled inside PropertyNameAndID::from_string().
	property := PropertyNameAndID.from_name(property_name) or { return }

	// NB: The remaining steps are implemented in set_property_internal().
	properties.set_property_internal(property, value, priority)!
}

// https://drafts.csswg.org/cssom/#dom-cssstyledeclaration-setproperty
pub fn (mut properties CSSStyleProperties) set_property_internal(property PropertyNameAndID, value string, priority string) ! {
	// NB: Steps 1 and 2 only apply to the IDL method that invokes this.

	// 3. If value is the empty string, invoke removeProperty() with property as argument and return.
	if value.len == 0 {
		properties.remove_property_internal(property)!
		return
	}

	// 4. If priority is not the empty string and is not an ASCII case-insensitive match for the string "important", then return.
	if priority.len != 0 && priority.to_lower() != 'important' {
		return
	}

	// 5. Let component value list be the result of parsing value for property property.
	component_value_list := parse_css_value(ParsingParams{}, value, property.id() or {
		PropertyID.color
	}) or {
		// 6. If component value list is null, then return.
		return
	}

	// 7. Let updated be false.
	mut updated := false

	// 8. If property is a shorthand property,
	if property_is_shorthand(property.id() or { PropertyID.color }) {
		// then for each longhand property longhand that property maps to, in canonical order, follow these substeps:
		StyleComputer.for_each_property_expanding_shorthands(property.id() or { PropertyID.color },
			component_value_list, fn [priority, mut properties, mut updated] (longhand_property_id PropertyID, longhand_value &dom.StyleValue) {
			// 1. Let longhand result be the result of set the CSS declaration longhand with the appropriate value(s) from component value list,
			//    with the important flag set if priority is not the empty string, and unset otherwise, and with the list of declarations being the declarations.
			// 2. If longhand result is true, let updated be true.
			updated =
				properties.set_a_css_declaration(longhand_property_id, longhand_value, if priority.len != 0 { Important.yes } else { Important.no })
				|| updated
		})
	}
	// 9. Otherwise,
	else {
		if property.is_custom_property() {
			mut serialized := value
			if priority.len != 0 {
				serialized += ' !important'
			}
			properties.custom_properties[property.name()] = serialized
			updated = true
		} else {
			// let updated be the result of set the CSS declaration property with value component value list,
			// with the important flag set if priority is not the empty string, and unset otherwise,
			// and with the list of declarations being the declarations.
			updated = properties.set_a_css_declaration(property.id() or { PropertyID.color },
				component_value_list, if priority.len != 0 { Important.yes } else { Important.no })
		}
	}

	// 10. If updated is true, update style attribute for the CSS declaration block.
	if updated {
		properties.update_style_attribute()

		// Non-standard: Invalidate style for the owners of our containing sheet, if any.
		properties.invalidate_owners(.style_sheet_changed)
	}
}

pub fn (mut properties CSSStyleProperties) set_property_by_id(property_id PropertyID, css_text string, priority string) ! {
	properties.set_property_internal(PropertyNameAndID.from_id(property_id), css_text, priority)!
}

pub fn (mut properties CSSStyleProperties) set_a_css_declaration(property_id PropertyID, value &dom.StyleValue, important Important) bool {
	mut new_property := CSSStyleProperty{
		name:        string_from_property_id(property_id)
		value:       dom_style_value_to_css_text(value)
		important:   important == .yes
		style_value: unsafe { value }
	}

	for index, property in properties.properties {
		if property.name == new_property.name {
			if property.important == new_property.important && property.value == new_property.value {
				return false
			}
			properties.properties[index] = new_property
			return true
		}
	}

	properties.properties << new_property
	return true
}

pub fn (mut properties CSSStyleProperties) remove_property(property_name string) !string {
	property := PropertyNameAndID.from_name(property_name) or { return '' }
	return properties.remove_property_internal(property)!
}

pub fn (mut properties CSSStyleProperties) remove_property_internal(property PropertyNameAndID) !string {
	if properties.is_readonly() {
		return error('NoModificationAllowedError: Cannot modify readonly CSSStyleProperties')
	}

	mut removed_value := ''
	if property.is_custom_property() {
		if value := properties.custom_properties[property.name()] {
			removed_value = value
			properties.custom_properties.delete(property.name())
		}
	} else {
		property_name := string_from_property_id(property.id() or { PropertyID.color })
		for index, existing in properties.properties {
			if existing.name == property_name {
				removed_value = existing.value
				properties.properties.delete(index)
				break
			}
		}
	}

	if removed_value.len != 0 {
		properties.update_style_attribute()
		properties.invalidate_owners(.style_sheet_changed)
	}
	return removed_value
}

pub fn (mut properties CSSStyleProperties) set_css_text(css_text string) ! {
	if properties.is_readonly() {
		return error('NoModificationAllowedError: Cannot modify readonly CSSStyleProperties')
	}
	new_properties := parse_css_property_declaration_block_stub(css_text)
	properties.properties = new_properties.properties
	properties.custom_properties = new_properties.custom_properties.clone()
	properties.update_style_attribute()
	properties.invalidate_owners(.style_sheet_changed)
}

pub fn (properties &CSSStyleProperties) get_property_internal(property PropertyNameAndID) ?StyleProperty {
	if property.is_custom_property() {
		return properties.custom_property(property.name())
	}
	property_name := string_from_property_id(property.id() or { PropertyID.color })
	for existing in properties.properties {
		if existing.name == property_name {
			return StyleProperty{
				important:   if existing.important { Important.yes } else { Important.no }
				property_id: property.id() or { PropertyID.color }
				value:       existing.style_value or {
					css_style_properties_empty_dom_style_value()
				}
			}
		}
	}
	return none
}

pub fn (properties &CSSStyleProperties) get_property_style_value(property PropertyNameAndID) ?&dom.StyleValue {
	if style_property := properties.get_property_internal(property) {
		return style_property.value
	}
	return none
}

pub fn (properties &CSSStyleProperties) has_property(property PropertyNameAndID) bool {
	return properties.get_property_internal(property) != none
}

pub fn (properties &CSSStyleProperties) property_value(property_name string) string {
	property := PropertyNameAndID.from_name(property_name) or { return '' }
	if style_property := properties.get_property_internal(property) {
		return dom_style_value_to_css_text(style_property.value)
	}
	return ''
}

pub fn (properties &CSSStyleProperties) property_priority(property_name string) string {
	property := PropertyNameAndID.from_name(property_name) or { return '' }
	if style_property := properties.get_property_internal(property) {
		if style_property.important == .yes {
			return 'important'
		}
	}
	return ''
}

fn (properties &CSSStyleProperties) invalidate_owners(reason StyleInvalidationReason) {
	_ = properties
	_ = reason
	// Stub: StyleSheet owner invalidation and DOM style invalidation hooks are not fully connected in this V port yet.
}

@[heap]
pub struct StylePropertyMapReadOnly {
pub mut:
	element     ?dom.AbstractElement
	declaration ?&CSSStyleProperties
}

pub fn StylePropertyMapReadOnly.create_computed_style(element dom.AbstractElement) &StylePropertyMapReadOnly {
	return &StylePropertyMapReadOnly{
		element: element
	}
}

pub fn StylePropertyMapReadOnly.create_for_declaration(declaration &CSSStyleProperties) &StylePropertyMapReadOnly {
	return &StylePropertyMapReadOnly{
		declaration: declaration
	}
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-stylepropertymapreadonly-get
pub fn (mut property_map StylePropertyMapReadOnly) get(property_name string) ?CSSStyleValue {
	// The get(property) method, when called on a StylePropertyMapReadOnly this, must perform the following steps:

	// 1. If property is not a custom property name string, set property to property ASCII lowercased.
	// 2. If property is not a valid CSS property, throw a TypeError.
	property := PropertyNameAndID.from_name(property_name) or { return none }

	// 3. Let props be the value of this's [[declarations]] internal slot.
	// 4. If props[property] exists, subdivide into iterations props[property], then reify the first item of the result and return it.
	if property_value := property_map.get_style_value(property) {
		_ = property_value
		return CSSStyleValue.from_source(StyleValue(StubStyleValue.create(.unresolved,
			property.name())))
	}

	// 5. Otherwise, return undefined.
	return none
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-stylepropertymapreadonly-getall
pub fn (mut property_map StylePropertyMapReadOnly) get_all(property_name string) []CSSStyleValue {
	// The getAll(property) method, when called on a StylePropertyMap this, must perform the following steps:

	// 1. If property is not a custom property name string, set property to property ASCII lowercased.
	// 2. If property is not a valid CSS property, throw a TypeError.
	property := PropertyNameAndID.from_name(property_name) or { return []CSSStyleValue{} }

	// 3. Let props be the value of this's [[declarations]] internal slot.
	// 4. If props[property] exists, subdivide into iterations props[property], then reify each item of the result, and return the list.
	if property_value := property_map.get_style_value(property) {
		_ = property_value
		return [
			CSSStyleValue.from_source(StyleValue(StubStyleValue.create(.unresolved, property.name()))),
		]
	}

	// 5. Otherwise, return an empty list.
	return []CSSStyleValue{}
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-stylepropertymapreadonly-has
pub fn (mut property_map StylePropertyMapReadOnly) has(property_name string) bool {
	// The has(property) method, when called on a StylePropertyMapReadOnly this, must perform the following steps:

	// 1. If property is not a custom property name string, set property to property ASCII lowercased.
	// 2. If property is not a valid CSS property, throw a TypeError.
	property := PropertyNameAndID.from_name(property_name) or { return false }

	// 3. Let props be the value of this's [[declarations]] internal slot.
	// 4. If props[property] exists, return true. Otherwise, return false.
	if _ := property_map.element {
		// From https://drafts.css-houdini.org/css-typed-om-1/#dom-element-computedstylemap we need to include:
		// "the name and computed value of every longhand CSS property supported by the User Agent, every
		// registered custom property, and every non-registered custom property which is not set to its initial
		// value on this"
		// Stub: computed style maps expose all known longhand properties.
		return !property.is_custom_property()
	}
	if declaration := property_map.declaration {
		return declaration.has_property(property)
	}
	return false
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-stylepropertymapreadonly-size
pub fn (property_map &StylePropertyMapReadOnly) size() u32 {
	// The size attribute, on getting from a StylePropertyMapReadOnly this, must perform the following steps:

	// 1. Return the size of the value of this's [[declarations]] internal slot.
	if _ := property_map.element {
		// From https://drafts.css-houdini.org/css-typed-om-1/#dom-element-computedstylemap we need to include:
		// "the name and computed value of every longhand CSS property supported by the User Agent, every
		// registered custom property, and every non-registered custom property which is not set to its initial
		// value on this"
		return number_of_longhand_properties
	}
	if declaration := property_map.declaration {
		return u32(declaration.length())
	}
	return 0
}

pub fn (mut property_map StylePropertyMapReadOnly) get_style_value(property PropertyNameAndID) ?&dom.StyleValue {
	if _ := property_map.element {
		// Stub: computed property extraction from DOM::Element requires the style tree.
		if property.is_custom_property() {
			return none
		}
		return css_style_properties_empty_dom_style_value()
	}
	if declaration := property_map.declaration {
		return declaration.get_property_style_value(property)
	}
	return none
}

pub type MutableStylePropertyMapValue = CSSStyleValue | string

@[heap]
pub struct MutableStylePropertyMap {
pub mut:
	declaration &CSSStyleProperties = unsafe { nil }
}

pub fn MutableStylePropertyMap.create(declaration &CSSStyleProperties) &MutableStylePropertyMap {
	return &MutableStylePropertyMap{
		declaration: declaration
	}
}

fn any_have_non_matching_associated_property(property string, values []MutableStylePropertyMapValue) bool {
	for value in values {
		if value is CSSStyleValue {
			if associated_property := value.associated_property {
				if associated_property != property {
					return true
				}
			}
		}
	}
	return false
}

// https://drafts.css-houdini.org/css-typed-om-1/#create-an-internal-representation
fn create_an_internal_representation(property PropertyNameAndID, value MutableStylePropertyMapValue) !&dom.StyleValue {
	// To create an internal representation, given a string property and a string or CSSStyleValue value:
	return match value {
		CSSStyleValue {
			_ = value.create_an_internal_representation(property, .yes)!
			css_style_properties_empty_dom_style_value()
		}
		string {
			// If value is a USVString,
			//     Parse a CSSStyleValue with property property, cssText value, and parseMultiple set to false, and
			//     return the result.
			// FIXME: Avoid passing name as a string, as it gets immediately converted back to PropertyNameAndID.
			_ = CSSStyleValue.parse_a_css_style_value(property.name(), value, false)!
			// AD-HOC: Result is a CSSStyleValue but we want an internal representation, so... convert it again I guess?
			css_style_properties_empty_dom_style_value()
		}
	}
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-stylepropertymap-set
pub fn (mut property_map MutableStylePropertyMap) set(property_name string, values []MutableStylePropertyMapValue) ! {
	// The set(property, ...values) method, when called on a StylePropertyMap this, must perform the following steps:

	// 1. If property is not a custom property name string, set property to property ASCII lowercased.
	// 2. If property is not a valid CSS property, throw a TypeError.
	property := PropertyNameAndID.from_name(property_name) or {
		return error("'${property_name}' is not a valid CSS property")
	}

	// 3. If property is a single-valued property and values has more than one item, throw a TypeError.
	// NB: Custom properties should all be single-valued.
	if (property.is_custom_property() || property_is_single_valued(property.id() or {
		PropertyID.color
	})) && values.len > 1 {
		return error("Property '${property_name}' only accepts a single value")
	}

	// 4. If any of the items in values have a non-null [[associatedProperty]] internal slot, and that slot's value is
	//    anything other than property, throw a TypeError.
	if any_have_non_matching_associated_property(property.name(), values) {
		return error('One of the passed CSSStyleValues has a different associated property')
	}

	// 5. If the size of values is two or more, and one or more of the items are a CSSUnparsedValue or
	//    CSSVariableReferenceValue object, throw a TypeError.
	// FIXME: This is done as part of step 9, because we need to detect if a string value would be an CSSUnparsedValue
	//        or CSSVariableReferenceValue. Spec issue: https://github.com/w3c/css-houdini-drafts/issues/1157

	// 6. Let props be the value of this's [[declarations]] internal slot.
	mut props := unsafe { &CSSStyleProperties(property_map.declaration) }

	// 7. If props[property] exists, remove it.
	props.remove_property(property.name())!

	// 8. Let values to set be an empty list.
	mut values_to_set := []&dom.StyleValue{}

	// 9. For each value in values, create an internal representation for property and value, and append the result to values to set.
	for value in values {
		internal_representation := create_an_internal_representation(property, value)!
		values_to_set << internal_representation
	}

	// 10. Set props[property] to values to set.
	// NOTE: The property is deleted then added back so that it gets put at the end of the ordered map, which gives the
	//       expected behavior in the face of shorthand properties.
	if values_to_set.len == 1 {
		props.set_a_css_declaration(property.id() or { PropertyID.color }, values_to_set[0], .no)
	} else {
		props.set_a_css_declaration(property.id() or { PropertyID.color },
			css_style_properties_empty_dom_style_value(), .no)
	}
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-stylepropertymap-append
pub fn (mut property_map MutableStylePropertyMap) append(property_name string, values []MutableStylePropertyMapValue) ! {
	// The append(property, ...values) method, when called on a StylePropertyMap this, must perform the following steps:

	// 1. If property is not a custom property name string, set property to property ASCII lowercased.
	// 2. If property is not a valid CSS property, throw a TypeError.
	property := PropertyNameAndID.from_name(property_name) or {
		return error("'${property_name}' is not a valid CSS property")
	}

	// 3. If property is not a list-valued property, throw a TypeError.
	if !property_is_list_valued(property.id() or { PropertyID.color }) {
		return error("'${property_name}' is not a list-valued property")
	}

	// 4. If any of the items in values have a non-null [[associatedProperty]] internal slot, and that slot's value is
	//    anything other than property, throw a TypeError.
	if any_have_non_matching_associated_property(property.name(), values) {
		return error('One of the passed CSSStyleValues has a different associated property')
	}

	// 5. If any of the items in values are a CSSUnparsedValue or CSSVariableReferenceValue object, throw a TypeError.
	// FIXME: This is done as part of step 10, because we need to detect if a string value would be an CSSUnparsedValue
	//        or CSSVariableReferenceValue. Spec issue: https://github.com/w3c/css-houdini-drafts/issues/1157

	// 6. Let props be the value of this's [[declarations]] internal slot.
	mut props := unsafe { &CSSStyleProperties(property_map.declaration) }

	// 7. If props[property] does not exist, set props[property] to an empty list.
	// 8. If props[property] contains a var() reference, throw a TypeError.
	// 9. Let temp values be an empty list.
	mut value_list := []&dom.StyleValue{}
	if existing_value := props.get_property_style_value(property) {
		value_list << existing_value
	}

	// 10. For each value in values, create an internal representation with property and value, and append the returned value to temp values.
	for value in values {
		value_list << create_an_internal_representation(property, value)!
	}

	// 11. Append the entries of temp values to props[property].
	props.set_a_css_declaration(property.id() or { PropertyID.color },
		css_style_properties_empty_dom_style_value(), .no)
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-stylepropertymap-delete
pub fn (mut property_map MutableStylePropertyMap) delete_(property string) ! {
	// The delete(property) method, when called on a StylePropertyMap this, must perform the following steps:

	// 1. If property is not a custom property name string, set property to property ASCII lowercased.
	mut property_name := property
	if !is_a_custom_property_name_string(property_name) {
		property_name = property_name.to_lower()
	}

	// 2. If property is not a valid CSS property, throw a TypeError.
	if !css_style_declarations_is_valid_css_property(property_name) {
		return error("'${property_name}' is not a valid CSS property")
	}

	// 3. If this's [[declarations]] internal slot contains property, remove it.
	mut props := unsafe { &CSSStyleProperties(property_map.declaration) }
	props.remove_property(property_name)!
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-stylepropertymap-clear
pub fn (mut property_map MutableStylePropertyMap) clear() ! {
	// The clear() method, when called on a StylePropertyMap this, must perform the following steps:

	// 1. Remove all of the declarations in this's [[declarations]] internal slot.
	mut props := unsafe { &CSSStyleProperties(property_map.declaration) }
	props.set_css_text('')!
}
