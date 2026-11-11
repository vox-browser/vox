// Copyright (c) 2026-present, the Ladybird developers.
//
// SPDX-License-Identifier: BSD-2-Clause

module libjs

// Scope analysis for the parser — translated from scope_collector.rs.

// === Enums ===

enum ScopeType {
	function_scope
	program_scope
	block_scope
	for_loop_scope
	with_scope
	catch_scope
	class_static_init
	class_field
	class_declaration
}

enum ScopeLevel {
	not_top_level
	script_top_level
	module_top_level
	function_top_level
	static_init_top_level
}

fn (sl ScopeLevel) is_top_level() bool {
	return sl != .not_top_level
}

// === Variable flags (bitflags) ===

const var_flag_empty = u16(0)
const var_flag_var = u16(1 << 0)
const var_flag_lexical = u16(1 << 1)
const var_flag_function = u16(1 << 2)
const var_flag_catch_parameter = u16(1 << 3)
const var_flag_forbidden_lexical = u16(1 << 4)
const var_flag_forbidden_var = u16(1 << 5)
const var_flag_bound = u16(1 << 6)
const var_flag_parameter_candidate = u16(1 << 7)
const var_flag_referenced_in_formal_parameters = u16(1 << 8)
// Function-level declarations are also vars, but unlike `var arguments` they
// replace the implicit arguments object. Keep that identity out of the flags
// used to reject lexical redeclarations.
const var_flag_function_declaration = u16(1 << 9)

// === Data structures ===

struct ScopeVariable {
mut:
	flags          u16
	var_identifier ?&Identifier
}

struct IdentifierGroup {
mut:
	captured_by_nested_function bool
	used_inside_with_statement  bool
	identifiers                 []&Identifier
	declaration_kind            int // 0=none, 1=var, 2=let, 3=const
}

struct HoistableFunction {
mut:
	name             Utf16String
	block_scope_data ?&ScopeData
}

struct ParameterName {
	name    Utf16String
	is_rest bool
}

struct ParameterEntry {
mut:
	name                  Utf16String
	identifier            ?&Identifier
	is_rest               bool
	is_from_pattern       bool
	is_first_from_pattern bool
}

struct ScopeRecord {
mut:
	scope_type  ScopeType
	scope_level ScopeLevel
	scope_data  ?&ScopeData

	variables          map[string]ScopeVariable
	identifier_groups  map[string]IdentifierGroup
	functions_to_hoist []HoistableFunction

	// Parameter tracking
	has_function_parameters bool
	parameter_names         []ParameterName

	// Flags
	contains_access_to_arguments_object_in_non_strict_mode bool
	contains_direct_call_to_eval                           bool
	contains_await_expression                              bool
	poisoned_by_eval_in_scope_chain                        bool
	eval_in_current_function                               bool
	uses_this_from_environment                             bool
	uses_this                                              bool
	is_arrow_function                                      bool
	is_function_declaration                                bool
	has_parameter_expressions                              bool

	// Tree (indices into ScopeCollector.records)
	parent    int // -1 = none
	top_level int // -1 = none
	children  []int
}

fn ScopeRecord.new(scope_type ScopeType, scope_level ScopeLevel, scope_data ?&ScopeData) ScopeRecord {
	return ScopeRecord{
		scope_type:  scope_type
		scope_level: scope_level
		scope_data:  scope_data
		parent:      -1
		top_level:   -1
	}
}

fn (sr &ScopeRecord) is_top_level() bool {
	return sr.scope_level.is_top_level()
}

fn (mut sr ScopeRecord) variable(name []u16) &ScopeVariable {
	key := string_from_utf16_lossy(name)
	if key !in sr.variables {
		sr.variables[key] = ScopeVariable{}
	}
	return unsafe { &sr.variables[key] }
}

fn (sr &ScopeRecord) has_flag(name []u16, flags u16) bool {
	key := string_from_utf16_lossy(name)
	if v := sr.variables[key] {
		return v.flags & flags != 0
	}
	return false
}

fn (sr &ScopeRecord) get_parameter_index(name []u16) int {
	// Iterate backwards to return the last parameter with the same name.
	for i := sr.parameter_names.len - 1; i >= 0; i-- {
		if utf16_equals(sr.parameter_names[i].name.data, name) {
			return i
		}
	}
	return -1
}

fn (sr &ScopeRecord) has_rest_parameter_with_name(name []u16) bool {
	for param in sr.parameter_names {
		if param.is_rest && utf16_equals(param.name.data, name) {
			return true
		}
	}
	return false
}

fn (sr &ScopeRecord) has_hoistable_function_named(name []u16) bool {
	for f in sr.functions_to_hoist {
		if utf16_equals(f.name.data, name) {
			return true
		}
	}
	return false
}

// === Helper: ancestor scope iteration ===

