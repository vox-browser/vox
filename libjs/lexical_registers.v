module libjs

// Uncaptured let/const bindings live in registers, as upstream LibJS keeps
// them in locals. Upstream checks the temporal dead zone at run time with
// ThrowIfTDZ on an empty local; this port has no empty-local operand, so the
// generator proves instead that every read follows the binding's initialization
// in emission order. Inside a block, code emitted after a declaration runs only
// after that declaration in the same block entry: blocks are entered at their
// start, and loops nested in a block lie wholly before or after the declaration.
// Case blocks are the exception (a case can jump past a declaration), so
// case-level declarations stay in the environment. A read or write before the
// initialization, or an assignment to a const, rejects that binding; the
// function is then compiled again with the binding in its environment, which
// raises the ReferenceError or TypeError at run time.

struct LexicalRegisterCandidate {
	local_index u32
	constant    bool
}

struct LexicalRegisterExclusions {
	all           bool
	local_indices []u32
}

$if test {
	__global lexical_registers_disabled_for_test bool
	__global lexical_register_recompilations_for_test u64
	pub fn set_lexical_registers_for_testing(enabled bool) {
		lexical_registers_disabled_for_test = !enabled
	}
	pub fn lexical_register_recompilations_for_testing() u64 {
		return lexical_register_recompilations_for_test
	}
}

fn (exclusions LexicalRegisterExclusions) excludes(local_index u32) bool {
	return exclusions.all || local_index in exclusions.local_indices
}

// A second rejection keeps every lexical binding of the function in the
// environment, so a function compiles at most three times.
fn (exclusions LexicalRegisterExclusions) with_rejected(rejected []u32) LexicalRegisterExclusions {
	if exclusions.local_indices.len > 0 { return LexicalRegisterExclusions{all: true} }
	return LexicalRegisterExclusions{local_indices: rejected.clone()}
}

// The identifiers a declaration initializes, in the order of declaration_bound_names.
fn collect_declarator_identifiers(target VariableDeclaratorTarget, mut identifiers []&Identifier) {
	match target {
		IdentifierVarTarget { identifiers << target.identifier }
		BindingPatternVarTarget { collect_pattern_identifiers(target.pattern, mut identifiers) }
	}
}

fn collect_pattern_identifiers(pattern BindingPattern, mut identifiers []&Identifier) {
	for entry in pattern.entries {
		if identifier := binding_entry_identifier(entry) {
			identifiers << identifier
		} else if nested := entry.alias.binding_pattern {
			collect_pattern_identifiers(nested, mut identifiers)
		}
	}
}

// The identifier initialized by a binding pattern entry (generator.binding_entry_name).
fn binding_entry_identifier(entry BindingEntry) ?&Identifier {
	if identifier := entry.alias.identifier { return identifier }
	if entry.alias.kind == .none_kind {
		if identifier := entry.name.identifier { return identifier }
	}
	return none
}

