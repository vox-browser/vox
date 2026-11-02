module css

import os
import platform

const retain_full_font_input_scan = os.getenv('VOX_RETAIN_FULL_FONT_INPUT_SCAN') != ''
const computed_font_input_diagnostics = os.getenv('VOX_COMPUTED_FONT_INPUT_DIAGNOSTICS') != ''

__global (
	computed_font_input_property_ids []PropertyID
	computed_font_input_scan_reported bool
)

// Derive this process-lifetime index from the mutation predicate once. The
// source dependency list and its constant-time membership checks stay intact;
// no per-element style values or font-environment state are memoized here.
fn computed_font_input_properties() []PropertyID {
	if computed_font_input_property_ids.len == 0 {
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		mut ids := []PropertyID{cap: 21}
		for id in computed_interpolation_longhand_property_ids() {
			if property_affects_computed_font_list(id) { ids << id }
		}
		computed_font_input_property_ids = unsafe { ids }
	}
	return computed_font_input_property_ids
}

fn computed_font_inputs_match(previous &ComputedProperties, current &ComputedProperties) bool {
	if retain_full_font_input_scan {
		for id in computed_interpolation_longhand_property_ids() {
			if property_affects_computed_font_list(id)
				&& style_value_option_changed(previous.property(id, .yes), current.property(id, .yes)) {
				return false
			}
		}
		return true
	}
	for id in computed_font_input_properties() {
		if style_value_option_changed(previous.property(id, .yes), current.property(id, .yes)) {
			return false
		}
	}
	if computed_font_input_diagnostics && !computed_font_input_scan_reported {
		computed_font_input_scan_reported = true
		eprintln('Vox font cache reuse: compared only declared font inputs')
	}
	return true
}
