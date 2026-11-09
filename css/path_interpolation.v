module css

import math
import svg
import strings

fn shape_outside_reference_box(value StyleValue) Keyword {
	if value is BasicShapeStyleValue { return .margin_box }
	if value is StyleValueList {
		for item in value.values() {
			keyword := item.to_keyword()
			if keyword in [.margin_box, .border_box, .padding_box, .content_box] { return keyword }
		}
	}
	return value.to_keyword()
}

fn shape_outside_without_default_box(value StyleValue) StyleValue {
	if value is StyleValueList && value.size() == 2 {
		first := value.value_at(0, false)
		second := value.value_at(1, false)
		if first is BasicShapeStyleValue && second.to_keyword() == .margin_box { return first }
	}
	return value
}

fn interpolate_basic_shape_path(from BasicShapePath, to BasicShapePath, delta f64) ?BasicShapePath {
	if from.fill_rule != to.fill_rule { return none }
	first := svg.parse_path_data(from.path_instructions).to_absolute()
	second := svg.parse_path_data(to.path_instructions).to_absolute()
	if first.instructions.len == 0 || first.instructions.len != second.instructions.len { return none }
	mut instructions := []svg.PathInstruction{cap:first.instructions.len}
	for index, a in first.instructions {
		b := second.instructions[index]
		if a.type_ != b.type_ || a.data.len != b.data.len { return none }
		mut data := []f64{len:a.data.len}
		for component, start in a.data {
			value := start + (b.data[component] - start) * delta
			data[component] = if a.type_ == .elliptical_arc && component in [3, 4] {
				if value == 0 { 0.0 } else { 1.0 }
			} else if a.type_ == .elliptical_arc && component in [0, 1] { math.max(0, value) } else { value }
		}
		instructions << svg.PathInstruction{type_:a.type_, absolute:true, data:data}
	}
	mut text := strings.new_builder(instructions.len * 16)
	for index, instruction in instructions {
		if index > 0 { text.write_u8(` `) }
		text.write_string(instruction.serialize()[..1])
		for value in instruction.data { text.write_u8(` `); text.write_string(serialize_a_number(value)) }
	}
	return BasicShapePath{fill_rule:from.fill_rule, path_instructions:text.str()}
}
