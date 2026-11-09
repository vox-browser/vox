module layout

import css
import html

fn test_text_orientation_selects_alphabetic_or_central_synthesized_grid_baselines() {
 for orientation,first_x in {'mixed':65.0,'upright':65.0,'sideways':70.0} {
  mut document := html.parse_document('<!doctype html><style>body{margin:0}#grid{display:grid;writing-mode:vertical-rl;text-orientation:${orientation};width:100px;height:400px;grid-template-columns:repeat(4,100px)}#grid>div{align-self:baseline}#a{width:20px}#b{width:10px;margin:0 20px 0 10px}#c{width:10px;margin-right:20px}#wide{width:100px;align-self:start!important}</style><div id="grid"><div id="a"></div><div id="b"></div><div id="c"></div><div id="wide"></div></div>')
  defer { document.finalize() }
  _ = layout_document_typed_in_viewport(document,800,600)
  assert (document.get_element_by_id('a') or { panic('a') }).get_bounding_client_rect().x == first_x, orientation
  assert (document.get_element_by_id('b') or { panic('b') }).get_bounding_client_rect().x == 70
  assert (document.get_element_by_id('c') or { panic('c') }).get_bounding_client_rect().x == 70
  computed := css.computed_properties_for_element(document.get_element_by_id('a') or { panic('a') }) or { panic('style') }
  assert computed.text_orientation().str() == orientation
 }
}
