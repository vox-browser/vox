module css

fn test_removing_a_shorthand_removes_all_expanded_longhands() {
 mut declaration := CSSStyleProperties.create()
 declaration.set_property('color', 'red', '')!
 declaration.set_property('animation-range', '10% 80%', '')!
 assert declaration.remove_property('animation-range')! == '10% 80%'
 assert declaration.get_property_value('animation-range-start') == ''
 assert declaration.get_property_value('animation-range-end') == ''
 assert declaration.get_property_value('color') == 'red'
 declaration.set_property('margin', '1px 2px', 'important')!
 declaration.set_property('margin', '', '')!
 for name in ['margin-top', 'margin-right', 'margin-bottom', 'margin-left'] {
  assert declaration.get_property_value(name) == ''
 }
 declaration.set_property('margin-left', '3px', '')!
 assert declaration.remove_property('margin')! == ''
 assert declaration.get_property_value('margin-left') == ''
}
