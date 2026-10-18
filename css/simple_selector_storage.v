module css

// Construction boundary for callers that provide more than one old field.
// The common parser constructors below retain one by-value union arm without
// allocating. A multi-field record owns an immutable compatibility snapshot.
pub struct SimpleSelectorInit {
pub mut:
	type_          SimpleSelectorType
	name           SelectorName
	qualified_name SelectorQualifiedName
	attribute      SelectorAttribute
	pseudo_class   PseudoClassSelector
	pseudo_element PseudoElementSelector
	invalid_text   string
}

enum SimpleSelectorPayloadKind {
	empty
	name
	qualified_name
	attribute
	pseudo_class
	pseudo_element
	invalid_text
	expanded
}

union SimpleSelectorPayload {
mut:
	name           SelectorName
	qualified_name SelectorQualifiedName
	attribute      SelectorAttribute
	pseudo_class   PseudoClassSelector
	pseudo_element PseudoElementSelector
	invalid_text   string
	expanded       &SimpleSelectorInit = unsafe { nil }
}

fn (mut selector SimpleSelector) clear_payload(kind SimpleSelectorPayloadKind) {
	// Clear the full storage before changing arms: inactive bytes must not keep
	// managed objects from a previous larger payload alive conservatively.
	unsafe { vmemset(&selector.payload_, 0, sizeof(SimpleSelectorPayload)) }
	selector.payload_kind_ = kind
}

pub fn SimpleSelector.with_name(type_ SimpleSelectorType, value SelectorName) SimpleSelector {
	mut selector := SimpleSelector{ type_: type_ }
	selector.clear_payload(.name)
	unsafe { selector.payload_.name = value }
	return selector
}

pub fn (selector &SimpleSelector) name() SelectorName {
	if selector.payload_kind_ == .name { return unsafe { selector.payload_.name } }
	if selector.payload_kind_ == .expanded { return unsafe { selector.payload_.expanded.name } }
	return SelectorName{}
}

pub fn SimpleSelector.with_qualified_name(type_ SimpleSelectorType, value SelectorQualifiedName) SimpleSelector {
	mut selector := SimpleSelector{ type_: type_ }
	selector.clear_payload(.qualified_name)
	unsafe { selector.payload_.qualified_name = value }
	return selector
}

pub fn (selector &SimpleSelector) qualified_name() SelectorQualifiedName {
	if selector.payload_kind_ == .qualified_name {
		return unsafe { selector.payload_.qualified_name }
	}
	if selector.payload_kind_ == .expanded {
		return unsafe { selector.payload_.expanded.qualified_name }
	}
	return SelectorQualifiedName{}
}

pub fn SimpleSelector.with_attribute(type_ SimpleSelectorType, value SelectorAttribute) SimpleSelector {
	mut selector := SimpleSelector{ type_: type_ }
	selector.clear_payload(.attribute)
	unsafe { selector.payload_.attribute = value }
	return selector
}

pub fn (selector &SimpleSelector) attribute() SelectorAttribute {
	if selector.payload_kind_ == .attribute { return unsafe { selector.payload_.attribute } }
	if selector.payload_kind_ == .expanded {
		return unsafe { selector.payload_.expanded.attribute }
	}
	return SelectorAttribute{}
}

pub fn SimpleSelector.with_pseudo_class(type_ SimpleSelectorType, value PseudoClassSelector) SimpleSelector {
	mut selector := SimpleSelector{ type_: type_ }
	selector.clear_payload(.pseudo_class)
	unsafe { selector.payload_.pseudo_class = value }
	return selector
}

pub fn (selector &SimpleSelector) pseudo_class() PseudoClassSelector {
	if selector.payload_kind_ == .pseudo_class { return unsafe { selector.payload_.pseudo_class } }
	if selector.payload_kind_ == .expanded {
		return unsafe { selector.payload_.expanded.pseudo_class }
	}
	return PseudoClassSelector{}
}

pub fn SimpleSelector.with_pseudo_element(type_ SimpleSelectorType, value PseudoElementSelector) SimpleSelector {
	mut selector := SimpleSelector{ type_: type_ }
	selector.clear_payload(.pseudo_element)
	unsafe { selector.payload_.pseudo_element = value }
	return selector
}

pub fn (selector &SimpleSelector) pseudo_element() PseudoElementSelector {
	if selector.payload_kind_ == .pseudo_element {
		return unsafe { selector.payload_.pseudo_element }
	}
	if selector.payload_kind_ == .expanded {
		return unsafe { selector.payload_.expanded.pseudo_element }
	}
	return PseudoElementSelector{}
}

pub fn SimpleSelector.with_invalid_text(type_ SimpleSelectorType, value string) SimpleSelector {
	mut selector := SimpleSelector{ type_: type_ }
	selector.clear_payload(.invalid_text)
	unsafe { selector.payload_.invalid_text = value }
	return selector
}

