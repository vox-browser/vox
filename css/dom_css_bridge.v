module css

import platform
import dom
import os
import mimesniff

// dom <-> css bridge
// ==================
// The DOM module cannot import css (css already imports dom; the reverse would be a module cycle). So the
// DOM stores this port's real style objects (css.ComputedProperties / css.CascadedProperties /
// css.StyleScope) as opaque `voidptr` handles embedded in placeholder structs (dom.CSSComputedProperties_,
// dom.CSSComputedProperties_ and dom.StyleScope). These helpers wrap a css object into its DOM placeholder
// and cast a placeholder's handle back to the css type.
//
// Lifetime: V's default GC is conservative, so a handle stored in a reachable DOM placeholder keeps its
// css target alive (the pointer bits are scanned). ComputedProperties/CascadedProperties are @[heap]
// (address-stable), and the StyleScope is heap-allocated by StyleScope.new, so the cast-back pointers
// stay valid.

// --- ComputedProperties ---

// Wrap a css.ComputedProperties into a DOM placeholder: store the handle back to it AND mirror the
// concrete layout-facing fields the DOM/layout read directly off the placeholder (which cannot name the
// css enums). The css module owns both sides of each enum, so it does the translation here.
fn computed_properties_to_dom(computed &ComputedProperties) &dom.CSSComputedProperties_ {
	display := computed.display()
	mut color_schemes := []string{}
	mut color_scheme_only := false
	if value := computed.typed_property_value(.color_scheme) {
		if value is ColorSchemeStyleValue {
			color_schemes = value.schemes()
			color_scheme_only = value.only()
		}
	}
	mut result := &dom.CSSComputedProperties_{
		display_: dom.CSSDisplay_{
			is_none_: display.is_none()
			is_list_item_: display.is_list_item()
			is_contents_: display.is_contents()
			is_inline_outside_: display.is_inline_outside()
			is_flow_inside_: display.is_flow_inside()
			is_flow_root_inside_: display.is_flow_root_inside()
			is_flex_inside_: display.is_flex_inside()
			is_grid_inside_: display.is_grid_inside()
			is_table_inside_: display.is_table_inside()
			is_math_inside_: display.is_math_inside()
			is_ruby_inside_: display.is_ruby_inside()
			is_block_outside_: display.is_block_outside()
			is_table_caption_: display.is_table_caption()
			is_table_cell_: display.is_table_cell()
			is_table_row_: display.is_table_row()
			is_table_row_group_: display.is_table_row_group()
			is_table_header_group_: display.is_table_header_group()
			is_table_footer_group_: display.is_table_footer_group()
			is_table_column_: display.is_table_column()
			is_table_column_group_: display.is_table_column_group()
		}
		non_animated_display_is_none_: computed_display_is_none_ignoring_animations(computed)
		client_border_top_width_: computed_values_border_data(computed, .border_top_width, .border_top_style).width.to_double()
		client_border_left_width_: computed_values_border_data(computed, .border_left_width, .border_left_style).width.to_double()
		overflow_x_: overflow_to_dom(computed.overflow_x())
		overflow_y_: overflow_to_dom(computed.overflow_y())
		scroll_behavior_: if computed.scroll_behavior() == .smooth { dom.ScrollBehavior.smooth } else { dom.ScrollBehavior.auto_ }
		scroll_snap_strictness_none_: computed.scroll_snap_type().strictness == .none_
		content_visibility_: content_visibility_to_dom(computed.content_visibility())
		opacity_: computed.opacity()
		visibility_: visibility_to_dom(computed.visibility())
		font_weight_: computed.font_weight()
		math_depth_: computed.math_depth()
		math_style_: math_style_to_dom(computed.math_style())
		color_scheme_only_: color_scheme_only
		has_casing_text_transform_: computed.text_transform() in [.uppercase, .lowercase, .capitalize]
		attempted_pseudo_class_matches_: attempted_pseudo_class_matches_to_dom(computed)
		css_handle: voidptr(computed)
	}
	result.set_rare_properties(dom.CSSComputedPropertiesRareData{
		view_transition_name: computed.view_transition_name()
		anchor_names: computed.anchor_names()
		color_schemes: color_schemes
	})
	return result
}

fn attempted_pseudo_class_matches_to_dom(computed &ComputedProperties) u8 {
	mut mask := u8(0)
	if computed.has_attempted_match_against_pseudo_class(.hover) {
		mask |= u8(1) << int(dom.PseudoClass.hover)
	}
	if computed.has_attempted_match_against_pseudo_class(.active) {
		mask |= u8(1) << int(dom.PseudoClass.active)
	}
	if computed.has_attempted_match_against_pseudo_class(.focus) {
		mask |= u8(1) << int(dom.PseudoClass.focus)
	}
	if computed.has_attempted_match_against_pseudo_class(.focus_within) {
		mask |= u8(1) << int(dom.PseudoClass.focus_within)
	}
	if computed.has_attempted_match_against_pseudo_class(.focus_visible) {
		mask |= u8(1) << int(dom.PseudoClass.focus_visible)
	}
	if computed.has_attempted_match_against_pseudo_class(.target) {
		mask |= u8(1) << int(dom.PseudoClass.target)
	}
	if computed.has_attempted_match_against_pseudo_class(.visited) {
		mask |= u8(1) << int(dom.PseudoClass.visited)
	}
	if computed.has_attempted_match_against_pseudo_class(.link) {
		mask |= u8(1) << int(dom.PseudoClass.link)
	}
	return mask
}

// css -> dom enum translations for the layout-facing computed fields mirrored above.

fn overflow_to_dom(overflow Overflow) dom.CSSOverflow_ {
	return match overflow {
		.visible { dom.CSSOverflow_.visible }
		.hidden { dom.CSSOverflow_.hidden }
		.clip { dom.CSSOverflow_.clip }
		.scroll { dom.CSSOverflow_.scroll }
		.auto_ { dom.CSSOverflow_.auto_ }
	}
}

fn content_visibility_to_dom(content_visibility ContentVisibility) dom.CSSContentVisibility_ {
	return match content_visibility {
		.auto_ { dom.CSSContentVisibility_.auto_ }
		.visible { dom.CSSContentVisibility_.visible }
		.hidden { dom.CSSContentVisibility_.hidden }
	}
}

fn visibility_to_dom(visibility Visibility) dom.CSSVisibility_ {
	return match visibility {
		.visible { dom.CSSVisibility_.visible }
		.hidden { dom.CSSVisibility_.hidden }
		.collapse { dom.CSSVisibility_.collapse }
	}
}

fn math_style_to_dom(math_style MathStyle) dom.CSSMathStyle_ {
	return match math_style {
		.normal { dom.CSSMathStyle_.normal }
		.compact { dom.CSSMathStyle_.compact }
	}
}

// The css.ComputedProperties a DOM placeholder points to, or none if it carries no handle.
fn computed_properties_from_dom(placeholder &dom.CSSComputedProperties_) ?&ComputedProperties {
	if placeholder.css_handle == unsafe { nil } {
		return none
	}
	return unsafe { &ComputedProperties(placeholder.css_handle) }
}

// The css.ComputedProperties of the element `abstract_element` inherits style from (its parent, or an
// inheritance override / host), if that element has already had its (bridged) computed style stored.
fn parent_computed_properties(abstract_element dom.AbstractElement) ?&ComputedProperties {
	inherit_from := abstract_element.element_to_inherit_style_from() or { return none }
	dom_computed := inherit_from.computed_properties() or { return none }
	return computed_properties_from_dom(dom_computed)
}

// --- StyleScope ---

// --- Author stylesheets ---

// The document's CSS-owned author-sheet state, reached through an opaque
// handle on dom.Document because DOM cannot import CSS.
@[heap]
struct DocumentAuthorStyleSheets {
mut:
	// Sheets installed explicitly by CSS-aware callers. They cascade before
	// the document CSS style sheets; constructed adopted sheets have their own
	// observable list and are iterated after both.
	sheets []&CSSStyleSheet
	// Sheets this bridge created for <link rel=stylesheet> elements in the
	// document CSS style sheet list, keyed by their source so that rebuilding
	// them on every layout neither duplicates nor reparses them.
	link_sheets  []&CSSStyleSheet
	link_sources []string
}

// The document's author-stylesheet holder, created on first use and cached on the document via its handle.
fn css_author_style_sheets_for(document &dom.Document) &DocumentAuthorStyleSheets {
	mut mutable_document := unsafe { &dom.Document(document) }
	if mutable_document.author_style_sheets_handle != unsafe { nil } {
		return unsafe { &DocumentAuthorStyleSheets(mutable_document.author_style_sheets_handle) }
	}
	holder := &DocumentAuthorStyleSheets{}
	mutable_document.author_style_sheets_handle = voidptr(holder)
	return holder
}

fn invalidation_property_from_dom(property dom.InvalidationProperty) InvalidationProperty {
	return match property.type_ {
		.invalidate_self { InvalidationProperty.invalidate_self() }
		.invalidate_whole_subtree { InvalidationProperty.invalidate_whole_subtree() }
		.class { InvalidationProperty.class(property.name) }
		.id { InvalidationProperty.id(property.name) }
		.tag_name { InvalidationProperty.tag_name(property.name) }
		.attribute { InvalidationProperty.attribute(property.name) }
		.pseudo_class {
			InvalidationProperty.pseudo_class(pseudo_class_from_name(property.pseudo_class_name))
		}
	}
}

