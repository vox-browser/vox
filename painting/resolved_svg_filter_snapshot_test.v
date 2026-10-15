module painting

$if gcboehm ? {
	fn C.GC_gcollect()
}

pub struct LegacyResolvedCSSFilter {
pub:
	operations        []ResolvedFilterOperation
	svg_filter        ?GfxFilter
	svg_filter_bounds ?Rect
}

pub fn (filter LegacyResolvedCSSFilter) has_filters() bool {
	return filter.operations.len > 0 || filter.svg_filter != none
}

pub fn (filter LegacyResolvedCSSFilter) has_svg_filters() bool {
	return filter.svg_filter != none
}

pub fn (filter LegacyResolvedCSSFilter) to_gfx_filter(device_scale f64) ?GfxFilter {
	mut operations := []GfxFilterOperation{}
	mut nodes := []GfxFilterNode{}
	mut root_id := ?int(none)
	mut bounds := ?Rect(none)
	for operation in filter.operations {
		match operation {
			BlurFilter {
				operations.prepend(GfxFilterOperation{
					kind:   'blur'
					first:  operation.radius * device_scale
					second: operation.radius * device_scale
				})
			}
			DropShadowFilter {
				operations.prepend(GfxFilterOperation{
					kind:   'drop-shadow'
					first:  operation.offset_x * device_scale
					second: operation.offset_y * device_scale
					third:  operation.radius * device_scale
					color:  operation.color
				})
			}
			ColorFilter {
				operations.prepend(GfxFilterOperation{
					kind:            'color'
					first:           operation.amount
					color_operation: operation.operation
				})
			}
			HueRotateFilter {
				operations.prepend(GfxFilterOperation{
					kind:  'hue-rotate'
					first: operation.angle_degrees
				})
			}
		}
	}
	if svg := filter.svg_filter {
		for operation in svg.operations.reverse() {
			operations.prepend(operation)
		}
		nodes = svg.nodes.clone()
		root_id = svg.root_id
		bounds = filter.svg_filter_bounds
	}
	if operations.len == 0 && root_id == none {
		return none
	}
	return GfxFilter{
		operations: operations
		nodes:      nodes
		root_id:    root_id
		bounds:     bounds
	}
}

pub fn (filter LegacyResolvedCSSFilter) dump() string {
	mut descriptions := []string{}
	for operation in filter.operations {
		descriptions << match operation {
			BlurFilter {
				'blur(${operation.radius})'
			}
			DropShadowFilter {
				'drop-shadow(${operation.offset_x} ${operation.offset_y} ${operation.radius})'
			}
			ColorFilter {
				'${operation.operation}(${operation.amount})'
			}
			HueRotateFilter {
				'hue-rotate(${operation.angle_degrees}deg)'
			}
		}
	}
	mut result := if descriptions.len > 0 { 'filters=(${descriptions.join(', ')})' } else { '' }
	if filter.svg_filter != none {
		result += ' svg_filter'
	}
	return result.trim_space()
}

fn svg_filter_snapshot_test_graph() GfxFilter {
	return GfxFilter{
		operations: [GfxFilterOperation{ kind: 'blur', first: 2 }]
		nodes:      [
			GfxFilterNode{
				id:                0
				kind:              'flood'
				input_ids:         [-1]
				parameters:        {
					'opacity': 0.25
				}
				string_parameters: {
					'mode': 'multiply'
				}
				color:             Color{12, 34, 56, 255}
				matrix:            [f64(1), 2, 3]
				color_tables:      [GfxFilterColorTable{ channel: 'R', values: [u8(4), 5, 6] }]
			},
		]
		root_id:    0
		bounds:     Rect{1, 2, 3, 4}
	}
}

fn svg_filter_snapshot_test_producer() ResolvedCSSFilter {
	return ResolvedCSSFilter.with_svg_filter([
		ResolvedFilterOperation(BlurFilter{ radius: 1.25 }),
	], svg_filter_snapshot_test_graph(), Rect{10, 20, 30, 40})
}

