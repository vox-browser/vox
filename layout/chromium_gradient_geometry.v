module layout

import css

fn chromium_default_gradient_geometry(layer css.BackgroundLayerData) bool {
	return layer.size_type == .length_percentage && layer.size_x.is_auto() && layer.size_y.is_auto()
		&& layer.position_x.is_percentage() && layer.position_x.percentage().value() == 0
		&& layer.position_y.is_percentage() && layer.position_y.percentage().value() == 0
}