pub fn (selector &SimpleSelector) invalid_text() string {
	if selector.payload_kind_ == .invalid_text { return unsafe { selector.payload_.invalid_text } }
	if selector.payload_kind_ == .expanded {
		return unsafe { selector.payload_.expanded.invalid_text }
	}
	return ''
}

pub fn SimpleSelector.create(fields SimpleSelectorInit) SimpleSelector {
	mut populated := 0
	if fields.name != SelectorName{} { populated++ }
	if fields.qualified_name != SelectorQualifiedName{} { populated++ }
	if fields.attribute != SelectorAttribute{} { populated++ }
	if fields.pseudo_class != PseudoClassSelector{} { populated++ }
	if fields.pseudo_element != PseudoElementSelector{} { populated++ }
	if fields.invalid_text != '' { populated++ }
	if populated == 0 { return SimpleSelector{ type_: fields.type_ } }
	if populated == 1 {
		if fields.name != SelectorName{} {
			return SimpleSelector.with_name(fields.type_, fields.name)
		}
		if fields.qualified_name != SelectorQualifiedName{} {
			return SimpleSelector.with_qualified_name(fields.type_, fields.qualified_name)
		}
		if fields.attribute != SelectorAttribute{} {
			return SimpleSelector.with_attribute(fields.type_, fields.attribute)
		}
		if fields.pseudo_class != PseudoClassSelector{} {
			return SimpleSelector.with_pseudo_class(fields.type_, fields.pseudo_class)
		}
		if fields.pseudo_element != PseudoElementSelector{} {
			return SimpleSelector.with_pseudo_element(fields.type_, fields.pseudo_element)
		}
		if fields.invalid_text != '' {
			return SimpleSelector.with_invalid_text(fields.type_, fields.invalid_text)
		}
	}
	mut selector := SimpleSelector{ type_: fields.type_ }
	selector.clear_payload(.expanded)
	unsafe { selector.payload_.expanded = &SimpleSelectorInit{ ...fields } }
	return selector
}

pub fn (selector &SimpleSelector) fields() SimpleSelectorInit {
	return SimpleSelectorInit{
		type_:          selector.type_
		name:           selector.name()
		qualified_name: selector.qualified_name()
		attribute:      selector.attribute()
		pseudo_class:   selector.pseudo_class()
		pseudo_element: selector.pseudo_element()
		invalid_text:   selector.invalid_text()
	}
}

pub fn (mut selector SimpleSelector) set_name(value SelectorName) {
	if selector.payload_kind_ in [.empty, .name] {
		selector.clear_payload(.name)
		unsafe { selector.payload_.name = value }
		return
	}
	mut fields := selector.fields()
	fields.name = value
	selector = SimpleSelector.create(fields)
}

pub fn (mut selector SimpleSelector) set_qualified_name(value SelectorQualifiedName) {
	if selector.payload_kind_ in [.empty, .qualified_name] {
		selector.clear_payload(.qualified_name)
		unsafe { selector.payload_.qualified_name = value }
		return
	}
	mut fields := selector.fields()
	fields.qualified_name = value
	selector = SimpleSelector.create(fields)
}

pub fn (mut selector SimpleSelector) set_attribute(value SelectorAttribute) {
	if selector.payload_kind_ in [.empty, .attribute] {
		selector.clear_payload(.attribute)
		unsafe { selector.payload_.attribute = value }
		return
	}
	mut fields := selector.fields()
	fields.attribute = value
	selector = SimpleSelector.create(fields)
}

pub fn (mut selector SimpleSelector) set_pseudo_class(value PseudoClassSelector) {
	if selector.payload_kind_ in [.empty, .pseudo_class] {
		selector.clear_payload(.pseudo_class)
		unsafe { selector.payload_.pseudo_class = value }
		return
	}
	mut fields := selector.fields()
	fields.pseudo_class = value
	selector = SimpleSelector.create(fields)
}

pub fn (mut selector SimpleSelector) set_pseudo_element(value PseudoElementSelector) {
	if selector.payload_kind_ in [.empty, .pseudo_element] {
		selector.clear_payload(.pseudo_element)
		unsafe { selector.payload_.pseudo_element = value }
		return
	}
	mut fields := selector.fields()
	fields.pseudo_element = value
	selector = SimpleSelector.create(fields)
}

pub fn (mut selector SimpleSelector) set_invalid_text(value string) {
	if selector.payload_kind_ in [.empty, .invalid_text] {
		selector.clear_payload(.invalid_text)
		unsafe { selector.payload_.invalid_text = value }
		return
	}
	mut fields := selector.fields()
	fields.invalid_text = value
	selector = SimpleSelector.create(fields)
}

pub fn (a SimpleSelector) == (b SimpleSelector) bool {
	return a.fields() == b.fields()
}
