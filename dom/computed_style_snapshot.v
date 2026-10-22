module dom

import platform

// Rare DOM-facing values are immutable snapshots. Replacing the pointer keeps
// copied CSSComputedProperties_ values independent of later style updates.
pub struct CSSComputedPropertiesRareData {
pub:
	scrollbar_width      string = 'auto'
	view_transition_name ?string
	anchor_names         []string
	color_schemes        []string
}

__global empty_computed_properties_rare_data = CSSComputedPropertiesRareData{}

fn (c CSSComputedProperties_) rare_properties() &CSSComputedPropertiesRareData {
	data := c.rare_properties_
	if data == unsafe { nil } {
		return &empty_computed_properties_rare_data
	}
	return data
}

pub fn (c &CSSComputedProperties_) scrollbar_width() string {
	return c.rare_properties().scrollbar_width
}

fn own_computed_style_strings(values []string) []string {
	if values.len == 0 {
		return []string{}
	}
	mut owned := []string{len: values.len}
	for index, value in values {
		owned[index] = value.clone()
	}
	return owned
}

// Inputs may belong to a caller's mutable vector or temporary parser arena.
// Publish owned strings and vectors into the retained owner before returning.
pub fn (mut c CSSComputedProperties_) set_rare_properties(data CSSComputedPropertiesRareData) {
	if data.scrollbar_width == 'auto' && data.view_transition_name == none
		&& data.anchor_names.len == 0 && data.color_schemes.len == 0 {
		c.rare_properties_ = unsafe { nil }
		return
	}
	if c.rare_properties_ != unsafe { nil } && *c.rare_properties_ == data {
		return
	}
	mut retained := platform.enter_retained_allocations()
	defer { retained.finish() }
	name := if value := data.view_transition_name { ?string(value.clone()) } else { none }
	c.rare_properties_ = &CSSComputedPropertiesRareData{
		scrollbar_width:      if data.scrollbar_width == 'auto' {
			'auto'
		} else {
			data.scrollbar_width.clone()
		}
		view_transition_name: name
		anchor_names:         own_computed_style_strings(data.anchor_names)
		color_schemes:        own_computed_style_strings(data.color_schemes)
	}
}
