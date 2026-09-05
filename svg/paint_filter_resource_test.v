module svg

fn test_gradient_stop_normalization_and_inheritance() {
	stops := normalized_stops([Stop{ offset: 0.7 }, Stop{ offset: 0.2 }, Stop{ offset: 2 }])
	assert stops.map(it.offset) == [0.7, 0.7, 1.0]
	gradients := {
		'base':  LinearGradient{
			id: 'base'
			x1: percentage(10)
			units: .user_space_on_use
			stops: [Stop{ offset: 0 }, Stop{ offset: 1 }]
		}
		'child': LinearGradient{
			id: 'child'
			href: '#base'
			x2: percentage(80)
		}
	}
	resolved := resolve_linear_gradient('child', gradients) or { ResolvedLinearGradient{} }
	assert resolved.x1 == percentage(10)
	assert resolved.x2 == percentage(80)
	assert resolved.units == .user_space_on_use
	assert resolved.stops.len == 2
}

fn test_gradient_and_pattern_cycle_detection() {
	cyclic_gradients := {
		'a': LinearGradient{
			id: 'a'
			href: '#b'
		}
		'b': LinearGradient{
			id: 'b'
			href: '#a'
		}
	}
	// A cycle stops inheritance but leaves the referring element's defaults usable.
	assert resolve_linear_gradient('a', cyclic_gradients) != none
	patterns := {
		'a': Pattern{
			id: 'a'
			href: '#b'
		}
		'b': Pattern{
			id: 'b'
			href: '#a'
		}
	}
	assert pattern_content_id('a', patterns) == none
}

fn test_radial_gradient_and_pattern_inheritance() {
	radials := {
		'base':  LinkedRadialGradient{
			id: 'base'
			cx: percentage(25)
			units: .user_space_on_use
			stops: [Stop{ offset: 0 }, Stop{ offset: 1 }]
		}
		'child': LinkedRadialGradient{
			id: 'child'
			href: '#base'
			fy: percentage(80)
		}
	}
	radial := resolve_radial_gradient('child', radials) or { ResolvedRadialGradient{} }
	assert radial.cx == percentage(25)
	assert radial.fx == percentage(25)
	assert radial.fy == percentage(80)
	assert radial.r == percentage(50)
	invalid_radius := resolve_radial_gradient('invalid', {
		'invalid': LinkedRadialGradient{
			id: 'invalid'
			r: number(-1)
			fr: percentage(-10)
		}
	}) or { ResolvedRadialGradient{} }
	assert invalid_radius.r == percentage(50)
	assert invalid_radius.fr == percentage(0)
	patterns := {
		'base':  Pattern{
			id: 'base'
			width: percentage(20)
			content_units: .object_bounding_box
			has_children: true
		}
		'child': Pattern{
			id: 'child'
			href: '#base'
			x: number(4)
		}
	}
	pattern := resolve_pattern('child', patterns) or { ResolvedPattern{} }
	assert pattern.x == number(4)
	assert pattern.width == percentage(20)
	assert pattern.content_units == .object_bounding_box
	assert pattern.content_id or { '' } == 'base'
}

fn test_component_transfer_tables() {
	identity := ComponentTransfer{
		type_: .identity
	}.color_table()
	assert identity[0] == 0
	assert identity[127] == 127
	assert identity[255] == 255
	linear := ComponentTransfer{
		type_: .linear
		slope: 0.5
		intercept: 0.25
	}.color_table()
	assert linear[0] == 63
	assert linear[255] == 191
	table := ComponentTransfer{
		type_: .table
		table_values: [0.0, 1.0]
	}.color_table()
	assert table[128] == 128
	discrete := ComponentTransfer{
		type_: .discrete
		table_values: [0.0, 1.0]
	}.color_table()
	assert discrete[127] == 0
	assert discrete[128] == 255
}

