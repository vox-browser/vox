module layout

import css

// Layout already resolved the coordinated background lists in apply_style().
// Read that immutable projection rather than serializing and splitting all
// nine longhands again for each painted box. Raw properties used outside a
// committed layout still need the full resolver.
fn resolved_background_layers_for_paint(properties &css.ComputedProperties) []css.BackgroundLayerData {
	if properties.computed_values_resolved_ {
		values := unsafe { &css.ComputedValues(properties) }
		return values.background_layers()
	}
	return properties.background_layers()
}
