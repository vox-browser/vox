module css

// Parse-time simplification of a calc() tree, ported from the C++
// simplify_a_calculation_tree run with an empty resolution context. This folds the
// constant parts of the expression so the serialized specified value matches upstream
// (e.g. `calc(1px + 2px)` -> `calc(3px)`, `calc(2 * 3px)` -> `calc(6px)`, `sqrt(16)` ->
// `calc(4)`), while leaving anything that needs a resolution context symbolic (relative
// lengths like em/rem/vw, and percentages).
//
// Only leaves that are already in - or convert without a context to - their canonical unit
// participate in folding: absolute lengths become px, angles become deg, times become s,
// etc.; relative lengths and percentages are kept as written. Simplification is idempotent,
// so the result round-trips.

fn calc_numeric_canonical_unit(kind CalcNumericKind) string {
	return match kind {
		.number { '' }
		.percentage { '%' }
		.length { 'px' }
		.angle { 'deg' }
		.time { 's' }
		.frequency { 'hz' }
		.resolution { 'dppx' }
		.flex { 'fr' }
	}
}

fn (leaf CalcNumeric) is_canonical() bool {
	return leaf.unit == calc_numeric_canonical_unit(leaf.kind)
}

fn calc_numeric_kind_type(kind CalcNumericKind) NumericType {
	return match kind {
		.number { NumericType.new() }
		.percentage { NumericType.with_type(.percent, 1) }
		.length { NumericType.with_type(.length, 1) }
		.angle { NumericType.with_type(.angle, 1) }
		.time { NumericType.with_type(.time, 1) }
		.frequency { NumericType.with_type(.frequency, 1) }
		.resolution { NumericType.with_type(.resolution, 1) }
		.flex { NumericType.with_type(.flex, 1) }
	}
}

fn simplify_calc(node CalcNode) CalcNode {
	match node {
		CalcNumeric {
			return canonicalize_calc_leaf(node)
		}
		CalcSum {
			mut children := []CalcNode{}
			for child in node.children {
				children << simplify_calc(child)
			}
			return simplify_calc_sum(children)
		}
		CalcProduct {
			mut children := []CalcNode{}
			for child in node.children {
				children << simplify_calc(child)
			}
			return simplify_calc_product(children)
		}
		CalcNegate {
			return simplify_calc_negate(simplify_calc(node.children[0]))
		}
		CalcInvert {
			return simplify_calc_invert(simplify_calc(node.children[0]))
		}
		CalcFunction {
			mut children := []CalcNode{}
			for child in node.children {
				children << simplify_calc(child)
			}
			return simplify_calc_function(node.name, node.strategy, children)
		}
	}
	return node
}

// Convert an absolute-unit leaf to its canonical unit; leave relative lengths, numbers and
// percentages unchanged.
fn canonicalize_calc_leaf(leaf CalcNumeric) CalcNode {
	if leaf.is_canonical() {
		return CalcNode(leaf)
	}
	match leaf.kind {
		.length {
			unit := string_to_length_unit(leaf.unit) or { return CalcNode(leaf) }
			length := Length.new(leaf.value, unit)
			if length.is_absolute() {
				return calc_canonical_leaf(.length, length.absolute_length_to_px_without_rounding())
			}
			return CalcNode(leaf)
		}
		.angle {
			unit := string_to_angle_unit(leaf.unit) or { return CalcNode(leaf) }
			return calc_canonical_leaf(.angle, Angle.new(leaf.value, unit).to_degrees())
		}
		.time {
			unit := string_to_time_unit(leaf.unit) or { return CalcNode(leaf) }
			return calc_canonical_leaf(.time, Time.new(leaf.value, unit).to_seconds())
		}
		.frequency {
			unit := string_to_frequency_unit(leaf.unit) or { return CalcNode(leaf) }
			return calc_canonical_leaf(.frequency, Frequency.new(leaf.value, unit).to_hertz())
		}
		.resolution {
			unit := string_to_resolution_unit(leaf.unit) or { return CalcNode(leaf) }
			return calc_canonical_leaf(.resolution, Resolution.new(leaf.value, unit).to_dots_per_pixel())
		}
		.flex {
			unit := string_to_flex_unit(leaf.unit) or { return CalcNode(leaf) }
			return calc_canonical_leaf(.flex, Flex.new(leaf.value, unit).to_fr())
		}
		else {
			return CalcNode(leaf)
		}
	}
}

fn calc_canonical_leaf(kind CalcNumericKind, value f64) CalcNode {
	return CalcNode(CalcNumeric{
		kind:  kind
		value: value
		unit:  calc_numeric_canonical_unit(kind)
		type_: calc_numeric_kind_type(kind)
	})
}

fn calc_result_to_leaf(result CalcResult) ?CalcNode {
	key := calc_canonical_key(result.type_) or { return none }
	kind := match key {
		'number' { CalcNumericKind.number }
		'percent' { CalcNumericKind.percentage }
		'length' { CalcNumericKind.length }
		'angle' { CalcNumericKind.angle }
		'time' { CalcNumericKind.time }
		'frequency' { CalcNumericKind.frequency }
		'resolution' { CalcNumericKind.resolution }
		'flex' { CalcNumericKind.flex }
		else { return none }
	}
	return calc_canonical_leaf(kind, result.value)
}