fn last_function_scope(index int, records []ScopeRecord) int {
	mut i := index
	for i >= 0 {
		if records[i].scope_type == .function_scope || records[i].scope_type == .class_static_init {
			return i
		}
		i = records[i].parent
	}
	return -1
}

// === ScopeCollector ===

struct ScopeError {
	message string
	line    u32
	column  u32
}

struct SavedScopeFlags {
	index                      int
	uses_this                  bool
	uses_this_from_environment bool
}

struct ScopeCollectorState {
mut:
	records_len int
	current     int
	errors_len  int
	saved_flags []SavedScopeFlags
}

struct ScopeCollector {
mut:
	records []ScopeRecord
	current int // -1 = none
	errors  []ScopeError
}

fn ScopeCollector.new() ScopeCollector {
	return ScopeCollector{
		current: -1
	}
}

fn (mut sc ScopeCollector) drain_errors() []ParserError {
	mut result := []ParserError{}
	for e in sc.errors {
		result << ParserError{
			message: e.message
			line:    e.line
			column:  e.column
		}
	}
	sc.errors = []ScopeError{}
	return result
}

fn (mut sc ScopeCollector) already_declared_error(name []u16, line u32, column u32) {
	sc.errors << ScopeError{
		message: "Identifier '${string_from_utf16_lossy(name)}' already declared"
		line:    line
		column:  column
	}
}

fn (sc &ScopeCollector) has_errors() bool {
	return sc.errors.len > 0
}

fn (sc &ScopeCollector) has_current_scope() bool {
	return sc.current >= 0
}

fn (mut sc ScopeCollector) save_state() ScopeCollectorState {
	mut saved_flags := []SavedScopeFlags{}
	if sc.current >= 0 {
		mut i := sc.current
		for i >= 0 {
			if sc.records[i].scope_type == .function_scope {
				saved_flags << SavedScopeFlags{
					index:                      i
					uses_this:                  sc.records[i].uses_this
					uses_this_from_environment: sc.records[i].uses_this_from_environment
				}
			}
			i = sc.records[i].parent
		}
	}
	return ScopeCollectorState{
		records_len: sc.records.len
		current:     sc.current
		errors_len:  sc.errors.len
		saved_flags: saved_flags
	}
}

fn (mut sc ScopeCollector) load_state(state ScopeCollectorState) {
	saved_len := state.records_len
	sc.records = sc.records[..saved_len]
	sc.current = state.current
	sc.errors = sc.errors[..state.errors_len]
	// Remove any child indices that pointed to now-truncated records.
	if sc.current >= 0 {
		mut kept := []int{}
		for c in sc.records[sc.current].children {
			if c < saved_len {
				kept << c
			}
		}
		sc.records[sc.current].children = kept
	}
	// Restore flags on ancestor function scopes.
	for saved in state.saved_flags {
		if saved.index < sc.records.len {
			sc.records[saved.index].uses_this = saved.uses_this
			sc.records[saved.index].uses_this_from_environment = saved.uses_this_from_environment
		}
	}
}

// === Open/close scopes ===

fn (mut sc ScopeCollector) open_scope(scope_type ScopeType, scope_data ?&ScopeData, scope_level ScopeLevel) {
	index := sc.records.len
	mut record := ScopeRecord.new(scope_type, scope_level, scope_data)
	record.parent = sc.current

	if scope_type != .function_scope && record.scope_data == none {
		if sc.current >= 0 {
			record.scope_data = sc.records[sc.current].scope_data
		}
	}

	if scope_level == .not_top_level {
		if sc.current >= 0 {
			record.top_level = sc.records[sc.current].top_level
		}
	} else {
		record.top_level = index
	}

	sc.records << record
	if sc.current >= 0 {
		sc.records[sc.current].children << index
	}
	sc.current = index
}

fn (mut sc ScopeCollector) close_scope() {
	index := sc.current
	if index < 0 {
		panic('close_scope with no current scope')
	}

	parent_index := sc.records[index].parent
	if parent_index >= 0 {
		if !sc.records[index].has_function_parameters {
			call_arguments := sc.records[index].contains_access_to_arguments_object_in_non_strict_mode
			eval := sc.records[index].contains_direct_call_to_eval
			contains_await := sc.records[index].contains_await_expression
			if call_arguments {
				sc.records[parent_index].contains_access_to_arguments_object_in_non_strict_mode = true
			}
			if eval {
				sc.records[parent_index].contains_direct_call_to_eval = true
			}
			if contains_await {
				sc.records[parent_index].contains_await_expression = true
			}
		} else if sc.records[index].is_arrow_function
			&& sc.records[index].contains_access_to_arguments_object_in_non_strict_mode {
			// Arrow functions do not own an arguments object. Propagate access
			// through the arrow scope even if it declares formal parameters.
			sc.records[parent_index].contains_access_to_arguments_object_in_non_strict_mode = true
		}
	}

	sc.current = sc.records[index].parent
}