fn invalidation_property_to_dom(property InvalidationProperty) dom.InvalidationProperty {
	return dom.InvalidationProperty{
		type_: match property.type_ {
			.invalidate_self { dom.InvalidationPropertyType.invalidate_self }
			.invalidate_whole_subtree { dom.InvalidationPropertyType.invalidate_whole_subtree }
			.class { dom.InvalidationPropertyType.class }
			.id { dom.InvalidationPropertyType.id }
			.tag_name { dom.InvalidationPropertyType.tag_name }
			.attribute { dom.InvalidationPropertyType.attribute }
			.pseudo_class { dom.InvalidationPropertyType.pseudo_class }
		}
		name: property.name()
		pseudo_class_name: if property.type_ == .pseudo_class {
			pseudo_class_name(property.pseudo_class)
		} else {
			''
		}
	}
}

fn invalidation_set_to_dom(set InvalidationSet) dom.StyleInvalidationSet {
	return dom.StyleInvalidationSet{
		properties: set.properties().map(invalidation_property_to_dom(it))
	}
}

fn invalidation_plan_to_dom(plan &InvalidationPlan) dom.InvalidationPlan {
	mut descendant_rules := []dom.DescendantInvalidationRule{}
	for rule in plan.descendant_rules {
		if rule.payload == unsafe { nil } {
			continue
		}
		descendant_rules << dom.DescendantInvalidationRule{
			match_set: invalidation_set_to_dom(rule.match_set)
			match_any: rule.match_any
			payload: invalidation_plan_to_dom(rule.payload)
		}
	}
	mut sibling_rules := []dom.SiblingInvalidationRule{}
	for rule in plan.sibling_rules {
		if rule.payload == unsafe { nil } {
			continue
		}
		sibling_rules << dom.SiblingInvalidationRule{
			match_set: invalidation_set_to_dom(rule.match_set)
			match_any: rule.match_any
			reach: match rule.reach {
				.adjacent { dom.SiblingInvalidationReach.adjacent }
				.subsequent { dom.SiblingInvalidationReach.subsequent }
			}
			payload: invalidation_plan_to_dom(rule.payload)
		}
	}
	return dom.InvalidationPlan{
		invalidate_self: plan.invalidate_self
		invalidate_whole_subtree: plan.invalidate_whole_subtree
		descendant_rules: descendant_rules
		sibling_rules: sibling_rules
	}
}

fn style_computer_invalidation_property_used_in_has_callback(target voidptr, property dom.InvalidationProperty, dom_scope &dom.StyleScope) bool {
	if dom_scope.css_handle == unsafe { nil } {
		return false
	}
	style_computer := unsafe { &StyleComputer(target) }
	scope := unsafe { &StyleScope(dom_scope.css_handle) }
	return style_computer.invalidation_property_used_in_has_selector(invalidation_property_from_dom(property), scope)
}

fn style_computer_invalidation_plan_callback(target voidptr, properties []dom.InvalidationProperty, dom_scope &dom.StyleScope) dom.InvalidationPlan {
	if dom_scope.css_handle == unsafe { nil } {
		return dom.InvalidationPlan{}
	}
	style_computer := unsafe { &StyleComputer(target) }
	scope := unsafe { &StyleScope(dom_scope.css_handle) }
	css_properties := properties.map(invalidation_property_from_dom(it))
	return invalidation_plan_to_dom(style_computer.invalidation_plan_for_properties(css_properties, scope))
}

fn style_scope_may_have_has_selectors_callback(target voidptr) bool {
	scope := unsafe { &StyleScope(target) }
	return scope.may_have_has_selectors()
}

fn style_scope_may_have_sibling_has_selectors_callback(target voidptr) bool {
	scope := unsafe { &StyleScope(target) }
	return scope.may_have_has_selectors_with_relative_selector_that_has_sibling_combinator()
}

fn style_scope_have_local_link_selectors_callback(target voidptr) bool {
	scope := unsafe { &StyleScope(target) }
	return scope.have_local_link_selectors()
}

fn element_has_feature_used_in_has_selector(element &dom.Element, data &StyleInvalidationData) bool {
	if data.tag_names_used_in_has_selectors[element.local_name()]
		|| ((element.namespace_uri() or { '' }) != 'http://www.w3.org/1999/xhtml'
			&& data.tag_names_used_in_has_selectors[element.lowercased_local_name()])
		|| (element.id() or { '' }) in data.ids_used_in_has_selectors {
		return true
	}
	for class_name in element.class_names() {
		if data.class_names_used_in_has_selectors[class_name] {
			return true
		}
	}
	if attributes := element.attribute_list() {
		for index := 0; index < attributes.length(); index++ {
			attribute := attributes.item(index) or { continue }
			name := attribute.local_name()
			if data.attribute_names_used_in_has_selectors[name]
				|| ((element.namespace_uri() or { '' }) != 'http://www.w3.org/1999/xhtml'
					&& data.attribute_names_used_in_has_selectors[name.to_lower()]) {
				return true
			}
		}
	}
	for pseudo_class, _ in data.pseudo_classes_used_in_has_selectors {
		set := dom.StyleInvalidationSet{
			properties: [
				invalidation_property_to_dom(InvalidationProperty.pseudo_class(pseudo_class)),
			]
		}
		if element.includes_properties_from_invalidation_set(set) {
			return true
		}
	}
	return false
}

fn subtree_has_feature_used_in_has_selector(node &dom.Node, data &StyleInvalidationData) bool {
	if node.is_character_data() {
		return true
	}
	if element := node.as_element() {
		if element_has_feature_used_in_has_selector(element, data) {
			return true
		}
	}
	for child in node.children {
		if subtree_has_feature_used_in_has_selector(child, data) {
			return true
		}
	}
	return false
}

fn style_scope_subtree_may_affect_has_callback(target voidptr, node &dom.Node) bool {
	scope := unsafe { &StyleScope(target) }
	data := scope.style_invalidation_data or { return true }
	if data.ids_used_in_has_selectors.len == 0 && data.class_names_used_in_has_selectors.len == 0
		&& data.attribute_names_used_in_has_selectors.len == 0
		&& data.tag_names_used_in_has_selectors.len == 0
		&& data.pseudo_classes_used_in_has_selectors.len == 0
		&& !data.has_selectors_sensitive_to_featureless_subtree_changes {
		return true
	}
	if data.has_selectors_sensitive_to_featureless_subtree_changes {
		return true
	}
	return subtree_has_feature_used_in_has_selector(node, data)
}

fn style_scope_pending_has_invalidation_covers_child_list_callback(target voidptr, node &dom.Node) bool {
	scope := unsafe { &StyleScope(target) }
	return scope.pending_has_invalidation_covers_all_child_list_mutation_features(node)
}

fn style_scope_has_featureless_sensitive_has_selectors_callback(target voidptr) bool {
	scope := unsafe { &StyleScope(target) }
	return scope.has_featureless_sensitive_has_selectors()
}

fn style_scope_record_has_mutation_callback(target voidptr, node &dom.Node, mutation_root &dom.Node, includes_descendants bool) {
	mut scope := unsafe { &StyleScope(target) }
	scope.record_pending_has_invalidation_mutation_features(node, mutation_root, includes_descendants)
}

fn style_scope_record_has_mutation_properties_callback(target voidptr, node &dom.Node, properties []dom.InvalidationProperty) {
	mut scope := unsafe { &StyleScope(target) }
	css_properties := properties.map(invalidation_property_from_dom(it))
	scope.record_pending_has_invalidation_mutation_properties(node, css_properties)
}

fn style_scope_record_conservative_has_invalidation_callback(target voidptr, node &dom.Node, may_affect_sibling_relationships bool) {
	mut scope := unsafe { &StyleScope(target) }
	scope.record_conservative_pending_has_invalidation(node, may_affect_sibling_relationships)
}

fn style_scope_schedule_has_invalidation_callback(target voidptr, node &dom.Node) {
	mut scope := unsafe { &StyleScope(target) }
	scope.schedule_ancestors_style_invalidation_due_to_presence_of_has(node)
}

fn style_scope_invalidate_user_style_callback(target voidptr) {
	mut scope := unsafe { &StyleScope(target) }
	scope.invalidate_user_style_sheet()
}

// CSS::update_style_for_element(): refresh the computed style of the element's flat-tree inheritance chain, from the
// rootmost element down to the element, and answer whether the element then has style. In stop-at-display-none mode
// the walk stops at a display:none element, whose subtree is left unstyled.
fn document_update_style_for_element_callback(_ voidptr, element &dom.Element, stop_at_display_none bool) bool {
	if !element.as_node().is_connected() {
		return false
	}
	mut chain := []&dom.Element{}
	mut current := ?&dom.Element(element)
	for {
		candidate := current or { break }
		chain << candidate
		current = candidate.element_to_inherit_style_from(none)
	}
	for index := chain.len - 1; index >= 0; index-- {
		computed := up_to_date_computed_properties_for_element(chain[index])
		if stop_at_display_none && computed.display().is_none() {
			return false
		}
	}
	return true
}

// Document::obtain_theme_color() steps 2.3 and 2.4: parse the value as a 'color' property value and, if it is a color,
// resolve it in the context of the root html element's layout node.
fn document_theme_color_parse_callback(target voidptr, value string) ?string {
	document := unsafe { &dom.Document(target) }
	// 3. Let color be the result of parsing value.
	css_value := parse_css_value_logic(color_property_id(), value) or { return none }

	// 4. If color is not failure, then return color.
	if !css_value.has_color() {
		return none
	}
	mut color_resolution_context := ColorResolutionContext{}
	// NB: Called during theme color computation, layout may be stale.
	if html_element := document.html_element() {
		if layout_node := html_element.as_node().unsafe_layout_node() {
			color_resolution_context = color_resolution_context_for_layout_node(layout_node)
		}
	}
	color := css_value.to_color(color_resolution_context) or { return none }
	return color.serialize_a_srgb_value()
}

