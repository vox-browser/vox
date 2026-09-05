module svg

import math

pub enum ComponentTransferType {
	unknown
	identity
	table
	discrete
	linear
	gamma
}

pub struct ComponentTransfer {
pub:
	type_        ComponentTransferType
	table_values []f64
	slope        f64 = 1
	intercept    f64
	amplitude    f64 = 1
	exponent     f64 = 1
	offset       f64
}

pub fn parse_component_transfer_type(value string) ComponentTransferType {
	return match value {
		'identity' { .identity }
		'table' { .table }
		'discrete' { .discrete }
		'linear' { .linear }
		'gamma' { .gamma }
		else { .unknown }
	}
}

pub fn (transfer ComponentTransfer) color_table() []u8 {
	mut result := []u8{len: 256}
	for index in 0 .. 256 {
		input := f64(index) / 255.0
		mut output := input
		match transfer.type_ {
			.unknown, .identity {}
			.table {
				if transfer.table_values.len > 0 {
					segments := f64(transfer.table_values.len - 1)
					if index == 255 || segments == 0 {
						output = transfer.table_values.last()
					} else {
						segment := int(input * segments)
						progress := (input - f64(segment) / segments) * segments
						output = transfer.table_values[segment] + progress * (transfer.table_values[segment + 1] - transfer.table_values[segment])
					}
				}
			}
			.discrete {
				if transfer.table_values.len > 0 {
					position := if index == 255 {
						transfer.table_values.len - 1
					} else {
						int(input * f64(transfer.table_values.len))
					}
					output = transfer.table_values[position]
				}
			}
			.linear {
				output = transfer.slope * input + transfer.intercept
			}
			.gamma {
				output = transfer.amplitude * math.pow(input, transfer.exponent) + transfer.offset
			}
		}
		result[index] = u8(clamp(output, 0, 1) * 255)
	}
	return result
}

pub enum CompositeOperator {
	unknown
	over
	in_
	out
	atop
	xor
	lighter
	arithmetic
}

pub fn composite_operator(value string) CompositeOperator {
	return match value {
		'over' { .over }
		'in' { .in_ }
		'out' { .out }
		'atop' { .atop }
		'xor' { .xor }
		'lighter' { .lighter }
		'arithmetic' { .arithmetic }
		else { .unknown }
	}
}

pub enum ColorMatrixType {
	unknown
	matrix
	saturate
	hue_rotate
	luminance_to_alpha
}

pub fn color_matrix_type(value string) ColorMatrixType {
	return match value.to_lower() {
		'', 'matrix' { .matrix }
		'saturate' { .saturate }
		'huerotate' { .hue_rotate }
		'luminancetoalpha' { .luminance_to_alpha }
		else { .unknown }
	}
}

pub enum ChannelSelector {
	red
	green
	blue
	alpha
}

pub fn channel_selector(value string) ChannelSelector {
	return match value {
		'R' { .red }
		'G' { .green }
		'B' { .blue }
		else { .alpha }
	}
}

pub enum MorphologyOperator {
	erode
	dilate
}

pub fn morphology_operator(value string) MorphologyOperator {
	return if value.to_lower() == 'erode' { .erode } else { .dilate }
}

pub enum TurbulenceType {
	turbulence
	fractal_noise
}

pub enum StitchType {
	no_stitch
	stitch
}

pub fn turbulence_type(value string) TurbulenceType {
	return if value == 'fractalNoise' { .fractal_noise } else { .turbulence }
}

pub fn stitch_type(value string) StitchType {
	return if value == 'stitch' { .stitch } else { .no_stitch }
}

pub struct NumberPair {
pub:
	x f64
	y f64
}

pub fn number_optional_number(value string, initial f64) NumberPair {
	parts := value.split(' ')
	first := if parts.len > 0 { reflected_number(parts[0], initial) } else { initial }
	return NumberPair{
		x: first
		y: if parts.len > 1 && parts[1].len > 0 {
			reflected_number(parts[1], initial)
		} else {
			first
		}
	}
}