fn test_resolved_css_filter_keeps_css_only_values_without_a_svg_snapshot() {
	assert sizeof(ResolvedCSSFilter) == sizeof([]ResolvedFilterOperation) + sizeof(voidptr)
	empty := ResolvedCSSFilter{}
	assert empty.svg_filter_data == unsafe { nil }
	assert !empty.has_filters()
	assert !empty.has_svg_filters()
	assert empty.dump() == ''
	assert empty.to_gfx_filter(1) == none
	css_only := ResolvedCSSFilter.with_svg_filter([
		ResolvedFilterOperation(BlurFilter{ radius: 3 }),
	], none, none)
	assert css_only.svg_filter_data == unsafe { nil }
	assert css_only.has_filters()
	assert !css_only.has_svg_filters()
	assert css_only.operations.len == 1
	assert css_only.to_gfx_filter(2) or { panic('missing CSS filter') }.bounds == none
}

fn test_resolved_css_filter_snapshot_matches_legacy_methods_for_every_source_combination() {
	operations := [ResolvedFilterOperation(BlurFilter{
		radius: 3
	}), DropShadowFilter{
		offset_x: 2
		offset_y: -1
		radius:   4
		color:    Color{9, 8, 7, 255}
	}, ColorFilter{ operation: .contrast, amount: 1.5 }, HueRotateFilter{ angle_degrees: 90 }]
	graphs := [?GfxFilter(none), ?GfxFilter(GfxFilter{}), ?GfxFilter(svg_filter_snapshot_test_graph())]
	for css_operations in [false, true] {
		for graph in graphs {
			for bounds in [?Rect(none), ?Rect(Rect{10, 20, 30, 40})] {
				values := if css_operations { operations } else { []ResolvedFilterOperation{} }
				legacy := LegacyResolvedCSSFilter{
					operations:        values
					svg_filter:        graph
					svg_filter_bounds: bounds
				}
				actual := ResolvedCSSFilter.with_svg_filter(values, graph, bounds)
				assert actual.operations == legacy.operations
				assert actual.has_filters() == legacy.has_filters()
				assert actual.has_svg_filters() == legacy.has_svg_filters()
				assert actual.dump() == legacy.dump()
				assert actual.svg_filter_bounds() == legacy.svg_filter_bounds
				for scale in [f64(0), 0.5, 1, 2.25] {
					assert actual.to_gfx_filter(scale) == legacy.to_gfx_filter(scale)
				}
			}
		}
	}
}

fn test_resolved_css_filter_snapshot_retains_the_graph_after_producer_exit_and_collections() {
	filter := svg_filter_snapshot_test_producer()
	assert filter.svg_filter_data != unsafe { nil }
	copy := filter
	assert copy.svg_filter_data == filter.svg_filter_data
	for _ in 0 .. 3 {
		$if gcboehm ? { C.GC_gcollect() }
		gfx := copy.to_gfx_filter(2) or { panic('missing retained SVG filter') }
		assert gfx.operations.len == 2
		assert gfx.nodes[0].parameters['opacity'] == 0.25
		assert gfx.nodes[0].string_parameters['mode'] == 'multiply'
		assert gfx.nodes[0].color == Color{12, 34, 56, 255}
		assert gfx.nodes[0].matrix == [f64(1), 2, 3]
		assert gfx.nodes[0].color_tables[0].values == [u8(4), 5, 6]
		assert gfx.bounds or { panic('missing retained bounds') } == Rect{10, 20, 30, 40}
		retained := filter.svg_filter_data.filter or { panic('missing snapshot graph') }
		assert gfx.nodes.data != retained.nodes.data
	}
}

fn test_resolved_css_filter_snapshots_keep_target_bounds_independent_for_a_shared_graph() {
	graph := svg_filter_snapshot_test_graph()
	first := ResolvedCSSFilter.with_svg_filter([], graph, Rect{1, 2, 30, 40})
	second := ResolvedCSSFilter.with_svg_filter([], graph, Rect{5, 6, 70, 80})
	assert first.svg_filter_data != second.svg_filter_data
	for _ in 0 .. 3 {
		$if gcboehm ? { C.GC_gcollect() }
		first_value := first.to_gfx_filter(1) or { panic('missing first target') }
		second_value := second.to_gfx_filter(1) or { panic('missing second target') }
		assert first_value.bounds or { panic('missing first bounds') } == Rect{1, 2, 30, 40}
		assert second_value.bounds or { panic('missing second bounds') } == Rect{5, 6, 70, 80}
		assert first_value.nodes == second_value.nodes
		assert graph.bounds or { panic('missing source bounds') } == Rect{1, 2, 3, 4}
	}
}
