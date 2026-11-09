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

fn simplify_calc(node CalcNode, calculation_context CalculationContext) CalcNode {
	match node {
		CalcNumeric {
			return canonicalize_calc_leaf(node)
		}
		CalcTreeCounting, CalcChannel {
			return node
		}
		CalcAnchor, CalcAnchorSize {
			return node
		}
		CalcSum {
			mut children := []CalcNode{}
			for child in node.children {
				children << simplify_calc(child, calculation_context)
			}
			return simplify_calc_sum(children)
		}
		CalcProduct {
			mut children := []CalcNode{}
			for child in node.children {
				children << simplify_calc(child, calculation_context)
			}
			return simplify_calc_product(children, calculation_context)
		}
		CalcNegate {
			return simplify_calc_negate(simplify_calc(node.children[0], calculation_context))
		}
		CalcInvert {
			return simplify_calc_invert(simplify_calc(node.children[0], calculation_context))
		}
		CalcFunction {
			mut children := []CalcNode{}
			for child in node.children {
				children << simplify_calc(child, calculation_context)
			}
			return simplify_calc_function(node.name, node.strategy, children, calculation_context)
		}
		CalcRandom {
			mut children := []CalcNode{cap: node.children.len}
			for child in node.children {
				children << simplify_calc(child, calculation_context)
			}
			return CalcNode(CalcRandom{
				sharing: node.sharing
				children: children
			})
		}
	}
	return node
}

// Computed-value-time form of simplify_a_calculation_tree(). Relative lengths
// become canonical px using the element/window font and viewport metrics, while
// percentages remain symbolic until a percentage basis is supplied at used-value
// time. The remaining folding is shared with the parse-time simplifier above.
fn simplify_calc_with_resolution(node CalcNode, calculation_context CalculationContext, context CalculationResolutionContext) CalcNode {
	match node {
		CalcNumeric {
			if node.kind == .length {
				unit := string_to_length_unit(node.unit) or { return CalcNode(node) }
				length := Length.new(node.value, unit)
				return calc_canonical_leaf(.length,
					length.to_px_without_rounding(context.length_resolution_context))
			}
			return canonicalize_calc_leaf(node)
		}
		CalcTreeCounting {
			abstract_element := context.abstract_element or { return node }
			value := node.style_value.resolve_for_dom_abstract_element(&abstract_element)
			return calc_canonical_leaf(.number, f64(value))
		}
		CalcChannel {
			for channel in context.relative_color_channels {
				if channel.name == node.name {
					return calc_canonical_leaf(.number, channel.value)
				}
			}
			return node
		}
		CalcAnchor {
			if resolved := resolve_calc_anchor(node, calculation_context, context) {
				return calc_canonical_leaf(.length, resolved.value)
			}
			return node
		}
		CalcAnchorSize {
			if resolved := resolve_calc_anchor_size(node, calculation_context, context) {
				return calc_canonical_leaf(.length, resolved.value)
			}
			return node
		}
		CalcSum {
			mut children := []CalcNode{cap: node.children.len}
			for child in node.children {
				children << simplify_calc_with_resolution(child, calculation_context, context)
			}
			return simplify_calc_sum(children)
		}
		CalcProduct {
			mut children := []CalcNode{cap: node.children.len}
			for child in node.children {
				children << simplify_calc_with_resolution(child, calculation_context, context)
			}
			return simplify_calc_product(children, calculation_context)
		}
		CalcNegate {
			return simplify_calc_negate(simplify_calc_with_resolution(node.children[0], calculation_context, context))
		}
		CalcInvert {
			return simplify_calc_invert(simplify_calc_with_resolution(node.children[0], calculation_context, context))
		}
		CalcFunction {
			mut children := []CalcNode{cap: node.children.len}
			for child in node.children {
				children << simplify_calc_with_resolution(child, calculation_context, context)
			}
			return simplify_calc_function(node.name, node.strategy, children, calculation_context)
		}
		CalcRandom {
			mut sharing := node.sharing
			if sharing.is_fixed() || context.abstract_element != none {
				absolutized := sharing.absolutized(ComputationContext{
					length_resolution_context: context.length_resolution_context
					abstract_element: context.abstract_element
				})
				if absolutized is RandomValueSharingStyleValue {
					sharing = absolutized
				}
			}

			mut children := []CalcNode{cap: node.children.len}
			for child in node.children {
				children << simplify_calc_with_resolution(child, calculation_context, context)
			}
			random := CalcRandom{
				sharing: sharing
				children: children
			}
			if sharing.is_fixed() {
				if result := resolve_calc_random(random, calculation_context, context) {
					if leaf := make_calculation_node(result, calculation_context) {
						return leaf
					}
				}
			}
			return CalcNode(random)
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
		kind: kind
		value: value
		unit: calc_numeric_canonical_unit(kind)
		type_: calc_numeric_kind_type(kind)
	})
}