fn reflected_number(value string, initial f64) f64 {
	parsed := parse_number_percentage(value) or { return initial }
	return parsed.value
}

pub struct FilterRegion {
pub:
	x      NumberPercentage = percentage(-10)
	y      NumberPercentage = percentage(-10)
	width  NumberPercentage = percentage(120)
	height NumberPercentage = percentage(120)
	units  Units = .object_bounding_box
}

pub fn (region FilterRegion) resolve(target Rect) Rect {
	if region.units == .user_space_on_use {
		return Rect{
			x: region.x.resolve_relative_to(target.width)
			y: region.y.resolve_relative_to(target.height)
			width: region.width.resolve_relative_to(target.width)
			height: region.height.resolve_relative_to(target.height)
		}
	}
	return Rect{
		x: target.x + region.x.resolve_relative_to(target.width)
		y: target.y + region.y.resolve_relative_to(target.height)
		width: region.width.resolve_relative_to(target.width)
		height: region.height.resolve_relative_to(target.height)
	}
}

pub struct FilterPrimitive {
pub:
	kind       string
	in1        string
	in2        string
	result     string
	parameters map[string]string
	children   []FilterPrimitive
}

pub fn (primitive FilterPrimitive) normalized_parameters() map[string]f64 {
	mut values := map[string]f64{}
	match primitive.kind {
		'feGaussianBlur' {
			pair := number_optional_number(primitive.parameters['stdDeviation'] or { '' }, 0)
			values['stdDeviationX'] = pair.x
			values['stdDeviationY'] = pair.y
		}
		'feDropShadow' {
			pair := number_optional_number(primitive.parameters['stdDeviation'] or { '' }, 2)
			values['dx'] = reflected_number(primitive.parameters['dx'] or { '' }, 2)
			values['dy'] = reflected_number(primitive.parameters['dy'] or { '' }, 2)
			values['stdDeviationX'] = pair.x
			values['stdDeviationY'] = pair.y
		}
		'feOffset' {
			values['dx'] = reflected_number(primitive.parameters['dx'] or { '' }, 0)
			values['dy'] = reflected_number(primitive.parameters['dy'] or { '' }, 0)
		}
		'feMorphology' {
			pair := number_optional_number(primitive.parameters['radius'] or { '' }, 0)
			values['radiusX'] = pair.x
			values['radiusY'] = pair.y
		}
		'feTurbulence' {
			pair := number_optional_number(primitive.parameters['baseFrequency'] or { '' }, 0)
			values['baseFrequencyX'] = pair.x
			values['baseFrequencyY'] = pair.y
			values['numOctaves'] = f64(parse_integer(primitive.parameters['numOctaves'] or { '' }) or {
				1
			})
			values['seed'] = reflected_number(primitive.parameters['seed'] or { '' }, 0)
		}
		else {}
	}
	return values
}

pub struct FilterNode {
pub:
	id                int
	kind              string
	input_ids         []int
	parameters        map[string]f64
	string_parameters map[string]string
	color             u32
	matrix            []f64
	color_tables      []FilterColorTable
}

pub struct FilterColorTable {
pub:
	channel string
	values  []u8
}

pub struct FilterGraph {
pub:
	nodes       []FilterNode
	root_id     ?int
	named_nodes map[string]int
}

struct FilterGraphBuilder {
mut:
	nodes []FilterNode
	named map[string]int
	root  ?int
}

fn (mut builder FilterGraphBuilder) append_node(kind string, inputs []int, parameters map[string]f64, string_parameters map[string]string, color u32, matrix []f64, color_tables []FilterColorTable) int {
	id := builder.nodes.len
	builder.nodes << FilterNode{
		id: id
		kind: kind
		input_ids: inputs
		parameters: parameters
		string_parameters: string_parameters
		color: color
		matrix: matrix
		color_tables: color_tables
	}
	return id
}

fn source_alpha_matrix() []f64 {
	return [f64(0), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0]
}

