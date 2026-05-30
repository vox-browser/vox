module css

import dom

// --- CustomPropertyData ---

const custom_property_data_max_ancestor_count = 32
const custom_property_data_absorb_threshold = 8

pub type StylePropertyMap = map[string]StyleProperty

// Chain of custom property maps with structural sharing.
// Each node stores only the properties declared directly on its element,
// with a parent pointer to the inherited chain.
@[heap]
pub struct CustomPropertyData {
pub mut:
	own_values_     StylePropertyMap
	parent_         ?&CustomPropertyData
	ancestor_count_ u8
}

pub fn CustomPropertyData.create(own_values StylePropertyMap, parent ?&CustomPropertyData) &CustomPropertyData {
	mut own_values_copy := own_values.clone()
	if parent == none {
		return &CustomPropertyData{
			own_values_: own_values_copy
		}
	}

	parent_data := parent

	// If parent chain is too deep, flatten by copying all ancestor values into own.
	if parent_data.ancestor_count_ >= custom_property_data_max_ancestor_count - 1 {
		parent_data.for_each_property(fn [mut own_values_copy] (name string, property StyleProperty) {
			if name !in own_values_copy {
				own_values_copy[name] = property
			}
		})
		return &CustomPropertyData{
			own_values_: own_values_copy
		}
	}

	// If parent has few own values, absorb them to shorten the chain.
	if parent_data.own_values_.len <= custom_property_data_absorb_threshold {
		for name, property in parent_data.own_values_ {
			if name !in own_values_copy {
				own_values_copy[name] = property
			}
		}
		grandparent := parent_data.parent_
		ancestor_count := if gp := grandparent { gp.ancestor_count_ + 1 } else { u8(0) }
		return &CustomPropertyData{
			own_values_:     own_values_copy
			parent_:         grandparent
			ancestor_count_: ancestor_count
		}
	}

	ancestor_count := parent_data.ancestor_count_ + 1
	return &CustomPropertyData{
		own_values_:     own_values_copy
		parent_:         parent_data
		ancestor_count_: ancestor_count
	}
}

pub fn (c &CustomPropertyData) get(name string) ?StyleProperty {
	if name in c.own_values_ {
		return c.own_values_[name] or { return none }
	}
	if parent := c.parent_ {
		return parent.get(name)
	}
	return none
}

pub fn (c &CustomPropertyData) own_values() StylePropertyMap {
	return c.own_values_
}

pub fn (c &CustomPropertyData) for_each_property(callback fn (string, StyleProperty)) {
	mut seen := map[string]bool{}
	mut current := ?&CustomPropertyData(c)
	for {
		node := current or { break }
		for name, property in node.own_values_ {
			if name in seen {
				continue
			}
			seen[name] = true
			callback(name, property)
		}
		current = node.parent_
	}
}

pub fn (c &CustomPropertyData) parent() ?&CustomPropertyData {
	return c.parent_
}

pub fn (c &CustomPropertyData) is_empty() bool {
	if c.own_values_.len != 0 {
		return false
	}
	if parent := c.parent_ {
		return parent.is_empty()
	}
	return true
}

// --- CascadedProperties ---

pub enum CascadeOrigin {
	user_agent
	user
	author
	transition
	animation
}

pub struct CascadedPropertiesEntry {
pub mut:
	property   StyleProperty
	origin     CascadeOrigin
	layer_name ?string
	source     voidptr
}

@[heap]
pub struct CascadedProperties {
pub mut:
	properties_                 map[PropertyID][]CascadedPropertiesEntry
	contained_properties_cache_ map[PropertyID]bool
}

pub fn CascadedProperties.new() &CascadedProperties {
	return &CascadedProperties{}
}

pub fn (mut c CascadedProperties) visit_edges() {
	// Base::visit_edges(visitor);
	// for each entry: visitor.visit(entry.source);
}

