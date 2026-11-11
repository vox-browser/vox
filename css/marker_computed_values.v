// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause

module css

// A marker nested in ::before or ::after starts with the host marker's
// computed values, but owns the mutable stores that layout or animation can
// replace. Anonymous-box cloning would reset non-inherited marker values.
pub fn (source &ComputedProperties) clone_for_nested_marker() &ComputedProperties {
	source.share_computed_layout_cache()
	note_computed_values_created()
	mut clone := &ComputedProperties{
		...source
		property_store_: source.clone_raw_property_store()
		computed_property_graph_token_: &ComputedPropertyGraphMutationToken{}
		device_layout_projection_: unsafe { nil }
		layout_cache_owner_serial_: 0
		animated_property_storage_: unsafe { nil }
		animated_custom_storage_: unsafe { nil }
		inheritance_specified_storage_: unsafe { nil }
		font_variation_storage_: unsafe { nil }
	}
	if source.animated_property_storage_ != unsafe { nil } {
		clone.animated_property_storage_ = &ComputedPropertyValueMap{
			values: source.animated_property_storage_.values.clone()
		}
	}
	if source.animated_custom_storage_ != unsafe { nil } {
		clone.animated_custom_storage_ = &ComputedCustomPropertyValueMap{
			values: source.animated_custom_storage_.values.clone()
		}
	}
	if source.inheritance_specified_storage_ != unsafe { nil } {
		clone.inheritance_specified_storage_ = &ComputedPropertyValueMap{
			values: source.inheritance_specified_storage_.values.clone()
		}
	}
	if source.font_variation_storage_ != unsafe { nil } {
		clone.font_variation_storage_ = &ComputedFontVariationMap{
			values: source.font_variation_storage_.values.clone()
		}
	}
	return clone
}