fn luminance_to_alpha_matrix() []f64 {
	return [f64(0), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.2126, 0.7152, 0.0722, 0, 0]
}

fn (mut builder FilterGraphBuilder) resolve_input(name string) int {
	if name == 'SourceGraphic' {
		return -1
	}
	if name == 'SourceAlpha' {
		return builder.append_node('color-matrix', [-1], map[string]f64{}, map[string]string{}, 0, source_alpha_matrix(), [])
	}
	if id := builder.named[name] {
		return id
	}
	return builder.root or { -1 }
}

fn (mut builder FilterGraphBuilder) finish_primitive(primitive FilterPrimitive, id int) {
	builder.root = id
	if primitive.result.len > 0 {
		builder.named[primitive.result] = id
	}
}

fn filter_parameter(parameters map[string]string, name string, fallback f64) f64 {
	return parse_single_number(parameters[name] or { '' }) or { fallback }
}

fn component_transfer_from_primitive(primitive FilterPrimitive) ComponentTransfer {
	return ComponentTransfer{
		type_: parse_component_transfer_type(primitive.parameters['type'] or { '' })
		table_values: parse_number_sequence(primitive.parameters['tableValues'] or { '' }) or {
			[]f64{}
		}
		slope: filter_parameter(primitive.parameters, 'slope', 1)
		intercept: filter_parameter(primitive.parameters, 'intercept', 0)
		amplitude: filter_parameter(primitive.parameters, 'amplitude', 1)
		exponent: filter_parameter(primitive.parameters, 'exponent', 1)
		offset: filter_parameter(primitive.parameters, 'offset', 0)
	}
}

fn component_transfer_channel(kind string) string {
	return match kind {
		'feFuncA' { 'alpha' }
		'feFuncR' { 'red' }
		'feFuncG' { 'green' }
		'feFuncB' { 'blue' }
		else { '' }
	}
}

fn normalized_blend_mode(value string) string {
	mode := value.to_lower()
	return if mode in ['normal', 'multiply', 'screen', 'overlay', 'darken', 'lighten', 'color-dodge',
		'color-burn', 'hard-light', 'soft-light', 'difference', 'exclusion', 'hue', 'saturation',
		'color', 'luminosity', 'plus-darker', 'plus-lighter'] {
		mode
	} else {
		'normal'
	}
}

fn graph_channel_selector(value string) string {
	return match channel_selector(value) {
		.red { 'R' }
		.green { 'G' }
		.blue { 'B' }
		.alpha { 'A' }
	}
}