fn document_theme_color_media_matches_callback(target voidptr, value string) bool {
	document := unsafe { &dom.Document(target) }
	query := parse_media_query(ParsingParams{
		document: document
	}, value) or { return false }
	return query.evaluate(document)
}

// Parse `css_text` as an author stylesheet and attach it to `document`, so the real StyleComputer matches
// its rules (author cascade origin). The css-aware equivalent of the minimal cascade taking explicit rules
// — the html parser can't build css.CSSStyleSheet objects (it doesn't import css), so author sheets are
// attached here by css-aware callers.
pub fn add_document_author_style_sheet(document &dom.Document, css_text string) {
	mut allocations := document.enter_native_storage()
	defer { allocations.finish() }
	holder := css_author_style_sheets_for(document)
	mut sheet := parse_css_stylesheet_with_params(ParsingParams{document: document}, css_text, none)
	sheet.add_owning_document_or_shadow_root(unsafe { &dom.Node(document) })
	// The holder is @[heap] (stable address) reached through a cached handle; append through the pointer.
	unsafe {
		holder.sheets << sheet
	}
	mut scope := css_style_scope_for_document(document)
	scope.invalidate_rule_cache()
}

struct DocumentStyleSource {
	cache_key string
	css_text  string
	location  string
	media     string
	title     string
	alternate bool
	owner     &dom.Element = unsafe { nil }
}

fn resolve_stylesheet_url(reference string, base_url string) ?string {
	resolved := dom.dom_url_parse(reference, dom.URL{
		value: base_url
	}, 'utf-8') or { return none }
	return resolved.to_string()
}

fn local_path_for_stylesheet_url(url string) ?string {
	if !url.starts_with('file://') {
		return none
	}
	mut path := url['file://'.len..]
	for path.starts_with('//') {
		path = path[1..]
	}
	query_index := path.index_any('?#')
	if query_index >= 0 {
		path = path[..query_index]
	}
	return path
}

fn read_local_stylesheet(reference string, base_url string) ?(string, string) {
	resolved_url := resolve_stylesheet_url(reference, base_url) or { return none }
	path := local_path_for_stylesheet_url(resolved_url) or { return none }
	return os.read_file(path) or { return none }, resolved_url
}

pub struct ImportedStyleSheetSource {
pub:
	css_text string
	response_url string
	content_type string
	// Set only when the transport establishes a CORS-same-origin response;
	// comparing the final URL alone loses cross-origin redirect tainting.
	cors_same_origin bool
}

// The embedding browser supplies its stylesheet transport and cache. Keeping
// this boundary in CSS lets imports retain their rule tree and response base
// URL instead of flattening their text into the importing sheet.
pub type RemoteStyleSheetLoader = fn (&dom.Document, string) ?ImportedStyleSheetSource

__global remote_style_sheet_loader_ ?RemoteStyleSheetLoader = ?RemoteStyleSheetLoader(none)

pub fn install_remote_style_sheet_loader(loader ?RemoteStyleSheetLoader) {
	remote_style_sheet_loader_ = loader
}

fn read_imported_stylesheet(document &dom.Document, reference string, base_url string) ?(string, string) {
	resolved_url := resolve_stylesheet_url(reference, base_url) or { return none }
	if path := local_path_for_stylesheet_url(resolved_url) {
		return os.read_file(path) or { return none }, resolved_url
	}
	if !resolved_url.starts_with('https://') && !resolved_url.starts_with('http://') { return none }
	loader := remote_style_sheet_loader_ or { return none }
	source := loader(document, resolved_url) or { return none }
	if mime := mimesniff.MimeType.parse(source.content_type) {
		if mime.essence() != 'text/css' && !(document.in_quirks_mode() && source.cors_same_origin) {
			return none
		}
	}
	return source.css_text, source.response_url
}

// The text of remote stylesheets that the browser fetched for links that
// scripts inserted after the document's initial resources, by resolved URL.
__global remote_link_style_sheets = map[string]ImportedStyleSheetSource{}

// Record a fetched remote link stylesheet. The next style synchronization
// installs it for each link that references it.
pub fn set_remote_link_style_sheet(resolved_url string, css_text string) {
	set_remote_link_style_sheet_response(resolved_url, ImportedStyleSheetSource{
		css_text: css_text
		response_url: resolved_url
	})
}

pub fn set_remote_link_style_sheet_response(resolved_url string, source ImportedStyleSheetSource) {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	remote_link_style_sheets[resolved_url.clone()] = ImportedStyleSheetSource{
		css_text: source.css_text.clone()
		response_url: source.response_url.clone()
		content_type: source.content_type.clone()
		cors_same_origin: source.cors_same_origin
	}
}

pub fn has_remote_link_style_sheet(resolved_url string) bool {
	return resolved_url in remote_link_style_sheets
}

// The URL a link's stylesheet resolves to, as the style synchronization keys it.
pub fn link_style_sheet_url(reference string, base_url string) ?string {
	return resolve_stylesheet_url(reference, base_url)
}

fn read_link_stylesheet(link &dom.Element, reference string, base_url string) ?(string, string) {
	if type_ := link.get_attribute_ns(none, 'type') {
		mime := mimesniff.MimeType.parse(type_) or { return none }
		if mime.essence() != 'text/css' { return none }
	}
	resolved_url := resolve_stylesheet_url(reference, base_url) or { return none }
	if path := local_path_for_stylesheet_url(resolved_url) {
		return os.read_file(path) or { return none }, resolved_url
	}
	source := remote_link_style_sheets[resolved_url] or { return none }
	if mime := mimesniff.MimeType.parse(source.content_type) {
		assume_css_in_quirks_mode := link.document().in_quirks_mode()
			&& dom.URL{value: source.response_url}.origin().is_same_origin(link.document().origin())
		if mime.essence() != 'text/css' && !assume_css_in_quirks_mode { return none }
	}
	// The browser inlines a parsed remote link's sheet as the <style> after it.
	if inlined := link.as_node().next_sibling() {
		if element := inlined.as_element() {
			if element.local_name() == 'style'
				&& element.get_attribute_value('data-libweb-v-source-url') == resolved_url {
				return none
			}
		}
	}
	return source.css_text, source.response_url
}

fn load_imported_stylesheets(document &dom.Document, mut sheet CSSStyleSheet, location string, mut active_urls map[string]bool) {
	for mut import_rule in sheet.import_rules {
		if supports := import_rule.supports {
			if !supports.matches_condition() {
				continue
			}
		}
		if mut media := import_rule.media {
			media.evaluate(document)
			if !media.matches() {
				continue
			}
		}
		request_url := resolve_stylesheet_url(import_rule.kind_data().url, location) or { continue }
		if active_urls[request_url] {
			continue
		}
		css_text, resolved_url := read_imported_stylesheet(document, request_url, location) or { continue }
		if active_urls[resolved_url] { continue }
		active_urls[request_url] = true
		active_urls[resolved_url] = true
		mut imported_sheet := parse_css_stylesheet_with_params(ParsingParams{document: document}, css_text, resolved_url)
		imported_sheet.set_parent_css_style_sheet(sheet)
		load_imported_stylesheets(document, mut imported_sheet, resolved_url, mut active_urls)
		imported_sheet.evaluate_media_queries(document)
		import_rule.set_style_sheet(imported_sheet)
		active_urls.delete(resolved_url)
		active_urls.delete(request_url)
	}
}

fn dump_css_style_sheet_if_requested(sheet &CSSStyleSheet) {
	if os.getenv('LIBWEB_V_CSS_DUMP') == '1' {
		for rule in sheet.css_rules().rules {
			eprintln(rule.dump(0))
		}
	}
}

// Load imports before the sheet joins its style sheet list so imported fonts,
// layers and style rules participate in the owner's initial invalidation.
// Like local imports, the embedding browser's remote loader is synchronous.
fn parse_css_style_sheet_for_owner_node(document &dom.Document, css_text string, location string) &CSSStyleSheet {
	phase_mark := platform.arena_phase_begin()
	defer {
		platform.arena_phase_end('css_parse', phase_mark)
	}
	mut sheet := parse_css_stylesheet_in_workspace(ParsingParams{document: document}, css_text, location, none, css_text.len >= 16_384)
	sheet.base.type_string = 'text/css'
	mut active_urls := map[string]bool{}
	active_urls[location] = true
	load_imported_stylesheets(document, mut sheet, location, mut active_urls)
	dump_css_style_sheet_if_requested(sheet)
	return sheet
}

fn css_style_scope_for_scope_node(scope_node &dom.Node) &StyleScope {
	if shadow_root := scope_node.as_shadow_root() {
		return css_style_scope_for_shadow_root(shadow_root)
	}
	return css_style_scope_for_document(scope_node.document())
}