fn test_filter_enumerations_defaults_and_pairs() {
	assert composite_operator('') == .unknown
	assert composite_operator('arithmetic') == .arithmetic
	assert color_matrix_type('hueRotate') == .hue_rotate
	assert channel_selector('bogus') == .alpha
	assert morphology_operator('ERODE') == .erode
	assert turbulence_type('fractalNoise') == .fractal_noise
	assert stitch_type('other') == .no_stitch
	assert number_optional_number('3', 0) == NumberPair{
		x: 3
		y: 3
	}
	assert number_optional_number('4,5', 2) == NumberPair{
		x: 2
		y: 2
	}
	assert number_optional_number('50% 25%', 0) == NumberPair{
		x: 0.5
		y: 0.25
	}
	primitive := FilterPrimitive{
		kind: 'feDropShadow'
		parameters: {
			'stdDeviation': '4 5'
		}
	}
	values := primitive.normalized_parameters()
	assert values['dx'] == 2
	assert values['stdDeviationY'] == 5
	percentage_offset := FilterPrimitive{
		kind: 'feOffset'
		parameters: {
			'dx': '50%'
		}
	}.normalized_parameters()
	assert percentage_offset['dx'] == 0.5
}

fn test_filter_region_resolution() {
	target := Rect{
		x: 10
		y: 20
		width: 100
		height: 50
	}
	resolved := FilterRegion{}.resolve(target)
	assert resolved == Rect{
		x: 0
		y: 15
		width: 120
		height: 60
	}
}

fn test_filter_graph_sequential_and_named_inputs() {
	graph := build_filter_graph([
		FilterPrimitive{ kind: 'feFlood', result: 'paint' },
		FilterPrimitive{ kind: 'feGaussianBlur', in1: 'SourceAlpha', result: 'blur' },
		FilterPrimitive{ kind: 'feBlend', in1: 'paint', in2: 'blur' },
	])
	assert graph.nodes.len == 4
	assert graph.nodes[1].kind == 'color-matrix'
	assert graph.nodes[1].matrix == source_alpha_matrix()
	assert graph.nodes[2].kind == 'blur'
	assert graph.nodes[2].input_ids == [1]
	// Gfx::Filter::blend takes background (in2) before foreground (in1).
	assert graph.nodes[3].input_ids == [2, 0]
	assert graph.root_id or { -1 } == 3
	assert graph.named_nodes['blur'] == 2
}

fn test_filter_graph_expands_drop_shadow_like_svg_filter_element() {
	graph := build_filter_graph([
		FilterPrimitive{
			kind: 'feDropShadow'
			in1: 'SourceGraphic'
			result: 'shadow'
			parameters: {
				'dx':            '7'
				'dy':            '-3'
				'stdDeviation':  '2 4'
				'flood-color':   '#123456'
				'flood-opacity': '.6'
			}
		},
	])
	assert graph.nodes.map(it.kind) == ['color-matrix', 'blur', 'offset', 'flood', 'blend', 'merge']
	assert graph.nodes[0].matrix == source_alpha_matrix()
	assert graph.nodes[1].input_ids == [0]
	assert graph.nodes[1].parameters['radius_x'] == 2
	assert graph.nodes[1].parameters['radius_y'] == 4
	assert graph.nodes[2].input_ids == [1]
	assert graph.nodes[2].parameters['dx'] == 7
	assert graph.nodes[2].parameters['dy'] == -3
	assert graph.nodes[3].color == u32(0xff123456)
	assert graph.nodes[3].parameters['opacity'] == 0.6
	assert graph.nodes[4].input_ids == [2, 3]
	assert graph.nodes[4].string_parameters['mode'] == 'source-in'
	assert graph.nodes[5].input_ids == [4, -1]
	assert graph.root_id? == 5
	assert graph.named_nodes['shadow'] == 5
}