fn (mut builder FilterGraphBuilder) process(primitive FilterPrimitive) {
	match primitive.kind {
		'feFlood' {
			id := builder.append_node('flood', [], {
				'opacity': filter_parameter(primitive.parameters, 'flood-opacity', 1)
			}, map[string]string{}, parse_svg_color(primitive.parameters['flood-color'] or {
				'black'
			}) or { u32(0xff000000) }, [], [])
			builder.finish_primitive(primitive, id)
		}
		'feBlend' {
			foreground := builder.resolve_input(primitive.in1)
			background := builder.resolve_input(primitive.in2)
			id := builder.append_node('blend', [background, foreground], map[string]f64{}, {
				'mode': normalized_blend_mode(primitive.parameters['mode'] or { 'normal' })
			}, 0, [], [])
			builder.finish_primitive(primitive, id)
		}
		'feComponentTransfer' {
			input := builder.resolve_input(primitive.in1)
			mut last_by_channel := map[string]ComponentTransfer{}
			for child in primitive.children {
				channel := component_transfer_channel(child.kind)
				if channel.len > 0 {
					last_by_channel[channel] = component_transfer_from_primitive(child)
				}
			}
			mut tables := []FilterColorTable{}
			for channel in ['alpha', 'red', 'green', 'blue'] {
				if transfer := last_by_channel[channel] {
					tables << FilterColorTable{
						channel: channel
						values: transfer.color_table()
					}
				}
			}
			id := builder.append_node('color-table', [input], map[string]f64{}, map[string]string{}, 0, [], tables)
			builder.finish_primitive(primitive, id)
		}
		'feComposite' {
			foreground := builder.resolve_input(primitive.in1)
			background := builder.resolve_input(primitive.in2)
			operator_ := composite_operator(primitive.parameters['operator'] or { '' })
			if operator_ == .arithmetic {
				id := builder.append_node('arithmetic', [background, foreground], {
					'k1': filter_parameter(primitive.parameters, 'k1', 0)
					'k2': filter_parameter(primitive.parameters, 'k2', 0)
					'k3': filter_parameter(primitive.parameters, 'k3', 0)
					'k4': filter_parameter(primitive.parameters, 'k4', 0)
				}, map[string]string{}, 0, [], [])
				builder.finish_primitive(primitive, id)
			} else {
				mode := match operator_ {
					.in_ { 'source-in' }
					.out { 'destination-out' }
					.atop { 'source-atop' }
					.xor { 'xor' }
					.lighter { 'lighter' }
					else { 'source-over' }
				}
				id := builder.append_node('blend', [background, foreground], map[string]f64{}, {
					'mode': mode
				}, 0, [], [])
				builder.finish_primitive(primitive, id)
			}
		}
		'feGaussianBlur' {
			input := builder.resolve_input(primitive.in1)
			pair := number_optional_number(primitive.parameters['stdDeviation'] or { '' }, 0)
			id := builder.append_node('blur', [input], {
				'radius_x': pair.x
				'radius_y': pair.y
			}, map[string]string{}, 0, [], [])
			builder.finish_primitive(primitive, id)
		}
		'feColorMatrix' {
			input := builder.resolve_input(primitive.in1)
			type_ := (primitive.parameters['type'] or { '' }).to_lower()
			values_text := primitive.parameters['values'] or { '' }
			if type_ == '' || type_ == 'matrix' {
				values := parse_number_sequence(values_text) or { []f64{} }
				if values.len == 20 {
					id := builder.append_node('color-matrix', [input], map[string]f64{}, map[string]string{}, 0, values, [])
					builder.finish_primitive(primitive, id)
				} else if input != -1 {
					builder.finish_primitive(primitive, input)
				}
			} else if type_ == 'saturate' {
				id := builder.append_node('saturate', [input], {
					'amount': filter_parameter(primitive.parameters, 'values', 1)
				}, map[string]string{}, 0, [], [])
				builder.finish_primitive(primitive, id)
			} else if type_ == 'huerotate' {
				id := builder.append_node('hue-rotate', [input], {
					'angle_degrees': filter_parameter(primitive.parameters, 'values', 0)
				}, map[string]string{}, 0, [], [])
				builder.finish_primitive(primitive, id)
			} else if type_ == 'luminancetoalpha' {
				id := builder.append_node('color-matrix', [input], map[string]f64{}, map[string]string{}, 0, luminance_to_alpha_matrix(), [])
				builder.finish_primitive(primitive, id)
			}
		}
		'feImage' {
			// SVGFEImageElement.cpp skips the primitive until a decoded bitmap and
			// content rectangle are both available; the renderer attaches those.
		}
		'feMerge' {
			mut inputs := []int{}
			for child in primitive.children {
				if child.kind == 'feMergeNode' {
					inputs << builder.resolve_input(child.in1)
				}
			}
			id := builder.append_node('merge', inputs, map[string]f64{}, map[string]string{}, 0, [], [])
			builder.finish_primitive(primitive, id)
		}
		'feMorphology' {
			input := builder.resolve_input(primitive.in1)
			pair := number_optional_number(primitive.parameters['radius'] or { '' }, 0)
			id := builder.append_node(if morphology_operator(primitive.parameters['operator'] or {
				'erode'
			}) == .erode {
				'erode'
			} else {
				'dilate'
			}, [input], {
				'radius_x': pair.x
				'radius_y': pair.y
			}, map[string]string{}, 0, [], [])
			builder.finish_primitive(primitive, id)
		}
		'feOffset' {
			input := builder.resolve_input(primitive.in1)
			id := builder.append_node('offset', [input], {
				'dx': filter_parameter(primitive.parameters, 'dx', 0)
				'dy': filter_parameter(primitive.parameters, 'dy', 0)
			}, map[string]string{}, 0, [], [])
			builder.finish_primitive(primitive, id)
		}
		'feDropShadow' {
			input := builder.resolve_input(primitive.in1)
			alpha := builder.append_node('color-matrix', [input], map[string]f64{}, map[string]string{}, 0, source_alpha_matrix(), [])
			pair := number_optional_number(primitive.parameters['stdDeviation'] or { '' }, 2)
			blurred := builder.append_node('blur', [alpha], {
				'radius_x': pair.x
				'radius_y': pair.y
			}, map[string]string{}, 0, [], [])
			offset := builder.append_node('offset', [blurred], {
				'dx': filter_parameter(primitive.parameters, 'dx', 2)
				'dy': filter_parameter(primitive.parameters, 'dy', 2)
			}, map[string]string{}, 0, [], [])
			flood := builder.append_node('flood', [], {
				'opacity': filter_parameter(primitive.parameters, 'flood-opacity', 1)
			}, map[string]string{}, parse_svg_color(primitive.parameters['flood-color'] or {
				'black'
			}) or { u32(0xff000000) }, [], [])
			colored := builder.append_node('blend', [offset, flood], map[string]f64{}, {
				'mode': 'source-in'
			}, 0, [], [])
			merged := builder.append_node('merge', [colored, input], map[string]f64{}, map[string]string{}, 0, [], [])
			builder.finish_primitive(primitive, merged)
		}
		'feTurbulence' {
			pair := number_optional_number(primitive.parameters['baseFrequency'] or { '' }, 0)
			id := builder.append_node('turbulence', [], {
				'base_frequency_x': pair.x
				'base_frequency_y': pair.y
				'num_octaves':      f64(parse_integer(primitive.parameters['numOctaves'] or { '' }) or {
					1
				})
				'seed':             filter_parameter(primitive.parameters, 'seed', 0)
				'tile_width':       filter_parameter(primitive.parameters, 'width', 0)
				'tile_height':      filter_parameter(primitive.parameters, 'height', 0)
			}, {
				'type':   if turbulence_type(primitive.parameters['type'] or { '' }) == .fractal_noise {
					'fractal-noise'
				} else {
					'turbulence'
				}
				'stitch': if stitch_type(primitive.parameters['stitchTiles'] or { '' }) == .stitch {
					'stitch'
				} else {
					'no-stitch'
				}
			}, 0, [], [])
			builder.finish_primitive(primitive, id)
		}
		'feDisplacementMap' {
			color := builder.resolve_input(primitive.in1)
			displacement := builder.resolve_input(primitive.in2)
			id := builder.append_node('displacement-map', [color, displacement], {
				'scale': filter_parameter(primitive.parameters, 'scale', 0)
			}, {
				'x_channel': graph_channel_selector(primitive.parameters['xChannelSelector'] or {
					'A'
				})
				'y_channel': graph_channel_selector(primitive.parameters['yChannelSelector'] or {
					'A'
				})
			}, 0, [], [])
			builder.finish_primitive(primitive, id)
		}
		else {}
	}
}

// Direct graph translation of SVGFilterElement::gfx_filter(). SourceGraphic is
// the renderer's implicit input (-1); SourceAlpha is materialized as the same
// 4x5 alpha-extraction matrix used by LibGfx. Nodes use LibGfx operation names
// and constructor input order, so no renderer has to reconstruct SVG semantics.
pub fn build_filter_graph(primitives []FilterPrimitive) FilterGraph {
	mut builder := FilterGraphBuilder{
		nodes: []FilterNode{cap: primitives.len}
		named: map[string]int{}
	}
	for primitive in primitives {
		builder.process(primitive)
	}
	return FilterGraph{
		nodes: builder.nodes
		root_id: builder.root
		named_nodes: builder.named
	}
}
