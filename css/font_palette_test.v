module css

fn test_font_palette_values_mix_and_preserve_shorthand_independence() {
 for source,expected in {'dark':'dark','--Palette':'--Palette','palette-mix(in oklab, light, dark 30%)':'palette-mix(in oklab, light, dark 30%)','palette-mix(in oklab, normal, light)':'palette-mix(in oklab, normal, light)','palette-mix(in oklab, light 20%, dark 30%)':'palette-mix(in oklab, light, dark 60%)'} {
  value := parse_css_value_logic(.font_palette,source) or { panic(source) }
  assert value.serialize(.normal) == expected,source
 }
 for source in ['none','--','blue','palette-mix(in oklab,light 0%,dark 0%)','palette-mix(in invalid,light,dark)'] {
  assert parse_css_value_logic(.font_palette,source) == none,source
 }
 mut style := CSSStyleProperties.create()
 style.set_property('font-palette','dark','')!
 style.set_property('font','16px serif','')!
 assert style.get_property_value('font-palette') == 'dark'
 assert is_inherited_property(.font_palette)
 assert is_animatable_property(.font_palette)
}
