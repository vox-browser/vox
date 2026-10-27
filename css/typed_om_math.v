// Translated from LibWeb/CSS CSSMathValue and concrete CSS Typed OM math classes.
module css

import math

// Generated Bindings::CSSMathOperator from CSSMathValue.idl, kept here because
// the V port does not generate a separate bindings module for enum-only IDL.
pub enum CSSMathOperator {
	sum
	product
	negate
	invert
	min
	max
	clamp
}

pub enum CSSMathValueNested {
	no
	yes
}

pub enum CSSMathValueParens {
	with
	without
}

pub struct CSSMathSum {
pub mut:
	type_   NumericType
	values_ CSSNumericArray
}

pub struct CSSMathProduct {
pub mut:
	type_   NumericType
	values_ CSSNumericArray
}

pub struct CSSMathNegate {
pub mut:
	type_  NumericType
	value_ []CSSNumericValue = [CSSNumericValue(CSSUnitValue{})]
}

pub struct CSSMathInvert {
pub mut:
	type_  NumericType
	value_ []CSSNumericValue = [CSSNumericValue(CSSUnitValue{})]
}

pub struct CSSMathMin {
pub mut:
	type_   NumericType
	values_ CSSNumericArray
}

pub struct CSSMathMax {
pub mut:
	type_   NumericType
	values_ CSSNumericArray
}

pub struct CSSMathClamp {
pub mut:
	type_  NumericType
	lower_ []CSSNumericValue = [CSSNumericValue(CSSUnitValue{})]
	value_ []CSSNumericValue = [CSSNumericValue(CSSUnitValue{})]
	upper_ []CSSNumericValue = [CSSNumericValue(CSSUnitValue{})]
}

pub type CSSMathValue = CSSMathClamp
	| CSSMathInvert
	| CSSMathMax
	| CSSMathMin
	| CSSMathNegate
	| CSSMathProduct
	| CSSMathSum

pub fn (value CSSMathValue) operator_() CSSMathOperator {
	return match value {
		CSSMathSum { .sum }
		CSSMathProduct { .product }
		CSSMathNegate { .negate }
		CSSMathInvert { .invert }
		CSSMathMin { .min }
		CSSMathMax { .max }
		CSSMathClamp { .clamp }
	}
}

pub fn (value CSSMathValue) type_() NumericType {
	return match value {
		CSSMathSum { value.type_ }
		CSSMathProduct { value.type_ }
		CSSMathNegate { value.type_ }
		CSSMathInvert { value.type_ }
		CSSMathMin { value.type_ }
		CSSMathMax { value.type_ }
		CSSMathClamp { value.type_ }
	}
}

pub fn (value CSSMathValue) serialize_math_value(nested CSSMathValueNested, parens CSSMathValueParens) string {
	return match value {
		CSSMathSum { value.serialize_math_value(nested, parens) }
		CSSMathProduct { value.serialize_math_value(nested, parens) }
		CSSMathNegate { value.serialize_math_value(nested, parens) }
		CSSMathInvert { value.serialize_math_value(nested, parens) }
		CSSMathMin { value.serialize_math_value(nested, parens) }
		CSSMathMax { value.serialize_math_value(nested, parens) }
		CSSMathClamp { value.serialize_math_value(nested, parens) }
	}
}

pub fn (value CSSMathValue) is_equal_numeric_value(other CSSNumericValue) bool {
	return match value {
		CSSMathSum { value.is_equal_numeric_value(other) }
		CSSMathProduct { value.is_equal_numeric_value(other) }
		CSSMathNegate { value.is_equal_numeric_value(other) }
		CSSMathInvert { value.is_equal_numeric_value(other) }
		CSSMathMin { value.is_equal_numeric_value(other) }
		CSSMathMax { value.is_equal_numeric_value(other) }
		CSSMathClamp { value.is_equal_numeric_value(other) }
	}
}

pub fn (value CSSMathValue) create_a_sum_value() ?SumValue {
	return match value {
		CSSMathSum { value.create_a_sum_value() }
		CSSMathProduct { value.create_a_sum_value() }
		CSSMathNegate { value.create_a_sum_value() }
		CSSMathInvert { value.create_a_sum_value() }
		CSSMathMin { value.create_a_sum_value() }
		CSSMathMax { value.create_a_sum_value() }
		CSSMathClamp { value.create_a_sum_value() }
	}
}

pub fn (value CSSMathValue) create_an_internal_representation(property PropertyNameAndID, perform_type_check PerformTypeCheck) !StyleValue {
	// If value is a CSSStyleValue subclass,
	//     If value does not match the grammar of a list-valued property iteration of property, throw a TypeError.
	//
	//     If any component of property's CSS grammar has a limited numeric range, and the corresponding part of value
	//     is a CSSUnitValue that is outside of that range, replace that value with the result of wrapping it in a
	//     fresh CSSMathSum whose values internal slot contains only that part of value.
	//
	//     Return the value.
	context := CalculationContext.for_property(property)
	type_ := value.type_()
	node := value.create_calculation_node(context)!
	property_id := property.id() or {
		if perform_type_check == .yes {
			return error('Property does not accept values of this type.')
		}
		return StyleValue(CalculatedStyleValue.create(node, type_, context))
	}
	matches := css_numeric_type_matches_property(type_, property_id, none)

	if perform_type_check == .yes && !matches {
		return error('Property does not accept values of this type.')
	}

	return StyleValue(CalculatedStyleValue.create(node, type_, context))
}

