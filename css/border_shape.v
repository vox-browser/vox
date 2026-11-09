module css

pub struct BorderShapeContour {
pub:
 shape BasicShapeStyleValue
 reference_box string
}

pub struct BorderShapeStyleValue {
pub:
 contours []BorderShapeContour
 computed bool
}

pub fn (value BorderShapeStyleValue) serialize(mode SerializationMode) string {
 mut contours := value.contours.clone()
 if value.computed && contours.len == 2 && contours[0].reference_box == contours[1].reference_box && contours[0].shape == contours[1].shape { contours = [contours[0]] }
 mut parts := []string{}
 for index,contour in contours {
  default_box := if contours.len == 1 { 'half-border-box' } else if index == 0 { 'border-box' } else { 'padding-box' }
  box := contour.reference_box
  parts << contour.shape.serialize(mode) + if box != '' && (!value.computed || box != default_box) { ' ${box}' } else { '' }
 }
 return parts.join(' ')
}

pub fn (value BorderShapeStyleValue) absolutized(context ComputationContext) StyleValue {
 mut contours := []BorderShapeContour{}
 for index,contour in value.contours {
  default_box := if value.contours.len == 1 { 'half-border-box' } else if index == 0 { 'border-box' } else { 'padding-box' }
  contours << BorderShapeContour{shape:contour.shape.absolutized(context) as BasicShapeStyleValue,reference_box:if contour.reference_box == '' { default_box } else { contour.reference_box }}
 }
 return StyleValue(BorderShapeStyleValue{contours:contours,computed:true})
}

fn (mut parser Parser) parse_border_shape_value(mut tokens ComponentValueStream) ?StyleValue {
 mut transaction := tokens.clone()
 if value := parse_property_keyword_value(mut transaction,['none']) { tokens = transaction;return value }
 mut contours := []BorderShapeContour{}
 for contours.len < 2 {
  transaction.consume_whitespace()
  if !transaction.has_more_tokens() { break }
  value := parser.parse_basic_shape_value(mut transaction) or { return none }
  if value !is BasicShapeStyleValue { return none }
  transaction.consume_whitespace()
  mut box := ''
  if component := transaction.peek() {
   if component.is(.ident) {
    box = component.token().ident().to_lower()
    if box !in ['margin-box','border-box','padding-box','content-box','fill-box','stroke-box','view-box','half-border-box'] { return none }
    transaction.consume()
   }
  }
  contours << BorderShapeContour{shape:value,reference_box:box}
 }
 if contours.len == 0 { return none }
 tokens = transaction
 return StyleValue(BorderShapeStyleValue{contours:contours})
}
