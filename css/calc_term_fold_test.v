module css

import math
import platform

fn calc_fold_number(value f64) CalcNode {
	return CalcNode(CalcNumeric{kind: .number, value: value, type_: NumericType.new()})
}

fn test_calc_term_fold_preserves_exact_trees_for_all_short_operator_sequences() {
	operators := [u8(`+`), `-`, `*`, `/`]
	for count in 1 .. 7 {
		mut combinations := 1
		for _ in 1 .. count { combinations *= 4 }
		for code in 0 .. combinations {
			mut terms := [CalcTerm{node: calc_fold_number(11)}]
			mut remaining := code
			for index in 1 .. count {
				terms << CalcTerm{is_operator: true, operator: operators[remaining % 4]}
				terms << CalcTerm{node: calc_fold_number(f64(index + 2))}
				remaining /= 4
			}
			actual := fold_calc_terms(terms)
			expected := fold_calc_terms_with_intermediate_arrays(terms)
			// Compare the unsimplified tree: serialization alone can hide changes
			// in child order, division grouping or subtraction association.
			assert actual == expected, 'operands=${count} operators=${code}'
			assert serialize_a_calculation_tree(actual, true) == serialize_a_calculation_tree(expected, true)
		}
	}
}

fn test_calc_term_fold_keeps_signed_zero_nonfinite_and_nested_operands() {
	for value in [-0.0, math.inf(1), math.inf(-1), math.nan()] {
		leaf := calc_fold_number(value)
		actual := fold_calc_terms([CalcTerm{node: leaf}])
		assert actual is CalcNumeric
		if actual is CalcNumeric { assert math.f64_bits(actual.value) == math.f64_bits(value) }
	}
	// Child subexpressions remain opaque: neither fold flattens or rewrites
	// existing sum/product nodes while grouping the enclosing calculation.
	leaves := [calc_fold_number(3), CalcNode(CalcSum{children: [calc_fold_number(5), calc_fold_number(7)]}),
		CalcNode(CalcProduct{children: [calc_fold_number(2), calc_fold_number(4)]})]
	terms := [CalcTerm{node: leaves[0]}, CalcTerm{is_operator: true, operator: `-`}, CalcTerm{node: leaves[1]},
		CalcTerm{is_operator: true, operator: `/`}, CalcTerm{node: leaves[2]},
		CalcTerm{is_operator: true, operator: `+`}, CalcTerm{node: leaves[0]}]
	assert fold_calc_terms(terms) == fold_calc_terms_with_intermediate_arrays(terms)
	assert terms[1].operator == `-` && terms[3].operator == `/`
	assert terms[2].node == leaves[1] && terms[4].node == leaves[2]
}

fn test_calc_term_fold_retains_operator_grammar_and_nonassociative_results() {
	for invalid in ['calc()', 'calc(1 +)', 'calc(* 2)', 'calc(1 2)', 'calc(1 + * 2)',
		'calc(1 / / 2)', 'calc(1 - + 2)', 'calc(1 + 2 3)'] {
		assert parse_css_value(ParsingParams{}, invalid, .opacity) == none, invalid
	}
	for source, expected in {
		'calc(12 / 2 / 3)': 'calc(2)'
		'calc(12 / (2 / 3))': 'calc(18)'
		'calc(12 - 2 - 3)': 'calc(7)'
		'calc(12 - 2 * 3)': 'calc(6)'
		'calc(12 - 2 / 4 + 3 * 2)': 'calc(17.5)'
	} {
		value := parse_css_value(ParsingParams{}, source, .opacity) or { panic(source) }
		assert value.css_text == expected, source
	}
}

fn test_calc_term_fold_result_survives_temporary_workspace_retirement() {
	mut owner := platform.new_retained_arena('calc fold result')
	mut entered := owner.enter()
	mut input := platform.begin_thread_scratch('calc fold input')
	terms := [CalcTerm{node: calc_fold_number(11)}, CalcTerm{is_operator: true, operator: `-`},
		CalcTerm{node: calc_fold_number(2)}, CalcTerm{is_operator: true, operator: `/`}, CalcTerm{node: calc_fold_number(4)}]
	input.leave()
	result := fold_calc_terms(terms)
	input.finish()
	entered.finish()
	defer { owner.release() }
	churn := platform.begin_thread_scratch('calc fold overwrite')
	_ = []u8{len: 256 * 1024, init: u8(0xa5)}
	churn.finish()
	assert serialize_a_calculation_tree(result, false) == '11 - (2 / 4)'
	assert result is CalcSum
	if result is CalcSum {
		$if prealloc { assert owner.arena.contains(result.children.data) }
	}
}