fn (mut sc ScopeCollector) open_program_scope(program_type ProgramType) {
	level := if program_type == .script {
		ScopeLevel.script_top_level
	} else {
		ScopeLevel.module_top_level
	}
	sc.open_scope(.program_scope, none, level)
}

fn (mut sc ScopeCollector) open_function_scope(function_name ?Utf16String) {
	sc.open_scope(.function_scope, none, .function_top_level)
	if fn_name := function_name {
		if fn_name.data.len > 0 {
			index := sc.current
			sc.records[index].variable(fn_name.data).flags |= var_flag_bound
		}
	}
}

fn (mut sc ScopeCollector) open_block_scope() {
	sc.open_scope(.block_scope, none, .not_top_level)
}

fn (mut sc ScopeCollector) open_for_loop_scope() {
	sc.open_scope(.for_loop_scope, none, .not_top_level)
}

fn (mut sc ScopeCollector) open_with_scope() {
	sc.open_scope(.with_scope, none, .not_top_level)
}

fn (mut sc ScopeCollector) open_catch_scope() {
	sc.open_scope(.catch_scope, none, .not_top_level)
}

fn (mut sc ScopeCollector) open_static_init_scope() {
	sc.open_scope(.class_static_init, none, .static_init_top_level)
}

fn (mut sc ScopeCollector) open_class_field_scope() {
	sc.open_scope(.class_field, none, .not_top_level)
}

fn (mut sc ScopeCollector) open_class_declaration_scope(class_name ?Utf16String) {
	sc.open_scope(.class_declaration, none, .not_top_level)
	if cn := class_name {
		if cn.data.len > 0 {
			index := sc.current
			sc.records[index].variable(cn.data).flags |= var_flag_bound
		}
	}
}

// === Declaration registration ===

fn (mut sc ScopeCollector) add_lexical_declaration(name []u16, declaration_line u32, declaration_column u32) {
	index := sc.current
	if index < 0 {
		return
	}
	flags := sc.records[index].variable(name).flags
	if flags & (var_flag_var | var_flag_forbidden_lexical | var_flag_function | var_flag_lexical) != 0 {
		sc.already_declared_error(name, declaration_line, declaration_column)
	}
	sc.records[index].variable(name).flags |= var_flag_lexical
}

fn (mut sc ScopeCollector) add_var_declaration(name []u16, id &Identifier, declaration_line u32, declaration_column u32, has_decl_kind bool) {
	index := sc.current
	if index < 0 {
		return
	}

	// Register the declaration identifier so it participates in scope analysis.
	if has_decl_kind {
		sc.register_identifier(id, name, int(DeclarationKind.var_kind))
	} else {
		sc.register_identifier(id, name, none)
	}

	mut scope_index := index
	for {
		existing_flags := sc.records[scope_index].variable(name).flags
		if existing_flags & (var_flag_lexical | var_flag_function | var_flag_forbidden_var) != 0 {
			sc.already_declared_error(name, declaration_line, declaration_column)
		}
		sc.records[scope_index].variable(name).flags |= var_flag_var
		sc.records[scope_index].variable(name).var_identifier = id
		if sc.records[scope_index].is_top_level() {
			break
		}
		scope_index = sc.records[scope_index].parent
		if scope_index < 0 {
			break
		}
	}
}

fn (mut sc ScopeCollector) add_function_declaration(fn_name Utf16String, name_identifier ?&Identifier, function_kind FunctionKind, strict_mode bool, declaration_line u32, declaration_column u32) {
	index := sc.current
	if index < 0 {
		return
	}
	scope_level := sc.records[index].scope_level

	// Register the name identifier so it participates in scope analysis.
	if name_id := name_identifier {
		sc.register_identifier(name_id, fn_name.data, none)
	}

	if scope_level != .not_top_level && scope_level != .module_top_level {
		sc.records[index].variable(fn_name.data).flags |= var_flag_var | var_flag_function_declaration
		sc.records[index].variable(fn_name.data).var_identifier = name_identifier
	} else {
		key := fn_name.str()
		existing_flags := if v := sc.records[index].variables[key] {
			v.flags
		} else {
			var_flag_empty
		}

		if existing_flags & (var_flag_var | var_flag_lexical) != 0 {
			sc.already_declared_error(fn_name.data, declaration_line, declaration_column)
		}

		if function_kind != .normal || strict_mode {
			if existing_flags & var_flag_function != 0 {
				sc.already_declared_error(fn_name.data, declaration_line, declaration_column)
			}
			sc.records[index].variable(fn_name.data).flags |= var_flag_lexical
			return
		}

		if existing_flags & var_flag_lexical == 0 {
			block_scope := sc.records[index].scope_data
			sc.records[index].functions_to_hoist << HoistableFunction{
				name:             fn_name.clone()
				block_scope_data: block_scope
			}
		}

		sc.records[index].variable(fn_name.data).flags |= var_flag_function
	}
}

