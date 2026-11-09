module css

import dom
import svg

// Typed CSS shape commands retain coordinates and control-point reference frames
// for native interpolation and path construction.
pub enum CSSShapeLineKind { move line hline vline close curve smooth arc }

pub struct CSSShapeControlPoint {
pub:
 value StyleValue
 origin string
}

pub struct CSSShapeLineCommand {
pub:
 kind CSSShapeLineKind
 relative bool
 value StyleValue
 controls []CSSShapeControlPoint
 radii []StyleValue
 rotation StyleValue = StyleValue(AngleStyleValue.create(Angle.make_degrees(0)))
 clockwise bool
 large bool
}

pub struct BasicShapeCommands {
pub:
 fill_rule FillRule
 origin StyleValue
 commands []CSSShapeLineCommand
}

pub fn (shape BasicShapeCommands) serialize(mode SerializationMode) string {
 mut parts := []string{}
 for command in shape.commands {
  if command.kind == .close { parts << 'close';continue }
  mut text := '${command.kind} ${if command.relative { 'by' } else { 'to' }} ${command.value.serialize(mode)}'
  if command.controls.len > 0 {
   mut controls := []string{}
   for control in command.controls {
    suffix := if control.origin == if command.relative { 'start' } else { 'origin' } { '' } else { ' from ${control.origin}' }
    controls << control.value.serialize(mode)+suffix
   }
   text += ' with '+controls.join(' / ')
  }
  if command.kind == .arc {
   text += ' of '+command.radii[0].serialize(mode)
   if command.radii[1].serialize(mode) != command.radii[0].serialize(mode) { text += ' '+command.radii[1].serialize(mode) }
   if command.rotation.serialize(mode) != '0deg' { text += ' rotate '+command.rotation.serialize(mode) }
   if command.clockwise { text += ' cw' }
   if command.large { text += ' large' }
  }
  parts << text
 }
 return 'shape(${if shape.fill_rule == .evenodd { 'evenodd ' } else { '' }}from ${shape.origin.serialize(mode)}, ${parts.join(', ')})'
}

pub fn (shape BasicShapeCommands) absolutized(context ComputationContext) BasicShapeCommands {
 mut commands := []CSSShapeLineCommand{}
 for command in shape.commands {
  mut controls := []CSSShapeControlPoint{}
  for control in command.controls { controls << CSSShapeControlPoint{...control,value:control.value.absolutized(context)} }
  commands << CSSShapeLineCommand{...command,value:command.value.absolutized(context),controls:controls,radii:command.radii.map(it.absolutized(context)),rotation:command.rotation.absolutized(context)}
 }
 return BasicShapeCommands{fill_rule:shape.fill_rule,origin:shape.origin.absolutized(context),commands:commands}
}

fn shape_consume_ident(mut stream ComponentValueStream) ?string {
 stream.consume_whitespace()
 component := stream.consume() or { return none }
 if !component.is(.ident) { return none }
 return component.token().ident().to_lower()
}

fn (mut parser Parser) parse_linear_shape_function(values []ComponentValue) ?BasicShapeCommands {
 groups := parse_a_comma_separated_list_of_component_values_for_value_logic(values)
 if groups.len < 2 { return none }
 mut start := ComponentValueStream.new(groups[0])
 mut first := shape_consume_ident(mut start) or { return none }
 mut rule := FillRule.nonzero
 if first in ['nonzero','evenodd'] {
  if first == 'evenodd' { rule = .evenodd }
  first = shape_consume_ident(mut start) or { return none }
 }
 if first != 'from' { return none }
 origin := parser.parse_css_position_value(mut start,.normal) or { return none }
 start.consume_whitespace()
 if start.has_more_tokens() { return none }
 mut commands := []CSSShapeLineCommand{}
 for group in groups[1..] {
  mut args := ComponentValueStream.new(group)
  name := shape_consume_ident(mut args) or { return none }
  if name in ['curve','smooth','arc'] {
   commands << parser.parse_curved_shape_command(name,mut args) or { return none }
   continue
  }
  kind := match name { 'move' { CSSShapeLineKind.move } 'line' { .line } 'hline' { .hline } 'vline' { .vline } 'close' { .close } else { return none } }
  mut relative := false
  mut value := StyleValue(KeywordStyleValue.create(.none_))
  if kind != .close {
   mode := shape_consume_ident(mut args) or { return none }
   if mode !in ['to','by'] { return none }
   relative = mode == 'by'
   args.consume_whitespace()
   if kind in [.move,.line] {
    if relative {
     x := parser.parse_length_percentage_value(mut args) or { return none }
     args.consume_whitespace()
     y := parser.parse_length_percentage_value(mut args) or { return none }
     value = StyleValue(PositionStyleValue.create(EdgeStyleValue.create(none,x),EdgeStyleValue.create(none,y)))
    } else { value = parser.parse_css_position_value(mut args,.normal) or { return none } }
   } else {
    mut attempt := args.clone()
    if distance := parser.parse_length_percentage_value(mut attempt) { value = distance;args = attempt }
    else {
     if relative { return none }
     edge := shape_consume_ident(mut args) or { return none }
     percentage := match edge {
      'center' { 50.0 }
      'left' { if kind != .hline { return none };0.0 }
      'right' { if kind != .hline { return none };100.0 }
      'top' { if kind != .vline { return none };0.0 }
      'bottom' { if kind != .vline { return none };100.0 }
      else { return none }
     }
     value = StyleValue(PercentageStyleValue.create(Percentage.new(percentage)))
    }
   }
  }
  args.consume_whitespace()
  if args.has_more_tokens() { return none }
  commands << CSSShapeLineCommand{kind:kind,relative:relative,value:value}
 }
 return BasicShapeCommands{fill_rule:rule,origin:origin,commands:commands}
}

