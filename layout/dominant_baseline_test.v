module layout

import css
import math
import platform

fn dominant_baseline_test_values(metric ?css.BaselineMetric, writing_mode css.WritingMode) &css.ComputedValues {
	values := css.ComputedProperties.new()
	mut mutable_values := unsafe { &css.MutableComputedValues(values) }
	mutable_values.set_dominant_baseline(metric)
	mutable_values.set_writing_mode(writing_mode)
	return values
}

fn test_dominant_baseline_offset_matches_font_metrics() {
	metrics := platform.FontPixelMetrics{
		x_height: 8
		ascent: 15
		descent: 5
	}

	assert dominant_baseline_offset(.alphabetic, metrics) == 0
	assert dominant_baseline_offset(.central, metrics) == 5
	assert dominant_baseline_offset(.middle, metrics) == 4
	assert math.abs(dominant_baseline_offset(.hanging, metrics) - 12) < 0.001
	assert dominant_baseline_offset(.ideographic, metrics) == -5
	assert dominant_baseline_offset(.mathematical, metrics) == 7.5
	assert dominant_baseline_offset(.text_top, metrics) == 0
	assert dominant_baseline_offset(.text_bottom, metrics) == 0
}

fn test_dominant_baseline_auto_resolves_from_writing_mode() {
	for writing_mode in [css.WritingMode.horizontal_tb, .sideways_rl, .sideways_lr] {
		values := dominant_baseline_test_values(none, writing_mode)
		assert resolve_dominant_baseline_metric(values) == .alphabetic
	}
	for writing_mode in [css.WritingMode.vertical_rl, .vertical_lr] {
		values := dominant_baseline_test_values(none, writing_mode)
		assert resolve_dominant_baseline_metric(values) == .central
	}
}

fn test_explicit_dominant_baseline_overrides_writing_mode() {
	values := dominant_baseline_test_values(css.BaselineMetric.hanging, .vertical_rl)
	assert resolve_dominant_baseline_metric(values) == .hanging
}
