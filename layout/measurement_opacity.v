module layout

import css
import os

const retain_animated_opacity_measurements = os.getenv('VOX_RETAIN_ANIMATED_OPACITY_MEASUREMENTS') != ''
const opacity_measurement_diagnostics = os.getenv('VOX_OPACITY_MEASUREMENT_DIAGNOSTICS') != ''

__global opacity_measurement_reported bool

// Only within-pass measurement snapshots use this predicate. A live opacity
// sample changes painting, not the numeric geometry being restored. The full
// graph revision still invalidates an entry after any animation/value write.
// Persistent layout and paint caches retain their existing animation guards.
fn measurement_style_has_reusable_animation(style &css.ComputedValues) bool {
	return !style.has_animated_properties()
		|| (!retain_animated_opacity_measurements && !style.has_animated_custom_properties()
			&& style.has_only_animated_property(.opacity))
}

fn measurement_inputs_have_animated_opacity(inputs []RetainedInlineInput) bool {
	for input in inputs {
		if input.node.computed_values().has_only_animated_property(.opacity) { return true }
	}
	return false
}

// A single-use animated context should not pay to snapshot its descendants.
// Only a later measurement in this same pass can start retaining its geometry.
// Call inside the shared pool's retained allocation scope.
fn (mut pool MeasurementUsedValuesChunkPool) admit_opacity_measurement(node u64) bool {
	if pool.opacity_measurement_seen_[node] { return true }
	pool.opacity_measurement_seen_[node] = true
	return false
}

fn report_opacity_measurement_reuse(inputs []RetainedInlineInput) {
	if !opacity_measurement_diagnostics || opacity_measurement_reported { return }
	for input in inputs {
		if input.node.computed_values().has_only_animated_property(.opacity) {
			opacity_measurement_reported = true
			eprintln('Vox opacity measurement: reused unchanged within-pass geometry')
			return
		}
	}
}