pub fn (shape BasicShapeCommands) to_path(box CSSPixelRect,node &dom.LayoutNode) StyleValuePath {
 context := style_values_extra_length_context(node)
 mut point := (shape.origin as PositionStyleValue).resolved(node,box)
 mut start := point
 mut shape_previous_control := point
 mut shape_previous_degree := 0
 mut path := StyleValuePath{fill_rule:shape.fill_rule,commands:[style_values_extra_move_to(point)]}
 for command in shape.commands {
  if command.kind == .close { path.commands << style_values_extra_close_path();point = start;shape_previous_control=point;shape_previous_degree=0;continue }
  if command.kind in [.curve,.smooth,.arc] {
   end_position := (command.value as PositionStyleValue).resolved(node,box)
   end := if command.relative { CSSPixelPoint.new(point.x().plus(end_position.x().minus(box.x)),point.y().plus(end_position.y().minus(box.y))) } else { end_position }
   mut controls := []CSSPixelPoint{}
   for control in command.controls {
    coordinate := (control.value as PositionStyleValue).resolved(node,box)
    base := match control.origin { 'start' { point } 'end' { end } else { CSSPixelPoint.new(box.x,box.y) } }
    controls << CSSPixelPoint.new(base.x().plus(coordinate.x().minus(box.x)),base.y().plus(coordinate.y().minus(box.y)))
   }
   mut source := 'M ${point.x().to_double()} ${point.y().to_double()} '
   if command.kind == .arc {
    rx := style_values_extra_length_percentage_to_px(command.radii[0],context,box.width).to_double()
    ry := style_values_extra_length_percentage_to_px(command.radii[1],context,box.height).to_double()
    rotation := (command.rotation as AngleStyleValue).angle().to_degrees()
    source += 'A ${rx} ${ry} ${rotation} ${if command.large { 1 } else { 0 }} ${if command.clockwise { 1 } else { 0 }} ${end.x().to_double()} ${end.y().to_double()}'
   } else {
    // Emit explicit reflected control points so each retained native segment
    // is independent of the preceding SVG path fragment.
    degree := if (command.kind == .smooth && controls.len == 0) || (command.kind == .curve && controls.len == 1) { 2 } else { 3 }
    previous := if shape_previous_degree == degree { shape_previous_control } else { point }
    reflected := CSSPixelPoint.new(point.x().plus(point.x().minus(previous.x())),point.y().plus(point.y().minus(previous.y())))
    if command.kind == .smooth { controls.prepend(reflected) }
    source += if controls.len == 1 { 'Q ' } else { 'C ' }
    for control in controls { source += '${control.x().to_double()} ${control.y().to_double()} ' }
    source += '${end.x().to_double()} ${end.y().to_double()}'
    shape_previous_control = controls.last()
    shape_previous_degree = degree
   }
   if command.kind == .arc { shape_previous_control=end;shape_previous_degree=0 }
   path.commands << style_values_extra_svg_path(source)
   point = end
   continue
  }
  shape_previous_control = point
  shape_previous_degree = 0
  if command.kind in [.move,.line] {
   resolved := (command.value as PositionStyleValue).resolved(node,box)
   point = if command.relative { CSSPixelPoint.new(point.x().plus(resolved.x().minus(box.x)),point.y().plus(resolved.y().minus(box.y))) } else { resolved }
  } else {
   distance := style_values_extra_length_percentage_to_px(command.value,context,if command.kind == .hline { box.width } else { box.height })
   if command.kind == .hline { point = CSSPixelPoint.new(if command.relative { point.x().plus(distance) } else { box.x.plus(distance) },point.y()) }
   else { point = CSSPixelPoint.new(point.x(),if command.relative { point.y().plus(distance) } else { box.y.plus(distance) }) }
  }
  if command.kind == .move { path.commands << style_values_extra_move_to(point);start = point }
  else { path.commands << style_values_extra_line_to(point) }
 }
 return path
}

