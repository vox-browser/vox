module css

import strings

pub struct FunctionParameterInternal {
pub:
	name          string
	type_         SyntaxNode
	default_value ?[]ComponentValue
}

pub struct FunctionParameter {
pub:
	name          string
	type_         string
	default_value ?string
}

fn serialize_a_css_type(type_ SyntaxNode) string {
	is_single_syntax_component := match type_.type() {
		.universal, .ident, .type_ { true }
		.multiplier, .comma_separated_multiplier {
			type_.child().type() in [.ident, .type_]
		}
		.alternatives { false }
	}

	if is_single_syntax_component {
		return type_.to_string()
	}
	return 'type(${type_.to_string()})'
}

fn (parameter FunctionParameterInternal) serialized() string {
	mut builder := strings.new_builder(32)
	builder.write_string(serialize_an_identifier(parameter.name))
	if parameter.type_.type() != .universal {
		builder.write_u8(` `)
		builder.write_string(serialize_a_css_type(parameter.type_))
	}
	if default_value := parameter.default_value {
		builder.write_string(': ')
		builder.write_string(parser_component_values_to_string(default_value).trim_space())
	}
	return builder.str()
}

fn (parameter FunctionParameterInternal) for_bindings() FunctionParameter {
	mut default_value := ?string(none)
	if values := parameter.default_value {
		default_value = parser_component_values_to_string(values).trim_space()
	}
	return FunctionParameter{
		name: parameter.name
		type_: parameter.type_.to_string()
		default_value: default_value
	}
}

pub fn (rule &CSSRule) function_rule_name() string {
	return rule.kind_data().function_name
}

pub fn (rule &CSSRule) get_function_parameters() []FunctionParameter {
	mut parameters := []FunctionParameter{cap: rule.kind_data().function_parameters.len}
	for parameter in rule.kind_data().function_parameters {
		parameters << parameter.for_bindings()
	}
	return parameters
}

pub fn (rule &CSSRule) function_return_type_string() string {
	return rule.kind_data().function_return_type.to_string()
}

pub fn (rule &CSSRule) function_declarations_style() ?&CSSFunctionDescriptors {
	return rule.kind_data().function_descriptors
}

pub fn (rule &CSSRule) serialized_function_rule() string {
	mut builder := strings.new_builder(64)
	builder.write_string('@function ')
	builder.write_string(serialize_an_identifier(rule.kind_data().function_name))
	builder.write_u8(`(`)
	for index, parameter in rule.kind_data().function_parameters {
		if index > 0 {
			builder.write_string(', ')
		}
		builder.write_string(parameter.serialized())
	}
	builder.write_u8(`)`)
	if rule.kind_data().function_return_type.type() != .universal {
		builder.write_string(' returns ')
		builder.write_string(serialize_a_css_type(rule.kind_data().function_return_type))
	}
	builder.write_string(' {')
	if rules := rule.rules {
		for child in rules.rules {
			serialized := child.serialized()
			if serialized.len > 0 {
				builder.write_u8(` `)
				builder.write_string(serialized)
			}
		}
	}
	builder.write_string(' }')
	return builder.str()
}
