module css

fn test_ex_units_round_after_multiplying_unrounded_font_metrics() {
	metrics := LengthFontMetrics{
		x_height: CSSPixels.nearest_value_for(14.2529296875)
		x_height_unrounded: 14.2529296875
	}
	root := LengthFontMetrics{
		x_height: CSSPixels.nearest_value_for(9.123)
		x_height_unrounded: 9.123
	}
	assert Length.new(4.1, .ex).font_relative_length_to_px(metrics, root).to_double() == 58.4375
	assert ratio_between_font_relative_unit_and_px(.rex, metrics, root) == 9.123
	assert metrics.x_height.to_double() * 4.1 != 58.4375
}

fn test_font_relative_unit_ratios_match_length_resolution() {
	font_metrics := LengthFontMetrics.new(CSSPixels.new(20), CSSPixels.new(9), CSSPixels.new(14), CSSPixels.new(11), CSSPixels.new(24))
	root_metrics := LengthFontMetrics.new(CSSPixels.new(32), CSSPixels.new(15), CSSPixels.new(23), CSSPixels.new(17), CSSPixels.new(40))
	expected := {
		LengthUnit.em:   20.0
		LengthUnit.rem:  32.0
		LengthUnit.ex:   9.0
		LengthUnit.rex:  15.0
		LengthUnit.cap:  14.0
		LengthUnit.rcap: 23.0
		LengthUnit.ch:   11.0
		LengthUnit.rch:  17.0
		LengthUnit.ic:   20.0
		LengthUnit.ric:  32.0
		LengthUnit.lh:   24.0
		LengthUnit.rlh:  40.0
	}
	for unit, ratio in expected {
		assert ratio_between_font_relative_unit_and_px(unit, font_metrics, root_metrics) == ratio
		assert Length.new(2.5, unit).font_relative_length_to_px_without_rounding(font_metrics, root_metrics) == ratio * 2.5
	}
}

fn test_viewport_relative_unit_ratios_match_length_resolution() {
	viewport := CSSPixelRect.new(0, 0, 800, 600)
	expected := {
		LengthUnit.vw:    8.0
		LengthUnit.svw:   8.0
		LengthUnit.lvw:   8.0
		LengthUnit.dvw:   8.0
		LengthUnit.vi:    8.0
		LengthUnit.svi:   8.0
		LengthUnit.lvi:   8.0
		LengthUnit.dvi:   8.0
		LengthUnit.vh:    6.0
		LengthUnit.svh:   6.0
		LengthUnit.lvh:   6.0
		LengthUnit.dvh:   6.0
		LengthUnit.vb:    6.0
		LengthUnit.svb:   6.0
		LengthUnit.lvb:   6.0
		LengthUnit.dvb:   6.0
		LengthUnit.vmin:  6.0
		LengthUnit.svmin: 6.0
		LengthUnit.lvmin: 6.0
		LengthUnit.dvmin: 6.0
		LengthUnit.vmax:  8.0
		LengthUnit.svmax: 8.0
		LengthUnit.lvmax: 8.0
		LengthUnit.dvmax: 8.0
	}
	for unit, ratio in expected {
		assert ratio_between_viewport_relative_unit_and_px(unit, viewport) == ratio
		assert Length.new(12.5, unit).viewport_relative_length_to_px_without_rounding(viewport) == ratio * 12.5
	}
}
