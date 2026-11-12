// Copyright (c) 2026, Vox contributors
// SPDX-License-Identifier: BSD-2-Clause
module shader

pub enum Stage {
	vertex
	fragment
}

pub struct Interface {
pub:
	name     string
	typ      string
	storage  string
	location int
}

pub struct Translation {
pub:
	source  string
	inputs  []Interface
	outputs []Interface
	version int
}

// The first direct-MSL slice deliberately rejects features it cannot lower.
// Callers must never interpret an unsupported declaration as an empty shader.
pub fn translate(source string, stage Stage) !Translation {
	processed := preprocess(source)!
	tokens := processed.tokens
	mut body := []string{}
	mut inputs := []Interface{}
	mut outputs := []Interface{}
	mut at := 0
	mut depth := 0
	mut main_count := 0
	mut precision := stage == .vertex
	version := processed.version
	for at < tokens.len {
		token := tokens[at]
		if token == '#' {
			return error('Preprocessor directives are not supported by the direct Metal slice yet')
		}
		if token in ['uniform', 'struct', 'layout', 'invariant', 'sampler2D', 'samplerCube'] {
			return error('Unsupported direct Metal declaration: ${token}')
		}
		if depth == 0 && token == 'precision' {
			if at + 3 >= tokens.len || tokens[at + 1] !in ['lowp', 'mediump', 'highp'] || tokens[at + 3] != ';' {
				return error('Invalid precision declaration')
			}
			if tokens[at + 2] == 'float' { precision = true }
			at += 4
			continue
		}
		if token in ['lowp', 'mediump', 'highp'] {
			at++
			continue
		}
		if depth == 0 && token in ['attribute', 'varying', 'in', 'out'] {
			if version == 100 && token in ['in', 'out'] {
				return error('ESSL 100 requires attribute/varying')
			}
			if version == 300 && token in ['attribute', 'varying'] {
				return error('Legacy interface in ESSL 300')
			}
			if token == 'attribute' && stage == .fragment { return error('Fragment attribute') }
			at++
			if at < tokens.len && tokens[at] in ['lowp', 'mediump', 'highp'] { at++ }
			if at + 2 >= tokens.len { return error('Incomplete interface declaration') }
			typ := tokens[at]
			metal_type(typ)!
			name := tokens[at + 1]
			if !identifier(name) || name.starts_with('gl_') || tokens[at + 2] != ';' {
				return error('Unsupported interface declaration')
			}
			is_input := token == 'attribute' || token == 'in' || (token == 'varying' && stage == .fragment)
			if inputs.any(it.name == name) || outputs.any(it.name == name) {
				return error('Duplicate interface: ${name}')
			}
			item := Interface{ name: name, typ: typ, storage: if is_input { 'in' } else { 'out' }, location: if is_input {
				inputs.len
			} else {
				outputs.len
			} }
			if is_input { inputs << item } else { outputs << item }
			at += 3
			continue
		}
		if token == 'main' && at > 0 && tokens[at - 1] == 'void' && depth == 0 {
			if at + 3 >= tokens.len || tokens[at + 1] != '(' || tokens[at + 2] != ')' || tokens[at + 3] != '{' {
				return error('Expected void main()')
			}
			main_count++
		}
		if token == '{' { depth++ }
		if token == '}' {
			depth--
			if depth < 0 { return error('Unbalanced braces') }
		}
		if token in ['double', 'uint', 'while', 'do', 'switch', 'discard', 'gl_FragData', 'gl_FragDepth',
			'gl_FragDepthEXT'] || token.starts_with('sampler') {
			return error('Unsupported direct Metal token: ${token}')
		}
		if token.starts_with('gl_') && token !in ['gl_Position', 'gl_PointSize', 'gl_FragColor',
			'gl_VertexID', 'gl_InstanceID'] {
			return error('Unsupported builtin: ${token}')
		}
		if stage == .vertex && token == 'gl_FragColor' {
			return error('Fragment builtin in vertex shader')
		}
		if version == 300 && token == 'gl_FragColor' {
			return error('gl_FragColor requires ESSL 100')
		}
		if version == 100 && token in ['gl_VertexID', 'gl_InstanceID'] {
			return error('Vertex IDs require ESSL 300')
		}
		body << if token == 'main' { 'run' } else { lower_token(token) }
		at++
	}
	if depth != 0 || main_count != 1 { return error('Shader must define exactly one void main()') }
	if !precision { return error('Fragment shader requires a default float precision') }
	mut lines := ['#include <metal_stdlib>', 'using namespace metal;', 'struct VoxState {']
	if stage == .vertex {
		lines << 'float4 gl_Position = float4(0.0); float gl_PointSize = 1.0; int gl_VertexID = 0; int gl_InstanceID = 0;'
	} else if version == 100 {
		lines << 'float4 gl_FragColor = float4(0.0);'
	}
	for item in inputs {
		lines << '${metal_type(item.typ)!} ${item.name} = ${metal_type(item.typ)!}(0);'
	}
	for item in outputs {
		lines << '${metal_type(item.typ)!} ${item.name} = ${metal_type(item.typ)!}(0);'
	}
	lines << body.join(' ')
	lines << '};'
	lines << 'struct VoxInput {'
	for item in inputs {
		attribute := if stage == .vertex {
			'attribute(${item.location})'
		} else {
			'user(v_${item.name})'
		}
		lines << '${metal_type(item.typ)!} ${item.name} [[${attribute}]];'
	}
	lines << '};'
	lines << 'struct VoxOutput {'
	if stage == .vertex {
		lines << 'float4 position [[position]]; float point_size [[point_size]];'
	} else if version == 100 {
		lines << 'float4 color [[color(0)]];'
	}
	for item in outputs {
		attribute := if stage == .vertex {
			'user(v_${item.name})'
		} else {
			'color(${item.location})'
		}
		lines << '${metal_type(item.typ)!} ${item.name} [[${attribute}]];'
	}
	lines << '};'
	qualifier := if stage == .vertex { 'vertex' } else { 'fragment' }
	mut args := []string{}
	if inputs.len > 0 { args << 'VoxInput input [[stage_in]]' }
	if stage == .vertex {
		args << 'uint vertex_id [[vertex_id]]'
		args << 'uint instance_id [[instance_id]]'
	}
	lines << '${qualifier} VoxOutput vox_main(${args.join(', ')}) { VoxState state;'
	for item in inputs { lines << 'state.${item.name} = input.${item.name};' }
	if stage == .vertex {
		lines << 'state.gl_VertexID = int(vertex_id); state.gl_InstanceID = int(instance_id);'
	}
	lines << 'state.run(); VoxOutput result;'
	if stage == .vertex {
		lines << 'result.position = state.gl_Position; result.position.y = -result.position.y; result.position.z = (result.position.z + result.position.w) * 0.5; result.point_size = state.gl_PointSize;'
	} else if version == 100 {
		lines << 'result.color = state.gl_FragColor;'
	}
	for item in outputs { lines << 'result.${item.name} = state.${item.name};' }
	lines << 'return result; }'
	return Translation{ source: lines.join('\n'), inputs: inputs, outputs: outputs, version: version }
}