fn (mut sc ScopeCollector) add_catch_parameter_pattern(name_slices [][]u16) {
	index := sc.current
	if index < 0 {
		return
	}
	for name in name_slices {
		sc.records[index].variable(name).flags |= var_flag_forbidden_var | var_flag_bound | var_flag_catch_parameter
	}
}

fn (mut sc ScopeCollector) add_catch_parameter_identifier(name []u16, id &Identifier) {
	index := sc.current
	if index < 0 {
		return
	}
	sc.records[index].variable(name).flags |= var_flag_var | var_flag_bound | var_flag_catch_parameter
	sc.records[index].variable(name).var_identifier = id
}

// === Identifier registration ===

fn (mut sc ScopeCollector) check_labelled_function_declaration(name []u16, line u32, column u32) {
	if sc.current >= 0 && sc.records[sc.current].has_flag(name, var_flag_lexical) {
		sc.already_declared_error(name, line, column)
	}
}

fn (mut sc ScopeCollector) register_identifier(id &Identifier, name []u16, declaration_kind ?int) {
	index := sc.current
	if index < 0 {
		return
	}
	key := string_from_utf16_lossy(name)
	dk_int := if dk := declaration_kind { dk } else { 0 }
	if key in sc.records[index].identifier_groups {
		unsafe {
			sc.records[index].identifier_groups[key].identifiers << id
			if declaration_kind != none
				&& sc.records[index].identifier_groups[key].declaration_kind == 0 {
				sc.records[index].identifier_groups[key].declaration_kind = dk_int
			}
		}
	} else {
		sc.records[index].identifier_groups[key] = IdentifierGroup{
			identifiers:      [id]
			declaration_kind: dk_int
		}
	}
}

// === Function parameters ===

fn (mut sc ScopeCollector) set_function_parameters(entries []ParameterEntry, has_parameter_expressions bool) {
	index := sc.current
	if index < 0 {
		return
	}
	sc.records[index].has_function_parameters = true
	sc.records[index].has_parameter_expressions = has_parameter_expressions

	for entry in entries {
		if entry.is_from_pattern {
			if entry.is_first_from_pattern {
				sc.records[index].parameter_names << ParameterName{
					name:    Utf16String.new()
					is_rest: false
				}
				continue
			}
		} else {
			sc.records[index].parameter_names << ParameterName{
				name:    entry.name.clone()
				is_rest: entry.is_rest
			}
		}
		if entry_id := entry.identifier {
			sc.register_identifier(entry_id, entry.name.data, none)
		}
		ekey := entry.name.str()
		if ekey !in sc.records[index].variables {
			sc.records[index].variables[ekey] = ScopeVariable{}
		}
		unsafe {
			sc.records[index].variables[ekey].flags |= var_flag_parameter_candidate | var_flag_forbidden_lexical
		}
	}

	// Mark non-parameter names referenced during formal parameter parsing.
	if has_parameter_expressions {
		mut names_to_mark := []string{}
		for gname, _ in sc.records[index].identifier_groups {
			if gname in sc.records[index].variables {
				if unsafe { sc.records[index].variables[gname] }.flags & var_flag_forbidden_lexical != 0 {
					continue
				}
			}
			names_to_mark << gname
		}
		for nm in names_to_mark {
			if nm !in sc.records[index].variables {
				sc.records[index].variables[nm] = ScopeVariable{}
			}
			unsafe {
				sc.records[index].variables[nm].flags |= var_flag_referenced_in_formal_parameters
			}
		}
	}
}

// === Scope node ===

fn (mut sc ScopeCollector) set_scope_node(scope &ScopeData) {
	index := sc.current
	if index < 0 {
		return
	}
	sc.records[index].scope_data = scope
	for i in 0 .. sc.records[index].functions_to_hoist.len {
		if sc.records[index].functions_to_hoist[i].block_scope_data == none {
			sc.records[index].functions_to_hoist[i].block_scope_data = scope
		}
	}
}

// === Flag setters ===

fn (mut sc ScopeCollector) set_contains_direct_call_to_eval() {
	index := sc.current
	if index < 0 {
		return
	}
	sc.records[index].contains_direct_call_to_eval = true
	sc.records[index].poisoned_by_eval_in_scope_chain = true
	sc.records[index].eval_in_current_function = true
}

fn (mut sc ScopeCollector) set_contains_access_to_arguments_object_in_non_strict_mode() {
	index := sc.current
	if index < 0 {
		return
	}
	sc.records[index].contains_access_to_arguments_object_in_non_strict_mode = true
}

fn (mut sc ScopeCollector) set_contains_await_expression() {
	index := sc.current
	if index < 0 {
		return
	}
	sc.records[index].contains_await_expression = true
}

