module css

fn test_border_image_slice_computes_number_and_percentage_math_children() {
 context := ComputationContext{length_resolution_context:LengthResolutionContext{viewport_rect:CSSPixelRect.new(0,0,200,100)}}
 for source,expected in {
  'calc(10 + (sign(2cqw - 10px) * 5))':'5'
  'calc(10 + (sign(2cqw - 10px) * 5)) calc(20% + (sign(2cqw - 10px) * 5%)) fill':'5 15% fill'
 } {
  value := parse_css_value_logic(.border_image_slice,source) or { panic(source) }
  assert value.absolutized(context).serialize(.normal) == expected
  assert value.serialize(.normal).contains('sign(')
 }
}