// StyleScope::create_a_css_style_sheet() for DOM::StyleElementBase.
fn style_scope_create_a_css_style_sheet_for_style_element(scope_node &dom.Node, css_text string, owner_node &dom.Element, media string, title string, location ?string) voidptr {
	document := owner_node.document()
	// Boundary: a style element's sheet has a null location, and this port
	// resolves a sheet's relative URLs against its location, so the sheet is
	// parsed at the document base URL. The shell's inlined remote link
	// stylesheets record their response URL instead.
	declared_location := owner_node.get_attribute_value('data-libweb-v-source-url')
	sheet_location := location or {
		if declared_location == '' {
			document.base_url().to_string()
		} else {
			declared_location
		}
	}
	mut sheet := parse_css_style_sheet_for_owner_node(document, css_text, sheet_location)
	mut scope := css_style_scope_for_scope_node(scope_node)
	mut list := scope.style_sheet_list()
	list.initialize_a_css_style_sheet(mut sheet, owner_node, media, title, .no, .yes, none,
		none)
	return voidptr(sheet)
}

fn style_scope_remove_a_css_style_sheet_for_style_element(scope_node &dom.Node, sheet voidptr) {
	mut scope := css_style_scope_for_scope_node(scope_node)
	mut list := scope.style_sheet_list()
	list.remove_a_css_style_sheet(mut unsafe { &CSSStyleSheet(sheet) })
}

fn style_scope_move_sheet_for_style_element(scope_node &dom.Node, sheet voidptr, destination_node &dom.Node) {
	mut scope := css_style_scope_for_scope_node(scope_node)
	mut list := scope.style_sheet_list()
	mut destination_scope := css_style_scope_for_scope_node(destination_node)
	mut destination := destination_scope.style_sheet_list()
	list.move_sheet(unsafe { &CSSStyleSheet(sheet) }, mut destination)
}

fn style_sheet_state_set_media(sheet voidptr, media string) {
	mut style_sheet := unsafe { &CSSStyleSheet(sheet) }
	if style_sheet.base.media.media_text() != media {
		style_sheet.set_media(media)
	}
}

// HTMLLinkElement::process_stylesheet_resource's CSS-owned sheet installation.
// The link retains the same object exposed through LinkStyle::sheet.
pub fn install_link_style_sheet(owner &dom.HTMLLinkElement, css_text string, location string, alternate bool) &CSSStyleSheet {
	mut link := unsafe { &dom.HTMLLinkElement(owner) }
	link.remove_linked_style_sheet()
	element := unsafe { &dom.Element(owner) }
	scope_node := element.as_node().document_or_shadow_root_style_scope_node()
	mut scope := css_style_scope_for_scope_node(scope_node)
	mut list := scope.style_sheet_list()
	mut sheet := parse_css_style_sheet_for_owner_node(element.document(), css_text, location)
	// Cache-only synchronization has no CORS response to approve. A Fetch
	// completion can replace this flag with its response's origin-clean state.
	origin_clean := if dom.URL{ value: location }.origin().is_same_origin(element.document().origin()) {
		StyleSheetListOriginClean.yes
	} else { StyleSheetListOriginClean.no }
	title := if element.as_node().in_a_document_tree() {
		element.get_attribute_value('title')
	} else {
		''
	}
	list.initialize_a_css_style_sheet(mut sheet, element, element.get_attribute_value('media'),
		title, if alternate { .yes } else { .no }, origin_clean, none, none)
	link.linked_style_sheet_ = voidptr(sheet)
	link.linked_style_sheet_scope_ = scope_node
	link.linked_style_sheet_from_resource_ = false
	return sheet
}

fn style_sheet_state_evaluate_media_queries(sheet voidptr, document &dom.Document) bool {
	mut style_sheet := unsafe { &CSSStyleSheet(sheet) }
	return style_sheet.evaluate_media_queries(document)
}

fn style_sheet_state_media_list_matches(sheet voidptr) bool {
	style_sheet := unsafe { &CSSStyleSheet(sheet) }
	return style_sheet.base.media.matches()
}

fn style_sheet_state_disabled(sheet voidptr) bool {
	style_sheet := unsafe { &CSSStyleSheet(sheet) }
	return style_sheet.base.disabled
}

fn style_sheet_state_set_disabled(sheet voidptr, disabled bool) {
	mut style_sheet := unsafe { &CSSStyleSheet(sheet) }
	style_sheet.set_disabled(disabled)
}

fn style_sheet_state_loading_state(sheet voidptr) dom.CSSStyleSheetLoadingState {
	style_sheet := unsafe { &CSSStyleSheet(sheet) }
	return match style_sheet.loading_state() {
		.unloaded, .loading { dom.CSSStyleSheetLoadingState.loading }
		.loaded { dom.CSSStyleSheetLoadingState.loaded }
		.error { dom.CSSStyleSheetLoadingState.error }
	}
}

fn init() {
	dom.install_document_font_face_set_factory(document_font_face_set_for_dom)
	dom.install_document_visual_viewport_factory(document_visual_viewport_for_dom)
	dom.install_style_sheet_scope_hooks(dom.StyleSheetScopeHooks{
		create_a_css_style_sheet: style_scope_create_a_css_style_sheet_for_style_element
		remove_a_css_style_sheet: style_scope_remove_a_css_style_sheet_for_style_element
		move_sheet:               style_scope_move_sheet_for_style_element
		set_media:                style_sheet_state_set_media
		evaluate_media_queries:   style_sheet_state_evaluate_media_queries
		media_list_matches:       style_sheet_state_media_list_matches
		disabled:                 style_sheet_state_disabled
		set_disabled:             style_sheet_state_set_disabled
		loading_state:            style_sheet_state_loading_state
	})
}

fn document_font_face_set_for_dom(document &dom.Document) dom.FontFaceSet {
	return css_style_computer_for(document).font_face_set_
}

fn document_visual_viewport_for_dom(document &dom.Document) dom.VisualViewport {
	mut viewport := VisualViewport.create(document)
	viewport.initialize()
	return viewport
}

// The associated CSS style sheet of a style element (LinkStyle::sheet).
pub fn style_element_sheet(element &dom.Element) ?&CSSStyleSheet {
	base := element.style_element_base() or { return none }
	sheet := base.sheet()
	if sheet == unsafe { nil } {
		return none
	}
	return unsafe { &CSSStyleSheet(sheet) }
}

// Synchronize the document CSS style sheet list with its <link rel=stylesheet>
// elements, then re-evaluate media rules for the current viewport. Style
// elements maintain their own sheets through DOM::StyleElementBase.
// Boundary: HTMLLinkElement does not yet fetch and process stylesheet
// resources, so this bridge reads local link stylesheets, and remote ones the
// browser fetched, on each layout and adds them to the list with the link's
// media, title, and alternate flag.
pub fn sync_document_style_elements(document &dom.Document) {
	mut allocations := document.enter_native_storage()
	defer { allocations.finish() }
	root := unsafe { &dom.Node(document) }
	base_url := document.base_url().to_string()
	mut link_sources := []DocumentStyleSource{}
	for element in query_selector_all(root, '*') {
		if element.local_name() != 'link' {
			continue
		}
		relations := element.get_attribute_value('rel').to_lower().fields()
		if 'stylesheet' !in relations || element.has_attribute('disabled') {
			continue
		}
		link := unsafe { &dom.HTMLLinkElement(element) }
		if link.linked_style_sheet_from_resource_ {
			continue
		}
		href := element.get_attribute_value('href')
		css_text, resolved_url := read_link_stylesheet(element, href, base_url) or { continue }
		link_sources << DocumentStyleSource{
			cache_key: 'link:${element.as_node().unique_id()}:${resolved_url}:${css_text}'
			css_text:  css_text
			location:  resolved_url
			media:     element.get_attribute_value('media')
			title:     element.get_attribute_value('title')
			alternate: 'alternate' in relations
			owner:     element
		}
	}
	sources := link_sources.map(it.cache_key)

	holder := css_author_style_sheets_for(document)
	if holder.link_sources != sources {
		mut scope := css_style_scope_for_document(document)
		mut list := scope.style_sheet_list()
		for old_sheet in holder.link_sheets {
			list.remove_a_css_style_sheet(mut unsafe { &CSSStyleSheet(old_sheet) })
			if owner := old_sheet.base.owner_node {
				mut link := unsafe { &dom.HTMLLinkElement(owner) }
				if link.linked_style_sheet_ == voidptr(old_sheet) {
					link.linked_style_sheet_ = unsafe { nil }
					link.linked_style_sheet_scope_ = none
				}
			}
		}
		mut parsed := []&CSSStyleSheet{cap: link_sources.len}
		for source in link_sources {
			sheet := install_link_style_sheet(unsafe { &dom.HTMLLinkElement(source.owner) },
				source.css_text, source.location, source.alternate)
			parsed << sheet
		}
		unsafe {
			holder.link_sources = sources.clone()
			holder.link_sheets = parsed
		}
	}
	// A resource cache hit must still forward live media changes to the existing
	// object. Retain CSSOM edits and sheet identity across these mutations.
	for index, source in link_sources {
		if index < holder.link_sheets.len {
			style_sheet_state_set_media(voidptr(holder.link_sheets[index]), source.media)
		}
	}
	evaluate_media_rules_for_document(document)
}

// Return the live CSSOM sheet owned by a document <style> or <link> element.
pub fn style_sheet_for_owner_node(document &dom.Document, owner &dom.Element) ?&CSSStyleSheet {
	if owner.is_style_element_base() {
		return style_element_sheet(owner)
	}
	if owner.is_html_element() && owner.local_name() == 'link' {
		link := unsafe { &dom.HTMLLinkElement(owner) }
		if link.linked_style_sheet_ != unsafe { nil } {
			return unsafe { &CSSStyleSheet(link.linked_style_sheet_) }
		}
	}
	sync_document_style_elements(document)
	holder := css_author_style_sheets_for(document)
	for sheet in holder.link_sheets {
		if sheet_owner := sheet.base.owner_node {
			if voidptr(sheet_owner) == voidptr(owner) {
				return sheet
			}
		}
	}
	return none
}

