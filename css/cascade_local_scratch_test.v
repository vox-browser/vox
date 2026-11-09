module css

import dom

fn scratch_cascade_element(document &dom.Document) &dom.Element {
 return document.create_element_ns('http://www.w3.org/1999/xhtml','div') or { panic(err) }
}
fn scratch_cascade_value(id PropertyID, text string) &dom.StyleValue {
 return dom_style_value_from_value_logic(parse_css_value_logic(id,text) or { panic(text) })
}
fn test_cascade_scratch_covers_every_generated_longhand_and_keeps_source() {
 document := dom.Document.create(dom.url_about_blank())
 element := scratch_cascade_element(document)
 abstract_element := dom.AbstractElement.new(element,none)
 value := scratch_cascade_value(.color,'initial')
 source := &dom.StyleValue{css_text:'source'}
 mut properties := []StyleProperty{}
 for index in 1 .. int(PropertyID.container)+1 {
  id := unsafe { PropertyID(index) }
  if computed_interpolation_is_longhand_property(id) {
   assert index <= int(PropertyID.mask)
   properties << StyleProperty{property_id:id value:value}
  }
 }
 assert properties.len > 300
 mut cascaded := CascadedProperties.new()
 context := LogicalAliasMappingContext{}
 apply_property_list_to_cascade(mut cascaded,abstract_element,properties,.author,.no,none,voidptr(source),none,context,[])
 for property in properties {
  id := if property_is_logical_alias(property.property_id) { map_logical_alias_to_physical_property(property.property_id,context) } else { property.property_id }
  assert cascaded.property(id)? == value
  assert cascaded.property_source(id) == voidptr(source)
 }
 gc_collect()
 assert cascaded.property(.color)?.css_text == 'initial'
}
fn test_cascade_scratch_is_fresh_for_repeated_lists_and_retains_metadata() {
 document := dom.Document.create(dom.url_about_blank())
 element := scratch_cascade_element(document)
 abstract_element := dom.AbstractElement.new(element,none)
 red := scratch_cascade_value(.color,'red')
 blue := scratch_cascade_value(.color,'blue')
 first_source := &dom.StyleValue{css_text:'first'}
 second_source := &dom.StyleValue{css_text:'second'}
 for _ in 0 .. 32 {
  mut cascaded := CascadedProperties.new()
  apply_property_list_to_cascade(mut cascaded,abstract_element,[StyleProperty{property_id:.color value:red}],.author,.no,'layer',voidptr(first_source),none,none,[])
  apply_property_list_to_cascade(mut cascaded,abstract_element,[StyleProperty{property_id:.color value:blue}],.author,.no,'layer',voidptr(second_source),none,none,[])
  assert cascaded.property(.color)? == blue
  assert cascaded.property_source(.color) == voidptr(second_source)
  gc_collect()
  assert cascaded.entry_node(cascaded.winning_entry_index(.color)).entry.layer_name? == 'layer'
  assert cascaded.property(.color)?.css_text == 'blue'
 }
}
fn test_cascade_scratch_keeps_shorthand_filtering_and_importance() {
 document := dom.Document.create(dom.url_about_blank())
 element := scratch_cascade_element(document)
 abstract_element := dom.AbstractElement.new(element,none)
 padding := scratch_cascade_value(.padding,'1px 2px 3px 4px')
 red := scratch_cascade_value(.color,'red')
 blue := scratch_cascade_value(.color,'blue')
 properties := [StyleProperty{property_id:.padding value:padding},StyleProperty{property_id:.color value:red},StyleProperty{property_id:.color value:blue important:.yes}]
 mut cascaded := CascadedProperties.new()
 apply_property_list_to_cascade(mut cascaded,abstract_element,properties,.author,.no,none,unsafe{nil},none,none,[PropertyID.padding_left,PropertyID.color])
 assert cascaded.property(.padding_left)?.css_text == '4px'
 assert cascaded.property(.padding_top) == none
 assert cascaded.property(.color)? == red
 apply_property_list_to_cascade(mut cascaded,abstract_element,properties,.author,.yes,none,unsafe{nil},none,none,[])
 assert cascaded.property(.color)? == blue
 assert cascaded.style_property(.color)?.important == .yes
 assert cascaded.property(.padding_left)?.css_text == '4px'
}
