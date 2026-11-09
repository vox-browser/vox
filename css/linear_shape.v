module css

import dom

// Native subset of shape(): straight subpaths, including relative commands.
// Curves and arcs remain unsupported and fail parsing rather than being stored
// as opaque tokens or silently reduced to line segments.
pub enum CSSShapeLineKind { move line hline vline close }

pub struct CSSShapeLineCommand {
pub:
 kind CSSShapeLineKind
 relative bool
 value StyleValue
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
  parts << '${command.kind} ${if command.relative { 'by' } else { 'to' }} ${command.value.serialize(mode)}'
 }
 return 'shape(${if shape.fill_rule == .evenodd { 'evenodd ' } else { '' }}from ${shape.origin.serialize(mode)}, ${parts.join(', ')})'
}

pub fn (shape BasicShapeCommands) absolutized(context ComputationContext) BasicShapeCommands {
 mut commands := []CSSShapeLineCommand{}
 for command in shape.commands { commands << CSSShapeLineCommand{...command,value:command.value.absolutized(context)} }
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
 mut path := StyleValuePath{fill_rule:shape.fill_rule,commands:[style_values_extra_move_to(point)]}
 for command in shape.commands {
  if command.kind == .close { path.commands << style_values_extra_close_path();point = start;continue }
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
