module css

import math
import platform

fn calculated_export_numeric(kind CalcNumericKind, number f64, unit string) CalcNode {
	return CalcNode(CalcNumeric{kind: kind, value: number, unit: unit.clone(), type_: calc_numeric_kind_type(kind)})
}

fn calculated_export_fixture() CalculatedStyleValue {
	root := CalcNode(CalcSum{children: [
		calculated_export_numeric(.length, 13, 'px'),
		CalcNode(CalcNegate{children: [CalcNode(CalcProduct{children: [
			calculated_export_numeric(.number, 2, ''),
			CalcNode(CalcFunction{name: 'round'.clone(), strategy: 'down'.clone(), children: [
				calculated_export_numeric(.length, 5, 'em'), calculated_export_numeric(.length, 2, 'px')]}),
			CalcNode(CalcInvert{children: [calculated_export_numeric(.number, 4, '')]}),
		]})]}),
	]})
	return CalculatedStyleValue{
		serialization: root.serialize_top()
		numeric_type_: NumericType.with_type(.length, 1)
		calculation_context: CalculationContext{
			percentages_resolve_as: .length
			resolve_numbers_as_integers: true
			accepted_type_ranges: {.length: AcceptedTypeRange{min: -12.5, max: 2048},
				.percentage: AcceptedTypeRange{min: 0, max: 100}}
		}
		node: [root]
	}
}

fn calculated_export_assert_owned(node CalcNode, owner &platform.RetainedArena) {
	match node {
		CalcNumeric {
			$if prealloc { if node.unit.len > 0 { assert owner.arena.contains(node.unit.str) } }
		}
		CalcSum, CalcProduct, CalcNegate, CalcInvert {
			$if prealloc { assert owner.arena.contains(node.children.data) }
			for child in node.children { calculated_export_assert_owned(child, owner) }
		}
		CalcFunction {
			$if prealloc {
				assert owner.arena.contains(node.children.data)
				if node.name.len > 0 { assert owner.arena.contains(node.name.str) }
				if node.strategy.len > 0 { assert owner.arena.contains(node.strategy.str) }
			}
			for child in node.children { calculated_export_assert_owned(child, owner) }
		}
		else { assert false, 'unsupported test tree' }
	}
}

fn test_calculated_export_owns_all_numeric_tree_payloads_strings_and_context_maps() {
	mut owner := platform.new_retained_arena('calculated value publication')
	mut entered := owner.enter()
	expected := calculated_export_fixture()
	work := platform.begin_thread_scratch('calculated value input')
	mut temporary := calculated_export_fixture()
	assert calculated_property_value_can_export(temporary)
	assert property_value_can_export(StyleValue(temporary)) == !retain_calculated_value_reparse
	work.leave()
	owned := export_calculated_property_value(temporary)
	// Publishing must detach both the top-level vector and context map.
	temporary.node.clear()
	temporary.calculation_context.accepted_type_ranges[.length] = AcceptedTypeRange{min: 9999, max: 10000}
	work.finish()
	churn := platform.begin_thread_scratch('calculated value overwrite')
	_ = []u8{len: 256 * 1024, init: u8(0xa5)}
	churn.finish()
	assert owned.node == expected.node
	assert owned.numeric_type_ == expected.numeric_type_
	assert owned.calculation_context == expected.calculation_context
	assert owned.serialize(.normal) == expected.serialize(.normal)
	assert owned.serialize(.resolved_value) == expected.serialize(.resolved_value)
	assert owned.resolve_raw_length(CalculationResolutionContext{}) == expected.resolve_raw_length(CalculationResolutionContext{})
	$if prealloc {
		assert owner.arena.contains(owned.serialization.str)
		assert owner.arena.contains(owned.node.data)
	}
	calculated_export_assert_owned(owned.node[0], owner)
	entered.finish()
	owner.release()
}

