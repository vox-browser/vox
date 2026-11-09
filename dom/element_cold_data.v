module dom

// These uncommon groups are immutable after publication. Arrays are cloned by
// their mutators; referenced DOM/CSS objects retain their existing live identity.
@[heap]
struct ElementCustomData {
mut:
	reactions  []CustomElementReaction
	definition ?&CustomElementDefinition
	is_value   ?string
	state_set  ?&CustomStateSet
}

@[heap]
struct ElementDependencyData {
mut:
	intersection_observers []voidptr
	computed_style_map     ?&StylePropertyMapReadOnly_
	removed_attributes     []string
	svg_boxes              []&Element
	svg_paint              []&Element
}

@[heap]
struct ElementBindingData {
mut:
	cryptographic_nonce string
	uppercased_name           ?string
	attribute_style_map       ?&StylePropertyMap_
	part_list                 ?&DOMTokenList
	parts                     []string
	associated_pseudo_element ?int
}

fn (e &Element) copy_custom_data() &ElementCustomData {
	if e.custom_data_ == unsafe { nil } { return &ElementCustomData{} }
	old := e.custom_data_
	return &ElementCustomData{
		reactions:  old.reactions
		definition: old.definition
		is_value:   old.is_value
		state_set:  old.state_set
	}
}

fn (e &Element) copy_dependency_data() &ElementDependencyData {
	if e.dependency_data_ == unsafe { nil } { return &ElementDependencyData{} }
	old := e.dependency_data_
	return &ElementDependencyData{
		intersection_observers: old.intersection_observers
		computed_style_map:     old.computed_style_map
		removed_attributes:     old.removed_attributes
		svg_boxes:              old.svg_boxes
		svg_paint:              old.svg_paint
	}
}

fn (e &Element) copy_binding_data() &ElementBindingData {
	if e.binding_data_ == unsafe { nil } { return &ElementBindingData{} }
	old := e.binding_data_
	return &ElementBindingData{
		uppercased_name:           old.uppercased_name
		attribute_style_map:       old.attribute_style_map
		part_list:                 old.part_list
		parts:                     old.parts
		associated_pseudo_element: old.associated_pseudo_element
		cryptographic_nonce: old.cryptographic_nonce
	}
}

fn (e &Element) cached_uppercase_name() ?string {
	if e.binding_data_ == unsafe { nil } { return none }
	return e.binding_data_.uppercased_name
}

fn (e &Element) cached_part_list() ?&DOMTokenList {
	if e.binding_data_ == unsafe { nil } { return none }
	return e.binding_data_.part_list
}

fn (e &Element) cached_attribute_style_map() ?&StylePropertyMap_ {
	if e.binding_data_ == unsafe { nil } { return none }
	return e.binding_data_.attribute_style_map
}

fn (e &Element) element_parts() []string {
	if e.binding_data_ == unsafe { nil } { return []string{} }
	return e.binding_data_.parts
}

pub fn (e &Element) has_part_names() bool {
	return e.element_parts().len > 0
}

fn (mut e Element) set_element_parts(parts []string) {
	if parts.len == 0 && !e.has_part_names() { return }
	mut state := e.copy_binding_data()
	state.parts = parts.clone()
	e.binding_data_ = state
}

fn (e &Element) intersection_observers() []voidptr {
	if e.dependency_data_ == unsafe { nil } { return []voidptr{} }
	return e.dependency_data_.intersection_observers
}

fn (e &Element) cached_computed_style_map() ?&StylePropertyMapReadOnly_ {
	if e.dependency_data_ == unsafe { nil } { return none }
	return e.dependency_data_.computed_style_map
}

pub fn (e &Element) removed_attribute_names_for_style_invalidation() []string {
	if e.dependency_data_ == unsafe { nil } { return []string{} }
	return e.dependency_data_.removed_attributes.clone()
}

fn (e &Element) removed_attribute_names() []string {
	if e.dependency_data_ == unsafe { nil } { return []string{} }
	return e.dependency_data_.removed_attributes
}

fn (e &Element) svg_box_references() []&Element {
	if e.dependency_data_ == unsafe { nil } { return []&Element{} }
	return e.dependency_data_.svg_boxes
}

fn (e &Element) svg_paint_references() []&Element {
	if e.dependency_data_ == unsafe { nil } { return []&Element{} }
	return e.dependency_data_.svg_paint
}
