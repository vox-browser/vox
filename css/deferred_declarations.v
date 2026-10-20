module css

import dom
import platform

@[heap]
struct DeferredStyleDeclaration {
	declarations []Declaration
	params ParsingParams
mut:
	base_url string
	resource_owner ?&CSSStyleSheet
	resource_owner_was_set bool
}

fn (mut parser RuleSelectorParser) declaration_for_style_rule(declarations []Declaration) &CSSStyleProperties {
	if !parser.defer_style_declarations || declarations.len == 0 {
		return parser.convert_to_style_declaration(declarations)
	}
	return &CSSStyleProperties{
		deferred_declarations_: &DeferredStyleDeclaration{
			declarations: parser.own_deferred_rule_declarations(declarations)
			params: parser.parsing_params()
		}
	}
}

// Syntax and selectors are parsed eagerly. Only ordinary style-rule property
// conversion waits for matching or CSSOM access; descriptors stay eager.
fn (properties &CSSStyleProperties) ensure_declarations_parsed() {
	deferred := properties.deferred_declarations_ or { return }
	persistent := platform.enter_persistent_if(properties.has_process_lifetime_sheet())
	defer { platform.leave_persistent(persistent) }
	mut target := unsafe { &CSSStyleProperties(properties) }
	target.deferred_declarations_ = none
	mut parser := RuleSelectorParser{
		document: deferred.params.document
		mode: deferred.params.mode
		value_context: deferred.params.value_context
		rule_context: deferred.params.rule_context
		declared_namespaces: deferred.params.declared_namespaces
		is_ua_style_sheet: deferred.params.is_ua_style_sheet
	}
	mut parsed := parser.convert_to_style_declaration(deferred.declarations)
	target.properties = parsed.properties
	target.custom_properties = parsed.custom_properties.move()
	target.typed_properties_cache_ = none
	target.typed_importance_mask_ = 0
	target.set_rule_base_url(deferred.base_url)
	if deferred.resource_owner_was_set {
		target.set_rule_resource_owner(deferred.resource_owner)
	}
}

fn (properties &CSSStyleProperties) has_process_lifetime_sheet() bool {
	if rule := properties.parent_rule { return rule.has_process_lifetime_sheet() }
	return false
}

fn (mut properties CSSStyleProperties) set_rule_base_url(base_url string) {
	if base_url == '' { return }
	if mut deferred := properties.deferred_declarations_ {
		deferred.base_url = base_url
		return
	}
	for mut property in properties.properties {
		if value := property.style_value {
			mut value_with_base := unsafe { &dom.StyleValue(value) }
			value_with_base.base_url = base_url
		}
	}
}

fn (mut properties CSSStyleProperties) set_rule_resource_owner(sheet ?&CSSStyleSheet) {
	if mut deferred := properties.deferred_declarations_ {
		deferred.resource_owner = sheet
		deferred.resource_owner_was_set = true
		return
	}
	for property in properties.properties {
		if value := property.style_value {
			set_style_sheet_on_dom_style_value(value, sheet)
		}
	}
}
