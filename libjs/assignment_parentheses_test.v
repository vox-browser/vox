module libjs

fn test_assignment_ast_retains_grouping_for_later_named_evaluation() {
	// Avoid a C trigraph in the old V compiler's generated string literal.
	for operator in ['=', '&&=', '||=', '?'.repeat(2) + '='] {
		for target in ['fn', '(fn)', '((fn))'] {
			parsed := parse_source('${target} ${operator} function() {};', .script)
			assert !parsed.has_errors(), '${parsed.diagnostics}'
			program := parsed.program.kind.program_data or { panic('missing program') }
			assignment := program.scope.children[0].kind.expression or {
				panic('missing expression')
			}

			assert assignment.kind.tag == .assignment
			assert parsed.dump_ast()!.contains('AssignmentExpression (${operator})')
			assert assignment.kind.lhs_is_parenthesized == target.starts_with('('), target
		}
	}
}

fn test_grouping_does_not_leak_through_secondary_member_access() {
	parsed := parse_source('(obj).fn = function() {};', .script)
	program := parsed.program.kind.program_data or { panic('missing program') }
	assignment := program.scope.children[0].kind.expression or { panic('missing expression') }
	assert !assignment.kind.lhs_is_parenthesized
	assert parse_source('({a}) = obj;', .script).has_errors()
	assert parse_source('([a]) = arr;', .script).has_errors()
	assert !parse_source('({a} = obj);', .script).has_errors()
	assert !parse_source('([a] = arr);', .script).has_errors()
}
