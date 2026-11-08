module layout

import os

const disable_static_generated_measurements = os.getenv('VOX_DISABLE_STATIC_GENERATED_MEASUREMENTS') != ''
const static_generated_measurement_diagnostics = os.getenv('VOX_STATIC_GENERATED_MEASUREMENT_DIAGNOSTICS') != ''
__global static_generated_measurements_reported bool

// Tree construction has already materialized generated text. Within one pass,
// the ordinary snapshot validates its live text, style, font and tree inputs.
// Before/after boxes and their generated text can use that same proof; markers,
// first-letter fragments and other generated kinds retain the full algorithm.
fn static_generated_measurement_input(node &Node) bool {
	if disable_static_generated_measurements { return false }
	if pseudo := node.generated_for_pseudo_element() {
		return pseudo in [.before, .after]
	}
	if node.is_generated_text_node() {
		parent := node.parent() or { return false }
		return parent.is_generated_for_before_pseudo_element()
			|| parent.is_generated_for_after_pseudo_element()
	}
	return false
}

fn report_static_generated_measurement(inputs []RetainedInlineInput) {
	if !static_generated_measurement_diagnostics || static_generated_measurements_reported { return }
	for input in inputs {
		if input.node.is_generated_for_pseudo_element() || input.node.is_generated_text_node() {
			static_generated_measurements_reported = true
			eprintln('Vox generated measurement: reused validated within-pass before/after geometry')
			return
		}
	}
}