fn evaluate_media_rules_for_shadow_root(shadow_root &dom.ShadowRoot, document &dom.Document) {
	mut scope := css_style_scope_for_shadow_root(shadow_root)
	mut media_queries_changed_match_state := false
	for sheet in scope.stylesheets_for_cascade_origin(.author) {
		mut mutable_sheet := unsafe { &CSSStyleSheet(sheet) }
		if mutable_sheet.evaluate_media_queries(document) {
			media_queries_changed_match_state = true
		}
	}
	if !media_queries_changed_match_state {
		return
	}
	scope.invalidate_rule_cache()
	mut shadow_node := unsafe { &dom.Node(shadow_root) }
	shadow_node.invalidate_style(.media_query_changed_match_state)
	invalidate_assigned_elements_for_dirty_style_sheet_slots(shadow_root)
	if host := shadow_root.host() {
		mut host_root := unsafe { &dom.Node(host.as_node().root()) }
		host_root.invalidate_style(.media_query_changed_match_state)
	}
}


// DOM::Document::evaluate_media_rules(). CSSStyleSheet is CSS-owned in the V
// module graph, so the translated algorithm lives at this bridge rather than
// in dom.Document.
fn evaluate_media_rules_for_document(document &dom.Document) {
	mut document_media_queries_changed_match_state := false
	mut document_scope := css_style_scope_for_document(document)
	for sheet in document_scope.stylesheets_for_cascade_origin(.author) {
		mut mutable_sheet := unsafe { &CSSStyleSheet(sheet) }
		if mutable_sheet.evaluate_media_queries(document) {
			document_media_queries_changed_match_state = true
		}
	}
	// Each shadow scope is independent. Visit the document's registered roots
	// instead of walking every ordinary element and text node to discover them.
	// Disconnected hosts were excluded by the old shadow-including traversal.
	for shadow_root in document.registered_shadow_roots() {
		if unsafe { &dom.Node(shadow_root) }.is_connected() {
			evaluate_media_rules_for_shadow_root(shadow_root, document)
		}
	}

	if document_media_queries_changed_match_state {
		document_scope.invalidate_rule_cache()
		mut mutable_document := unsafe { &dom.Document(document) }
		mut document_node := unsafe { &dom.Node(mutable_document) }
		document_node.invalidate_style(.media_query_changed_match_state)
	}
}

fn document_evaluate_media_rules_callback(target voidptr) {
	document := unsafe { &dom.Document(target) }
	evaluate_media_rules_for_document(document)
}

fn find_style_sheet_with_url(url string, sheet &CSSStyleSheet) ?&CSSStyleSheet {
	if href := sheet.href() {
		if href == url {
			return sheet
		}
	}
	for import_rule in sheet.import_rules {
		if loaded_style_sheet := import_rule.kind_data().loaded_style_sheet {
			if found := find_style_sheet_with_url(url, loaded_style_sheet) {
				return found
			}
		}
	}
	return none
}

fn document_get_style_sheet_source_callback(target voidptr, identifier &dom.StyleSheetIdentifier) ?string {
	document := unsafe { &dom.Document(target) }
	return match identifier.type_ {
		.style_element {
			unique_id := identifier.dom_element_unique_id or { return none }
			node := dom.Node.from_unique_id(unique_id) or { return none }
			element := node.as_element() or { return none }
			if element.local_name() != 'style' {
				return none
			}
			element.as_node().child_text_content()
		}
		.link_element, .import_rule {
			url := identifier.url or { return none }
			holder := css_author_style_sheets_for(document)
			for sheet in holder.sheets {
				if found := find_style_sheet_with_url(url, sheet) {
					return found.source_text()
				}
			}
			scope := css_style_scope_for_document(document)
			if list := scope.style_sheets {
				for sheet in list.sheets {
					if found := find_style_sheet_with_url(url, sheet) {
						return found.source_text()
					}
				}
			}
			none
		}
		.user_agent {
			url := identifier.url or { return none }
			user_agent_style_sheet_source(url)
		}
		.user_style {
			scope := css_style_scope_for_document(document)
			scope.user_style_source
		}
	}
}

fn document_size_query_invalidation_callback(_ voidptr, query_container &dom.Element) {
	invalidate_descendant_styles_depending_on_size_container_query(query_container)
}

// DOM::Document::build_registered_properties_cache(). The concrete CSS rules
// remain CSS-owned, while the compact registration records are mirrored onto
// Document for custom-property computation.
fn build_registered_properties_cache_for_document(document &dom.Document) {
	mut registrations := map[string]dom.CustomPropertyRegistration{}
	scope := css_style_scope_for_document(document)
	for sheet in scope.stylesheets_for_cascade_origin(.author) {
		for name, registration in sheet.registered_properties_from_css_property_rules() {
			registrations[name] = dom.CustomPropertyRegistration{
				initial_value: registration.initial_value
				syntax: registration.syntax
				inherits: registration.inherit
			}
		}
	}
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.cached_registered_properties_from_css_property_rules = registrations.clone()
}

fn style_computer_build_registered_properties_cache_callback(target voidptr) {
	style_computer := unsafe { &StyleComputer(target) }
	if style_computer.document_ != unsafe { nil } {
		build_registered_properties_cache_for_document(style_computer.document_)
	}
}

fn style_computer_build_counter_style_cache_callback(target voidptr) {
	style_computer := unsafe { &StyleComputer(target) }
	if style_computer.document_ != unsafe { nil } {
		rebuild_registered_counter_styles_for_document(style_computer.document_)
	}
}

// Return the concrete computed style stored on an element by the document
// style pass. Layout consumes that single canonical result instead of running
// a second, inheritance-blind computation while building its tree.
pub fn computed_properties_for_element(element &dom.Element) ?&ComputedProperties {
	placeholder := dom.AbstractElement.new(element, none).computed_properties() or { return none }
	return computed_properties_from_dom(placeholder)
}

// Recover the canonical typed CSS layer represented by DOM's cycle-breaking
// view. No CSS text serialization or reparsing occurs.
pub fn background_layer_from_dom(layer dom.BackgroundLayerData) ?BackgroundLayerData {
	if layer.computed_properties_handle == unsafe { nil } {
		return none
	}
	computed := unsafe { &ComputedProperties(layer.computed_properties_handle) }
	layers := computed.background_layers()
	if layer.layer_index < 0 || layer.layer_index >= layers.len {
		return none
	}
	return layers[layer.layer_index]
}

// Return the concrete computed style installed for a generated pseudo-element
// during the top-down style pass.
pub fn computed_properties_for_pseudo_element(element &dom.Element, pseudo_element dom.PseudoElement) ?&ComputedProperties {
	abstract_element := dom.AbstractElement.new(element, pseudo_element)
	placeholder := abstract_element.computed_properties() or { return none }
	return computed_properties_from_dom(placeholder)
}

// Parse and attach an author sheet to a shadow-root style scope. Keeping the
// concrete CSSStyleSheet on css.StyleScope avoids a dom -> css import cycle.
pub fn add_shadow_root_author_style_sheet(shadow_root &dom.ShadowRoot, css_text string) {
	mut scope := css_style_scope_for_shadow_root(shadow_root)
	mut sheet := parse_css_stylesheet_with_params(ParsingParams{document: shadow_root.as_node().document()}, css_text, none)
	sheet.add_owning_document_or_shadow_root(unsafe { &dom.Node(shadow_root) })
	scope.author_style_sheets << sheet
	scope.invalidate_rule_cache()
}

// Set the page-level user stylesheet used by the user cascade origin.
pub fn set_document_user_style_sheet(document &dom.Document, css_text string) {
	mut scope := css_style_scope_for_document(document)
	if existing := scope.user_style_source {
		if existing == css_text { return }
	}
	change := prepare_targeted_user_style_change(document, mut scope, css_text)
	scope.user_style_source = css_text
	scope.invalidate_rule_cache()
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.bump_style_environment_version()
	if targeted := change {
		// Keep the parsed replacement used to project the invalidation plan.
		scope.user_style_sheet = targeted.sheet
		invalidate_user_style_change_tree(document.as_node(), targeted.invalidation, targeted.subject_filter)
	} else {
		mutable_document.set_needs_full_style_update(true)
	}
}

// --- Document style-update hook ---

