module css

import dom

fn test_shape_curves_keep_control_frames_interpolate_and_construct_native_paths() {
 from := parse_css_value_logic(.clip_path,'shape(from 0px 0px, curve to 100% 50% with 20px 30px from origin / 40px 50px, arc by 10px 10px of 20px rotate 30deg cw)') or { panic('from') }
 to := parse_css_value_logic(.clip_path,'shape(from 0px 0px, curve to 100% 50% with 20px 30px / 40px 150px, arc by 20px 20px of 40px rotate 50deg cw)') or { panic('to') }
 value := interpolate_style_value(InterpolationCalculationContext{property:.clip_path,percentages_resolve_as:.length},from,to,0.5,.no) or { panic('interpolation') }
 text := value.serialize(.normal)
 assert text.contains('40px 100px'),text
 assert text.contains('of 30px'),text
 shape := value as BasicShapeStyleValue
 path := shape.to_path(CSSPixelRect.new(0,0,200,100),dom.LayoutNode{})
 assert path.commands.len == 3
 assert path.commands[1].svg_source.contains('C ')
 assert path.commands[2].svg_source.contains('A ')
 assert parse_css_value_logic(.clip_path,'shape(from 0 0, curve to 10px 20px)') == none
}

fn test_clip_geometry_boxes_and_rounded_polygons_retain_native_geometry() {
 for source in ['shape(from 0 0, line to 10px 20px) padding-box','padding-box','polygon(round 10px,0px 0px,100px 0px,100px 100px)'] {
  value := parse_css_value_logic(.clip_path,source) or { panic(source) }
  assert parse_css_value_logic(.clip_path,value.serialize(.normal)) != none
 }
 value := parse_css_value_logic(.clip_path,'polygon(round 10px,0px 0px,100px 0px,100px 100px)') or { panic('polygon') }
 shape := value as BasicShapeStyleValue
 path := shape.to_path(CSSPixelRect.new(0,0,100,100),dom.LayoutNode{})
 assert path.commands.any(it.type_ == .elliptical_arc_to)
}

fn test_shape_and_svg_path_interpolate_compatible_native_commands() {
 a := parse_css_value_logic(.clip_path,'shape(from 5px 5px,hline to 5px,vline to -5px,close)') or { panic('shape') }
 b := parse_css_value_logic(.clip_path,'path("M15 15 H25 V-15 Z")') or { panic('path') }
 value := interpolate_style_value(InterpolationCalculationContext{property:.clip_path,percentages_resolve_as:.length},a,b,0.5,.no) or { panic('interpolation') }
 expected := parse_css_value_logic(.clip_path,'shape(from 10px 10px,hline to 15px,vline to -10px,close)') or { panic('expected') }
 assert value.serialize(.normal)==expected.serialize(.normal)
}
