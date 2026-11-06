module css

import dom

// These stores are independent: recording an inherited font-relative value
// must not allocate animation or font-variation maps for an ordinary style.
@[heap]
struct ComputedPropertyValueMap {
mut:
	values map[PropertyID]&dom.StyleValue
}

@[heap]
struct ComputedCustomPropertyValueMap {
mut:
	values map[string]&dom.StyleValue
}

@[heap]
struct ComputedFontVariationMap {
mut:
	values map[string]f64
}

fn (mut c ComputedProperties) ensure_animated_property_storage() &ComputedPropertyValueMap {
	if c.animated_property_storage_ == unsafe { nil } {
		c.animated_property_storage_ = &ComputedPropertyValueMap{
			values: map[PropertyID]&dom.StyleValue{}
		}
	}
	return c.animated_property_storage_
}

fn (mut c ComputedProperties) ensure_animated_custom_storage() &ComputedCustomPropertyValueMap {
	if c.animated_custom_storage_ == unsafe { nil } {
		c.animated_custom_storage_ = &ComputedCustomPropertyValueMap{
			values: map[string]&dom.StyleValue{}
		}
	}
	return c.animated_custom_storage_
}

fn (mut c ComputedProperties) ensure_inheritance_specified_storage() &ComputedPropertyValueMap {
	if c.inheritance_specified_storage_ == unsafe { nil } {
		c.inheritance_specified_storage_ = &ComputedPropertyValueMap{
			values: map[PropertyID]&dom.StyleValue{}
		}
	}
	return c.inheritance_specified_storage_
}

fn (mut c ComputedProperties) ensure_font_variation_storage() &ComputedFontVariationMap {
	if c.font_variation_storage_ == unsafe { nil } {
		c.font_variation_storage_ = &ComputedFontVariationMap{
			values: map[string]f64{}
		}
	}
	return c.font_variation_storage_
}

pub fn (c &ComputedProperties) has_animated_properties() bool {
	return c.animated_property_storage_ != unsafe { nil }
		&& c.animated_property_storage_.values.len > 0
}

pub fn (c &ComputedProperties) has_animated_property(property_id PropertyID) bool {
	return c.animated_property_storage_ != unsafe { nil }
		&& property_id in c.animated_property_storage_.values
}

// Inspect the live store without cloning a map or borrowing a sample value.
// Custom properties live in their own store and are queried separately.
pub fn (c &ComputedProperties) has_only_animated_property(property_id PropertyID) bool {
	return c.animated_property_storage_ != unsafe { nil }
		&& c.animated_property_storage_.values.len == 1
		&& property_id in c.animated_property_storage_.values
}

pub fn (c &ComputedProperties) animated_property_value(property_id PropertyID) ?&dom.StyleValue {
	if !c.has_animated_property(property_id) {
		return none
	}
	return unsafe { c.animated_property_storage_.values[property_id] }
}

pub fn (c &ComputedProperties) has_animated_custom_properties() bool {
	return c.animated_custom_storage_ != unsafe { nil }
		&& c.animated_custom_storage_.values.len > 0
}

fn (c &ComputedProperties) animated_custom_property_value(name string) ?&dom.StyleValue {
	if c.animated_custom_storage_ == unsafe { nil }
		|| name !in c.animated_custom_storage_.values {
		return none
	}
	return unsafe { c.animated_custom_storage_.values[name] }
}