// The persistent css.StyleComputer for `document`, created on first use and cached on the document's
// dom.StyleComputer placeholder via its handle (Ladybird's Document owns its StyleComputer, so the
// ancestor filter / viewport / caches persist across style updates). Obtaining it also installs the
// update-style hook, so `css_style_computer_for(doc)` is all a css-aware caller needs to make plain
// doc.update_style() run the CSS style pass.
pub fn css_style_computer_for(document &dom.Document) &StyleComputer {
	install_document_selector_query_hook(document)
	mut mutable_document := unsafe { &dom.Document(document) }
	dom_style_computer := mutable_document.style_computer
	if dom_style_computer != unsafe { nil } && dom_style_computer.css_handle != unsafe { nil } {
		install_document_background_style_hook(document)
		install_document_scroll_style_hook(document)
		return unsafe { &StyleComputer(dom_style_computer.css_handle) }
	}
	style_computer := StyleComputer.new(document)
	mutable_document.set_css_animation_timeline_update_hook(dom.DocumentCSSAnimationTimelineUpdateHook{
		target: voidptr(style_computer)
		callback: style_computer_document_timeline_update_callback
	})
	mutable_document.set_css_animation_event_hook(dom.DocumentCSSAnimationEventHook{
		target: voidptr(style_computer)
		dispatch: style_computer_dispatch_css_animation_event
	})
	mutable_document.style_computer = &dom.StyleComputer{
		css_handle: voidptr(style_computer)
		invalidation_property_used_in_has_callback: style_computer_invalidation_property_used_in_has_callback
		invalidation_plan_callback: style_computer_invalidation_plan_callback
		shadow_root_may_match_host_callback: style_computer_shadow_root_may_match_host_callback
		recompute_style_callback: style_computer_recompute_style_callback
		recompute_inherited_style_callback: style_computer_recompute_inherited_style_callback
		update_animated_style_callback: style_computer_update_animated_style_callback
		build_registered_properties_cache_callback: style_computer_build_registered_properties_cache_callback
		build_counter_style_cache_callback: style_computer_build_counter_style_cache_callback
	}
	mutable_document.set_update_style_for_element_hook(dom.DocumentUpdateStyleForElementHook{
		target: voidptr(document)
		update_style_for_element: document_update_style_for_element_callback
	})
	mutable_document.set_theme_color_hook(dom.DocumentThemeColorHook{
		target: voidptr(document)
		parse_color: document_theme_color_parse_callback
		media_matches: document_theme_color_media_matches_callback
	})
	install_document_background_style_hook(document)
	install_document_scroll_style_hook(document)
	install_document_style_hook(document)
	return style_computer
}

// A CSS transition or animation of a document, for Document.getAnimations().
pub struct DocumentCSSAnimation {
pub:
	element        &dom.Element = unsafe { nil }
	pseudo_element string
	is_transition  bool
	// The transition property or the animation name.
	name       string
	play_state string
	handle     voidptr
}

fn web_animation_play_state_name(state WebAnimationPlayState) string {
	return match state {
		.idle { 'idle' }
		.running { 'running' }
		.paused { 'paused' }
		.finished { 'finished' }
	}
}

fn document_css_animation_pseudo(abstract_element dom.AbstractElement) string {
	pseudo := abstract_element.pseudo_element_ or { return '' }
	return '::' + dom.pseudo_element_name(pseudo)
}

// The document's relevant CSS transitions, then its CSS animations, each in
// the order they were created.
// https://drafts.csswg.org/web-animations-1/#dom-documentorshadowroot-getanimations
pub fn document_css_animations(document &dom.Document) []DocumentCSSAnimation {
	dom_style_computer := document.style_computer
	if dom_style_computer == unsafe { nil } || dom_style_computer.css_handle == unsafe { nil } {
		return []DocumentCSSAnimation{}
	}
	style_computer := unsafe { &StyleComputer(dom_style_computer.css_handle) }
	mut transitions := []&CSSTransition{}
	mut transition_targets := map[voidptr]dom.AbstractElement{}
	if style_computer.css_transition_storage_ != unsafe { nil } {
		for _, bucket in style_computer.css_transition_storage_.associated_transitions {
			for entry in bucket.entries {
				if entry.transition == unsafe { nil } { continue }
				if entry.transition.play_state_ !in [.running, .paused] { continue }
				transitions << entry.transition
				transition_targets[voidptr(entry.transition)] = entry.abstract_element
			}
		}
	}
	transitions.sort_with_compare(fn (a &&CSSTransition, b &&CSSTransition) int {
		if a.global_animation_list_order_ < b.global_animation_list_order_ { return -1 }
		if a.global_animation_list_order_ > b.global_animation_list_order_ { return 1 }
		return 0
	})
	mut result := []DocumentCSSAnimation{cap: transitions.len}
	for transition in transitions {
		target := transition_targets[voidptr(transition)] or { continue }
		if !target.element_.as_node().is_connected() { continue }
		result << DocumentCSSAnimation{
			element:        target.element_
			pseudo_element: document_css_animation_pseudo(target)
			is_transition:  true
			name:           transition.transition_property()
			play_state:     web_animation_play_state_name(transition.play_state_)
			handle:         voidptr(transition)
		}
	}
	if style_computer.css_animation_storage_ != unsafe { nil } {
		for entry in style_computer.css_animation_storage_.entries {
			if entry.animation == unsafe { nil } { continue }
			state := entry.animation.play_state()
			if state !in [.running, .paused] { continue }
			if !entry.abstract_element.element_.as_node().is_connected() { continue }
			result << DocumentCSSAnimation{
				element:        entry.abstract_element.element_
				pseudo_element: document_css_animation_pseudo(entry.abstract_element)
				name:           entry.name
				play_state:     web_animation_play_state_name(state)
				handle:         voidptr(entry.animation)
			}
		}
	}
	return result
}

fn document_css_transition_for_handle(style_computer &StyleComputer, handle voidptr) ?&CSSTransition {
	if style_computer.css_transition_storage_ == unsafe { nil } { return none }
	for _, bucket in style_computer.css_transition_storage_.associated_transitions {
		for entry in bucket.entries {
			if voidptr(entry.transition) == handle { return entry.transition }
		}
	}
	return none
}

fn document_css_animation_for_handle(style_computer &StyleComputer, handle voidptr) ?&CSSAnimation {
	if style_computer.css_animation_storage_ == unsafe { nil } { return none }
	for entry in style_computer.css_animation_storage_.entries {
		if voidptr(entry.animation) == handle { return entry.animation }
	}
	return none
}

// https://drafts.csswg.org/web-animations-1/#dom-animation-currenttime for a
// CSS transition or animation listed by document_css_animations().
pub fn document_css_animation_current_time(document &dom.Document, handle voidptr) ?f64 {
	dom_style_computer := document.style_computer
	if dom_style_computer == unsafe { nil } || dom_style_computer.css_handle == unsafe { nil } { return none }
	style_computer := unsafe { &StyleComputer(dom_style_computer.css_handle) }
	now := style_computer.animation_clock_now(document)
	if transition := document_css_transition_for_handle(style_computer, handle) {
		if transition.play_state_ == .idle { return none }
		delay := if transition.keyframe_effect_ != unsafe { nil } { transition.keyframe_effect_.specified_start_delay } else { 0.0 }
		return now - (transition.start_time_ - delay)
	}
	animation := document_css_animation_for_handle(style_computer, handle) or { return none }
	if animation.play_state_ == .idle || animation.paused_progress_ != none { return none }
	return now - animation.start_time_
}

// Seeks a running CSS transition or animation; the next style update samples it there.
pub fn document_css_animation_set_current_time(document &dom.Document, handle voidptr, time_ms f64) bool {
	dom_style_computer := document.style_computer
	if dom_style_computer == unsafe { nil } || dom_style_computer.css_handle == unsafe { nil } { return false }
	style_computer := unsafe { &StyleComputer(dom_style_computer.css_handle) }
	now := style_computer.animation_clock_now(document)
	if found := document_css_transition_for_handle(style_computer, handle) {
		mut transition := unsafe { &CSSTransition(found) }
		if transition.play_state_ == .idle { return false }
		delay := if transition.keyframe_effect_ != unsafe { nil } { transition.keyframe_effect_.specified_start_delay } else { 0.0 }
		shift := (now - time_ms + delay) - transition.start_time_
		transition.start_time_ += shift
		transition.end_time_ += shift
		if transition.play_state_ == .finished && now < transition.end_time_ {
			transition.play_state_ = .running
		}
		return true
	}
	found := document_css_animation_for_handle(style_computer, handle) or { return false }
	mut animation := unsafe { &CSSAnimation(found) }
	if animation.play_state_ != .running || animation.paused_progress_ != none { return false }
	animation.start_time_ = now - time_ms
	return true
}

pub fn document_css_animation_cancel(document &dom.Document, handle voidptr) bool {
	bridge := document.style_computer
	if bridge == unsafe { nil } || bridge.css_handle == unsafe { nil } { return false }
	computer := unsafe { &StyleComputer(bridge.css_handle) }
	if found := document_css_transition_for_handle(computer,handle) {
		mut transition := unsafe { &CSSTransition(found) }
		transition.cancel()
		return true
	}
	if found := document_css_animation_for_handle(computer,handle) {
		mut animation := unsafe { &CSSAnimation(found) }
		animation.cancel()
		return true
	}
	return false
}

// Whether the browser host needs to schedule another rendering update for a
// running CSS animation or transition owned by this document.
pub fn document_has_running_css_animations(document &dom.Document) bool {
	dom_style_computer := document.style_computer
	if dom_style_computer == unsafe { nil } || dom_style_computer.css_handle == unsafe { nil } {
		return false
	}
	style_computer := unsafe { &StyleComputer(dom_style_computer.css_handle) }
	if style_computer.css_animation_storage_ != unsafe { nil } {
		for entry in style_computer.css_animation_storage_.entries {
			if entry.animation.play_state() == .running
				&& style_computer.animation_target_needs_rendering(entry.abstract_element) {
				return true
			}
		}
	}
	if style_computer.css_transition_storage_ != unsafe { nil } {
		for _, bucket in style_computer.css_transition_storage_.associated_transitions {
			for entry in bucket.entries {
				if entry.transition.play_state_ == .running
					&& style_computer.animation_target_needs_rendering(entry.abstract_element) {
					return true
				}
			}
		}
	}
	return false
}

