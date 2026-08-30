module css

// State shared by CSSOM rule/list/sheet wrappers whose upstream differences
// are WebIDL inheritance and ownership rather than parsing semantics.
pub struct CSSRuleFacade {
pub mut:
	declarations_ map[string]string
	rules          []string
	custom         map[string]string
	name_          string
	namespace_uri  string
	prefix_        string
	css_float_     string
	loading        string
	committed      bool
	font_loaders   []string
}

pub fn CSSRuleFacade.create() CSSRuleFacade {
	return CSSRuleFacade{declarations_: map[string]string{}, custom: map[string]string{}}
}

pub fn (mut rule CSSRuleFacade) append(name string, value string) { rule.declarations_[name] = value }
pub fn (mut rule CSSRuleFacade) set(name string, value string) { rule.declarations_[name] = value }
pub fn (mut rule CSSRuleFacade) delete_(name string) { rule.declarations_.delete(name) }
pub fn (mut rule CSSRuleFacade) clear() { rule.declarations_.clear() }
pub fn (rule CSSRuleFacade) declarations() map[string]string { return rule.declarations_.clone() }
pub fn (rule CSSRuleFacade) properties() []string { return rule.declarations_.keys() }
pub fn (rule CSSRuleFacade) custom_properties() map[string]string { return rule.custom.clone() }
pub fn (rule CSSRuleFacade) custom_property_count() int { return rule.custom.len }
pub fn (mut rule CSSRuleFacade) set_property_style_value(name string, value string) { rule.declarations_[name] = value }
pub fn (rule CSSRuleFacade) get_direct_property(name string) string { return rule.declarations_[name] }
pub fn (rule CSSRuleFacade) style_value_for_computed_property(name string) string { return rule.declarations_[name] }
pub fn (mut rule CSSRuleFacade) empty_the_declarations() { rule.declarations_.clear() }
pub fn (mut rule CSSRuleFacade) set_the_declarations(values map[string]string) { rule.declarations_ = values.clone() }
pub fn (mut rule CSSRuleFacade) set_declarations_from_text(text string) {
	for declaration in text.split(';') {
		parts := declaration.split_nth(':', 2)
		if parts.len == 2 { rule.declarations_[parts[0].trim_space()] = parts[1].trim_space() }
	}
}
pub fn (rule CSSRuleFacade) convert_declarations_to_specified_order() []string { mut names := rule.declarations_.keys(); names.sort(); return names }
pub fn (rule CSSRuleFacade) generated_style_properties_to_css_style_properties() CSSRuleFacade { return rule }
pub fn (rule CSSRuleFacade) serialize_a_css_value(name string) string { return rule.declarations_[name] }
pub fn (rule CSSRuleFacade) css_float() string { return rule.css_float_ }
pub fn (mut rule CSSRuleFacade) set_css_float(value string) { rule.css_float_ = value }
pub fn (rule CSSRuleFacade) begin() int { return 0 }
pub fn (rule CSSRuleFacade) end() int { return rule.rules.len }
pub fn (rule CSSRuleFacade) type_() string { return rule.name_ }
pub fn (rule CSSRuleFacade) url() string { return rule.namespace_uri }
pub fn (rule CSSRuleFacade) loaded_style_sheet() string { return rule.name_ }
pub fn (rule CSSRuleFacade) internal_layer_name() string { return rule.name_ }
pub fn (rule CSSRuleFacade) parent_style_sheet_for_subresource() string { return rule.name_ }
pub fn (rule CSSRuleFacade) declaration() map[string]string { return rule.declarations() }
pub fn (rule CSSRuleFacade) descriptors() map[string]string { return rule.declarations() }
pub fn (rule CSSRuleFacade) key() string { return rule.name_ }
pub fn (mut rule CSSRuleFacade) set_name(name string) { rule.name_ = name }
pub fn (mut rule CSSRuleFacade) set_namespace_uri(uri string) { rule.namespace_uri = uri }
pub fn (mut rule CSSRuleFacade) set_prefix(prefix string) { rule.prefix_ = prefix }
pub fn (rule CSSRuleFacade) css_rules_for_bindings() []string { return rule.rules.clone() }
pub fn (rule CSSRuleFacade) map_entries() map[string]string { return rule.declarations() }
pub fn (rule CSSRuleFacade) item_value(index int) string { return if index < rule.rules.len { rule.rules[index] } else { '' } }
pub fn (rule CSSRuleFacade) evaluate() bool { return true }
pub fn (rule CSSRuleFacade) next_unique_anonymous_layer_name() string { return 'anonymous-layer-' + rule.rules.len.str() }
pub fn (rule CSSRuleFacade) construct_impl() CSSRuleFacade { return rule }
pub fn (rule CSSRuleFacade) owner_rule() string { return rule.name_ }
pub fn (rule CSSRuleFacade) owning_documents_or_shadow_roots() []string { return rule.rules.clone() }
pub fn (rule CSSRuleFacade) default_namespace_rule() string { return rule.namespace_uri }
pub fn (rule CSSRuleFacade) import_rules() []string { return rule.rules.filter(it.starts_with('@import')) }
pub fn (mut rule CSSRuleFacade) register_pending_image_value(value string) { rule.rules << value }
pub fn (mut rule CSSRuleFacade) add_associated_font_loader(loader string) { rule.font_loaders << loader }
pub fn (rule CSSRuleFacade) has_associated_font_loader() bool { return rule.font_loaders.len > 0 }
pub fn (mut rule CSSRuleFacade) set_loading_state(state string) { rule.loading = state }
pub fn (rule CSSRuleFacade) loading_state() string { return rule.loading }
pub fn (rule CSSRuleFacade) node() string { return rule.name_ }
pub fn (rule CSSRuleFacade) author_rule_cache() []string { return rule.rules.clone() }
pub fn (rule CSSRuleFacade) user_agent_rule_cache() []string { return rule.rules.clone() }
pub fn (rule CSSRuleFacade) user_rule_cache() []string { return rule.rules.clone() }
pub fn (mut rule CSSRuleFacade) commit() { rule.committed = true }
pub fn (rule CSSRuleFacade) create_child() CSSRuleFacade { return rule }
pub fn (rule CSSRuleFacade) document_or_shadow_root() string { return rule.name_ }
pub fn (rule CSSRuleFacade) parent_style_sheet() string { return rule.name_ }

