module css

// These borrowed maps stay inside synchronous, read-only font computation.
// Matching and cache-key generation do not retain mutable settings; cache
// misses materialize independently owned variation axes and shape features.
fn (computer &FontComputer) variation_settings_for_computation(style &ComputedProperties) map[string]f64 {
	value := style.property(.font_variation_settings, .yes) or {
		return computer.normal_variation_settings_
	}
	if computed_font_setting_is_normal(value) {
		return computer.normal_variation_settings_
	}
	return style.font_variation_settings()
}

fn (computer &FontComputer) feature_data_for_computation(style &ComputedProperties) FontFeatureData {
	value := style.property(.font_feature_settings, .yes) or {
		return style.font_feature_data_with_settings(computer.normal_feature_settings_)
	}
	if computed_font_setting_is_normal(value) {
		return style.font_feature_data_with_settings(computer.normal_feature_settings_)
	}
	return style.font_feature_data()
}