pub fn (mut c CascadedProperties) revert_property(property_id PropertyID, important Important, cascade_origin CascadeOrigin) {
	if property_id !in c.properties_ {
		return
	}
	mut entries := c.properties_[property_id] or { return }
	mut filtered := []CascadedPropertiesEntry{}
	for entry in entries {
		if entry.property.property_id == property_id && entry.property.important == important
			&& cascade_origin == entry.origin {
			continue
		}
		filtered << entry
	}
	if filtered.len == 0 {
		c.contained_properties_cache_[property_id] = false
		c.properties_.delete(property_id)
		return
	}
	c.properties_[property_id] = filtered
}

pub fn (mut c CascadedProperties) revert_layer_property(property_id PropertyID, important Important, layer_name ?string) {
	if property_id !in c.properties_ {
		return
	}
	mut entries := c.properties_[property_id] or { return }
	mut filtered := []CascadedPropertiesEntry{}
	for entry in entries {
		if entry.property.property_id == property_id && entry.property.important == important
			&& entry.layer_name == layer_name {
			continue
		}
		filtered << entry
	}
	if filtered.len == 0 {
		c.contained_properties_cache_[property_id] = false
		c.properties_.delete(property_id)
		return
	}
	c.properties_[property_id] = filtered
}

pub fn (mut c CascadedProperties) resolve_unresolved_properties(abstract_element &dom.AbstractElement) {
	_ = abstract_element
	// Parser::Parser::resolve_unresolved_style_value is not translated yet.
}

pub fn (mut c CascadedProperties) set_property(property_id PropertyID, value &dom.StyleValue, important Important, origin CascadeOrigin, layer_name ?string, source voidptr) {
	c.contained_properties_cache_[property_id] = true

	mut entries := c.properties_[property_id] or { []CascadedPropertiesEntry{} }
	for index := entries.len - 1; index >= 0; index-- {
		mut entry := entries[index]
		if entry.origin == origin && entry.layer_name == layer_name {
			if entry.property.important == .yes && important == .no {
				return
			}
			entry.property = StyleProperty{
				important:   important
				property_id: property_id
				value:       unsafe { value }
			}
			entries[index] = entry
			c.properties_[property_id] = entries
			return
		}
	}

	entries << CascadedPropertiesEntry{
		property:   StyleProperty{
			important:   important
			property_id: property_id
			value:       unsafe { value }
		}
		origin:     origin
		layer_name: layer_name
		source:     source
	}
	c.properties_[property_id] = entries
}

pub fn (mut c CascadedProperties) set_property_from_presentational_hint(property_id PropertyID, value &dom.StyleValue) {
	// StyleComputer::for_each_property_expanding_shorthands is not translated yet; keep the longhand path.
	c.contained_properties_cache_[property_id] = true
	mut entries := c.properties_[property_id] or { []CascadedPropertiesEntry{} }
	entries << CascadedPropertiesEntry{
		property:   StyleProperty{
			important:   .no
			property_id: property_id
			value:       unsafe { value }
		}
		origin:     .author
		layer_name: none
		source:     unsafe { nil }
	}
	c.properties_[property_id] = entries
}

pub fn (c &CascadedProperties) property(property_id PropertyID) ?&dom.StyleValue {
	if property_id !in c.contained_properties_cache_ || !c.contained_properties_cache_[property_id] {
		return none
	}
	entries := c.properties_[property_id] or { return none }
	if entries.len == 0 {
		return none
	}
	return entries[entries.len - 1].property.value
}

pub fn (c &CascadedProperties) property_source(property_id PropertyID) voidptr {
	if property_id !in c.contained_properties_cache_ || !c.contained_properties_cache_[property_id] {
		return unsafe { nil }
	}
	entries := c.properties_[property_id] or { return unsafe { nil } }
	if entries.len == 0 {
		return unsafe { nil }
	}
	return entries[entries.len - 1].source
}

pub fn (c &CascadedProperties) style_property(property_id PropertyID) ?StyleProperty {
	if property_id !in c.contained_properties_cache_ || !c.contained_properties_cache_[property_id] {
		return none
	}
	entries := c.properties_[property_id] or { return none }
	if entries.len == 0 {
		return none
	}
	return entries[entries.len - 1].property
}