fn shape_split_keyword(values []ComponentValue, keyword string) ([]ComponentValue,[]ComponentValue) {
 for i,value in values {
  if value.is(.ident) && value.token().ident().to_lower() == keyword { return values[..i],values[i+1..] }
 }
 return values,[]ComponentValue{}
}

fn (mut parser Parser) shape_coordinate_pair(values []ComponentValue, relative bool) ?StyleValue {
 mut stream := ComponentValueStream.new(values)
 if !relative {
  value := parser.parse_css_position_value(mut stream,.normal) or { return none }
  stream.consume_whitespace()
  if stream.has_more_tokens() { return none }
  return value
 }
 x := parser.parse_length_percentage_value(mut stream) or { return none }
 stream.consume_whitespace()
 y := parser.parse_length_percentage_value(mut stream) or { return none }
 stream.consume_whitespace()
 if stream.has_more_tokens() { return none }
 return StyleValue(PositionStyleValue.create(EdgeStyleValue.create(none,x),EdgeStyleValue.create(none,y)))
}

fn (mut parser Parser) parse_curved_shape_command(name string, mut stream ComponentValueStream) ?CSSShapeLineCommand {
 mode := shape_consume_ident(mut stream) or { return none }
 if mode !in ['to','by'] { return none }
 relative := mode == 'by'
 values := stream.consume_remaining_component_values()
 endpoint,parameters := shape_split_keyword(values,if name == 'arc' { 'of' } else { 'with' })
 value := parser.shape_coordinate_pair(endpoint,relative) or { return none }
 kind := match name { 'curve' { CSSShapeLineKind.curve } 'smooth' { .smooth } else { .arc } }
 mut controls := []CSSShapeControlPoint{}
 mut radii := []StyleValue{}
 mut rotation := StyleValue(AngleStyleValue.create(Angle.make_degrees(0)))
 mut clockwise := false
 mut large := false
 if kind == .arc {
  mut args := ComponentValueStream.new(parameters)
  first := parser.parse_length_percentage_value(mut args) or { return none }
  if style_value_numeric_component_is_negative_for_value_logic(first) { return none }
  radii << first
  args.consume_whitespace()
  mut attempt := args.clone()
  if second := parser.parse_length_percentage_value(mut attempt) {
   if style_value_numeric_component_is_negative_for_value_logic(second) { return none }
   radii << second
   args = attempt
  } else { radii << first }
  mut seen := map[string]bool{}
  for {
   args.consume_whitespace()
   if !args.has_more_tokens() { break }
   flag := shape_consume_ident(mut args) or { return none }
   group := match flag { 'cw','ccw' { 'direction' } 'small','large' { 'size' } 'rotate' { 'rotation' } else { return none } }
   if group in seen { return none };seen[group] = true
   if group == 'direction' { clockwise = flag == 'cw' }
   if group == 'size' { large = flag == 'large' }
   if group == 'rotation' { args.consume_whitespace();rotation = parser.parse_angle_value(mut args) or { return none } }
  }
 } else if parameters.len > 0 {
  groups := grid_split_by_slash(parameters)
  if groups.len > if kind == .curve { 2 } else { 1 } { return none }
  for group in groups {
   coordinates,origin_tokens := shape_split_keyword(group,'from')
   position := parser.shape_coordinate_pair(coordinates,true) or { return none }
   mut origin := if relative { 'start' } else { 'origin' }
   if origin_tokens.len > 0 {
    mut args := ComponentValueStream.new(origin_tokens)
    origin = shape_consume_ident(mut args) or { return none }
    args.consume_whitespace()
    if origin !in ['start','end','origin'] || args.has_more_tokens() { return none }
   }
   controls << CSSShapeControlPoint{value:position,origin:origin}
  }
 } else if kind == .curve { return none }
 return CSSShapeLineCommand{kind:kind,relative:relative,value:value,controls:controls,radii:radii,rotation:rotation,clockwise:clockwise,large:large}
}