fn test_filter_graph_retains_color_matrix_component_tables_and_merge_inputs() {
	matrix_values := '1 0 0 0 0, 0 1 0 0 0, 0 0 1 0 0, 0 0 0 1 0'
	graph := build_filter_graph([
		FilterPrimitive{
			kind: 'feColorMatrix'
			result: 'matrix'
			parameters: {
				'type':   'matrix'
				'values': matrix_values
			}
		},
		FilterPrimitive{
			kind: 'feComponentTransfer'
			in1: 'matrix'
			result: 'transfer'
			children: [
				FilterPrimitive{
					kind: 'feFuncR'
					parameters: {
						'type':  'linear'
						'slope': '2'
					}
				},
				FilterPrimitive{
					kind: 'feFuncR'
					parameters: {
						'type':        'discrete'
						'tableValues': '0 1'
					}
				},
				FilterPrimitive{
					kind: 'feFuncA'
					parameters: {
						'type':      'gamma'
						'amplitude': '.5'
						'exponent':  '2'
					}
				},
			]
		},
		FilterPrimitive{
			kind: 'feMerge'
			children: [
				FilterPrimitive{ kind: 'feMergeNode', in1: 'matrix' },
				FilterPrimitive{ kind: 'feMergeNode', in1: 'transfer' },
			]
		},
	])
	assert graph.nodes.len == 3
	assert graph.nodes[0].kind == 'color-matrix'
	assert graph.nodes[0].matrix.len == 20
	assert graph.nodes[1].kind == 'color-table'
	assert graph.nodes[1].color_tables.len == 2
	// The last feFuncR wins, and unspecified green/blue functions stay identity
	// by being absent from LibGfx::Filter::color_table's optional arguments.
	red := graph.nodes[1].color_tables.filter(it.channel == 'red')[0]
	assert red.values[127] == 0
	assert red.values[128] == 255
	assert graph.nodes[2].kind == 'merge'
	assert graph.nodes[2].input_ids == [0, 1]
}

fn test_filter_graph_retains_composite_and_displacement_parameters() {
	graph := build_filter_graph([
		FilterPrimitive{ kind: 'feFlood', result: 'paint' },
		FilterPrimitive{
			kind: 'feComposite'
			in1: 'paint'
			in2: 'missing-name'
			result: 'math'
			parameters: {
				'operator': 'arithmetic'
				'k1':       '.1'
				'k2':       '.2'
				'k3':       '.3'
				'k4':       '.4'
			}
		},
		FilterPrimitive{
			kind: 'feDisplacementMap'
			in1: 'math'
			in2: 'SourceAlpha'
			parameters: {
				'scale':            '12'
				'xChannelSelector': 'R'
				'yChannelSelector': 'B'
			}
		},
	])
	assert graph.nodes[1].kind == 'arithmetic'
	// An unknown named input falls back to the preceding result.
	assert graph.nodes[1].input_ids == [0, 0]
	assert graph.nodes[1].parameters == {
		'k1': 0.1
		'k2': 0.2
		'k3': 0.3
		'k4': 0.4
	}
	assert graph.nodes[2].kind == 'color-matrix'
	assert graph.nodes[3].kind == 'displacement-map'
	assert graph.nodes[3].input_ids == [1, 2]
	assert graph.nodes[3].parameters['scale'] == 12
	assert graph.nodes[3].string_parameters['x_channel'] == 'R'
	assert graph.nodes[3].string_parameters['y_channel'] == 'B'
}