fn simplify_calc_sum(children []CalcNode) CalcNode {
	// 1. Flatten nested sums.
	mut flattened := []CalcNode{}
	for child in children {
		if child is CalcSum {
			flattened << child.children
		} else {
			flattened << child
		}
	}

	// 2. Combine numeric children that share a unit.
	mut combined := []CalcNode{}
	for child in flattened {
		if child is CalcNumeric {
			mut merged := false
			for index, existing in combined {
				if existing is CalcNumeric {
					if existing.kind == child.kind && existing.unit == child.unit {
						combined[index] = CalcNode(CalcNumeric{
							kind:  child.kind
							value: existing.value + child.value
							unit:  child.unit
							type_: child.type_
						})
						merged = true
						break
					}
				}
			}
			if !merged {
				combined << child
			}
		} else {
			combined << child
		}
	}

	if combined.len == 1 {
		return combined[0]
	}
	return CalcNode(CalcSum{
		children: combined
	})
}

fn simplify_calc_product(children []CalcNode) CalcNode {
	// 1. Flatten nested products.
	mut flattened := []CalcNode{}
	for child in children {
		if child is CalcProduct {
			flattened << child.children
		} else {
			flattened << child
		}
	}

	// 2. Combine plain-number children into a single number.
	mut number_value := 1.0
	mut has_number := false
	mut rest := []CalcNode{}
	for child in flattened {
		if child is CalcNumeric && child.kind == .number {
			number_value *= child.value
			has_number = true
		} else {
			rest << child
		}
	}
	mut merged := []CalcNode{}
	if has_number {
		merged << calc_canonical_leaf(.number, number_value)
	}
	merged << rest

	// 3. If every remaining child is a canonical numeric value (or the inverse of one),
	//    evaluate the product.
	if folded := try_fold_calc_product(merged) {
		return folded
	}

	if merged.len == 1 {
		return merged[0]
	}
	return CalcNode(CalcProduct{
		children: merged
	})
}

fn try_fold_calc_product(children []CalcNode) ?CalcNode {
	mut accumulated := CalcResult{
		value: 1.0
		type_: NumericType.new()
	}
	for child in children {
		if child is CalcNumeric {
			if !child.is_canonical() {
				return none
			}
			accumulated = calc_result_multiply(accumulated, CalcResult{
				value: child.value
				type_: child.type_
			}) or { return none }
		} else if child is CalcInvert {
			inner := child.children[0]
			if inner is CalcNumeric {
				if !inner.is_canonical() {
					return none
				}
				accumulated = calc_result_multiply(accumulated, CalcResult{
					value: 1.0 / inner.value
					type_: inner.type_.inverted()
				}) or { return none }
			} else {
				return none
			}
		} else {
			return none
		}
	}
	return calc_result_to_leaf(accumulated)
}

fn simplify_calc_negate(child CalcNode) CalcNode {
	if child is CalcNumeric {
		return CalcNode(CalcNumeric{
			kind:  child.kind
			value: -child.value
			unit:  child.unit
			type_: child.type_
		})
	}
	if child is CalcNegate {
		return child.children[0]
	}
	if child is CalcSum {
		mut negated := []CalcNode{}
		for sum_child in child.children {
			negated << simplify_calc_negate(sum_child)
		}
		return CalcNode(CalcSum{
			children: negated
		})
	}
	return CalcNode(CalcNegate{
		children: [child]
	})
}

fn simplify_calc_invert(child CalcNode) CalcNode {
	if child is CalcNumeric && child.kind == .number {
		return calc_canonical_leaf(.number, 1.0 / child.value)
	}
	if child is CalcInvert {
		return child.children[0]
	}
	return CalcNode(CalcInvert{
		children: [child]
	})
}

fn simplify_calc_function(name string, strategy string, children []CalcNode) CalcNode {
	// Fold only when every argument is a canonical numeric constant that shares a single
	// canonical unit. Requiring a single unit avoids mis-folding a percentage mixed with
	// dimensions (e.g. clamp(10px, 50%, 90px)), which can only be resolved with a basis.
	mut foldable := true
	mut unit_key := ?string(none)
	for child in children {
		if child is CalcNumeric && child.is_canonical() {
			child_key := calc_canonical_key(child.type_) or {
				foldable = false
				break
			}
			if key := unit_key {
				if key != child_key {
					foldable = false
					break
				}
			} else {
				unit_key = child_key
			}
		} else {
			foldable = false
			break
		}
	}
	if foldable {
		function := CalcFunction{
			name:     name
			strategy: strategy
			children: children
		}
		if result := resolve_calc_function(function, CalculationResolutionContext{}) {
			if leaf := calc_result_to_leaf(result) {
				return leaf
			}
		}
	}
	return CalcNode(CalcFunction{
		name:     name
		strategy: strategy
		children: children
	})
}
