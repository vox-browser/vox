module css

import dom
import platform

// A function-local custom property is resolved against the registrations and
// declarations of the hypothetical element created while evaluating
// @function. Keeping these scopes on the shared substitution context lets
// nested var(), inherit(), and dashed-function calls see the same state.
struct FunctionLocalRegistration {
mut:
	syntax         SyntaxNode
	initial_tokens ?[]ComponentValue
	is_result      bool
}

struct FunctionLocalValue {
	tokens                []ComponentValue
	includes_substitution bool
}

@[heap]
struct FunctionLocalScope {
	function_identity u64
mut:
	resolved_value_cache map[string][]ComponentValue
	values               map[string]FunctionLocalValue
	registrations        map[string]FunctionLocalRegistration
}

enum FunctionLocalResolutionKind {
	not_handled
	resolved
	invalid
}

struct FunctionLocalResolution {
	kind   FunctionLocalResolutionKind
	tokens []ComponentValue
}

fn function_local_not_handled() FunctionLocalResolution {
	return FunctionLocalResolution{
		kind: .not_handled
	}
}

fn function_local_invalid() FunctionLocalResolution {
	return FunctionLocalResolution{
		kind: .invalid
	}
}

fn function_local_resolved(tokens []ComponentValue) FunctionLocalResolution {
	return FunctionLocalResolution{
		kind:   .resolved
		tokens: tokens
	}
}

fn trim_component_value_whitespace(values []ComponentValue) []ComponentValue {
	mut start := 0
	for start < values.len && values[start].is(.whitespace) {
		start++
	}
	mut end := values.len
	for end > start && values[end - 1].is(.whitespace) {
		end--
	}
	return values[start..end].clone()
}

fn single_css_wide_keyword_from_component_values(values []ComponentValue) ?string {
	trimmed := trim_component_value_whitespace(values)
	if trimmed.len != 1 || !trimmed[0].is(.ident) {
		return none
	}
	keyword := trimmed[0].token().ident()
	if !is_css_wide_keyword_string(keyword) {
		return none
	}
	return keyword.to_lower()
}

fn normalize_custom_function_tokens(tokens []ComponentValue, syntax SyntaxNode) FunctionLocalResolution {
	if contains_guaranteed_invalid_value(tokens) {
		return function_local_invalid()
	}
	if syntax.type() == .universal {
		return function_local_resolved(tokens.clone())
	}
	parsed := parse_with_a_syntax(tokens, syntax)
	if parsed.type_() == .guaranteed_invalid {
		return function_local_invalid()
	}
	return function_local_resolved(parsed.tokenize())
}

fn function_local_scope_index_for_property(guarded_contexts GuardedSubstitutionContexts, name string) int {
	for index := guarded_contexts.function_local_scopes.len - 1; index >= 0; index-- {
		scope := guarded_contexts.function_local_scopes[index]
		if name in scope.values || name in scope.registrations {
			return index
		}
	}
	return -1
}

fn resolve_function_local_property(element ?dom.AbstractElement, name string, mut guarded_contexts GuardedSubstitutionContexts, scope &FunctionLocalScope) FunctionLocalResolution {
	if cached := scope.resolved_value_cache[name] {
		return function_local_resolved(cached.clone())
	}

	registration := scope.registrations[name] or {
		FunctionLocalRegistration{
			syntax: SyntaxNode.create_universal()
		}
	}
	mut result := FunctionLocalResolution{}
	if value := scope.values[name] {
		if value.includes_substitution {
			substituted := substitute_arbitrary_substitution_functions_with_optional_element(element, mut guarded_contexts, value.tokens, SubstitutionContext{
				dependency_type:   .property
				first:             name
				function_identity: scope.function_identity
			})
			if contains_guaranteed_invalid_value(substituted) {
				result = function_local_invalid()
			} else {
				result = function_local_resolved(substituted)
			}
		} else {
			result = function_local_resolved(value.tokens.clone())
		}
	} else if initial_tokens := registration.initial_tokens {
		result = function_local_resolved(initial_tokens.clone())
	} else {
		return function_local_invalid()
	}

	if result.kind == .resolved && !registration.is_result {
		if keyword := single_css_wide_keyword_from_component_values(result.tokens) {
			if keyword == 'initial' {
				if initial_tokens := registration.initial_tokens {
					result = function_local_resolved(initial_tokens.clone())
				} else {
					return function_local_invalid()
				}
			} else if keyword == 'inherit' {
				// The hypothetical function element inherits from the calling
				// context. Temporarily hide this scope so the lookup reaches an
				// outer function scope or the actual element.
				popped := guarded_contexts.function_local_scopes.pop()
				result = resolve_custom_property_for_function_scope(element, name, mut guarded_contexts)
				guarded_contexts.function_local_scopes << popped
			} else {
				return function_local_invalid()
			}
		}
	}

	if result.kind != .resolved {
		return result
	}
	return normalize_custom_function_tokens(result.tokens, registration.syntax)
}