fn document_background_layers_callback(_ voidptr, element &dom.Element) ?[]dom.BackgroundLayerData {
	computed := computed_properties_for_element(element) or { return none }
	layers := computed.background_layers()
	mut result := []dom.BackgroundLayerData{cap: layers.len}
	for index, _ in layers {
		result << dom.BackgroundLayerData{
			computed_properties_handle: voidptr(computed)
			layer_index: index
		}
	}
	return result
}

fn document_background_color_callback(_ voidptr, element &dom.Element) dom.Color {
	computed := computed_properties_for_element(element) or { return dom.Color{} }
	abstract_element := dom.AbstractElement.new(element, none)
	context := ColorResolutionContext.for_element(&abstract_element)
	value := computed.typed_property_value(.background_color) or { return dom.Color{} }
	color := value.to_color(context) or { return dom.Color{} }
	return dom.Color{
		r: color.r
		g: color.g
		b: color.b
		a: color.a
	}
}

fn document_background_image_rendering_callback(_ voidptr, element &dom.Element) dom.ImageRendering {
	computed := computed_properties_for_element(element) or { return .auto_ }
	return match computed.image_rendering() {
		.auto_ { .auto_ }
		.crisp_edges { .crisp_edges }
		.high_quality { .high_quality }
		.pixelated { .pixelated }
		.smooth { .smooth }
	}
}

fn install_document_background_style_hook(document &dom.Document) {
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.set_background_style_hook(dom.DocumentBackgroundStyleHook{
		target: voidptr(document)
		background_color: document_background_color_callback
		background_layers: document_background_layers_callback
		background_image_rendering: document_background_image_rendering_callback
	})
}

fn document_scroll_margin_callback(_ voidptr, element &dom.Element) dom.ScrollMarginData {
	computed := computed_properties_for_element(element) or { return dom.ScrollMarginData{} }
	layout_node := element.as_node().layout_node() or { return dom.ScrollMarginData{} }
	margin := computed.length_box(.scroll_margin_left, .scroll_margin_top, .scroll_margin_right, .scroll_margin_bottom, LengthPercentageOrAuto.from_length(Length.make_px(0)))
	context := LengthResolutionContext.for_layout_node(layout_node)
	return dom.ScrollMarginData{
		top: margin.top().to_px_or_zero(context, CSSPixels.new(0)).to_double()
		right: margin.right().to_px_or_zero(context, CSSPixels.new(0)).to_double()
		bottom: margin.bottom().to_px_or_zero(context, CSSPixels.new(0)).to_double()
		left: margin.left().to_px_or_zero(context, CSSPixels.new(0)).to_double()
	}
}

fn document_scroll_padding_callback(_ voidptr, scrolling_box &dom.Node) dom.ScrollMarginData {
	element := if scrolling_box.is_document() {
		scrolling_box.document().scrolling_element() or { return dom.ScrollMarginData{} }
	} else {
		scrolling_box.as_element() or { return dom.ScrollMarginData{} }
	}
	computed := computed_properties_for_element(element) or { return dom.ScrollMarginData{} }
	padding := computed.length_box(.scroll_padding_left, .scroll_padding_top, .scroll_padding_right, .scroll_padding_bottom, LengthPercentageOrAuto.make_auto())
	abstract_element := dom.AbstractElement.new(element, none)
	context := LengthResolutionContext.for_element(&abstract_element)
	viewport := scrolling_box.document().viewport_rect()
	return dom.ScrollMarginData{
		top: padding.top().to_px_or_zero(context, CSSPixels.nearest_value_for(viewport.height)).to_double()
		right: padding.right().to_px_or_zero(context, CSSPixels.nearest_value_for(viewport.width)).to_double()
		bottom: padding.bottom().to_px_or_zero(context, CSSPixels.nearest_value_for(viewport.height)).to_double()
		left: padding.left().to_px_or_zero(context, CSSPixels.nearest_value_for(viewport.width)).to_double()
	}
}

fn install_document_scroll_style_hook(document &dom.Document) {
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.set_scroll_style_hook(dom.DocumentScrollStyleHook{
		target: voidptr(document)
		scroll_margin: document_scroll_margin_callback
		scroll_padding: document_scroll_padding_callback
	})
}

fn style_computer_document_timeline_update_callback(target voidptr, timestamp f64) {
	mut style_computer := unsafe { &StyleComputer(target) }
	style_computer.set_animation_time_ms(timestamp)
	if style_computer.css_animation_storage_ != unsafe { nil } {
		for entry in style_computer.css_animation_storage_.entries {
			mut animation := unsafe { &CSSAnimation(entry.animation) }
			_ = animation.sample_at(style_computer.animation_time_ms_)
			mut document := unsafe { &dom.Document(style_computer.document_) }
			document.dispatch_events_for_animation_if_necessary(&animation.Animation)
		}
	}
	if style_computer.css_transition_storage_ != unsafe { nil } {
		for _, bucket in style_computer.css_transition_storage_.associated_transitions {
			for entry in bucket.entries {
				mut transition := unsafe { &CSSTransition(entry.transition) }
				_ = transition.sample_at(style_computer.animation_time_ms_)
				mut document := unsafe { &dom.Document(style_computer.document_) }
				document.dispatch_events_for_animation_if_necessary(&transition.Animation)
			}
		}
	}
}

fn required_style_invalidation_to_dom(invalidation RequiredInvalidationAfterStyleChange) dom.RequiredInvalidationAfterStyleChange {
	return dom.RequiredInvalidationAfterStyleChange{
		relayout: invalidation.needs_relayout()
		rebuild_layout_tree: invalidation.needs_layout_tree_rebuild()
		repaint: invalidation.needs_repaint()
		rebuild_stacking_context_tree: invalidation.needs_stacking_context_tree_rebuild()
		rebuild_accumulated_visual_contexts: invalidation.accumulated_visual_contexts() == .rebuild
		recompute_descendant_styles: invalidation.recompute_descendant_styles
		invalidates_hit_test_display_list: invalidation.invalidates_hit_test_display_list()
	}
}

fn style_computer_recompute_style_callback(target voidptr, element &dom.Element) dom.RequiredInvalidationAfterStyleChange {
	style_computer := unsafe { &StyleComputer(target) }
	mut abstract_element := dom.AbstractElement.new(element, none)
	mut did_change_custom_properties := false
	invalidation, _ := style_computer.recompute_style_with_invalidation(mut abstract_element, &did_change_custom_properties)
	return required_style_invalidation_to_dom(invalidation)
}

fn style_computer_recompute_inherited_style_callback(target voidptr, element &dom.Element) dom.RequiredInvalidationAfterStyleChange {
	style_computer := unsafe { &StyleComputer(target) }
	mut abstract_element := dom.AbstractElement.new(element, none)
	return required_style_invalidation_to_dom(style_computer.recompute_inherited_style_with_invalidation(mut abstract_element))
}

// The DOM->CSS callback DOM::Document.update_style() invokes: run the CSS style pass (recompute_style_for_subtree)
// over the document's element tree. `target` is the &dom.Document passed at install time.
fn document_style_update_callback(target voidptr) dom.RequiredInvalidationAfterStyleChange {
	document := unsafe { &dom.Document(target) }
	invalidation := update_style_for_document_from_upstream(document)
	return dom.RequiredInvalidationAfterStyleChange{
		relayout: invalidation.needs_relayout()
		rebuild_layout_tree: invalidation.needs_layout_tree_rebuild()
		repaint: invalidation.needs_repaint()
		rebuild_stacking_context_tree: invalidation.needs_stacking_context_tree_rebuild()
		rebuild_accumulated_visual_contexts: invalidation.accumulated_visual_contexts() == .rebuild
		recompute_descendant_styles: invalidation.recompute_descendant_styles
		invalidates_hit_test_display_list: invalidation.invalidates_hit_test_display_list()
	}
}

fn selector_pseudo_class_from_dom(pseudo_class dom.PseudoClass) ?PseudoClass {
	return match pseudo_class {
		.hover { PseudoClass.hover }
		.active { PseudoClass.active }
		.focus { PseudoClass.focus }
		.focus_within { PseudoClass.focus_within }
		.focus_visible { PseudoClass.focus_visible }
		.target { PseudoClass.target }
		.visited { PseudoClass.visited }
		.link { PseudoClass.link }
	}
}

$if test {
	fn selector_matches_pseudo_class_invalidation_candidate(selector Selector, element &dom.Element) bool {
		mut context := MatchContext{}
		return selector_matches_pseudo_class_invalidation_candidate_with_context(selector, element, mut context)
	}
}

fn selector_matches_pseudo_class_invalidation_candidate_with_context(selector Selector, element &dom.Element, mut context MatchContext) bool {
	target_pseudo := selector.pseudo_element() or {
		return matches(selector, element, none, mut context, none, none, .normal, none)
	}
	return match target_pseudo.type_ {
		.before {
			matches(selector, element, none, mut context, .before, none, .normal, none)
		}
		.after {
			matches(selector, element, none, mut context, .after, none, .normal, none)
		}
		else { false }
	}
}

struct PseudoClassInvalidationContexts {
mut:
	before MatchContext = MatchContext{has_result_cache: unsafe { nil }}
	after MatchContext = MatchContext{has_result_cache: unsafe { nil }}
}