pub struct CSSFontFacade {
pub mut:
	loading_ []string
	loaded_  []string
	failed_  []string
	events   map[string]string
	document_ string
	parent_ string
}

pub fn CSSFontFacade.new() CSSFontFacade { return CSSFontFacade{events: map[string]string{}} }
pub fn (font CSSFontFacade) loading_fonts() []string { return font.loading_.clone() }
pub fn (font CSSFontFacade) loaded_fonts() []string { return font.loaded_.clone() }
pub fn (font CSSFontFacade) failed_fonts() []string { return font.failed_.clone() }
pub fn (font CSSFontFacade) onloading() string { return font.events['loading'] }
pub fn (font CSSFontFacade) onloadingdone() string { return font.events['loadingdone'] }
pub fn (font CSSFontFacade) onloadingerror() string { return font.events['loadingerror'] }
pub fn (mut font CSSFontFacade) set_onloading(value string) { font.events['loading'] = value }
pub fn (mut font CSSFontFacade) set_onloadingdone(value string) { font.events['loadingdone'] = value }
pub fn (mut font CSSFontFacade) set_onloadingerror(value string) { font.events['loadingerror'] = value }
pub fn (mut font CSSFontFacade) on_set_modified_from_js() { font.events['modified'] = 'true' }
pub fn (font CSSFontFacade) document() string { return font.document_ }
pub fn (font CSSFontFacade) find_matching_font_weight_ascending() []string { return font.loaded_.clone() }
pub fn (font CSSFontFacade) find_matching_font_weight_descending() []string { mut result := font.loaded_.clone(); result.reverse_in_place(); return result }
pub fn (mut font CSSFontFacade) load_fonts_from_sheet(fonts []string) { font.loading_ << fonts }
pub fn (mut font CSSFontFacade) unload_fonts_from_sheet(fonts []string) {
	font.loading_ = font.loading_.filter(it !in fonts)
}
pub fn (font CSSFontFacade) font_status_promise() string { return if font.failed_.len > 0 { 'rejected' } else { 'fulfilled' } }
pub fn (font CSSFontFacade) parent_rule() string { return font.parent_ }