fn (mut sc ScopeCollector) set_uses_this() {
	index := sc.current
	if index < 0 {
		return
	}
	closest_fn := last_function_scope(index, sc.records)
	this_from_env := closest_fn >= 0 && sc.records[closest_fn].is_arrow_function

	// Collect ancestor indices first to avoid borrow issues.
	mut ancestors := []int{}
	mut ai := index
	for ai >= 0 {
		ancestors << ai
		ai = sc.records[ai].parent
	}
	for si in ancestors {
		if sc.records[si].scope_type == .function_scope {
			sc.records[si].uses_this = true
			if this_from_env {
				sc.records[si].uses_this_from_environment = true
			}
		}
	}
}

fn (mut sc ScopeCollector) set_uses_new_target() {
	index := sc.current
	if index < 0 {
		return
	}
	mut ancestors := []int{}
	mut ai := index
	for ai >= 0 {
		ancestors << ai
		ai = sc.records[ai].parent
	}
	for si in ancestors {
		if sc.records[si].scope_type == .function_scope {
			sc.records[si].uses_this = true
			sc.records[si].uses_this_from_environment = true
		}
	}
}

fn (mut sc ScopeCollector) set_is_arrow_function() {
	index := sc.current
	if index < 0 {
		return
	}
	sc.records[index].is_arrow_function = true
}

fn (mut sc ScopeCollector) set_is_function_declaration() {
	index := sc.current
	if index < 0 {
		return
	}
	sc.records[index].is_function_declaration = true
}

// === Getters ===

fn (sc &ScopeCollector) contains_direct_call_to_eval() bool {
	if sc.current >= 0 {
		return sc.records[sc.current].contains_direct_call_to_eval
	}
	return false
}

fn (sc &ScopeCollector) uses_this_from_environment() bool {
	if sc.current >= 0 {
		return sc.records[sc.current].uses_this_from_environment
	}
	return false
}

fn (sc &ScopeCollector) uses_this() bool {
	if sc.current >= 0 {
		return sc.records[sc.current].uses_this
	}
	return false
}

fn (sc &ScopeCollector) contains_await_expression() bool {
	if sc.current >= 0 {
		return sc.records[sc.current].contains_await_expression
	}
	return false
}

fn (sc &ScopeCollector) can_have_using_declaration() bool {
	if sc.current >= 0 {
		return sc.records[sc.current].scope_level != .script_top_level
	}
	return true
}

fn (sc &ScopeCollector) has_declaration_in_current_function(name []u16) bool {
	if sc.current < 0 {
		return false
	}
	fn_scope := last_function_scope(sc.current, sc.records)
	stop := if fn_scope >= 0 { sc.records[fn_scope].parent } else { -1 }
	mut declaring_flags := var_flag_lexical | var_flag_var | var_flag_parameter_candidate
	if fn_scope >= 0 && sc.records[fn_scope].scope_type == .function_scope
		&& !sc.records[fn_scope].is_arrow_function {
		// A var in a function with its own arguments object is that object's
		// binding. Arrow functions have no implicit object and keep a real var.
		// Catch parameters still shadow it, including simple catches marked as vars.
		declaring_flags = var_flag_lexical | var_flag_function | var_flag_function_declaration
			| var_flag_parameter_candidate | var_flag_catch_parameter
	}
	mut si := sc.current
	for si >= 0 {
		if si == stop {
			break
		}
		if sc.records[si].has_flag(name, declaring_flags) {
			return true
		}
		if sc.records[si].has_hoistable_function_named(name) {
			return true
		}
		si = sc.records[si].parent
	}
	return false
}

// === Post-parse analysis ===

fn (mut sc ScopeCollector) analyze(initiated_by_eval bool) {
	sc.analyze_inner(initiated_by_eval, false)
}

fn (mut sc ScopeCollector) analyze_as_dynamic_function() {
	sc.analyze_inner(false, true)
}

fn (mut sc ScopeCollector) analyze_inner(initiated_by_eval bool, suppress_globals bool) {
	if sc.records.len > 0 {
		sc.analyze_recursive(0, initiated_by_eval, suppress_globals)
	}
}

fn (mut sc ScopeCollector) analyze_recursive(index int, initiated_by_eval bool, suppress_globals bool) {
	// Process children first (bottom-up traversal).
	children := sc.records[index].children.clone()
	for child_index in children {
		sc.analyze_recursive(child_index, initiated_by_eval, suppress_globals)
	}

	// 1. Propagate eval() flags from children to parent.
	sc.propagate_eval_poisoning(index)
	// 2. Match identifier references to declarations; optimize as locals.
	sc.resolve_identifiers(index, initiated_by_eval, suppress_globals)
	// 3. Annex B: hoist block-scoped functions to enclosing function scope.
	sc.hoist_functions(index)

	// 4. For function-like scopes, build the var declaration list.
	if sc.records[index].scope_data != none {
		st := sc.records[index].scope_type
		needs_fsd := (st == .function_scope && sc.records[index].has_function_parameters)
			|| st == .class_static_init || st == .class_field
		if needs_fsd {
			sc.build_function_scope_data(index)
		}
	}
}