fn test_calculated_export_keeps_numeric_bits_and_every_unit_kind() {
	for kind in [CalcNumericKind.number, .length, .angle, .time, .frequency, .resolution, .flex, .percentage] {
		for number in [-0.0, 1.25, math.inf(1), math.inf(-1), math.nan()] {
			work := platform.begin_thread_scratch('calculated numeric input')
			value := CalculatedStyleValue{
				serialization: 'calc(0px)'.clone()
				numeric_type_: calc_numeric_kind_type(kind)
				node: [calculated_export_numeric(kind, number, calc_numeric_canonical_unit(kind))]
			}
			assert calculated_property_value_can_export(value)
			work.leave()
			owned := export_calculated_property_value(value)
			work.finish()
			assert owned.node[0] is CalcNumeric
			leaf := owned.node[0] as CalcNumeric
			assert math.f64_bits(leaf.value) == math.f64_bits(number)
			assert leaf.kind == kind && leaf.type_ == calc_numeric_kind_type(kind)
			assert leaf.unit == calc_numeric_canonical_unit(kind)
		}
	}
}

fn test_calculated_export_parser_matches_reparse_in_lists_ratios_and_value_contexts() {
	properties := [PropertyID.width, .width, .width, .width, .opacity, .z_index, .rotate,
		.aspect_ratio, .margin, .width]
	sources := ['calc(13px + 2%)', 'min(1em, 3px)', 'round(down, 5em, 3px)', 'calc(-12px)',
		'calc(.25 + .125)', 'calc(1.5)', 'calc(1turn / 3)',
		'calc(6em / 1px) / calc(3rem / 1px)', 'calc(1em + 3px) calc(1% + 7px)',
		'calc(100vw - (56px + 204px))']
	for index, property in properties {
		mut reference := Parser.from_css_text(sources[index])
		expected := reference.parse_css_value(property) or { panic(sources[index]) }
		// rotate wraps its calculation in TransformationStyleValue, which
		// retains the existing fallback even when its numeric child is closed.
		assert property_value_can_export(expected) == (index != 6 && !retain_calculated_value_reparse), sources[index]
		actual := parse_css_value_logic(property, sources[index]) or { panic('workspace parse') }
		assert actual.equals(expected)
		assert actual.serialize(.normal) == expected.serialize(.normal)
		assert actual.serialize(.resolved_value) == expected.serialize(.resolved_value)
		if actual is CalculatedStyleValue && expected is CalculatedStyleValue {
			assert actual.node == expected.node
			assert actual.numeric_type_ == expected.numeric_type_
			assert actual.calculation_context == expected.calculation_context
		}
	}
}

fn test_calculated_export_rejects_dependent_leaves_and_nested_unsupported_values_without_allocating() {
	properties := [PropertyID.width, .left, .width]
	sources := ['calc(13px + sibling-index() * 2px)', 'calc(anchor(left, 7px) + 3px)',
		'random(fixed .25, 0px, 10px)']
	for index, property in properties {
		mut parser := Parser.from_css_text(sources[index])
		value := parser.parse_css_value(property) or { panic(sources[index]) }
		assert value is CalculatedStyleValue
		calculated := value as CalculatedStyleValue
		nested := StyleValue(StyleValueList.create([StyleValue(NumberStyleValue.create(1)), value], .space, .no))
		before := platform.thread_arena_usage().used
		for _ in 0 .. 64 {
			assert !calculated_property_value_can_export(calculated)
			assert !property_value_can_export(nested)
		}
		$if prealloc { assert platform.thread_arena_usage().used - before < 1024 }
		actual := parse_css_value_logic(property, sources[index]) or { panic('fallback parse') }
		assert actual.serialize(.normal) == value.serialize(.normal)
	}
}

fn test_calculated_export_inspection_bounds_depth_node_count_and_malformed_trees() {
	leaf := calculated_export_numeric(.number, 1, '')
	mut node := leaf
	for depth in 0 .. 65 {
		assert calculated_property_value_can_export(CalculatedStyleValue{node: [node]}) == (depth < 64)
		node = CalcNode(CalcInvert{children: [node]})
	}
	for count in [4095, 4096] {
		value := CalculatedStyleValue{node: [CalcNode(CalcSum{children: []CalcNode{len: count, init: leaf}})]}
		before := platform.thread_arena_usage().used
		assert calculated_property_value_can_export(value) == (count == 4095)
		$if prealloc { assert platform.thread_arena_usage().used == before }
	}
	for malformed in [CalculatedStyleValue{}, CalculatedStyleValue{node: [leaf, leaf]},
		CalculatedStyleValue{node: [CalcNode(CalcNegate{})]},
		CalculatedStyleValue{node: [CalcNode(CalcInvert{children: [leaf, leaf]})]},
		CalculatedStyleValue{node: [CalcNode(CalcSum{})]}] {
		assert !calculated_property_value_can_export(malformed)
	}
}
