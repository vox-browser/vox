module css

import dom

fn test_border_shape_validates_contours_and_computes_reference_box_defaults() {
 for input in ['circle() border-box polygon(0 0,100% 0,0 100%) padding-box','shape(from 0 0, hline to 100%, vline by 2em, close)'] {
  value := parse_css_value_logic(.border_shape,input) or { panic(input) }
  assert value is BorderShapeStyleValue
 }
 for input in ['border-box circle()','circle() garbage','none circle()','circle() circle() circle()','shape(from 0 0, hline to)','shape(from 0 0, close garbage)','shape(from 0 0,)'] {
  assert parse_css_value_logic(.border_shape,input) == none,input
 }
 mut document := dom.Document.create(dom.url_about_blank())
 defer { document.finalize() }
 add_document_author_style_sheet(document,'#a{border-shape:circle(farthest-corner at center) border-box circle(farthest-corner at center) border-box}#b{border-shape:circle() border-box polygon(0 0,100% 0,0 100%) padding-box}')
 mut computer := StyleComputer.new(document)
 for id,expected in {'a':'circle(farthest-corner at 50% 50%) border-box','b':'circle() polygon(0px 0px, 100% 0px, 0px 100%)'} {
  mut element := document.create_element('div') or { panic(err) }
  element.set_attribute_value('id',id)
  style := computer.compute_style(dom.AbstractElement.new(element,none))
  assert (style.property(.border_shape,.no) or { panic('border-shape') }).css_text == expected
 }
}

fn test_linear_shape_keeps_typed_relative_commands_and_resolves_real_path_geometry() {
 value := parse_css_value_logic(.clip_path,'shape(from 10px 20px, hline by 30px, vline to 60px, line by -10px -20px, close)') or { panic('shape') }
 assert value is BasicShapeStyleValue
 shape := value.basic_shape()
 assert shape is BasicShapeCommands
 node := dom.LayoutNode{}
 path := value.to_path(CSSPixelRect{x:CSSPixels.new(0),y:CSSPixels.new(0),width:CSSPixels.new(100),height:CSSPixels.new(100)},node)
 assert path.commands.len == 5
 assert path.commands[1].point.x().to_double() == 40
 assert path.commands[2].point.y().to_double() == 60
 assert path.commands[3].point.x().to_double() == 30
 assert path.commands[3].point.y().to_double() == 40
 assert path.commands[4].type_ == .close
}