fn test_filter_graph_retains_color_matrix_variants_morphology_and_turbulence() {
	graph := build_filter_graph([
		FilterPrimitive{ kind: 'feFlood', result: 'source' },
		FilterPrimitive{
			kind: 'feColorMatrix'
			in1: 'source'
			result: 'invalid-is-identity'
			parameters: {
				'type':   'matrix'
				'values': '1 0 0'
			}
		},
		FilterPrimitive{
			kind: 'feColorMatrix'
			in1: 'invalid-is-identity'
			parameters: {
				'type':   'saturate'
				'values': '.25'
			}
		},
		FilterPrimitive{
			kind: 'feColorMatrix'
			parameters: {
				'type':   'hueRotate'
				'values': '45'
			}
		},
		FilterPrimitive{
			kind: 'feColorMatrix'
			result: 'alpha'
			parameters: {
				'type': 'luminanceToAlpha'
			}
		},
		FilterPrimitive{
			kind: 'feMorphology'
			in1: 'alpha'
			parameters: {
				'operator': 'dilate'
				'radius':   '3 5'
			}
		},
		FilterPrimitive{
			kind: 'feOffset'
			parameters: {
				'dx': '-2'
				'dy': '6'
			}
		},
		FilterPrimitive{
			kind: 'feTurbulence'
			result: 'noise'
			parameters: {
				'baseFrequency': '.1 .2'
				'numOctaves':    '3'
				'seed':          '4'
				'type':          'fractalNoise'
				'stitchTiles':   'stitch'
				'width':         '120'
				'height':        '80'
			}
		},
	])
	assert graph.nodes.map(it.kind) == ['flood', 'saturate', 'hue-rotate', 'color-matrix', 'dilate',
		'offset', 'turbulence']
	assert graph.named_nodes['invalid-is-identity'] == 0
	assert graph.nodes[1].parameters['amount'] == 0.25
	assert graph.nodes[2].parameters['angle_degrees'] == 45
	assert graph.nodes[3].matrix == luminance_to_alpha_matrix()
	assert graph.nodes[4].parameters['radius_x'] == 3
	assert graph.nodes[4].parameters['radius_y'] == 5
	assert graph.nodes[5].parameters['dx'] == -2
	assert graph.nodes[5].parameters['dy'] == 6
	assert graph.nodes[6].parameters['base_frequency_x'] == 0.1
	assert graph.nodes[6].parameters['base_frequency_y'] == 0.2
	assert graph.nodes[6].parameters['num_octaves'] == 3
	assert graph.nodes[6].parameters['seed'] == 4
	assert graph.nodes[6].parameters['tile_width'] == 120
	assert graph.nodes[6].parameters['tile_height'] == 80
	assert graph.nodes[6].string_parameters['type'] == 'fractal-noise'
	assert graph.nodes[6].string_parameters['stitch'] == 'stitch'
}

fn test_filter_graph_non_arithmetic_composite_uses_libgfx_blend_mapping() {
	graph := build_filter_graph([
		FilterPrimitive{ kind: 'feFlood', result: 'first' },
		FilterPrimitive{ kind: 'feFlood', result: 'second' },
		FilterPrimitive{
			kind: 'feComposite'
			in1: 'first'
			in2: 'second'
			parameters: {
				'operator': 'atop'
			}
		},
	])
	assert graph.nodes[2].kind == 'blend'
	assert graph.nodes[2].input_ids == [1, 0]
	assert graph.nodes[2].string_parameters['mode'] == 'source-atop'
}

fn test_image_use_script_and_decoded_resource_lifecycle() {
	mut image := ImageResource{}
	image.update_href('cat.png')
	assert image.state == .loading
	image.complete(640, 320)
	assert image.state == .ready
	assert image.intrinsic_aspect_ratio() or { 0 } == 2
	document := {
		'shape': Element{
			tag: 'circle'
			attributes: {
				'r': '10'
			}
		}
	}
	mut use := UseReference{}
	use.process_url('#shape', document)
	assert use.state == .ready
	assert use.shadow or { Element{} }.tag == 'circle'
	cyclic_document := {
		'a': Element{
			tag: 'use'
			attributes: {
				'href': '#b'
			}
		}
		'b': Element{
			tag: 'g'
			children: [
				Element{
					tag: 'use'
					attributes: {
						'href': '#a'
					}
				},
			]
		}
	}
	mut cyclic_use := UseReference{}
	cyclic_use.process_url('#a', cyclic_document)
	assert cyclic_use.state == .failed
	mut script := ScriptResource{
		text: 'answer = 42'
	}
	assert script.process() or { '' } == 'answer = 42'
	assert script.process() == none
	decoded := DecodedImageData{
		viewbox: ViewBox{
			width: 300
			height: 150
		}
	}
	assert decoded.intrinsic_aspect_ratio() or { 0 } == 2
}
