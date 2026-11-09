module css

fn test_relative_color_conversion_carries_missing_channels_and_powerless_hues() {
 for source, expected in {
  'hsl(from hsl(none 50% 50%) h s l)':'hsl(none 50% 50%)'
  'hsl(from hwb(180 100% 25%) h s l)':'hsl(none 0% 80%)'
  'hsl(from hwb(none 25% 25%) h s l)':'hsl(none 50% 50%)'
  'lch(from lch(none none none) l c h)':'lch(none none none)'
  'hsl(from lab(0 0 0) h s l)':'hsl(none 0% 0%)'
  'color-mix(in hsl, hsl(none 50% 50%))':'hsl(none 50% 50%)'
  'color-mix(in oklab, oklab(0.5 0.1 none))':'oklab(0.5 0.1 none)'
 } {
  value := parse_css_value_logic(.color,source) or { panic(source) }
  computed := value.absolutized(ComputationContext{})
  assert computed.serialize(.resolved_value) == expected,source
  reparsed := parse_css_value_logic(.color,expected) or { panic('roundtrip') }
  assert reparsed.absolutized(ComputationContext{}).serialize(.resolved_value) == expected,source
 }
}