// Let/const declarations of one function whose every initialization the
// generator emits through store_declared_binding. Nested functions have their
// own locals and are not visited.
fn collect_lexical_register_candidates(statement &Statement, mut candidates []LexicalRegisterCandidate) {
	kind := statement.kind
	match kind.tag {
		.block, .function_body {
			scope := kind.scope or { return }
			for child in scope.children { collect_lexical_register_candidates(&child, mut candidates) }
		}
		.variable_declaration {
			if kind.decl_kind == .var_kind { return }
			for declaration in kind.declarations {
				mut identifiers := []&Identifier{}
				collect_declarator_identifiers(declaration.target, mut identifiers)
				for identifier in identifiers {
					if identifier.local_type == 2 && !identifier.is_inside_scope_with_eval {
						candidates << LexicalRegisterCandidate{identifier.local_index, kind.decl_kind == .const_kind}
					}
				}
			}
		}
		.if_stmt {
			if consequent := kind.consequent { collect_lexical_register_candidates(consequent, mut candidates) }
			if alternate := kind.alternate { collect_lexical_register_candidates(alternate, mut candidates) }
		}
		.while_stmt, .do_while, .for_stmt, .for_in_of {
			if init := kind.for_init {
				if init is ForInitDeclaration { collect_lexical_register_candidates(init.statement, mut candidates) }
			}
			if lhs := kind.for_in_of_lhs {
				if lhs is ForInOfLhsDeclaration { collect_lexical_register_candidates(lhs.statement, mut candidates) }
			}
			if body := kind.body { collect_lexical_register_candidates(body, mut candidates) }
		}
		.switch_stmt {
			data := kind.switch_data or { return }
			for clause in data.cases {
				for child in clause.scope.children {
					if child.kind.tag != .variable_declaration { collect_lexical_register_candidates(&child, mut candidates) }
				}
			}
		}
		.try_stmt {
			data := kind.try_data or { return }
			collect_lexical_register_candidates(&data.block, mut candidates)
			if handler := data.handler { collect_lexical_register_candidates(&handler.body, mut candidates) }
			if finalizer := data.finalizer { collect_lexical_register_candidates(&finalizer, mut candidates) }
		}
		.labelled {
			if item := kind.labelled_item { collect_lexical_register_candidates(item, mut candidates) }
		}
		else {}
	}
}

// Appends the function's lexical register bindings after its parameter and var
// bindings. They are generator-only: calls initialize no lexical binding, and
// name-based parameter/var queries never see them.
fn (mut generator BytecodeGenerator) add_lexical_registers(body &Statement, scope &ScopeData, exclusions LexicalRegisterExclusions) {
	$if test {
		if lexical_registers_disabled_for_test { return }
	}
	if exclusions.all { return }
	mut candidates := []LexicalRegisterCandidate{}
	collect_lexical_register_candidates(body, mut candidates)
	mut added := map[int]bool{}
	for candidate in candidates {
		index := int(candidate.local_index)
		if index >= scope.local_variables.len || scope.local_variables[index].kind != .let_or_const
			|| exclusions.excludes(candidate.local_index) || index in added {
			continue
		}
		added[index] = true
		generator.register_bindings << FunctionRegisterBinding{
			name:        scope.local_variables[index].name
			slot:        u32(generator.register_bindings.len)
			local_type:  2
			local_index: candidate.local_index
			lexical:     true
			constant:    candidate.constant
		}
	}
}

fn (generator &BytecodeGenerator) lexical_register_position(identifier &Identifier) ?int {
	if identifier.local_type != 2 { return none }
	position := generator.identifier_register_position(identifier) or { return none }
	return if generator.register_bindings[position].lexical { position } else { none }
}

// Whether every binding of a let/const declaration statement is a register.
fn (generator &BytecodeGenerator) declaration_in_registers(declaration &Statement) bool {
	for declarator in declaration.kind.declarations {
		mut identifiers := []&Identifier{}
		collect_declarator_identifiers(declarator.target, mut identifiers)
		for identifier in identifiers {
			if generator.lexical_register_position(identifier) == none { return false }
		}
	}
	return true
}

// Whether a block's let/const declarations all live in registers. Class and
// function declarations are checked separately by elide_empty_block.
fn (generator &BytecodeGenerator) lexicals_in_registers(children []Statement) bool {
	for child in children {
		if child.kind.tag == .variable_declaration && child.kind.decl_kind != .var_kind
			&& !generator.declaration_in_registers(&child) {
			return false
		}
	}
	return true
}

// Initializes a lexical register at its declaration.
fn (mut generator BytecodeGenerator) initialize_lexical_register(identifier &Identifier, value Operand) bool {
	position := generator.lexical_register_position(identifier) or { return false }
	generator.emit(Instruction{op: .mov, dst: Operand.local(generator.register_bindings[position].slot), lhs: value})
	generator.lexical_initialized[position] = true
	return true
}