fn pseudo_class_rule_matches_element(style_computer &StyleComputer, element &dom.Element, rule &MatchingRule, cache &HasResultCache, mut context MatchContext) bool {
	selector := rule.selector
	if selector.can_use_ancestor_filter()
		&& style_computer.should_reject_with_ancestor_filter(selector) {
		return false
	}

	// A rule's traversal flags and subject must not leak into the next rule.
	// The relational cache alone is shared within this old/new document state.
	context = MatchContext{has_result_cache: unsafe { &HasResultCache(cache) }}
	return selector_matches_pseudo_class_invalidation_candidate_with_context(selector, element, mut context)
}

fn pseudo_class_matches_different_rule_set_after_state_change(document &dom.Document, pseudo_class dom.PseudoClass, new_node ?&dom.Node, element &dom.Element, rules &RuleCache, style_computer &StyleComputer, before_cache &HasResultCache, after_cache &HasResultCache, mut contexts PseudoClassInvalidationContexts) bool {
	abstract_element := dom.AbstractElement.new(element, none)
	old_node := document.pseudo_class_state_node(pseudo_class)
	mut iterator := rule_bucket_iterator(rules, abstract_element)
	for {
		bucket := iterator.next() or { break }
		for rule in bucket {
			before := pseudo_class_rule_matches_element(style_computer, element, rule, before_cache, mut contexts.before)
			mut mutable_document := unsafe { &dom.Document(document) }
			mutable_document.set_pseudo_class_state_without_invalidation(pseudo_class, new_node)
			after := pseudo_class_rule_matches_element(style_computer, element, rule, after_cache, mut contexts.after)
			mutable_document.set_pseudo_class_state_without_invalidation(pseudo_class, old_node)
			if before != after {
				return true
			}
		}
	}
	return false
}

fn invalidate_elements_affected_by_pseudo_class_recursively(document &dom.Document, pseudo_class dom.PseudoClass, new_node ?&dom.Node, node &dom.Node, rules &RuleCache, style_computer &StyleComputer, before_cache &HasResultCache, after_cache &HasResultCache, mut contexts PseudoClassInvalidationContexts) {
	mut element_for_pop := ?&dom.Element(none)
	if element := node.as_element() {
		mut mutable_style_computer := unsafe { &StyleComputer(style_computer) }
		mutable_style_computer.push_ancestor(element)
		element_for_pop = element
		if element.affected_by_pseudo_class(pseudo_class)
			&& pseudo_class_matches_different_rule_set_after_state_change(document, pseudo_class, new_node, element, rules, style_computer, before_cache, after_cache, mut contexts) {
			mut mutable_element := unsafe { &dom.Element(element) }
			mutable_element.set_needs_style_update(true)
		}
	}

	for child := node.first_child(); child != none; {
		current := child or { break }
		invalidate_elements_affected_by_pseudo_class_recursively(document, pseudo_class, new_node, current, rules, style_computer, before_cache, after_cache, mut contexts)
		child = current.next_sibling()
	}

	if element := element_for_pop {
		mut mutable_style_computer := unsafe { &StyleComputer(style_computer) }
		mutable_style_computer.pop_ancestor(element)
	}
}

fn document_pseudo_class_invalidation_callback(target voidptr, pseudo_class dom.PseudoClass, common_ancestor &dom.Node, new_node ?&dom.Node) {
	document := unsafe { &dom.Document(target) }
	selector_pseudo_class := selector_pseudo_class_from_dom(pseudo_class) or { return }
	root := common_ancestor.root()
	shadow_root := root.as_shadow_root()
	scope := if concrete_shadow_root := shadow_root {
		css_style_scope_for_shadow_root(concrete_shadow_root)
	} else {
		css_style_scope_for_document(document)
	}
	rules := scope.get_pseudo_class_rule_cache(selector_pseudo_class) or { return }
	style_computer := css_style_computer_for(document)

	// Seed the ancestor bloom filter above the subtree root, exactly as
	// Document.cpp does for ancestor-dependent selectors.
	mut ancestor := common_ancestor.parent()
	for ancestor != none {
		current := ancestor or { break }
		if element := current.as_element() {
			mut mutable_style_computer := unsafe { &StyleComputer(style_computer) }
			mutable_style_computer.push_ancestor(element)
		}
		ancestor = current.parent()
	}

	// Every candidate observes the same old and new pseudo-class states. Reuse
	// relational results within each state, keeping the two caches separate so
	// :has(:hover), :has(:focus), etc. cannot reuse a result across the change.
	before_cache := &HasResultCache{}
	after_cache := &HasResultCache{}
	mut contexts := PseudoClassInvalidationContexts{}
	invalidate_elements_affected_by_pseudo_class_recursively(document, pseudo_class, new_node, common_ancestor, rules, style_computer, before_cache, after_cache, mut contexts)

	ancestor = common_ancestor.parent()
	for ancestor != none {
		current := ancestor or { break }
		if element := current.as_element() {
			mut mutable_style_computer := unsafe { &StyleComputer(style_computer) }
			mutable_style_computer.pop_ancestor(element)
		}
		ancestor = current.parent()
	}
}

// Register the CSS style pass as DOM::Document.update_style()'s hook, so a plain doc.update_style() call
// styles the whole tree. (dom cannot import css, so it calls back through this fn(voidptr), following the
// same pattern as the CSSMediaQueryList registrations.)
pub fn install_document_style_hook(document &dom.Document) {
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.set_style_update_hook(dom.DocumentStyleUpdateHook{
		target: voidptr(document)
		callback: document_style_update_callback
		invalidate_for_pseudo_class: document_pseudo_class_invalidation_callback
		invalidate_size_dependents: document_size_query_invalidation_callback
		evaluate_media_rules: document_evaluate_media_rules_callback
		get_style_sheet_source: document_get_style_sheet_source_callback
	})
}

// Return the CSS scope stored behind a DOM scope. DOM cannot import CSS, so it
// owns only the address-stable handle and callbacks; the translated StyleScope
// itself remains owned by this module.
fn css_style_scope_from_dom(mut dom_scope dom.StyleScope, node &dom.Node) &StyleScope {
	if dom_scope.css_handle != unsafe { nil } {
		return unsafe { &StyleScope(dom_scope.css_handle) }
	}
	scope := StyleScope.new(node)
	dom_scope.css_handle = voidptr(scope)
	dom_scope.may_have_has_selectors_callback = style_scope_may_have_has_selectors_callback
	dom_scope.may_have_sibling_has_callback = style_scope_may_have_sibling_has_selectors_callback
	dom_scope.have_local_link_selectors_callback = style_scope_have_local_link_selectors_callback
	dom_scope.subtree_may_affect_has_callback = style_scope_subtree_may_affect_has_callback
	dom_scope.pending_has_covers_child_list = style_scope_pending_has_invalidation_covers_child_list_callback
	dom_scope.has_featureless_sensitive_callback = style_scope_has_featureless_sensitive_has_selectors_callback
	dom_scope.record_has_mutation_callback = style_scope_record_has_mutation_callback
	dom_scope.record_has_properties_callback = style_scope_record_has_mutation_properties_callback
	dom_scope.record_conservative_has_callback = style_scope_record_conservative_has_invalidation_callback
	dom_scope.schedule_has_invalidation_callback = style_scope_schedule_has_invalidation_callback
	dom_scope.invalidate_user_style_callback = style_scope_invalidate_user_style_callback
	return scope
}

// The persistent css.StyleScope for `abstract_element`'s document/shadow root: created on first use and
// cached on the DOM-side dom.StyleScope placeholder via its handle, so repeated style computations share
// one scope (and its rule cache), as in Ladybird where the scope is owned by the Document/ShadowRoot.
fn css_style_scope_for(abstract_element dom.AbstractElement) &StyleScope {
	mut dom_scope := abstract_element.style_scope()
	root := abstract_element.element().as_node().root()
	if shadow_root := root.as_shadow_root() {
		if !shadow_root.uses_document_style_sheets() {
			return css_style_scope_from_dom(mut dom_scope, root)
		}
	}
	return css_style_scope_from_dom(mut dom_scope, unsafe { &dom.Node(root.document()) })
}

pub fn style_scope_for_abstract_element(abstract_element dom.AbstractElement) &StyleScope {
	return css_style_scope_for(abstract_element)
}

fn css_style_scope_for_document(document &dom.Document) &StyleScope {
	mut dom_scope := unsafe { document.style_scope() }
	return css_style_scope_from_dom(mut dom_scope, unsafe { &dom.Node(document) })
}

fn css_style_scope_for_shadow_root(shadow_root &dom.ShadowRoot) &StyleScope {
	if shadow_root.uses_document_style_sheets() {
		return css_style_scope_for_document(shadow_root.document())
	}
	mut dom_scope := unsafe { shadow_root.style_scope() }
	return css_style_scope_from_dom(mut dom_scope, unsafe { &dom.Node(shadow_root) })
}

fn css_style_scope_for_node(node &dom.Node) &StyleScope {
	mut dom_scope := node.style_scope()
	root := node.root()
	if shadow_root := root.as_shadow_root() {
		if !shadow_root.uses_document_style_sheets() {
			return css_style_scope_from_dom(mut dom_scope, root)
		}
	}
	return css_style_scope_from_dom(mut dom_scope, unsafe { &dom.Node(root.document()) })
}

pub fn style_scope_for_dom_node(node &dom.Node) &StyleScope {
	return css_style_scope_for_node(node)
}

fn invalidate_css_style_scope_for_node(node &dom.Node) {
	mut scope := css_style_scope_for_node(node)
	scope.invalidate_rule_cache()
}