fn resolve_custom_property_for_function_scope(element ?dom.AbstractElement, name string, mut guarded_contexts GuardedSubstitutionContexts) FunctionLocalResolution {
	index := function_local_scope_index_for_property(guarded_contexts, name)
	if index < 0 {
		el := element or { return function_local_not_handled() }
		computed_value := compute_value_of_custom_property_with_guarded_contexts(el, name, mut guarded_contexts)
		typed := typed_style_value_logic_from_dom(computed_value) or {
			return function_local_resolved(parse_component_values_for_value_logic(computed_value.css_text))
		}
		if typed is GuaranteedInvalidStyleValue {
			return function_local_invalid()
		}
		return function_local_resolved(typed.tokenize())
	}

	// While resolving an outer scope, inner function scopes must not intercept
	// references made by that outer function.
	child_scopes := guarded_contexts.function_local_scopes[index + 1..].clone()
	guarded_contexts.function_local_scopes = guarded_contexts.function_local_scopes[..index + 1].clone()
	scope := guarded_contexts.function_local_scopes[index]
	result := resolve_function_local_property(element, name, mut guarded_contexts, scope)
	guarded_contexts.function_local_scopes << child_scopes
	if result.kind == .resolved {
		mut mutable_scope := unsafe { &FunctionLocalScope(scope) }
		mutable_scope.resolved_value_cache[name] = result.tokens.clone()
	}
	return result
}

fn resolve_custom_function_definition(element ?dom.AbstractElement, name string, guarded_contexts GuardedSubstitutionContexts) ?FunctionDefinitionAndScope {
	el := element or { return none }
	// A lookup may initialize a document/shadow style scope or its rule cache.
	// Those records outlive a caller's property-substitution workspace.
	mut allocations := el.document().enter_native_storage()
	defer { allocations.finish() }
	owner := el.document().native_storage()
	use_document := owner != unsafe { nil }
		&& voidptr(owner) == voidptr(platform.current_retained_arena())
	persistent := platform.enter_persistent_if(!use_document && platform.transient_arena_entered())
	mut retained := if use_document {
		platform.enter_retained_allocations()
	} else {
		platform.RetainedAllocationScope{}
	}
	defer {
		retained.finish()
		platform.leave_persistent(persistent)
	}
	// Rust custom_properties.rs resolves nested names where the calling
	// function was defined. Top-level names use the element's style scope.
	for index := guarded_contexts.contexts.len - 1; index >= 0; index-- {
		context := guarded_contexts.contexts[index]
		if context.dependency_type == .function {
			if scope := guarded_contexts.definition_scope(context.function_identity) {
				return scope.get_function_definition(name)
			}
		}
	}
	return css_style_scope_for(el).get_function_definition(name)
}

fn split_custom_function_arguments(values []ComponentValue) [][]ComponentValue {
	if trim_component_value_whitespace(values).len == 0 {
		return [][]ComponentValue{}
	}
	mut call_arguments := [][]ComponentValue{}
	mut start := 0
	for index, value in values {
		if value.is(.comma) {
			call_arguments << values[start..index].clone()
			start = index + 1
		}
	}
	call_arguments << values[start..].clone()
	return call_arguments
}

fn custom_function_argument_contents(values []ComponentValue) []ComponentValue {
	trimmed := trim_component_value_whitespace(values)
	if trimmed.len == 1 && trimmed[0].is_curly_block() {
		return trimmed[0].block().value.clone()
	}
	return trimmed
}

fn component_values_include_substitution(values []ComponentValue) bool {
	mut presence := SubstitutionFunctionsPresence{}
	collect_arbitrary_substitution_function_presence(values, mut presence) or { return true }
	return presence.has_any()
}

fn collect_custom_function_body(rule &CSSRule) (map[string]FunctionLocalValue, []string) {
	mut values := map[string]FunctionLocalValue{}
	mut names := []string{}
	values_ptr := &values
	names_ptr := &names
	rule.for_each_effective_rule(.preorder, fn [values_ptr, names_ptr] (child &CSSRule) {
		if child.type_ != .function_declarations {
			return
		}
		descriptors := child.kind_data().function_descriptors or { return }
		unsafe {
			mut collected_values := *values_ptr
			mut collected_names := *names_ptr
			for descriptor in descriptors.base.descriptors {
				name := descriptor.descriptor_name_and_id.name()
				tokens := parse_component_values_for_value_logic(descriptor.serialized_value)
				collected_values[name] = FunctionLocalValue{
					tokens:                tokens
					includes_substitution: component_values_include_substitution(tokens)
				}
				if name !in collected_names {
					collected_names << name
				}
			}
			*values_ptr = collected_values
			*names_ptr = collected_names
		}
	})
	return values, names
}

