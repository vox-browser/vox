module css

// Physical sides are top, right, bottom, left, matching position_try.rs.
pub struct PositionTryTacticContext {
pub:
	mapping [4]int
	container_starts [2]int
	self_starts [2]int
	inline_horizontal bool
}

fn position_try_axis(side int) int { return if side in [1,3] { 0 } else { 1 } }

fn (context PositionTryTacticContext) transposes() bool { return position_try_axis(context.mapping[0]) == 0 }

fn (context PositionTryTacticContext) reverses(side int) bool {
	start := context.container_starts[position_try_axis(side)]
	moved := context.mapping[start]
	return moved != context.container_starts[position_try_axis(moved)]
}

fn (context PositionTryTacticContext) anchor_side(value StyleValue, side int) StyleValue {
	if value is PercentageStyleValue {
		return if context.reverses(side) { StyleValue(PercentageStyleValue.create(Percentage.new(100-value.percentage().value()))) } else { value }
	}
	if value is CalculatedStyleValue && context.reverses(side) {
		if percentage := value.resolve_percentage(CalculationResolutionContext{}) {
			return StyleValue(PercentageStyleValue.create(Percentage.new(100 - percentage.value())))
		}
	}
	if value is KeywordStyleValue {
		word := value.serialize(.normal)
		mut physical := ['top','right','bottom','left'].index(word)
		if word in ['start','end','self-start','self-end'] {
			physical = if word.starts_with('self-') { context.self_starts[position_try_axis(side)] } else { context.container_starts[position_try_axis(side)] }
			if word.ends_with('end') { physical = (physical+2)%4 }
		}
		if physical >= 0 {
			keyword := keyword_from_string(['top','right','bottom','left'][context.mapping[physical]]) or { return value }
			return StyleValue(KeywordStyleValue.create(keyword))
		}
	}
	return value
}

fn (context PositionTryTacticContext) move_value(value StyleValue, side int) StyleValue {
	match value {
		AnchorStyleValue {
			return StyleValue(AnchorStyleValue.create(value.anchor_name(),context.anchor_side(value.anchor_side(),side),value.fallback_value()))
		}
		AnchorSizeStyleValue {
			if !context.transposes() { return value }
			size := value.anchor_size() or { return value }
			moved := match size { .width { AnchorSize.height } .height { AnchorSize.width }
				.inline_ { AnchorSize.block } .block { AnchorSize.inline_ }
				.self_inline { AnchorSize.self_block } .self_block { AnchorSize.self_inline } }
			return StyleValue(AnchorSizeStyleValue.create(value.anchor_name(),moved,value.fallback_value()))
		}
		CalculatedStyleValue {
			if value.node.len != 1 { return value }
			node := context.move_calculation(value.node[0],side)
			return StyleValue(CalculatedStyleValue{...value,node:[node],serialization:node.serialize_top()})
		}
		else { return value }
	}
}

fn (context PositionTryTacticContext) move_children(children []CalcNode, side int) []CalcNode {
	mut result := []CalcNode{cap:children.len}
	for child in children { result << context.move_calculation(child,side) }
	return result
}

fn (context PositionTryTacticContext) move_calculation(node CalcNode, side int) CalcNode {
	return match node {
		CalcAnchor { CalcNode(CalcAnchor{style_value:context.move_value(StyleValue(node.style_value),side) as AnchorStyleValue}) }
		CalcAnchorSize { CalcNode(CalcAnchorSize{style_value:context.move_value(StyleValue(node.style_value),side) as AnchorSizeStyleValue}) }
		CalcSum { CalcNode(CalcSum{...node,children:context.move_children(node.children,side)}) }
		CalcProduct { CalcNode(CalcProduct{...node,children:context.move_children(node.children,side)}) }
		CalcNegate { CalcNode(CalcNegate{...node,children:context.move_children(node.children,side)}) }
		CalcInvert { CalcNode(CalcInvert{...node,children:context.move_children(node.children,side)}) }
		CalcFunction { CalcNode(CalcFunction{...node,children:context.move_children(node.children,side)}) }
		CalcRandom { CalcNode(CalcRandom{...node,children:context.move_children(node.children,side)}) }
		else { node }
	}
}

fn (context PositionTryTacticContext) alignment(text string, start int, destination_start int, inline_axis bool) string {
	reversed := context.mapping[start] != destination_start
	mut words := []string{}
	for word in text.split(' ') {
		mut moved := word
		if reversed {
			moved = match word { 'start' {'end'} 'end' {'start'} 'self-start' {'self-end'} 'self-end' {'self-start'}
				'flex-start' {'flex-end'} 'flex-end' {'flex-start'} 'flow-start' {'flow-end'} 'flow-end' {'flow-start'} else {word} }
		}
		if word in ['left','right'] {
			// line-left is inline-start with direction:ltr.
			line_left := if context.inline_horizontal { 3 } else { 0 }
			physical := if word == 'left' { line_left } else { (line_left+2)%4 }
			side := context.mapping[physical]
			moved = if inline_axis && side == line_left { 'left' } else if inline_axis && side == (line_left+2)%4 { 'right' }
				else if side == destination_start { 'start' } else { 'end' }
		}
		words << moved
	}
	return words.join(' ')
}

pub fn position_try_tactic_declaration(computed &ComputedProperties, context PositionTryTacticContext) &CSSStyleProperties {
	mut declaration := CSSStyleProperties.create()
	insets := [PropertyID.top,.right,.bottom,.left]
	margins := [PropertyID.margin_top,.margin_right,.margin_bottom,.margin_left]
	for properties in [insets,margins] {
		for side, property in properties {
			if value := computed.typed_property_value(property) {
				declaration.set_property(string_from_property_id(properties[context.mapping[side]]),context.move_value(value,side).serialize(.normal),'') or { panic(err) }
			}
		}
	}
	for pair in [[PropertyID.width,.height],[PropertyID.min_width,.min_height],[PropertyID.max_width,.max_height]] {
		for axis, property in pair {
			if value := computed.typed_property_value(property) {
				destination := pair[if context.transposes() { 1-axis } else { axis }]
				declaration.set_property(string_from_property_id(destination),context.move_value(value,if axis == 0 { 3 } else { 0 }).serialize(.normal),'') or { panic(err) }
			}
		}
	}
	for index, property in [PropertyID.justify_self,.align_self] {
		inline_axis := index == 0
		axis := if inline_axis == context.inline_horizontal { 0 } else { 1 }
		destination_axis := if context.transposes() { 1-axis } else { axis }
		destination_inline := (destination_axis == 0) == context.inline_horizontal
		value := computed.property(property,.yes) or { continue }
		declaration.set_property(if destination_inline { 'justify-self' } else { 'align-self' },
			context.alignment(value.css_text,context.container_starts[axis],context.container_starts[destination_axis],destination_inline),'') or { panic(err) }
	}
	for property in [PropertyID.position_anchor,.position_area] {
		if value := computed.property(property,.yes) { declaration.set_property(string_from_property_id(property),value.css_text,'') or { panic(err) } }
	}
	return declaration
}