fn make_calculation_node(result CalcResult, calculation_context CalculationContext) ?CalcNode {
	percentages_resolve_as := calculation_context.percentages_resolve_as
	key := if result.type_.matches_number(percentages_resolve_as) {
		'number'
	} else if result.type_.matches_percentage() {
		'percent'
	} else if result.type_.matches_length(percentages_resolve_as) {
		'length'
	} else if result.type_.matches_angle(percentages_resolve_as) {
		'angle'
	} else if result.type_.matches_time(percentages_resolve_as) {
		'time'
	} else if result.type_.matches_frequency(percentages_resolve_as) {
		'frequency'
	} else if result.type_.matches_resolution(percentages_resolve_as) {
		'resolution'
	} else if result.type_.matches_flex(percentages_resolve_as) {
		'flex'
	} else {
		return none
	}
	kind := match key {
		'number' { CalcNumericKind.number }
		'percent' { CalcNumericKind.percentage }
		'length' { CalcNumericKind.length }
		'angle' { CalcNumericKind.angle }
		'time' { CalcNumericKind.time }
		'frequency' { CalcNumericKind.frequency }
		'resolution' { CalcNumericKind.resolution }
		'flex' { CalcNumericKind.flex }
		else {
			return none
		}
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
							kind: child.kind
							value: existing.value + child.value
							unit: child.unit
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

fn simplify_calc_product(children []CalcNode, calculation_context CalculationContext) CalcNode {
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

	// 3. If there are exactly two children, one a number and the other a sum made only
	//    of numeric values, distribute the number over the sum. This is step 9.3 of the
	//    upstream simplify_a_calculation_tree algorithm and is important for retaining
	//    only the irreducible relative-unit work (for example 2 * (1em + 3px)).
	if merged.len == 2 {
		multiplier_node := merged[0]
		sum_node := merged[1]
		if multiplier_node is CalcNumeric && multiplier_node.kind == .number
			&& sum_node is CalcSum {
			mut multiplied_children := []CalcNode{cap: sum_node.children.len}
			mut all_numeric := true
			for sum_child in sum_node.children {
				if sum_child is CalcNumeric {
					multiplied_children << CalcNode(CalcNumeric{
						kind: sum_child.kind
						value: sum_child.value * multiplier_node.value
						unit: sum_child.unit
						type_: sum_child.type_
					})
				} else {
					all_numeric = false
					break
				}
			}
			if all_numeric {
				return CalcNode(CalcSum{
					children: multiplied_children
				})
			}
		}
	}

	// 4. If every remaining child is a canonical numeric value (or the inverse of one),
	//    evaluate the product.
	if folded := try_fold_calc_product(merged, calculation_context) {
		return folded
	}

	if merged.len == 1 {
		return merged[0]
	}
	return CalcNode(CalcProduct{
		children: merged
	})
}

fn try_fold_calc_product(children []CalcNode, calculation_context CalculationContext) ?CalcNode {
	mut accumulated := CalcResult{
		value: 1.0
		type_: NumericType.new()
	}
	for child in children {
		if child is CalcNumeric {
			if !child.is_canonical() {
				return none
			}
			// Upstream deliberately strips a contextual percent hint while folding a
			// product. Otherwise `0.5 * 50%` in a length-percentage context would be
			// mistaken for 25px instead of remaining 25%.
			child_type := if child.kind == .percentage {
				NumericType.with_type(.percent, 1)
			} else {
				child.type_
			}
			accumulated = calc_result_multiply(accumulated, CalcResult{
				value: child.value
				type_: child_type
			}) or { return none }
		} else if child is CalcInvert {
			inner := child.children[0]
			if inner is CalcNumeric {
				if !inner.is_canonical() {
					return none
				}
				inner_type := if inner.kind == .percentage {
					NumericType.with_type(.percent, 1)
				} else {
					inner.type_
				}
				accumulated = calc_result_multiply(accumulated, CalcResult{
					value: 1.0 / inner.value
					type_: inner_type.inverted()
				}) or { return none }
			} else {
				return none
			}
		} else {
			return none
		}
	}
	return make_calculation_node(accumulated, calculation_context)
}

fn simplify_calc_negate(child CalcNode) CalcNode {
	if child is CalcNumeric {
		return CalcNode(CalcNumeric{
			kind: child.kind
			value: -child.value
			unit: child.unit
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

fn calc_function_needs_resolved_percentage(name string) bool {
	return name in ['min', 'max', 'clamp', 'hypot', 'abs', 'atan2', 'round', 'mod', 'rem']
}

// C++ step 5 partially combines comparable same-unit children of min()/max(), even
// when another child prevents the whole function from being evaluated.
fn simplify_calc_min_or_max(name string, strategy string, children []CalcNode, calculation_context CalculationContext) CalcNode {
	mut simplified_children := []CalcNode{cap: children.len}
	for child in children {
		if child is CalcNumeric {
			// A percentage tied to another value type cannot be compared until its basis is
			// available. This is the same guard used by the upstream simplifier.
			if child.kind == .percentage && calculation_context.percentages_resolve_as != none {
				simplified_children << child
				continue
			}

			mut matching_index := -1
			for index, existing in simplified_children {
				if existing is CalcNumeric && existing.kind == child.kind
					&& existing.unit == child.unit {
					matching_index = index
					break
				}
			}
			if matching_index >= 0 {
				existing := simplified_children[matching_index]
				if existing is CalcNumeric {
					should_replace := if name == 'min' {
						child.value < existing.value
					} else {
						child.value > existing.value
					}
					if should_replace {
						simplified_children[matching_index] = child
					}
				}
				continue
			}
		}
		simplified_children << child
	}

	if simplified_children.len == 1 {
		return simplified_children[0]
	}
	return CalcNode(CalcFunction{
		name: name
		strategy: strategy
		children: simplified_children
	})
}

fn simplify_calc_function(name string, strategy string, children []CalcNode, calculation_context CalculationContext) CalcNode {
	// sign() is the one operation that runs on any numeric leaf, because the sign of a
	// value does not depend on the unit it is expressed in. SignCalculationNode reads the
	// child's raw value directly instead of going through try_get_value_with_canonical_unit,
	// so `sign(1em)` folds to 1 while `abs(1em)` stays symbolic.
	if name == 'sign' && children.len == 1 && children[0] is CalcNumeric {
		function := CalcFunction{
			name: name
			strategy: strategy
			children: children
		}
		if result := resolve_calc_function(function, calculation_context, CalculationResolutionContext{}) {
			if leaf := make_calculation_node(result, calculation_context) {
				return leaf
			}
		}
	}

	// Fold only when every argument is a canonical numeric constant that shares a single
	// canonical unit. Requiring a single unit avoids mis-folding a percentage mixed with
	// dimensions (e.g. clamp(10px, 50%, 90px)), which can only be resolved with a basis.
	mut foldable := true
	mut unit_key := ?string(none)
	for child in children {
		if child is CalcNumeric && child.is_canonical() {
			if child.kind == .percentage && calculation_context.percentages_resolve_as != none
				&& calc_function_needs_resolved_percentage(name) {
				foldable = false
				break
			}
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
			name: name
			strategy: strategy
			children: children
		}
		if result := resolve_calc_function(function, calculation_context, CalculationResolutionContext{}) {
			if leaf := make_calculation_node(result, calculation_context) {
				return leaf
			}
		}
	}
	if name == 'min' || name == 'max' {
		return simplify_calc_min_or_max(name, strategy, children, calculation_context)
	}
	return CalcNode(CalcFunction{
		name: name
		strategy: strategy
		children: children
	})
}