pub fn (value CSSMathValue) create_calculation_node(context CalculationContext) !CalculationNode {
	return match value {
		CSSMathSum { value.create_calculation_node(context)! }
		CSSMathProduct { value.create_calculation_node(context)! }
		CSSMathNegate { value.create_calculation_node(context)! }
		CSSMathInvert { value.create_calculation_node(context)! }
		CSSMathMin { value.create_calculation_node(context)! }
		CSSMathMax { value.create_calculation_node(context)! }
		CSSMathClamp { value.create_calculation_node(context)! }
	}
}

pub fn (value CSSNumericValue) create_calculation_node(context CalculationContext) !CalculationNode {
	return match value {
		CSSUnitValue {
			value.create_calculation_node(context)!
		}
		CSSMathSum {
			value.create_calculation_node(context)!
		}
		CSSMathProduct {
			value.create_calculation_node(context)!
		}
		CSSMathNegate {
			value.create_calculation_node(context)!
		}
		CSSMathInvert {
			value.create_calculation_node(context)!
		}
		CSSMathMin {
			value.create_calculation_node(context)!
		}
		CSSMathMax {
			value.create_calculation_node(context)!
		}
		CSSMathClamp {
			value.create_calculation_node(context)!
		}
	}
}

fn css_numberish_from_numeric_value(value CSSNumericValue) CSSNumberish {
	return match value {
		CSSUnitValue { CSSNumberish(value) }
		CSSMathSum { CSSNumberish(value) }
		CSSMathProduct { CSSNumberish(value) }
		CSSMathNegate { CSSNumberish(value) }
		CSSMathInvert { CSSNumberish(value) }
		CSSMathMin { CSSNumberish(value) }
		CSSMathMax { CSSNumberish(value) }
		CSSMathClamp { CSSNumberish(value) }
	}
}

fn css_numeric_type_matches_property(type_ NumericType, property_id PropertyID, percentages_resolve_as ?ValueType) bool {
	if type_.matches_angle(percentages_resolve_as) {
		return property_accepts_type(property_id, .angle)
	}
	if type_.matches_flex(percentages_resolve_as) {
		return property_accepts_type(property_id, .flex)
	}
	if type_.matches_frequency(percentages_resolve_as) {
		return property_accepts_type(property_id, .frequency)
	}
	if type_.matches_length(percentages_resolve_as) {
		return property_accepts_type(property_id, .length)
	}
	if type_.matches_number(percentages_resolve_as) {
		return property_accepts_type(property_id, .number)
	}
	if type_.matches_percentage() {
		return property_accepts_type(property_id, .percentage)
	}
	if type_.matches_resolution(percentages_resolve_as) {
		return property_accepts_type(property_id, .resolution)
	}
	if type_.matches_time(percentages_resolve_as) {
		return property_accepts_type(property_id, .time)
	}
	return false
}

pub fn CSSMathSum.create(type_ NumericType, values CSSNumericArray) CSSMathSum {
	return CSSMathSum{
		type_:   type_
		values_: values
	}
}

