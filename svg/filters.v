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
						output = transfer.table_values[segment] +
							progress * (transfer.table_values[segment + 1] - transfer.table_values[segment])
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
	arithmetic
}

pub fn composite_operator(value string) CompositeOperator {
	return match value {
		'over', '' { .over }
		'in' { .in_ }
		'out' { .out }
		'atop' { .atop }
		'xor' { .xor }
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
	units  Units            = .object_bounding_box
}

pub fn (region FilterRegion) resolve(target Rect) Rect {
	if region.units == .user_space_on_use {
		return Rect{
			x:      region.x.resolve_relative_to(target.width)
			y:      region.y.resolve_relative_to(target.height)
			width:  region.width.resolve_relative_to(target.width)
			height: region.height.resolve_relative_to(target.height)
		}
	}
	return Rect{
		x:      target.x + region.x.resolve_relative_to(target.width)
		y:      target.y + region.y.resolve_relative_to(target.height)
		width:  region.width.resolve_relative_to(target.width)
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
	id         int
	kind       string
	input_ids  []int
	parameters map[string]f64
}

pub struct FilterGraph {
pub:
	nodes       []FilterNode
	root_id     ?int
	named_nodes map[string]int
}

// build_filter_graph translates SVG's sequential filter input/result rules to
// a renderer-neutral graph. An empty input selects the previous result;
// SourceGraphic is represented by -1 and SourceAlpha by -2.
pub fn build_filter_graph(primitives []FilterPrimitive) FilterGraph {
	mut nodes := []FilterNode{cap: primitives.len}
	mut named := map[string]int{}
	mut root := ?int(none)
	for index, primitive in primitives {
		mut inputs := []int{}
		if primitive.kind !in ['feFlood', 'feImage', 'feTurbulence'] {
			inputs << resolve_filter_input(primitive.in1, root, named)
		}
		if primitive.kind in ['feBlend', 'feComposite', 'feDisplacementMap'] {
			inputs << resolve_filter_input(primitive.in2, root, named)
		}
		node := FilterNode{
			id:         index
			kind:       primitive.kind
			input_ids:  inputs
			parameters: primitive.normalized_parameters()
		}
		nodes << node
		root = index
		if primitive.result.len > 0 {
			named[primitive.result] = index
		}
	}
	return FilterGraph{
		nodes:       nodes
		root_id:     root
		named_nodes: named
	}
}

fn resolve_filter_input(name string, root ?int, named map[string]int) int {
	if name == 'SourceGraphic' {
		return -1
	}
	if name == 'SourceAlpha' {
		return -2
	}
	if id := named[name] {
		return id
	}
	return root or { -1 }
}