fn (mut sc ScopeCollector) propagate_eval_poisoning(index int) {
	parent_index := sc.records[index].parent
	if parent_index >= 0 {
		if sc.records[index].contains_direct_call_to_eval
			|| sc.records[index].poisoned_by_eval_in_scope_chain {
			sc.records[parent_index].poisoned_by_eval_in_scope_chain = true
		}
		if sc.records[index].eval_in_current_function
			&& sc.records[index].scope_type != .function_scope {
			sc.records[parent_index].eval_in_current_function = true
		}
	}
}

fn (mut sc ScopeCollector) resolve_identifiers(index int, initiated_by_eval bool, suppress_globals bool) {
	// V maps retain insertion order, matching upstream's IndexMap. Local
	// variable indices follow the first registration, including propagated uses.
	groups := sc.records[index].identifier_groups.clone()
	sc.records[index].identifier_groups = map[string]IdentifierGroup{}

	mut propagate_to_parent := []string{}
	mut propagate_groups := []IdentifierGroup{}

	for key, original_group in groups {
		mut group := original_group

		// Annotate each Identifier AST node with its declaration kind.
		if group.declaration_kind != 0 {
			for id in group.identifiers {
				unsafe {
					id.declaration_kind = group.declaration_kind
				}
			}
		}

		var_key := key
		var_flags := if v := sc.records[index].variables[var_key] {
			v.flags
		} else {
			var_flag_empty
		}

		// Determine what kind of local variable this is (if any).
		mut local_var_kind := -1 // -1 = none
		if sc.records[index].is_top_level() && var_flags & var_flag_var != 0 {
			local_var_kind = int(LocalVarKind.var_kind)
		} else if var_flags & var_flag_lexical != 0 {
			local_var_kind = int(LocalVarKind.let_or_const)
		} else if var_flags & var_flag_function != 0 {
			local_var_kind = int(LocalVarKind.function_kind)
		}

		// Non-arrow functions implicitly declare `arguments` as a local.
		arguments_u16 := utf16('arguments')
		name_u16 := if group.identifiers.len > 0 {
			group.identifiers[0].name.data
		} else {
			[]u16{}
		}
		if sc.records[index].scope_type == .function_scope && !sc.records[index].is_arrow_function
			&& utf16_equals(name_u16, arguments_u16) {
			local_var_kind = int(LocalVarKind.arguments_object)
		}

		if sc.records[index].scope_type == .catch_scope && var_flags & var_flag_catch_parameter != 0 {
			local_var_kind = int(LocalVarKind.catch_clause_parameter)
		}

		// Parameter expression handling.
		if var_flags & var_flag_referenced_in_formal_parameters != 0
			&& var_flags & var_flag_var != 0 && var_flags & var_flag_forbidden_lexical == 0 {
			parent_index := sc.records[index].parent
			if parent_index >= 0 {
				unsafe {
					if key in sc.records[parent_index].identifier_groups {
						sc.records[parent_index].identifier_groups[key].captured_by_nested_function = true
					} else {
						sc.records[parent_index].identifier_groups[key] = IdentifierGroup{
							captured_by_nested_function: true
						}
					}
				}
			}
			continue
		}

		hoistable := sc.records[index].has_hoistable_function_named(name_u16)

		// ClassDeclaration with IsBound: skip entirely.
		if sc.records[index].scope_type == .class_declaration && var_flags & var_flag_bound != 0 {
			continue
		}

		// Function expression name binding.
		if sc.records[index].scope_type == .function_scope
			&& !sc.records[index].is_function_declaration && var_flags & var_flag_bound != 0 {
			for id in group.identifiers {
				unsafe {
					id.is_inside_scope_with_eval = true
				}
			}
		}

		if sc.records[index].scope_type == .class_declaration {
			local_var_kind = -1
		}

		mut is_function_parameter := false
		if sc.records[index].scope_type == .function_scope {
			if var_flags & var_flag_parameter_candidate != 0
				&& (!sc.records[index].contains_access_to_arguments_object_in_non_strict_mode
				|| sc.records[index].has_rest_parameter_with_name(name_u16)) {
				is_function_parameter = true
			} else if var_flags & var_flag_forbidden_lexical != 0 {
				continue
			}
		}

		if sc.records[index].scope_type == .function_scope && hoistable {
			continue
		}

		if sc.records[index].scope_type == .program_scope {
			can_use_global := !(suppress_globals || group.used_inside_with_statement
				|| initiated_by_eval)
			if can_use_global {
				for id in group.identifiers {
					unsafe {
						if !id.is_inside_scope_with_eval {
							id.is_global = true
						}
					}
				}
			}
		} else if local_var_kind >= 0 || is_function_parameter {
			if hoistable {
				continue
			}

			// Propagate captured-by-nested for parameter expressions.
			if sc.records[index].has_parameter_expressions && group.captured_by_nested_function
				&& var_flags & var_flag_var != 0 && var_flags & var_flag_forbidden_lexical == 0 {
				parent_index := sc.records[index].parent
				if parent_index >= 0 {
					unsafe {
						if key in sc.records[parent_index].identifier_groups {
							sc.records[parent_index].identifier_groups[key].captured_by_nested_function = true
						} else {
							sc.records[parent_index].identifier_groups[key] = IdentifierGroup{
								captured_by_nested_function: true
							}
						}
					}
				}
			}

			if !group.captured_by_nested_function && !group.used_inside_with_statement {
				if sc.records[index].poisoned_by_eval_in_scope_chain {
					continue
				}

				mut local_scope := last_function_scope(index, sc.records)
				if local_scope < 0 {
					if group.declaration_kind == int(DeclarationKind.var_kind) {
						continue
					}
					local_scope = sc.records[index].top_level
				}

				if local_scope >= 0 {
					if sd := sc.records[local_scope].scope_data {
						unsafe {
							if is_function_parameter {
								argument_index :=
									sc.records[local_scope].get_parameter_index(name_u16)
								if argument_index >= 0 {
									for id in group.identifiers {
										id.local_index = u32(argument_index)
										id.local_type = 1 // argument
									}
								} else {
									lvi := u32(sd.local_variables.len)
									sd.local_variables << LocalVariable{
										name: Utf16String.from_slice(name_u16)
										kind: .var_kind
									}
									for id in group.identifiers {
										id.local_index = lvi
										id.local_type = 2 // variable
									}
								}
							} else {
								kind := LocalVarKind(local_var_kind)
								lvi := u32(sd.local_variables.len)
								sd.local_variables << LocalVariable{
									name: Utf16String.from_slice(name_u16)
									kind: kind
								}
								for id in group.identifiers {
									id.local_index = lvi
									id.local_type = 2 // variable
								}
							}
						}
					}
				}
			}
		} else {
			if sc.records[index].has_function_parameters
				|| sc.records[index].scope_type == .class_field
				|| sc.records[index].scope_type == .class_static_init {
				group.captured_by_nested_function = true
			}

			if sc.records[index].scope_type == .with_scope {
				group.used_inside_with_statement = true
			}

			if sc.records[index].eval_in_current_function {
				for id in group.identifiers {
					unsafe {
						id.is_inside_scope_with_eval = true
					}
				}
			}

			propagate_to_parent << key
			propagate_groups << group
		}
	}

	parent_index := sc.records[index].parent
	if parent_index >= 0 {
		for pi in 0 .. propagate_to_parent.len {
			pkey := propagate_to_parent[pi]
			pgroup := propagate_groups[pi]
			unsafe {
				if pkey in sc.records[parent_index].identifier_groups {
					for pid in pgroup.identifiers {
						sc.records[parent_index].identifier_groups[pkey].identifiers << pid
					}
					if pgroup.captured_by_nested_function {
						sc.records[parent_index].identifier_groups[pkey].captured_by_nested_function = true
					}
					if pgroup.used_inside_with_statement {
						sc.records[parent_index].identifier_groups[pkey].used_inside_with_statement = true
					}
				} else {
					sc.records[parent_index].identifier_groups[pkey] = pgroup
				}
			}
		}
	}
}