fn evaluate_a_custom_function(element ?dom.AbstractElement, mut guarded_contexts GuardedSubstitutionContexts, definition FunctionDefinitionAndScope, arguments [][]ComponentValue) []ComponentValue {
	rule := definition.function
	identity := u64(voidptr(rule))
	mut function_context := SubstitutionContext{
		dependency_type:   .function
		first:             rule.kind_data().function_name
		function_identity: identity
	}
	guarded_contexts.guard(mut function_context)
	if function_context.is_cyclic {
		return arbitrary_substitution_guaranteed_invalid_value()
	}
	guarded_contexts.remember_definition_scope(identity, definition.scope)

	if arguments.len > rule.kind_data().function_parameters.len {
		guarded_contexts.unguard(function_context)
		return arbitrary_substitution_guaranteed_invalid_value()
	}

	mut registrations := map[string]FunctionLocalRegistration{}
	for parameter in rule.kind_data().function_parameters {
		registrations[parameter.name] = FunctionLocalRegistration{
			syntax: parameter.type_
		}
	}
	registrations['result'] = FunctionLocalRegistration{
		syntax:    rule.kind_data().function_return_type
		is_result: true
	}

	mut argument_values := map[string]FunctionLocalValue{}
	for index, parameter in rule.kind_data().function_parameters {
		if index >= arguments.len && parameter.default_value == none {
			guarded_contexts.unguard(function_context)
			return arbitrary_substitution_guaranteed_invalid_value()
		}
		mut normalized := function_local_invalid()
		if index < arguments.len {
			normalized = normalize_custom_function_tokens(arguments[index], parameter.type_)
		}
		if normalized.kind == .resolved {
			argument_values[parameter.name] = FunctionLocalValue{
				tokens: normalized.tokens
			}
		} else if default_value := parameter.default_value {
			argument_values[parameter.name] = FunctionLocalValue{
				tokens:                trim_component_value_whitespace(default_value)
				includes_substitution: true
			}
		}
	}

	mut argument_scope := &FunctionLocalScope{
		function_identity: identity
		values:            argument_values
		registrations:     registrations.clone()
	}
	guarded_contexts.function_local_scopes << argument_scope
	mut argument_styles := map[string][]ComponentValue{}
	for parameter in rule.kind_data().function_parameters {
		resolution := resolve_custom_property_for_function_scope(element, parameter.name, mut guarded_contexts)
		if resolution.kind == .resolved {
			argument_styles[parameter.name] = resolution.tokens
		}
	}
	guarded_contexts.function_local_scopes.pop()

	mut body_values := map[string]FunctionLocalValue{}
	for parameter in rule.kind_data().function_parameters {
		if tokens := argument_styles[parameter.name] {
			body_values[parameter.name] = FunctionLocalValue{
				tokens: tokens.clone()
			}
			mut registration := registrations[parameter.name]
			registration.initial_tokens = tokens.clone()
			registrations[parameter.name] = registration
		}
	}
	body_declarations, body_declaration_names := collect_custom_function_body(rule)
	for name, value in body_declarations {
		body_values[name] = value
	}
	mut body_names := []string{}
	for name in body_declaration_names {
		if name != 'result' {
			body_names << name
		}
	}
	body_names << 'result'

	mut body_scope := &FunctionLocalScope{
		function_identity: identity
		values:            body_values
		registrations:     registrations
	}
	guarded_contexts.function_local_scopes << body_scope
	mut result := function_local_invalid()
	for name in body_names {
		resolution := resolve_custom_property_for_function_scope(element, name, mut guarded_contexts)
		if name == 'result' {
			result = resolution
		}
	}
	guarded_contexts.function_local_scopes.pop()

	if guarded_contexts.is_marked_cyclic(function_context) {
		result = function_local_invalid()
	}
	guarded_contexts.unguard(function_context)
	if result.kind != .resolved {
		return arbitrary_substitution_guaranteed_invalid_value()
	}
	return result.tokens
}

// https://drafts.csswg.org/css-mixins/#replace-a-dashed-function
fn replace_a_dashed_function(element ?dom.AbstractElement, mut guarded_contexts GuardedSubstitutionContexts, name string, raw_arguments []ComponentValue) []ComponentValue {
	definition := resolve_custom_function_definition(element, name, guarded_contexts) or {
		return arbitrary_substitution_guaranteed_invalid_value()
	}
	argument_slices := split_custom_function_arguments(raw_arguments)
	mut call_arguments := [][]ComponentValue{cap: argument_slices.len}
	// Argument substitution deliberately precedes arity checks. Recursive calls
	// in missing/excess arguments must still mark the enclosing function cycle.
	for argument in argument_slices {
		contents := custom_function_argument_contents(argument)
		call_arguments << substitute_arbitrary_substitution_functions_with_optional_element(element, mut guarded_contexts, contents, none)
	}
	return evaluate_a_custom_function(element, mut guarded_contexts, definition, call_arguments)
}