pub fn link(vertex Translation, fragment Translation) ! {
	if vertex.version != fragment.version {
		return error('Vertex and fragment ESSL versions differ')
	}
	for input in fragment.inputs {
		matches := vertex.outputs.filter(it.name == input.name)
		if matches.len != 1 || matches[0].typ != input.typ {
			return error('Varying mismatch: ${input.name}')
		}
	}
}

fn metal_type(typ string) !string {
	if typ in ['void', 'float', 'int', 'bool'] { return typ }
	for prefix, replacement in {
		'vec':  'float'
		'ivec': 'int'
		'bvec': 'bool'
	} {
		if typ.len == prefix.len + 1 && typ.starts_with(prefix) && typ[typ.len - 1] >= `2` && typ[typ.len - 1] <= `4` {
			return replacement + typ[typ.len - 1..]
		}
	}
	if typ in ['mat2', 'mat3', 'mat4'] { return 'float' + typ[3..] + 'x' + typ[3..] }
	return error('Unsupported shader type: ${typ}')
}

fn lower_token(token string) string {
	return metal_type(token) or { token }
}

fn identifier(text string) bool {
	if text.len == 0 || !(text[0].is_letter() || text[0] == `_`) { return false }
	for c in text { if !(c.is_alnum() || c == `_`) { return false } }
	return true
}

// Tokens preserve compound operators and numeric literals; comments never
// contribute declarations or interface names. Invalid bytes fail closed.
fn lex(source string) ![]string {
	if source.len > 1024 * 1024 { return error('Shader exceeds the source limit') }
	mut tokens := []string{}
	mut at := 0
	for at < source.len {
		c := source[at]
		if c.is_space() {
			at++
			continue
		}
		if c == `/` && at + 1 < source.len && source[at + 1] == `/` {
			for at < source.len && source[at] != `\n` { at++ }
			continue
		}
		if c == `/` && at + 1 < source.len && source[at + 1] == `*` {
			at += 2
			for at + 1 < source.len && !(source[at] == `*` && source[at + 1] == `/`) { at++ }
			if at + 1 >= source.len { return error('Unterminated shader comment') }
			at += 2
			continue
		}
		begin := at
		if c.is_letter() || c == `_` {
			at++
			for at < source.len && (source[at].is_alnum() || source[at] == `_`) { at++ }
		} else if c.is_digit() || (c == `.` && at + 1 < source.len && source[at + 1].is_digit()) {
			at++
			for at < source.len && (source[at].is_alnum() || source[at] == `.` || (source[at] in [
				`+`,
				`-`,
			] && source[at - 1] in [`e`, `E`])) {
				at++
			}
		} else if c in [`{`, `}`, `(`, `)`, `[`, `]`, `;`, `,`, `.`, `+`, `-`, `*`, `/`, `=`, `<`,
			`>`, `!`, `?`, `:`, `&`, `|`, `%`, `#`, `^`, `~`] {
			at++
			if at < source.len && source[begin..at + 1] in ['++', '--', '+=', '-=', '*=', '/=',
				'==', '!=', '<=', '>=', '&&', '||', '<<', '>>'] {
				at++
			}
		} else {
			return error('Invalid shader byte at ${at}')
		}
		tokens << source[begin..at]
	}
	return tokens
}