fn (mut sc ScopeCollector) build_function_scope_data(index int) {
	scope_data := sc.records[index].scope_data or { return }

	arguments_u16 := utf16('arguments')
	has_argument_parameter := if v := sc.records[index].variables[string_from_utf16_lossy(arguments_u16)] {
		v.flags & var_flag_forbidden_lexical != 0
	} else {
		false
	}

	mut vars_to_initialize := []VarToInit{}
	mut var_names := []Utf16String{}
	mut has_function_named_arguments := false
	mut has_lexically_declared_arguments := false
	mut non_local_var_count := 0
	mut non_local_var_count_for_parameter_expressions := 0

	// Keep the last declaration of each name, in source order, including
	// function declarations wrapped in one or more labels.
	mut functions_to_initialize := []FunctionToInit{}
	mut seen_function_names := map[string]int{}
	for i, child in scope_data.children {
		if function := child.function_declaration_for_labelled_item() {
			if name := function.kind.func_name {
				seen_function_names[name.name.str()] = i
			}
		}
	}
	for i, child in scope_data.children {
		if function := child.function_declaration_for_labelled_item() {
			if name := function.kind.func_name {
				if seen_function_names[name.name.str()] == i {
					functions_to_initialize << FunctionToInit{
						child_index: i
					}
				}
			}
		}
	}

	for vname, var_ in sc.records[index].variables {
		if var_.flags & var_flag_var == 0 {
			continue
		}

		name := Utf16String.from_slice(string_to_u16(vname))
		var_names << name.clone()

		is_parameter := var_.flags & var_flag_forbidden_lexical != 0
		is_function_name := vname in seen_function_names

		mut local_info := ?LocalBinding(none)
		if var_ident := var_.var_identifier {
			if var_ident.is_local() {
				local_info = LocalBinding{
					local_type: if var_ident.local_type == 1 {
						LocalType.argument
					} else {
						LocalType.variable
					}
					index:      var_ident.local_index
				}
			}
		}

		if local_info == none {
			non_local_var_count_for_parameter_expressions++
			if !is_parameter {
				non_local_var_count++
			}
		}

		vars_to_initialize << VarToInit{
			name:             name
			is_parameter:     is_parameter
			is_function_name: is_function_name
			local:            local_info
		}
	}

	// Sort by name for deterministic output.
	vars_to_initialize.sort_with_compare(fn (a &VarToInit, b &VarToInit) int {
		if a.name < b.name {
			return -1
		}
		if b.name < a.name {
			return 1
		}
		return 0
	})
	var_names.sort_with_compare(fn (a &Utf16String, b &Utf16String) int {
		if *a < *b {
			return -1
		}
		if *b < *a {
			return 1
		}
		return 0
	})

	arguments_key := string_from_utf16_lossy(arguments_u16)
	for fn_name, _ in seen_function_names {
		if fn_name == arguments_key {
			has_function_named_arguments = true
			break
		}
	}

	if v := sc.records[index].variables[arguments_key] {
		if v.flags & var_flag_lexical != 0 {
			has_lexically_declared_arguments = true
		}
	}

	fsd := FunctionScopeData{
		functions_to_initialize:                       functions_to_initialize
		vars_to_initialize:                            vars_to_initialize
		var_names:                                     var_names
		has_function_named_arguments:                  has_function_named_arguments
		has_argument_parameter:                        has_argument_parameter
		has_lexically_declared_arguments:              has_lexically_declared_arguments
		non_local_var_count:                           non_local_var_count
		non_local_var_count_for_parameter_expressions: non_local_var_count_for_parameter_expressions
	}

	unsafe {
		scope_data.function_scope_data = fsd
		scope_data.uses_this = sc.records[index].uses_this
		scope_data.uses_this_from_environment = sc.records[index].uses_this_from_environment
		scope_data.contains_direct_call_to_eval = sc.records[index].contains_direct_call_to_eval
			|| sc.records[index].poisoned_by_eval_in_scope_chain
		scope_data.contains_access_to_arguments_object = sc.records[index].contains_access_to_arguments_object_in_non_strict_mode
	}
}

