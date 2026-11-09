module css

fn test_font_size_adjust_grammar_and_inheritance_metadata() {
 for source, expected in {'none':'none','0.5':'0.5','ex-height 0.5':'0.5','cap-height 0.5':'cap-height 0.5','ch-width from-font':'ch-width from-font','calc(1 + 0.5)':'calc(1.5)'} {
  value := parse_css_value_logic(.font_size_adjust,source) or { panic(source) }
  assert value.serialize(.normal) == expected,source
 }
 for source in ['-1','auto','cap-height','none 1','1 2','50%','1px'] {
  assert parse_css_value_logic(.font_size_adjust,source) == none,source
 }
 assert property_id_from_string('font-size-adjust')? == .font_size_adjust
 assert is_inherited_property(.font_size_adjust)
 assert is_animatable_property(.font_size_adjust)
 assert number_of_longhand_properties == int(last_longhand_property_id()) - int(first_longhand_property_id()) + 1
 for index in 0 .. number_of_longhand_properties {
  assert int(property_id_from_longhand_index(index)?) == int(first_longhand_property_id())+index
 }
}

fn test_font_shorthand_resets_size_adjust_and_reconstructs_only_initial_reset_values() {
 mut style := CSSStyleProperties.create()
 style.set_property('font-size-adjust','cap-height 0.5','')!
 style.set_property('font','italic 16px serif','')!
 assert style.get_property_value('font-size-adjust') == 'none'
 assert style.get_property_value('font') == 'italic 16px serif'
 style.set_property('font-size-adjust','0.5','')!
 assert style.get_property_value('font') == ''
}

fn test_font_size_adjust_addition_preserves_a_matching_metric() {
 underlying := dom_style_value_from_value_logic(parse_css_value_logic(.font_size_adjust,'cap-height 0.5')?)
 animated := dom_style_value_from_value_logic(parse_css_value_logic(.font_size_adjust,'cap-height 2')?)
 assert composite_value(.font_size_adjust,underlying,animated,.add)?.css_text == 'cap-height 2.5'
}
