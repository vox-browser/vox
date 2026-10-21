module layout

import css
import dom

fn zero_indent_builder(declarations string, direction css.Direction, writing_mode css.WritingMode) &LineBuilder {
 document := dom.Document.create(dom.url_about_blank())
 mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic(err) }
 element.set_attribute_value('style', 'display:block;font:20px/24px SerenitySans;${declarations}')
 style := css.css_style_computer_for(document).compute_style(dom.AbstractElement.new(element, none))
 container := BlockContainer.new(document, none, style)
 assign_layout_indexes(unsafe { &Node(container) })
 mut state := LayoutState.new()
 mut used := state.get_mutable(unsafe { &NodeWithStyle(container) })
 used.set_content_width(CSSPixels.new(320))
 return LineBuilder.new(mut state, container, used, AvailableSize.make_definite(CSSPixels.new(320)), direction, writing_mode)
}

fn test_absolute_zero_text_indent_keeps_initial_line_geometry_and_flags() {
 for value in ['0', '0px', '-0px', '0pt', '-0in', '0cm', '0mm', '0pc', '0Q'] {
  for direction in [css.Direction.ltr, .rtl] {
   for mode in [css.WritingMode.horizontal_tb, .vertical_rl, .vertical_lr] {
    mut builder := zero_indent_builder('text-indent:${value}', direction, mode)
    assert builder.text_indent.raw_value() == 0
    assert builder.ensure_last_line_box().inline_length().raw_value() == 0
    assert !builder.text_indent_hanging
    assert !builder.text_indent_each_line
    assert builder.direction == direction
    assert builder.writing_mode == mode
   }
  }
 }
}

fn test_nonzero_relative_percentage_and_calculated_text_indent_keep_resolution() {
 values := ['1.25px', '-2px', '1.5pt', '0.25in', '2.54cm', '12pc', '10%', '-12.5%', '2em', 'calc(2em + 10%)']
 expected := [1.25, -2.0, 2.0, 24.0, 96.0, 192.0, 32.0, -40.0, 40.0, 72.0]
 for index, value in values {
  mut builder := zero_indent_builder('text-indent:${value}', .ltr, .horizontal_tb)
  assert builder.text_indent == CSSPixels.nearest_value_for(expected[index])
  assert builder.ensure_last_line_box().inline_length() == builder.text_indent
 }
 // A calculated or font-relative zero retains the existing resolver too.
 for value in ['0em', '0%', 'calc(1em - 20px)'] {
  mut builder := zero_indent_builder('text-indent:${value}', .ltr, .horizontal_tb)
  assert builder.text_indent.raw_value() == 0
  assert builder.ensure_last_line_box().inline_length().raw_value() == 0
 }
}

fn test_text_indent_hanging_each_line_keeps_soft_and_forced_break_behavior() {
 for value in ['0px', '10%'] {
  for direction in [css.Direction.ltr, .rtl] {
   for mode in [css.WritingMode.horizontal_tb, .vertical_rl] {
    mut builder := zero_indent_builder('text-indent:${value} hanging each-line', direction, mode)
    expected := if value == '0px' { CSSPixels.new(0) } else { CSSPixels.new(32) }
    assert builder.text_indent == expected
    assert builder.text_indent_hanging
    assert builder.text_indent_each_line
    assert builder.ensure_last_line_box().inline_length().raw_value() == 0
    builder.break_line(.no, none)
    assert builder.ensure_last_line_box().inline_length() == expected
    builder.break_line(.yes, none)
    assert builder.ensure_last_line_box().inline_length().raw_value() == 0
   }
  }
 }
}
