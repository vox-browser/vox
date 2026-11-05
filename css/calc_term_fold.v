module css

import os
import sync.stdatomic

const retain_calc_term_arrays = os.getenv('VOX_RETAIN_CALC_TERM_ARRAYS') != ''
const calc_term_fold_diagnostics = os.getenv('VOX_CALC_TERM_FOLD_DIAGNOSTICS') != ''
__global calc_term_fold_reported stdatomic.AtomicVal[bool]

// The parser has already validated the complete alternating sequence. Build
// products directly from it, then append the same sum children as the original
// fold. A subtracted product stays inside one negate node, and each divided
// operand stays inside its own invert node; no arithmetic is reassociated.
fn fold_calc_terms(terms []CalcTerm) CalcNode {
	if retain_calc_term_arrays { return fold_calc_terms_with_intermediate_arrays(terms) }
	if calc_term_fold_diagnostics && calc_term_fold_reported.compare_and_swap(false, true) {
		eprintln('Vox calculation parser: validated terms folded without intermediate arrays')
	}
	if terms.len == 1 { return terms[0].node }
	mut factors := [terms[0].node]
	mut sum_children := []CalcNode{}
	mut negate_product := false
	for index := 1; index < terms.len; index += 2 {
		operator := terms[index].operator
		right := terms[index + 1].node
		if operator == u8(`*`) {
			factors << right
		} else if operator == u8(`/`) {
			factors << CalcNode(CalcInvert{children: [right]})
		} else {
			product := make_calc_product(factors)
			sum_children << if negate_product { CalcNode(CalcNegate{children: [product]}) } else { product }
			negate_product = operator == u8(`-`)
			factors = [right]
		}
	}
	product := make_calc_product(factors)
	if sum_children.len == 0 { return product }
	sum_children << if negate_product { CalcNode(CalcNegate{children: [product]}) } else { product }
	return CalcNode(CalcSum{children: sum_children})
}

// Retain the original fold for matched instruction and tree comparisons.
fn fold_calc_terms_with_intermediate_arrays(terms []CalcTerm) CalcNode {
	// Split into operands and the operators between them.
	mut operands := []CalcNode{}
	mut operators := []u8{}
	for term in terms {
		if term.is_operator {
			operators << term.operator
		} else {
			operands << term.node
		}
	}

	// Fold products (`*` and `/`) first, leaving a sum-level operand list.
	mut sum_operands := []CalcNode{}
	mut sum_operators := []u8{}
	mut factors := [operands[0]]
	for index := 0; index < operators.len; index++ {
		operator := operators[index]
		right := operands[index + 1]
		if operator == u8(`*`) {
			factors << right
		} else if operator == u8(`/`) {
			factors << CalcNode(CalcInvert{
				children: [right]
			})
		} else {
			sum_operands << make_calc_product(factors)
			sum_operators << operator
			factors = [right]
		}
	}
	sum_operands << make_calc_product(factors)

	if sum_operands.len == 1 {
		return sum_operands[0]
	}

	// Fold the sum, wrapping subtracted operands in CalcNegate.
	mut sum_children := [sum_operands[0]]
	for index := 0; index < sum_operators.len; index++ {
		right := sum_operands[index + 1]
		if sum_operators[index] == u8(`-`) {
			sum_children << CalcNode(CalcNegate{
				children: [right]
			})
		} else {
			sum_children << right
		}
	}
	return CalcNode(CalcSum{
		children: sum_children
	})
}