fn (mut sc ScopeCollector) hoist_functions(index int) {
	functions := sc.records[index].functions_to_hoist.clone()
	sc.records[index].functions_to_hoist = []HoistableFunction{}

	for function in functions {
		// A let/const or forbidden var with the same name blocks hoisting.
		if sc.records[index].has_flag(function.name.data, var_flag_lexical | var_flag_forbidden_var) {
			continue
		}

		if sc.records[index].is_top_level() {
			// AnnexB.3.3.1: Skip hoisting if the function name is a parameter name.
			if sc.records[index].has_flag(function.name.data, var_flag_forbidden_lexical) {
				continue
			}
			// AnnexB.3.3.1: Skip hoisting if the function name is "arguments"
			// and the function needs an arguments object.
			arguments_u16 := utf16('arguments')
			if utf16_equals(function.name.data, arguments_u16)
				&& sc.records[index].contains_access_to_arguments_object_in_non_strict_mode
				&& !sc.records[index].has_flag(arguments_u16, var_flag_forbidden_lexical) {
				continue
			}
			// Reached function/program scope — register the hoisted function name.
			if sd := sc.records[index].scope_data {
				unsafe {
					mut already_present := false
					for existing in sd.annexb_function_names {
						if existing == function.name {
							already_present = true
							break
						}
					}
					if !already_present {
						sd.annexb_function_names << function.name.clone()
					}
				}
			}
			// Mark all function declarations with this name in the block as hoisted.
			if block_sd := function.block_scope_data {
				unsafe {
					for ci in 0 .. block_sd.children.len {
						if declaration := block_sd.children[ci].function_declaration_for_labelled_item() {
							if fn_id := declaration.kind.func_name {
								if fn_id.name == function.name {
									declaration.kind.is_hoisted = true
								}
							}
						}
					}
				}
			}
		} else {
			parent_index := sc.records[index].parent
			if parent_index >= 0 {
				if !sc.records[parent_index].has_flag(function.name.data,
					var_flag_lexical | var_flag_function) {
					sc.records[parent_index].functions_to_hoist << function
				}
			}
		}
	}
}

// === Helper: string to u16 (for map key back-conversion) ===

fn string_to_u16(s string) []u16 {
	return utf16(s)
}
