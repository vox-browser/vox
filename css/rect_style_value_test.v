module css

fn parsed_rect(text string) RectStyleValue {
	value := parse_css_value_logic(.clip, text) or { panic('could not parse ${text}') }
	if value is RectStyleValue {
		return value
	}
	panic('expected RectStyleValue')
}

fn test_rect_style_value_retains_edge_style_values() {
	rect := parsed_rect('rect(calc(10px + 5px), auto, -2em, 4px)')
	assert rect.top() is CalculatedStyleValue
	assert rect.right().has_auto()
	assert rect.bottom() is LengthStyleValue
	assert rect.left() is LengthStyleValue
	assert rect.serialize(.normal) == 'rect(calc(15px), auto, -2em, 4px)'
}

fn test_rect_style_value_absolutizes_each_edge() {
	rect := parsed_rect('rect(calc(10px + 5px), auto, 2em, 4px)')
	absolutized := rect.absolutized(ComputationContext{
		length_resolution_context: LengthResolutionContext{
			font_metrics: LengthFontMetrics.default()
			root_font_metrics: LengthFontMetrics.default()
		}
	})
	assert absolutized is RectStyleValue
	absolute_rect := absolutized as RectStyleValue
	assert absolute_rect.serialize(.normal) == 'rect(calc(15px), auto, 32px, 4px)'
	edges := absolute_rect.rect()
	assert edges.top_edge.length() or { Length.make_px(0) } == Length.make_px(15)
	assert edges.right_edge.is_auto()
	assert edges.bottom_edge.length() or { Length.make_px(0) } == Length.make_px(32)
	assert edges.left_edge.length() or { Length.make_px(0) } == Length.make_px(4)
}

fn test_rect_interpolation_preserves_matching_auto_edges_while_interpolating_lengths() {
 a := StyleValue(parsed_rect('rect(50px auto auto 50px)'))
 b := StyleValue(parsed_rect('rect(100px auto auto 100px)'))
 for progress,expected in {'-1':'rect(0px, auto, auto, 0px)','0.25':'rect(62.5px, auto, auto, 62.5px)','2':'rect(150px, auto, auto, 150px)'} {
  value := interpolate_style_value(InterpolationCalculationContext{property:.clip},a,b,progress.f64(),.no) or { panic('interpolation') }
  assert value.serialize(.normal)==expected
 }
}
