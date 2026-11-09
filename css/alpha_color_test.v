module css

fn test_alpha_color_preserves_origin_space_and_replaces_alpha() {
 for source, expected in {
  'alpha(from red / 50%)':'color(srgb 1 0 0 / 0.5)'
  'alpha(from color(display-p3 1 0 0) / 0.5)':'color(display-p3 1 0 0 / 0.5)'
  'alpha(from alpha(from red / 0.5) / calc(alpha + 0.25))':'color(srgb 1 0 0 / 0.75)'
  'alpha(from red / none)':'color(srgb 1 0 0 / none)'
 } {
  value := parse_css_value_logic(.color, source) or { panic(source) }
  assert value.absolutized(ComputationContext{}).serialize(.resolved_value) == expected, source
 }
 for source in ['alpha(red / 0.5)','alpha(from red)','alpha(from red / r)','alpha(from red / 0.5 1)','alpha(from red / 1px)'] {
  assert parse_css_value_logic(.color,source) == none, source
 }
}