pub fn CSSMathSum.add_all_types_into_math_sum(values []CSSNumericValue) !CSSMathSum {
	if values.len == 0 {
		return error('Cannot create an empty CSSMathSum')
	}
	mut type_ := values[0].type_()
	for i := 1; i < values.len; i++ {
		if added_types := type_.added_to(values[i].type_()) {
			type_ = added_types
		} else {
			return error('Cannot create a CSSMathSum with values of incompatible types')
		}
	}

	values_array := CSSNumericArray.create(values)
	return CSSMathSum.create(type_, values_array)
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssmathsum-cssmathsum
pub fn CSSMathSum.construct_impl(values []CSSNumberish) !CSSMathSum {
	// The CSSMathSum(...args) constructor must, when called, perform the following steps:

	// 1. Replace each item of args with the result of rectifying a numberish value for the item.
	mut converted_values := []CSSNumericValue{cap: values.len}
	for value in values {
		converted_values << rectify_a_numberish_value(value)
	}

	// 2. If args is empty, throw a SyntaxError.
	if converted_values.len == 0 {
		return error('Cannot create an empty CSSMathSum')
	}

	// 3. Let type be the result of adding the types of all the items of args. If type is failure, throw a TypeError.
	// 4. Return a new CSSMathSum whose values internal slot is set to args.
	return CSSMathSum.add_all_types_into_math_sum(converted_values)
}

// https://drafts.css-houdini.org/css-typed-om-1/#serialize-a-cssmathvalue
pub fn (sum CSSMathSum) serialize_math_value(nested CSSMathValueNested, parens CSSMathValueParens) string {
	// NB: Only steps 1 and 3 apply here.
	// 1. Let s initially be the empty string.
	mut s := ''

	// 3. Otherwise, if this is a CSSMathSum:
	{
		// 1. If paren-less is true, continue to the next step; otherwise, if nested is true, append "(" to s;
		//    otherwise, append "calc(" to s.
		if parens == .with {
			if nested == .yes {
				s += '('
			} else {
				s += 'calc('
			}
		}

		// 2. Serialize the first item in this's values internal slot with nested set to true, and append the result
		//    to s.
		values := sum.values_.values()
		if values.len > 0 {
			s += values[0].serialize(CSSNumericSerializationParams{
				nested: true
			})
		}

		// 3. For each arg in this's values internal slot beyond the first:
		for i := 1; i < values.len; i++ {
			arg := values[i]

			// 1. If arg is a CSSMathNegate, append " - " to s, then serialize arg's value internal slot with nested
			//    set to true, and append the result to s.
			if arg is CSSMathNegate {
				s += ' - '
				s += arg.value().serialize(CSSNumericSerializationParams{
					nested: true
				})
			}
			// 2. Otherwise, append " + " to s, then serialize arg with nested set to true, and append the result to s.
			else {
				s += ' + '
				s += arg.serialize(CSSNumericSerializationParams{
					nested: true
				})
			}
		}

		// 4. If paren-less is false, append ")" to s,
		if parens == .with {
			s += ')'
		}

		// 5. Return s.
	}
	return s
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssmathsum-values
pub fn (sum CSSMathSum) values() CSSNumericArray {
	return sum.values_
}

// https://drafts.css-houdini.org/css-typed-om-1/#equal-numeric-value
pub fn (sum CSSMathSum) is_equal_numeric_value(other CSSNumericValue) bool {
	// NB: Only steps 1 and 3 are relevant.
	// 1. If value1 and value2 are not members of the same interface, return false.
	if other !is CSSMathSum {
		return false
	}
	other_sum := other as CSSMathSum

	// 3. If value1 and value2 are both CSSMathSums, CSSMathProducts, CSSMathMins, or CSSMathMaxs:
	// NB: Substeps are implemented in CSSNumericArray.
	return sum.values_.is_equal_numeric_values(other_sum.values_)
}

// https://drafts.css-houdini.org/css-typed-om-1/#create-a-sum-value
pub fn (sum CSSMathSum) create_a_sum_value() ?SumValue {
	// 1. Let values initially be an empty list.
	mut values := SumValue{}

	// 2. For each item in this's values internal slot:
	for item in sum.values_.values() {
		// 1. Let value be the result of creating a sum value from item. If value is failure, return failure.
		value := item.create_a_sum_value() or { return none }

		// 2. For each subvalue of value:
		for subvalue in value {
			// 1. If values already contains an item with the same unit map as subvalue, increment that item's value by
			//    the value of subvalue.
			mut found_existing_item := false
			for mut existing_item in values {
				if subvalue.unit_map == existing_item.unit_map {
					existing_item.value += subvalue.value
					found_existing_item = true
					break
				}
			}
			// 2. Otherwise, append subvalue to values.
			if !found_existing_item {
				values << subvalue
			}
		}
	}

	if values.len == 0 {
		return none
	}

	// 3. Create a type from the unit map of each item of values, and add all the types together.
	//    If the result is failure, return failure.
	mut added_type := numeric_type_from_sum_value_unit_map(values[0].unit_map) or { return none }
	for i := 1; i < values.len; i++ {
		type_ := numeric_type_from_sum_value_unit_map(values[i].unit_map) or { return none }
		added_type = added_type.added_to(type_) or { return none }
	}
	_ = added_type

	// 4. Return values.
	return values
}

pub fn (sum CSSMathSum) create_calculation_node(context CalculationContext) !CalculationNode {
	mut children := []CalcNode{}
	for child_value in sum.values_.values() {
		children << child_value.create_calculation_node(context)!.typed_node()!
	}
	return calculation_node_from_calc(CalcNode(CalcSum{
		children: children
	}))
}

pub fn CSSMathProduct.create(type_ NumericType, values CSSNumericArray) CSSMathProduct {
	return CSSMathProduct{
		type_:   type_
		values_: values
	}
}

pub fn CSSMathProduct.multiply_all_types_into_math_product(values []CSSNumericValue) !CSSMathProduct {
	if values.len == 0 {
		return error('Cannot create an empty CSSMathProduct')
	}
	mut type_ := values[0].type_()
	for i := 1; i < values.len; i++ {
		if multiplied_types := type_.multiplied_by(values[i].type_()) {
			type_ = multiplied_types
		} else {
			return error('Cannot create a CSSMathProduct with values of incompatible types')
		}
	}

	values_array := CSSNumericArray.create(values)
	return CSSMathProduct.create(type_, values_array)
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssmathproduct-cssmathproduct
pub fn CSSMathProduct.construct_impl(values []CSSNumberish) !CSSMathProduct {
	// The CSSMathProduct(...args) constructor is defined identically to the above, except that in step 3 it multiplies
	// the types instead of adding, and in the last step it returns a CSSMathProduct.
	// NB: So, the steps below are a modification of the CSSMathSum steps.

	// 1. Replace each item of args with the result of rectifying a numberish value for the item.
	mut converted_values := []CSSNumericValue{cap: values.len}
	for value in values {
		converted_values << rectify_a_numberish_value(value)
	}

	// 2. If args is empty, throw a SyntaxError.
	if converted_values.len == 0 {
		return error('Cannot create an empty CSSMathProduct')
	}

	// 3. Let type be the result of multiplying the types of all the items of args. If type is failure, throw a TypeError.
	// 4. Return a new CSSMathProduct whose values internal slot is set to args.
	return CSSMathProduct.multiply_all_types_into_math_product(converted_values)
}

// https://drafts.css-houdini.org/css-typed-om-1/#serialize-a-cssmathvalue
pub fn (product CSSMathProduct) serialize_math_value(nested CSSMathValueNested, parens CSSMathValueParens) string {
	// NB: Only steps 1 and 5 apply here.
	// 1. Let s initially be the empty string.
	mut s := ''

	// 5. Otherwise, if this is a CSSMathProduct:
	{
		// 1. If paren-less is true, continue to the next step; otherwise, if nested is true, append "(" to s;
		//    otherwise, append "calc(" to s.
		if parens == .with {
			if nested == .yes {
				s += '('
			} else {
				s += 'calc('
			}
		}

		// 2. Serialize the first item in this's values internal slot with nested set to true, and append the result to s.
		values := product.values_.values()
		if values.len > 0 {
			s += values[0].serialize(CSSNumericSerializationParams{
				nested: true
			})
		}

		// 3. For each arg in this's values internal slot beyond the first:
		for i := 1; i < values.len; i++ {
			arg := values[i]

			// 1. If arg is a CSSMathInvert, append " / " to s, then serialize arg's value internal slot with nested
			//    set to true, and append the result to s.
			if arg is CSSMathInvert {
				s += ' / '
				s += arg.value().serialize(CSSNumericSerializationParams{
					nested: true
				})
			}
			// 2. Otherwise, append " * " to s, then serialize arg with nested set to true, and append the result to s.
			else {
				s += ' * '
				s += arg.serialize(CSSNumericSerializationParams{
					nested: true
				})
			}
		}

		// 4. If paren-less is false, append ")" to s,
		if parens == .with {
			s += ')'
		}

		// 5. Return s.
	}
	return s
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssmathproduct-values
pub fn (product CSSMathProduct) values() CSSNumericArray {
	return product.values_
}

// https://drafts.css-houdini.org/css-typed-om-1/#equal-numeric-value
pub fn (product CSSMathProduct) is_equal_numeric_value(other CSSNumericValue) bool {
	// NB: Only steps 1 and 3 are relevant.
	// 1. If value1 and value2 are not members of the same interface, return false.
	if other !is CSSMathProduct {
		return false
	}
	other_product := other as CSSMathProduct

	// 3. If value1 and value2 are both CSSMathSums, CSSMathProducts, CSSMathMins, or CSSMathMaxs:
	// NB: Substeps are implemented in CSSNumericArray.
	return product.values_.is_equal_numeric_values(other_product.values_)
}

// https://drafts.css-houdini.org/css-typed-om-1/#create-a-sum-value
pub fn (product CSSMathProduct) create_a_sum_value() ?SumValue {
	// 1. Let values initially be the sum value <(1, <[ ]>)>. (I.e. what you'd get from 1.)
	mut values := SumValue{
		len: 1
	}
	values[0] = SumValueItem{
		value:    1
		unit_map: map[string]int{}
	}

	// 2. For each item in this's values internal slot:
	for item in product.values_.values() {
		// 1. Let new values be the result of creating a sum value from item.
		//    Let temp initially be an empty list.
		new_values := item.create_a_sum_value() or { return none }
		mut temp := SumValue{}

		// 3. For each item1 in values:
		for item1 in values {
			// 1. For each item2 in new values:
			for item2 in new_values {
				// 1. Let item be a tuple with its value set to the product of the values of item1 and item2, and its
				//    unit map set to the product of the unit maps of item1 and item2, with all entries with a zero
				//    value removed.
				mut unit_map := product_of_two_unit_maps(item1.unit_map, item2.unit_map)
				remove_zero_entries_from_unit_map(mut unit_map)

				// 2. Append item to temp.
				temp << SumValueItem{
					value:    item1.value * item2.value
					unit_map: unit_map
				}
			}
		}

		// 4. Set values to temp.
		values = temp
	}

	// 3. Return values.
	return values
}

pub fn (product CSSMathProduct) create_calculation_node(context CalculationContext) !CalculationNode {
	mut children := []CalcNode{}
	for child_value in product.values_.values() {
		children << child_value.create_calculation_node(context)!.typed_node()!
	}
	return calculation_node_from_calc(CalcNode(CalcProduct{
		children: children
	}))
}

pub fn CSSMathNegate.create(type_ NumericType, value CSSNumericValue) CSSMathNegate {
	return CSSMathNegate{
		type_:  type_
		value_: [value]
	}
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssmathnegate-cssmathnegate
pub fn CSSMathNegate.construct_impl(value CSSNumberish) CSSMathNegate {
	// The CSSMathNegate(arg) constructor must, when called, perform the following steps:
	// 1. Replace arg with the result of rectifying a numberish value for arg.
	converted_value := rectify_a_numberish_value(value)

	// 2. Return a new CSSMathNegate whose value internal slot is set to arg.
	return CSSMathNegate.create(converted_value.type_(), converted_value)
}

// https://drafts.css-houdini.org/css-typed-om-1/#serialize-a-cssmathvalue
pub fn (negate CSSMathNegate) serialize_math_value(nested CSSMathValueNested, parens CSSMathValueParens) string {
	// NB: Only steps 1 and 4 apply here.
	// 1. Let s initially be the empty string.
	mut s := ''

	// 4. Otherwise, if this is a CSSMathNegate:
	{
		// 1. If paren-less is true, continue to the next step; otherwise, if nested is true, append "(" to s;
		//    otherwise, append "calc(" to s.
		if parens == .with {
			if nested == .yes {
				s += '('
			} else {
				s += 'calc('
			}
		}

		// 2. Append "-" to s.
		s += '-'

		// 3. Serialize this's value internal slot with nested set to true, and append the result to s.
		s += negate.value_[0].serialize(CSSNumericSerializationParams{
			nested: true
		})

		// 4. If paren-less is false, append ")" to s,
		if parens == .with {
			s += ')'
		}

		// 5. Return s.
	}
	return s
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssmathnegate-value
pub fn (negate CSSMathNegate) value() CSSNumericValue {
	return negate.value_[0]
}

// https://drafts.css-houdini.org/css-typed-om-1/#equal-numeric-value
pub fn (negate CSSMathNegate) is_equal_numeric_value(other CSSNumericValue) bool {
	// NB: Only steps 1, 4 and 5 are relevant.
	// 1. If value1 and value2 are not members of the same interface, return false.
	if other !is CSSMathNegate {
		return false
	}
	other_negate := other as CSSMathNegate

	// 4. Assert: value1 and value2 are both CSSMathNegates or CSSMathInverts.
	// 5. Return whether value1's value and value2's value are equal numeric values.
	return negate.value_[0].is_equal_numeric_value(other_negate.value_[0])
}

// https://drafts.css-houdini.org/css-typed-om-1/#create-a-sum-value
pub fn (negate CSSMathNegate) create_a_sum_value() ?SumValue {
	// 1. Let values be the result of creating a sum value from this's value internal slot.
	mut values := negate.value_[0].create_a_sum_value() or { return none }

	// 2. If values is failure, return failure.

	// 3. Negate the value of each item of values.
	for mut value in values {
		value.value = -value.value
	}

	// 4. Return values.
	return values
}

pub fn (negate CSSMathNegate) create_calculation_node(context CalculationContext) !CalculationNode {
	child := negate.value_[0].create_calculation_node(context)!
	return calculation_node_from_calc(CalcNode(CalcNegate{
		children: [child.typed_node()!]
	}))
}

pub fn CSSMathInvert.create(type_ NumericType, value CSSNumericValue) CSSMathInvert {
	return CSSMathInvert{
		type_:  type_
		value_: [value]
	}
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssmathinvert-cssmathinvert
pub fn CSSMathInvert.construct_impl(value CSSNumberish) CSSMathInvert {
	// The CSSMathInvert(arg) constructor is defined identically to the above, except that in the last step it returns
	// a new CSSMathInvert object.
	// NB: So, the steps below are a modification of the CSSMathNegate steps.

	// 1. Replace arg with the result of rectifying a numberish value for arg.
	converted_value := rectify_a_numberish_value(value)

	// 2. Return a new CSSMathInvert whose value internal slot is set to arg.
	return CSSMathInvert.create(converted_value.type_().inverted(), converted_value)
}

// https://drafts.css-houdini.org/css-typed-om-1/#serialize-a-cssmathvalue
pub fn (invert CSSMathInvert) serialize_math_value(nested CSSMathValueNested, parens CSSMathValueParens) string {
	// NB: Only steps 1 and 6 apply here.
	// 1. Let s initially be the empty string.
	mut s := ''

	// 6. Otherwise, if this is a CSSMathInvert:
	{
		// 1. If paren-less is true, continue to the next step; otherwise, if nested is true, append "(" to s;
		//    otherwise, append "calc(" to s.
		if parens == .with {
			if nested == .yes {
				s += '('
			} else {
				s += 'calc('
			}
		}

		// 2. Append "1 / " to s.
		s += '1 / '

		// 3. Serialize this's value internal slot with nested set to true, and append the result to s.
		s += invert.value_[0].serialize(CSSNumericSerializationParams{
			nested: true
		})

		// 4. If paren-less is false, append ")" to s,
		if parens == .with {
			s += ')'
		}

		// 5. Return s.
	}
	return s
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssmathinvert-value
pub fn (invert CSSMathInvert) value() CSSNumericValue {
	return invert.value_[0]
}

// https://drafts.css-houdini.org/css-typed-om-1/#equal-numeric-value
pub fn (invert CSSMathInvert) is_equal_numeric_value(other CSSNumericValue) bool {
	// NB: Only steps 1, 4 and 5 are relevant.
	// 1. If value1 and value2 are not members of the same interface, return false.
	if other !is CSSMathInvert {
		return false
	}
	other_invert := other as CSSMathInvert

	// 4. Assert: value1 and value2 are both CSSMathNegates or CSSMathInverts.
	// 5. Return whether value1's value and value2's value are equal numeric values.
	return invert.value_[0].is_equal_numeric_value(other_invert.value_[0])
}

// https://drafts.css-houdini.org/css-typed-om-1/#create-a-sum-value
pub fn (invert CSSMathInvert) create_a_sum_value() ?SumValue {
	// 1. Let values be the result of creating a sum value from this's value internal slot.
	mut values := invert.value_[0].create_a_sum_value() or { return none }

	// 2. If values is failure, return failure.

	// 3. If the length of values is more than one, return failure.
	if values.len > 1 {
		return none
	}

	// 4. Invert (find the reciprocal of) the value of the item in values, and negate the value of each entry in its unit map.
	for mut value in values {
		value.value = 1.0 / value.value
		for unit, power in value.unit_map {
			value.unit_map[unit] = -power
		}
	}

	// 5. Return values.
	return values
}

pub fn (invert CSSMathInvert) create_calculation_node(context CalculationContext) !CalculationNode {
	child := invert.value_[0].create_calculation_node(context)!
	return calculation_node_from_calc(CalcNode(CalcInvert{
		children: [child.typed_node()!]
	}))
}

pub fn CSSMathMin.create(type_ NumericType, values CSSNumericArray) CSSMathMin {
	return CSSMathMin{
		type_:   type_
		values_: values
	}
}

pub fn CSSMathMin.add_all_types_into_math_min(values []CSSNumericValue) !CSSMathMin {
	if values.len == 0 {
		return error('Cannot create an empty CSSMathMin')
	}
	mut type_ := values[0].type_()
	for i := 1; i < values.len; i++ {
		if added_types := type_.added_to(values[i].type_()) {
			type_ = added_types
		} else {
			return error('Cannot create a CSSMathMin with values of incompatible types')
		}
	}

	values_array := CSSNumericArray.create(values)
	return CSSMathMin.create(type_, values_array)
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssmathmin-cssmathmin
pub fn CSSMathMin.construct_impl(values []CSSNumberish) !CSSMathMin {
	// The CSSMathMin(...args) and CSSMathMax(...args) constructors are defined identically to the above, except that
	// in the last step they return a new CSSMathMin or CSSMathMax object, respectively.
	// NB: So, the steps below are a modification of the CSSMathSum steps.

	// 1. Replace each item of args with the result of rectifying a numberish value for the item.
	mut converted_values := []CSSNumericValue{cap: values.len}
	for value in values {
		converted_values << rectify_a_numberish_value(value)
	}

	// 2. If args is empty, throw a SyntaxError.
	if converted_values.len == 0 {
		return error('Cannot create an empty CSSMathMin')
	}

	// 3. Let type be the result of adding the types of all the items of args. If type is failure, throw a TypeError.
	// 4. Return a new CSSMathMin whose values internal slot is set to args.
	return CSSMathMin.add_all_types_into_math_min(converted_values)
}

// https://drafts.css-houdini.org/css-typed-om-1/#serialize-a-cssmathvalue
pub fn (min CSSMathMin) serialize_math_value(nested CSSMathValueNested, parens CSSMathValueParens) string {
	_ = nested
	_ = parens
	return serialize_min_or_max_math_value('min', min.values_)
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssmathmin-values
pub fn (min CSSMathMin) values() CSSNumericArray {
	return min.values_
}

// https://drafts.css-houdini.org/css-typed-om-1/#equal-numeric-value
pub fn (min CSSMathMin) is_equal_numeric_value(other CSSNumericValue) bool {
	// NB: Only steps 1 and 3 are relevant.
	// 1. If value1 and value2 are not members of the same interface, return false.
	if other !is CSSMathMin {
		return false
	}
	other_min := other as CSSMathMin

	// 3. If value1 and value2 are both CSSMathSums, CSSMathProducts, CSSMathMins, or CSSMathMaxs:
	// NB: Substeps are implemented in CSSNumericArray.
	return min.values_.is_equal_numeric_values(other_min.values_)
}

// https://drafts.css-houdini.org/css-typed-om-1/#create-a-sum-value
pub fn (min CSSMathMin) create_a_sum_value() ?SumValue {
	// 1. Let args be the result of creating a sum value for each item in this's values internal slot.
	mut args := []?SumValue{cap: int(min.values_.length())}
	for value in min.values_.values() {
		args << value.create_a_sum_value()
	}

	if args.len == 0 {
		return none
	}

	mut item_with_smallest_value := args[0] or { return none }
	for item in args {
		// 2. If any item of args is failure, or has a length greater than one, return failure.
		actual_item := item or { return none }
		if actual_item.len > 1 {
			return none
		}

		// 3. If not all of the unit maps among the items of args are identical, return failure.
		if actual_item[0].unit_map != item_with_smallest_value[0].unit_map {
			return none
		}

		if actual_item[0].value < item_with_smallest_value[0].value {
			item_with_smallest_value = actual_item.clone()
		}
	}

	// 4. Return the item of args whose sole item has the smallest value.
	return item_with_smallest_value
}

pub fn (min CSSMathMin) create_calculation_node(context CalculationContext) !CalculationNode {
	mut children := []CalcNode{}
	for child_value in min.values_.values() {
		children << child_value.create_calculation_node(context)!.typed_node()!
	}
	return calculation_node_from_calc(CalcNode(CalcFunction{
		name:     'min'
		children: children
	}))
}

pub fn CSSMathMax.create(type_ NumericType, values CSSNumericArray) CSSMathMax {
	return CSSMathMax{
		type_:   type_
		values_: values
	}
}

pub fn CSSMathMax.add_all_types_into_math_max(values []CSSNumericValue) !CSSMathMax {
	if values.len == 0 {
		return error('Cannot create an empty CSSMathMax')
	}
	mut type_ := values[0].type_()
	for i := 1; i < values.len; i++ {
		if added_types := type_.added_to(values[i].type_()) {
			type_ = added_types
		} else {
			return error('Cannot create a CSSMathMax with values of incompatible types')
		}
	}

	values_array := CSSNumericArray.create(values)
	return CSSMathMax.create(type_, values_array)
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssmathmin-cssmathmin
pub fn CSSMathMax.construct_impl(values []CSSNumberish) !CSSMathMax {
	// The CSSMathMin(...args) and CSSMathMax(...args) constructors are defined identically to the above, except that
	// in the last step they return a new CSSMathMin or CSSMathMax object, respectively.
	// NB: So, the steps below are a modification of the CSSMathSum steps.

	// 1. Replace each item of args with the result of rectifying a numberish value for the item.
	mut converted_values := []CSSNumericValue{cap: values.len}
	for value in values {
		converted_values << rectify_a_numberish_value(value)
	}

	// 2. If args is empty, throw a SyntaxError.
	if converted_values.len == 0 {
		return error('Cannot create an empty CSSMathMax')
	}

	// 3. Let type be the result of adding the types of all the items of args. If type is failure, throw a TypeError.
	// 4. Return a new CSSMathMax whose values internal slot is set to args.
	return CSSMathMax.add_all_types_into_math_max(converted_values)
}

// https://drafts.css-houdini.org/css-typed-om-1/#serialize-a-cssmathvalue
pub fn (max CSSMathMax) serialize_math_value(nested CSSMathValueNested, parens CSSMathValueParens) string {
	_ = nested
	_ = parens
	return serialize_min_or_max_math_value('max', max.values_)
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssmathmin-values
pub fn (max CSSMathMax) values() CSSNumericArray {
	return max.values_
}

// https://drafts.css-houdini.org/css-typed-om-1/#equal-numeric-value
pub fn (max CSSMathMax) is_equal_numeric_value(other CSSNumericValue) bool {
	// NB: Only steps 1 and 3 are relevant.
	// 1. If value1 and value2 are not members of the same interface, return false.
	if other !is CSSMathMax {
		return false
	}
	other_max := other as CSSMathMax

	// 3. If value1 and value2 are both CSSMathSums, CSSMathProducts, CSSMathMins, or CSSMathMaxs:
	// NB: Substeps are implemented in CSSNumericArray.
	return max.values_.is_equal_numeric_values(other_max.values_)
}

// https://drafts.css-houdini.org/css-typed-om-1/#create-a-sum-value
pub fn (max CSSMathMax) create_a_sum_value() ?SumValue {
	// 1. Let args be the result of creating a sum value for each item in this's values internal slot.
	mut args := []?SumValue{cap: int(max.values_.length())}
	for value in max.values_.values() {
		args << value.create_a_sum_value()
	}

	if args.len == 0 {
		return none
	}

	mut item_with_largest_value := args[0] or { return none }
	for item in args {
		// 2. If any item of args is failure, or has a length greater than one, return failure.
		actual_item := item or { return none }
		if actual_item.len > 1 {
			return none
		}

		// 3. If not all of the unit maps among the items of args are identical, return failure.
		if actual_item[0].unit_map != item_with_largest_value[0].unit_map {
			return none
		}

		if actual_item[0].value > item_with_largest_value[0].value {
			item_with_largest_value = actual_item.clone()
		}
	}

	// 4. Return the item of args whose sole item has the largest value.
	return item_with_largest_value
}

pub fn (max CSSMathMax) create_calculation_node(context CalculationContext) !CalculationNode {
	mut children := []CalcNode{}
	for child_value in max.values_.values() {
		children << child_value.create_calculation_node(context)!.typed_node()!
	}
	return calculation_node_from_calc(CalcNode(CalcFunction{
		name:     'max'
		children: children
	}))
}

pub fn CSSMathClamp.create(type_ NumericType, lower CSSNumericValue, value CSSNumericValue, upper CSSNumericValue) CSSMathClamp {
	return CSSMathClamp{
		type_:  type_
		lower_: [lower]
		value_: [value]
		upper_: [upper]
	}
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssmathclamp-cssmathclamp
pub fn CSSMathClamp.construct_impl(lower CSSNumberish, value CSSNumberish, upper CSSNumberish) !CSSMathClamp {
	// The CSSMathClamp(lower, value, upper) constructor must, when called, perform the following steps:
	// 1. Replace lower, value, and upper with the result of rectifying a numberish value for each.
	lower_rectified := rectify_a_numberish_value(lower)
	value_rectified := rectify_a_numberish_value(value)
	upper_rectified := rectify_a_numberish_value(upper)

	// 2. Let type be the result of adding the types of lower, value, and upper. If type is failure, throw a TypeError.
	lower_and_value_type := lower_rectified.type_().added_to(value_rectified.type_()) or {
		return error('Cannot create a CSSMathClamp with values of incompatible types')
	}
	type_ := lower_and_value_type.added_to(upper_rectified.type_()) or {
		return error('Cannot create a CSSMathClamp with values of incompatible types')
	}

	// 3. Return a new CSSMathClamp whose lower, value, and upper internal slots are set to lower, value, and upper, respectively.
	return CSSMathClamp.create(type_, lower_rectified, value_rectified, upper_rectified)
}

// https://drafts.css-houdini.org/css-typed-om-1/#serialize-a-cssmathvalue
pub fn (clamp_value CSSMathClamp) serialize_math_value(nested CSSMathValueNested, parens CSSMathValueParens) string {
	_ = nested
	_ = parens
	// AD-HOC: The spec is missing serialization rules for CSSMathClamp: https://github.com/w3c/css-houdini-drafts/issues/1152
	mut s := 'clamp('
	s += clamp_value.lower_[0].serialize(CSSNumericSerializationParams{
		nested:    true
		parenless: true
	})
	s += ', '
	s += clamp_value.value_[0].serialize(CSSNumericSerializationParams{
		nested:    true
		parenless: true
	})
	s += ', '
	s += clamp_value.upper_[0].serialize(CSSNumericSerializationParams{
		nested:    true
		parenless: true
	})
	s += ')'
	return s
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssmathclamp-lower
pub fn (clamp_value CSSMathClamp) lower() CSSNumericValue {
	// AD-HOC: No spec definition.
	return clamp_value.lower_[0]
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssmathclamp-value
pub fn (clamp_value CSSMathClamp) value() CSSNumericValue {
	// AD-HOC: No spec definition.
	return clamp_value.value_[0]
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssmathclamp-upper
pub fn (clamp_value CSSMathClamp) upper() CSSNumericValue {
	// AD-HOC: No spec definition.
	return clamp_value.upper_[0]
}

// https://drafts.css-houdini.org/css-typed-om-1/#equal-numeric-value
pub fn (clamp_value CSSMathClamp) is_equal_numeric_value(other CSSNumericValue) bool {
	// AD-HOC: Spec doesn't handle clamp(). https://github.com/w3c/css-houdini-drafts/issues/1152
	// 1. If value1 and value2 are not members of the same interface, return false.
	if other !is CSSMathClamp {
		return false
	}
	other_clamp := other as CSSMathClamp

	return clamp_value.lower_[0].is_equal_numeric_value(other_clamp.lower_[0])
		&& clamp_value.value_[0].is_equal_numeric_value(other_clamp.value_[0])
		&& clamp_value.upper_[0].is_equal_numeric_value(other_clamp.upper_[0])
}

// https://drafts.css-houdini.org/css-typed-om-1/#create-a-sum-value
pub fn (clamp_value CSSMathClamp) create_a_sum_value() ?SumValue {
	// AD-HOC: There is no spec for this. https://github.com/w3c/css-houdini-drafts/issues/1152
	//         So, basing it on the spec for CSSMathMin.

	// Create sum values from lower, value, and upper.
	lower := clamp_value.lower_[0].create_a_sum_value()
	value := clamp_value.value_[0].create_a_sum_value()
	upper := clamp_value.upper_[0].create_a_sum_value()

	// If any of those are failure, or has a length greater than one, return failure.
	actual_lower := lower or { return none }
	actual_value := value or { return none }
	actual_upper := upper or { return none }
	if actual_lower.len > 1 || actual_value.len > 1 || actual_upper.len > 1 {
		return none
	}

	// If not all their unit maps are identical, return failure.
	if actual_lower[0].unit_map != actual_value[0].unit_map
		|| actual_value[0].unit_map != actual_upper[0].unit_map {
		return none
	}

	// Return value clamped between lower and upper.
	return [
		SumValueItem{
			value:    math.max(actual_lower[0].value, math.min(actual_value[0].value,
				actual_upper[0].value))
			unit_map: actual_value[0].unit_map
		},
	]
}

pub fn (clamp_value CSSMathClamp) create_calculation_node(context CalculationContext) !CalculationNode {
	lower := clamp_value.lower_[0].create_calculation_node(context)!
	value := clamp_value.value_[0].create_calculation_node(context)!
	upper := clamp_value.upper_[0].create_calculation_node(context)!
	return calculation_node_from_calc(CalcNode(CalcFunction{
		name: 'clamp'
		children: [lower.typed_node()!, value.typed_node()!, upper.typed_node()!]
	}))
}

fn serialize_min_or_max_math_value(name string, values CSSNumericArray) string {
	// NB: Only steps 1 and 2 apply here.
	// 1. Let s initially be the empty string.
	mut s := ''

	// 2. If this is a CSSMathMin or CSSMathMax:
	{
		// 1. Append "min(" or "max(" to s, as appropriate.
		s += '${name}('

		// 2. For each arg in this's values internal slot, serialize arg with nested and paren-less both true, and
		//    append the result to s, appending a ", " between successive values.
		mut first := true
		for arg in values.values() {
			if first {
				first = false
			} else {
				s += ', '
			}
			s += arg.serialize(CSSNumericSerializationParams{
				nested:    true
				parenless: true
			})
		}

		// 3. Append ")" to s and return s.
		s += ')'
	}
	return s
}

fn remove_zero_entries_from_unit_map(mut unit_map map[string]int) {
	mut keys_to_remove := []string{}
	for unit, power in unit_map {
		if power == 0 {
			keys_to_remove << unit
		}
	}
	for unit in keys_to_remove {
		unit_map.delete(unit)
	}
}

fn numeric_type_from_sum_value_unit_map(unit_map map[string]int) ?NumericType {
	if unit_map.len == 0 {
		return NumericType.new()
	}
	return NumericType.create_from_unit_map(unit_map)
}
