// StyleScope.cpp: cached function definitions, origin/layer precedence, and
// dereference_global_tree_scoped_reference. The rule is the translated V
// function body; the source Rust compiled function is evaluated by that body.
module css

pub struct CachedFunctionDefinition {
pub:
	function             &CSSRule
	qualified_layer_name string
	cascade_origin       CascadeOrigin
}

pub struct FunctionDefinitionAndScope {
pub:
	function &CSSRule
	scope    &StyleScope
}

struct CachedFunctionRuleContext {
	cache &StyleCache
	origin CascadeOrigin
}

fn cache_function_rule(raw_context voidptr, rule &CSSRule) {
	context := unsafe { &CachedFunctionRuleContext(raw_context) }
	mut cache := unsafe { &StyleCache(context.cache) }
	origin := context.origin
	if rule.type_ != .function_rule { return }
	mut mutable_rule := unsafe { &CSSRule(rule) }
	mut definitions := cache.function_rules_by_name[rule.function_name] or { []CachedFunctionDefinition{} }
	definitions << CachedFunctionDefinition{
		function:             rule
		qualified_layer_name: mutable_rule.qualified_layer_name()
		cascade_origin:       origin
	}
	cache.function_rules_by_name[rule.function_name] = definitions
}

fn (scope &StyleScope) cache_function_definitions(mut cache StyleCache, origin CascadeOrigin) {
	for sheet in scope.stylesheets_for_cascade_origin(origin) {
		context := CachedFunctionRuleContext{cache: &cache, origin: origin}
		sheet.for_each_effective_rule_with_context(.preorder, voidptr(&context), cache_function_rule)
	}
}

// Rust StyleSheetProgram::layer_index(): unknown names and the implicit outer
// layer sort after all named layers. The flattened cache ends in that layer.
fn (scope &StyleScope) custom_function_layer_index(name string) int {
	named_layers := scope.qualified_layer_names_in_order.filter(it != '')
	if name != '' {
		index := named_layers.index(name)
		if index >= 0 { return index }
	}
	return named_layers.len
}

fn (scope &StyleScope) function_definition_for_origin(name string, origin CascadeOrigin) ?&CSSRule {
	cache := scope.rule_cache or { return none }
	definitions := cache.function_rules_by_name[name] or { return none }
	mut result := ?&CSSRule(none)
	mut existing_layer_index := 0
	for definition in definitions {
		if definition.cascade_origin != origin { continue }
		layer_index := scope.custom_function_layer_index(definition.qualified_layer_name)
		if result == none || layer_index >= existing_layer_index {
			result = definition.function
			existing_layer_index = layer_index
		}
	}
	return result
}

pub fn (scope &StyleScope) get_function_definition(name string) ?FunctionDefinitionAndScope {
	scope.build_rule_cache_if_needed()
	node := scope.node or { return none }
	mut result := ?&CSSRule(none)
	if node.is_document() {
		for origin in [CascadeOrigin.user_agent, .user] {
			if definition := scope.function_definition_for_origin(name, origin) {
				result = definition
			}
		}
	}
	if definition := scope.function_definition_for_origin(name, .author) { result = definition }
	if definition := result {
		return FunctionDefinitionAndScope{ function: definition, scope: scope }
	}
	shadow := node.as_shadow_root() or { return none }
	host := shadow.host() or { return none }
	root := host.as_node().root()
	if parent_shadow := root.as_shadow_root() {
		return css_style_scope_for_shadow_root(parent_shadow).get_function_definition(name)
	}
	if root.is_document() {
		return css_style_scope_for_document(root.document()).get_function_definition(name)
	}
	// An ordinary detached root carries no tree-scoped names of its own.
	return none
}