fn interpolate_shape_commands(context InterpolationCalculationContext,from BasicShapeCommands,to BasicShapeCommands,delta f64) ?BasicShapeCommands {
 if from.fill_rule != to.fill_rule || from.commands.len != to.commands.len { return none }
 origin := interpolate_style_value(context,from.origin,to.origin,delta,.no) or { return none }
 mut commands := []CSSShapeLineCommand{}
 for i,a in from.commands {
  b := to.commands[i]
  if a.kind != b.kind || a.relative != b.relative || a.controls.len != b.controls.len || a.radii.len != b.radii.len { return none }
  mut controls := []CSSShapeControlPoint{}
  for j,control in a.controls {
   other := b.controls[j]
   if control.origin != other.origin { return none }
   controls << CSSShapeControlPoint{...control,value:interpolate_style_value(context,control.value,other.value,delta,.no) or { return none }}
  }
  mut radii := []StyleValue{}
  for j,radius in a.radii { radii << interpolate_style_value(context,radius,b.radii[j],delta,.no) or { return none } }
  commands << CSSShapeLineCommand{...a,
   value:if a.kind == .close { a.value } else { interpolate_style_value(context,a.value,b.value,delta,.no) or { return none } },
   controls:controls,radii:radii,
   rotation:interpolate_style_value(context,a.rotation,b.rotation,delta,.no) or { return none },
   clockwise:(if a.clockwise { 1.0 } else { 0.0 })*(1-delta)+(if b.clockwise { 1.0 } else { 0.0 })*delta > 0,
   large:(if a.large { 1.0 } else { 0.0 })*(1-delta)+(if b.large { 1.0 } else { 0.0 })*delta > 0
  }
 }
 return BasicShapeCommands{fill_rule:from.fill_rule,origin:origin,commands:commands}
}

fn shape_pair_in_pixels(x f64,y f64) StyleValue {
 return StyleValue(PositionStyleValue.create(EdgeStyleValue.create(none,StyleValue(LengthStyleValue.create(Length.make_px(x)))),EdgeStyleValue.create(none,StyleValue(LengthStyleValue.create(Length.make_px(y))))))
}

// SVG path coordinates are absolute pixel lengths, while relative instruction
// modes and control-point frames remain explicit for shape() compatibility.
fn shape_commands_from_svg_path(shape BasicShapePath) ?BasicShapeCommands {
 path := svg.parse_path_data(shape.path_instructions)
 if path.instructions.len == 0 || path.instructions[0].type_ != .move { return none }
 first := path.instructions[0]
 origin := shape_pair_in_pixels(first.data[0],first.data[1])
 mut commands := []CSSShapeLineCommand{}
 for instruction in path.instructions[1..] {
  data := instruction.data
  relative := !instruction.absolute
  mut kind := CSSShapeLineKind.close
  mut value := StyleValue(KeywordStyleValue.create(.none_))
  mut controls := []CSSShapeControlPoint{}
  mut radii := []StyleValue{}
  mut rotation := StyleValue(AngleStyleValue.create(Angle.make_degrees(0)))
  mut clockwise,mut large := false,false
  frame := if relative { 'start' } else { 'origin' }
  match instruction.type_ {
   .close_path {}
   .move,.line,.smooth_quadratic_bezier_curve {
    kind = match instruction.type_ { .move { .move } .line { .line } else { .smooth } }
    value = shape_pair_in_pixels(data[0],data[1])
   }
   .horizontal_line,.vertical_line {
    kind = if instruction.type_ == .horizontal_line { .hline } else { .vline }
    value = StyleValue(LengthStyleValue.create(Length.make_px(data[0])))
   }
   .curve {
    kind = .curve
    value = shape_pair_in_pixels(data[4],data[5])
    controls = [CSSShapeControlPoint{value:shape_pair_in_pixels(data[0],data[1]),origin:frame},CSSShapeControlPoint{value:shape_pair_in_pixels(data[2],data[3]),origin:frame}]
   }
   .smooth_curve,.quadratic_bezier_curve {
    kind = if instruction.type_ == .smooth_curve { .smooth } else { .curve }
    value = shape_pair_in_pixels(data[2],data[3])
    controls = [CSSShapeControlPoint{value:shape_pair_in_pixels(data[0],data[1]),origin:frame}]
   }
   .elliptical_arc {
    kind = .arc
    value = shape_pair_in_pixels(data[5],data[6])
    radii = [StyleValue(LengthStyleValue.create(Length.make_px(data[0]))),StyleValue(LengthStyleValue.create(Length.make_px(data[1])))]
    rotation = StyleValue(AngleStyleValue.create(Angle.make_degrees(data[2])))
    large = data[3] != 0;clockwise = data[4] != 0
   }
  }
  commands << CSSShapeLineCommand{kind:kind,relative:relative,value:value,controls:controls,radii:radii,rotation:rotation,large:large,clockwise:clockwise}
 }
 return BasicShapeCommands{fill_rule:shape.fill_rule,origin:origin,commands:commands}
}
