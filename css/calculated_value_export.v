module css

import os
import sync.stdatomic

const retain_calculated_value_reparse = os.getenv('VOX_RETAIN_CALCULATED_VALUE_REPARSE') != ''
const calculated_value_export_diagnostics = os.getenv('VOX_CALCULATED_VALUE_EXPORT_DIAGNOSTICS') != ''
__global calculated_value_export_reported stdatomic.AtomicVal[bool]

struct CalculationExportScan {
mut:
	remaining int = 4096
}

// Export only closed numeric trees. Layout/element-dependent leaves and random
// sharing keep the original reparse path. Bound this allocation-free inspection
// before any caller-owned payload is published.
fn calculated_property_value_can_export(value CalculatedStyleValue) bool {
	if value.node.len != 1 { return false }
	mut scan := CalculationExportScan{}
	return calculation_node_can_export(value.node[0], 0, mut scan)
}

fn calculation_node_can_export(node CalcNode, depth int, mut scan CalculationExportScan) bool {
	if depth >= 64 || scan.remaining <= 0 { return false }
	scan.remaining--
	return match node {
		CalcNumeric { true }
		CalcSum, CalcProduct, CalcFunction {
			node.children.len > 0 && calculation_children_can_export(node.children, depth, mut scan)
		}
		CalcNegate, CalcInvert {
			node.children.len == 1 && calculation_children_can_export(node.children, depth, mut scan)
		}
		else { false }
	}
}

fn calculation_children_can_export(nodes []CalcNode, depth int, mut scan CalculationExportScan) bool {
	for node in nodes {
		if !calculation_node_can_export(node, depth + 1, mut scan) { return false }
	}
	return true
}

fn export_calculation_children(nodes []CalcNode) []CalcNode {
	mut owned := []CalcNode{cap: nodes.len}
	for node in nodes { owned << export_calculation_node(node) }
	return owned
}

fn export_calculation_node(node CalcNode) CalcNode {
	// Reconstruct each variant: copying a sum-type handle would retain its
	// temporary payload even after copying the surrounding child vector.
	return match node {
		CalcNumeric { CalcNode(CalcNumeric{
			kind: node.kind
			value: node.value
			unit: node.unit.clone()
			type_: node.type_
		}) }
		CalcSum { CalcNode(CalcSum{children: export_calculation_children(node.children)}) }
		CalcProduct { CalcNode(CalcProduct{children: export_calculation_children(node.children)}) }
		CalcNegate { CalcNode(CalcNegate{children: export_calculation_children(node.children)}) }
		CalcInvert { CalcNode(CalcInvert{children: export_calculation_children(node.children)}) }
		CalcFunction { CalcNode(CalcFunction{
			name: node.name.clone()
			strategy: node.strategy.clone()
			children: export_calculation_children(node.children)
		}) }
		else { panic('unsupported calculation node export') }
	}
}

fn export_calculated_property_value(value CalculatedStyleValue) CalculatedStyleValue {
	if !retain_calculated_value_reparse && calculated_value_export_diagnostics
		&& calculated_value_export_reported.compare_and_swap(false, true) {
		eprintln('Vox calculated value export: copied closed numeric tree without reparsing')
	}
	return CalculatedStyleValue{
		serialization: value.serialization.clone()
		numeric_type_: value.numeric_type_
		calculation_context: CalculationContext{
			percentages_resolve_as: value.calculation_context.percentages_resolve_as
			resolve_numbers_as_integers: value.calculation_context.resolve_numbers_as_integers
			accepted_type_ranges: value.calculation_context.accepted_type_ranges.clone()
		}
		node: export_calculation_children(value.node)
	}
}
