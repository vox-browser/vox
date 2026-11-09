module css

import dom
import platform

// Kind-specific state is uncommon on style and grouping rules. Payloads are
// immutable: replacing a field preserves the shallow value semantics of a
// copied CSSRule, including its cached selector lists and referenced wrappers.
struct CSSRuleKindData {
	url                               string
	document                          ?&dom.Document
	layer                             ?string
	layer_internal                    ?string
	loaded_style_sheet                ?&CSSStyleSheet
	loading_state                     CSSStyleSheetLoadingState = .unloaded
	namespace_uri                     string
	prefix                            string
	scope_start_selectors             ?SelectorList
	scope_end_selectors               ?SelectorList
	cached_scope_start_selectors      ?SelectorList
	cached_scope_end_selectors        ?SelectorList
	import_has_scope                  bool
	keyframe_key                      ?Percentage
	layer_name_list                   []string
	page_selectors                    PageSelectorList
	page_descriptors                  ?&CSSPageDescriptors
	margin_name                       string
	property_rule_name                string
	position_try_name                 string
	property_rule_syntax              string
	property_rule_inherits            bool
	property_rule_initial_value       ?string
	property_rule_initial_style_value ?StyleValue
	function_name                     string
	function_parameters               []FunctionParameterInternal
	function_return_type              SyntaxNode
	function_descriptors              ?&CSSFunctionDescriptors
	font_face_rule                    ?&CSSFontFaceRule
	font_feature_values_rule          ?&CSSFontFeatureValuesRule
	counter_style_rule                ?&CSSCounterStyleRule
}

__global empty_css_rule_kind_data = CSSRuleKindData{}

fn (rule CSSRule) kind_data() &CSSRuleKindData {
	data := rule.kind_data_
	if data == unsafe { nil } {
		return &empty_css_rule_kind_data
	}
	return data
}

struct CSSRuleKindStorageScope {
	persistent platform.ArenaEntry
mut:
	retained platform.RetainedAllocationScope
}

// Lazy caches and scalar mutations can run inside a caller's scratch scope.
// Keep their newly published storage with the sheet's actual lifetime.
fn (rule &CSSRule) enter_kind_data_storage() CSSRuleKindStorageScope {
	persistent := rule.has_process_lifetime_sheet() || platform.current_retained_arena() == unsafe { nil }
	return CSSRuleKindStorageScope{
		persistent: platform.enter_persistent_if(persistent)
		retained:   if persistent {
			platform.RetainedAllocationScope{}
		} else {
			platform.enter_retained_allocations()
		}
	}
}

fn (mut scope CSSRuleKindStorageScope) finish() {
	scope.retained.finish()
	platform.leave_persistent(scope.persistent)
}

fn (mut rule CSSRule) set_kind_data(data CSSRuleKindData) {
	mut storage := rule.enter_kind_data_storage()
	defer { storage.finish() }
	rule.kind_data_ = &CSSRuleKindData{ ...data }
}
