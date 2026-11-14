// SPDX-License-Identifier: BSD-2-Clause
module libjs

fn test_ordinary_expression_tails_preserve_call_member_and_binary_precedence() {
	parsed := parse_source('f(a).b[c] + g(d) * 2;', .script)
	assert !parsed.has_errors()
	statement := parsed.program.kind.program_data?.scope.children[0]
	expression := statement.kind.expression?
	assert expression.kind.tag == .binary && expression.kind.binary_op == .addition
	left := expression.kind.lhs?
	assert left.kind.tag == .member && left.kind.computed
	assert left.kind.object?.kind.tag == .member
	assert left.kind.object?.kind.object?.kind.tag == .call
	right := expression.kind.rhs?
	assert right.kind.tag == .binary && right.kind.binary_op == .multiplication
	assert right.kind.lhs?.kind.tag == .call
}

fn test_tagged_template_tails_retain_nested_tags_and_substitutions() {
	parsed := parse_source('tag`first\${value}last``second`.member;', .script)
	assert !parsed.has_errors()
	expression := parsed.program.kind.program_data?.scope.children[0].kind.expression?
	assert expression.kind.tag == .member
	outer := expression.kind.object?
	assert outer.kind.tag == .tagged_template_literal
	inner := outer.kind.tag_expr?
	assert inner.kind.tag == .tagged_template_literal
	assert inner.kind.tag_expr?.kind.tag == .identifier_expr
	assert inner.kind.template_literal_expr?.kind.tag == .template_literal
	assert inner.kind.template_literal_expr?.kind.template_data?.expressions.len == 3
}
