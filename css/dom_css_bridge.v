module css

import dom
import os

// dom <-> css bridge
// ==================
// The DOM module cannot import css (css already imports dom; the reverse would be a module cycle). So the
// DOM stores this port's real style objects (css.ComputedProperties / css.CascadedProperties /
// css.StyleScope) as opaque `voidptr` handles embedded in placeholder structs (dom.CSSComputedProperties_,
// dom.CSSCascadedProperties_, dom.StyleScope). These helpers wrap a css object into its DOM placeholder
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
	return &dom.CSSComputedProperties_{
		display_:                        dom.CSSDisplay_{
			is_none_:           display.is_none()
			is_list_item_:      display.is_list_item()
			is_contents_:       display.is_contents()
			is_inline_outside_: display.is_inline_outside()
			is_flow_inside_:    display.is_flow_inside()
			is_flow_root_inside_: display.is_flow_root_inside()
			is_flex_inside_:    display.is_flex_inside()
			is_grid_inside_:    display.is_grid_inside()
			is_table_inside_:   display.is_table_inside()
			is_math_inside_:    display.is_math_inside()
			is_ruby_inside_:    display.is_ruby_inside()
			is_block_outside_:  display.is_block_outside()
			is_table_caption_:  display.is_table_caption()
			is_table_cell_:     display.is_table_cell()
			is_table_row_:      display.is_table_row()
			is_table_row_group_: display.is_table_row_group()
			is_table_header_group_: display.is_table_header_group()
			is_table_footer_group_: display.is_table_footer_group()
			is_table_column_: display.is_table_column()
			is_table_column_group_: display.is_table_column_group()
		}
		overflow_x_:                     overflow_to_dom(computed.overflow_x())
		overflow_y_:                     overflow_to_dom(computed.overflow_y())
		content_visibility_:             content_visibility_to_dom(computed.content_visibility())
		opacity_:                        computed.opacity()
		visibility_:                     visibility_to_dom(computed.visibility())
		font_weight_:                    computed.font_weight()
		math_depth_:                     computed.math_depth()
		math_style_:                     math_style_to_dom(computed.math_style())
		view_transition_name_:           computed.view_transition_name()
		attempted_pseudo_class_matches_: attempted_pseudo_class_matches_to_dom(computed)
		css_handle:                      voidptr(computed)
	}
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

// --- CascadedProperties ---

fn cascaded_properties_to_dom(cascaded &CascadedProperties) &dom.CSSCascadedProperties_ {
	return &dom.CSSCascadedProperties_{
		css_handle: voidptr(cascaded)
	}
}

fn cascaded_properties_from_dom(placeholder &dom.CSSCascadedProperties_) ?&CascadedProperties {
	if placeholder.css_handle == unsafe { nil } {
		return none
	}
	return unsafe { &CascadedProperties(placeholder.css_handle) }
}

// --- StyleScope ---

// --- Author stylesheets ---

// A minimal css-side holder for a document's author stylesheets, cached on the document via an opaque
// handle. Deliberately NOT css.StyleSheetList: using that type's full method surface (add_a_css_style_sheet
// -> media evaluation, style invalidation, attribute code) drags in many `?string ==` comparisons that
// trip a V codegen bug. This holder only needs to store + iterate the parsed sheets for rule matching.
@[heap]
struct DocumentAuthorStyleSheets {
mut:
	// Sheets installed explicitly by CSS-aware callers (link-sheet
	// equivalents in this port). Constructed adopted sheets have their own
	// observable list and are iterated after the document's ordinary sheets.
	sheets []&CSSStyleSheet
	// Sheets backed by <style> elements are kept separately so rebuilding the
	// DOM-derived list neither duplicates them on every layout nor discards
	// explicitly installed sheets.
	embedded_sheets  []&CSSStyleSheet
	embedded_sources []string
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
		.pseudo_class { InvalidationProperty.pseudo_class(pseudo_class_from_name(property.pseudo_class_name)) }
	}
}

fn invalidation_property_to_dom(property InvalidationProperty) dom.InvalidationProperty {
	return dom.InvalidationProperty{
		type_:             match property.type_ {
			.invalidate_self { dom.InvalidationPropertyType.invalidate_self }
			.invalidate_whole_subtree { dom.InvalidationPropertyType.invalidate_whole_subtree }
			.class { dom.InvalidationPropertyType.class }
			.id { dom.InvalidationPropertyType.id }
			.tag_name { dom.InvalidationPropertyType.tag_name }
			.attribute { dom.InvalidationPropertyType.attribute }
			.pseudo_class { dom.InvalidationPropertyType.pseudo_class }
		}
		name:              property.name()
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
			payload:   invalidation_plan_to_dom(rule.payload)
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
			reach:     match rule.reach {
				.adjacent { dom.SiblingInvalidationReach.adjacent }
				.subsequent { dom.SiblingInvalidationReach.subsequent }
			}
			payload:   invalidation_plan_to_dom(rule.payload)
		}
	}
	return dom.InvalidationPlan{
		invalidate_self:          plan.invalidate_self
		invalidate_whole_subtree: plan.invalidate_whole_subtree
		descendant_rules:         descendant_rules
		sibling_rules:            sibling_rules
	}
}

fn style_computer_invalidation_property_used_in_has_callback(target voidptr, property dom.InvalidationProperty, dom_scope &dom.StyleScope) bool {
	if dom_scope.css_handle == unsafe { nil } {
		return false
	}
	style_computer := unsafe { &StyleComputer(target) }
	scope := unsafe { &StyleScope(dom_scope.css_handle) }
	return style_computer.invalidation_property_used_in_has_selector(invalidation_property_from_dom(property),
		scope)
}

fn style_computer_invalidation_plan_callback(target voidptr, properties []dom.InvalidationProperty, dom_scope &dom.StyleScope) dom.InvalidationPlan {
	if dom_scope.css_handle == unsafe { nil } {
		return dom.InvalidationPlan{}
	}
	style_computer := unsafe { &StyleComputer(target) }
	scope := unsafe { &StyleScope(dom_scope.css_handle) }
	css_properties := properties.map(invalidation_property_from_dom(it))
	return invalidation_plan_to_dom(style_computer.invalidation_plan_for_properties(css_properties,
		scope))
}

fn style_scope_may_have_has_selectors_callback(target voidptr) bool {
	scope := unsafe { &StyleScope(target) }
	return scope.may_have_has_selectors()
}

fn style_scope_schedule_has_invalidation_callback(target voidptr, node &dom.Node) {
	mut scope := unsafe { &StyleScope(target) }
	scope.schedule_ancestors_style_invalidation_due_to_presence_of_has(node)
}

fn document_theme_color_parse_callback(target voidptr, value string) ?string {
	_ = target
	color := parse_color_string(value) or { return none }
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
	holder := css_author_style_sheets_for(document)
	sheet := parse_css_stylesheet_with_parser(css_text, none)
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

fn load_local_imported_stylesheets(document &dom.Document, mut sheet CSSStyleSheet, location string, mut active_urls map[string]bool) {
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
		css_text, resolved_url := read_local_stylesheet(import_rule.url, location) or { continue }
		if active_urls[resolved_url] {
			continue
		}
		active_urls[resolved_url] = true
		mut imported_sheet := parse_css_stylesheet_with_parser(css_text, resolved_url)
		imported_sheet.set_parent_css_style_sheet(sheet)
		load_local_imported_stylesheets(document, mut imported_sheet, resolved_url, mut active_urls)
		imported_sheet.evaluate_media_queries(document)
		import_rule.set_style_sheet(imported_sheet)
		active_urls.delete(resolved_url)
	}
}

fn sync_shadow_root_style_sheets(document &dom.Document, shadow_root &dom.ShadowRoot) {
	mut scope := css_style_scope_for_shadow_root(shadow_root)
	scope.author_style_sheets.clear()
	location := document.base_url().to_string()
	root := unsafe { &dom.Node(shadow_root) }
	for style_element in query_selector_all(root, 'style') {
		type_ := style_element.get_attribute_value('type').trim_space().to_lower()
		if type_.len > 0 && type_ != 'text/css' {
			continue
		}
		mut sheet := parse_css_stylesheet_with_parser(style_element.as_node().text_content() or {
			''
		}, location)
		mut active_urls := map[string]bool{}
		active_urls[location] = true
		load_local_imported_stylesheets(document, mut sheet, location, mut active_urls)
		sheet.evaluate_media_queries(document)
		scope.author_style_sheets << sheet
	}
	scope.invalidate_rule_cache()
	for element in query_selector_all(root, '*') {
		if nested_root := element.shadow_root() {
			sync_shadow_root_style_sheets(document, nested_root)
		}
	}
}

fn sync_shadow_style_sheets_in_subtree(document &dom.Document, node &dom.Node) {
	if element := node.as_element() {
		if shadow_root := element.shadow_root() {
			sync_shadow_root_style_sheets(document, shadow_root)
		}
	}
	for child in node.children_as_vector() {
		sync_shadow_style_sheets_in_subtree(document, child)
	}
}

// CSSOM's "add a CSS style sheet" steps select one preferred titled set.
// Untitled persistent sheets stay active, while an alternate sheet is disabled
// until its title is the selected set. The local-file bridge has no separate
// StyleSheetList object to perform those steps, so preserve the same decision
// while collecting DOM-owned sheets.
fn document_style_sheet_is_active(title string, is_alternate bool, disabled bool,
	preferred_title string) (bool, string) {
	if disabled {
		return false, preferred_title
	}
	mut preferred := preferred_title
	if title != '' && !is_alternate && preferred == '' {
		preferred = title
	}
	if title == '' {
		return !is_alternate, preferred
	}
	return preferred != '' && title.to_lower() == preferred.to_lower(), preferred
}

// Synchronize the document's CSS-owned author-sheet list with its <style>
// elements. The HTML module cannot construct CSSStyleSheet objects without an
// import cycle, so this is the module boundary corresponding to
// HTMLStyleElement::update_a_style_block in LibWeb.
pub fn sync_document_style_elements(document &dom.Document) {
	root := unsafe { &dom.Node(document) }
	sync_shadow_style_sheets_in_subtree(document, root)
	base_url := document.base_url().to_string()
	mut style_sources := []DocumentStyleSource{}
	mut preferred_title := ''
	for element in query_selector_all(root, '*') {
		if element.local_name() == 'style' {
			type_ := element.get_attribute_value('type').trim_space().to_lower()
			if type_.len > 0 && type_ != 'text/css' {
				continue
			}
			active, selected_title := document_style_sheet_is_active(element.get_attribute_value('title'),
				false, false, preferred_title)
			preferred_title = selected_title
			if !active {
				continue
			}
			css_text := element.as_node().text_content() or { '' }
			declared_location := element.get_attribute_value('data-libweb-v-source-url')
			style_location := if declared_location == '' { base_url } else { declared_location }
			style_sources << DocumentStyleSource{
				cache_key: 'style:${style_location}:${css_text}'
				css_text: css_text
				location: style_location
				media: element.get_attribute_value('media')
			}
		} else if element.local_name() == 'link' {
			relations := element.get_attribute_value('rel').to_lower().fields()
			if 'stylesheet' !in relations {
				continue
			}
			active, selected_title := document_style_sheet_is_active(element.get_attribute_value('title'),
				'alternate' in relations, element.has_attribute('disabled'), preferred_title)
			preferred_title = selected_title
			if !active {
				continue
			}
			href := element.get_attribute_value('href')
			css_text, resolved_url := read_local_stylesheet(href, base_url) or { continue }
			style_sources << DocumentStyleSource{
				cache_key: 'link:${resolved_url}:${css_text}'
				css_text:  css_text
				location:  resolved_url
				media:     element.get_attribute_value('media')
			}
		}
	}
	sources := style_sources.map(it.cache_key)

	holder := css_author_style_sheets_for(document)
	if holder.embedded_sources == sources {
		mut media_changed := false
		for sheet in holder.embedded_sheets {
			mut mutable_sheet := unsafe { &CSSStyleSheet(sheet) }
			if mutable_sheet.evaluate_media_queries(document) {
				media_changed = true
			}
		}
		if media_changed {
			mut scope := css_style_scope_for_document(document)
			scope.invalidate_rule_cache()
		}
		return
	}
	mut parsed := []&CSSStyleSheet{cap: style_sources.len}
	for source in style_sources {
		mut sheet := parse_css_stylesheet_with_parser(source.css_text, source.location)
		if source.media.trim_space().len > 0 {
			sheet.set_media(source.media)
		}
		mut active_urls := map[string]bool{}
		active_urls[source.location] = true
		load_local_imported_stylesheets(document, mut sheet, source.location, mut active_urls)
		sheet.evaluate_media_queries(document)
		if os.getenv('LIBWEB_V_CSS_DUMP') == '1' {
			for rule in sheet.css_rules().rules {
				eprintln(rule.dump(0))
			}
		}
		parsed << sheet
	}
	style_computer := css_style_computer_for(document)
	mut font_computer := unsafe { &FontComputer(style_computer.font_computer_) }
	for old_sheet in holder.embedded_sheets {
		font_computer.unload_fonts_from_css_rules(old_sheet.css_rules().rules)
	}
	for new_sheet in parsed {
		font_computer.load_fonts_from_css_rules(new_sheet.css_rules().rules,
			style_computer.font_face_set_)
	}
	unsafe {
		holder.embedded_sources = sources.clone()
		holder.embedded_sheets = parsed
	}
	mut scope := css_style_scope_for_document(document)
	scope.invalidate_rule_cache()
}

// DOM::Document::evaluate_media_rules(). CSSStyleSheet is CSS-owned in the V
// module graph, so the translated algorithm lives at this bridge rather than
// in dom.Document.
fn evaluate_media_rules_for_document(document &dom.Document) {
	mut any_media_queries_changed_match_state := false
	changed_ptr := &any_media_queries_changed_match_state
	mut document_scope := css_style_scope_for_document(document)
	for sheet in document_scope.stylesheets_for_cascade_origin(.author) {
		mut mutable_sheet := unsafe { &CSSStyleSheet(sheet) }
		if mutable_sheet.evaluate_media_queries(document) {
			any_media_queries_changed_match_state = true
		}
	}

	root := unsafe { &dom.Node(document) }
	root.for_each_shadow_including_inclusive_descendant(fn [document, changed_ptr] (node &dom.Node) dom.TraversalDecision {
		if shadow_root := node.as_shadow_root() {
			mut scope := css_style_scope_for_shadow_root(shadow_root)
			for sheet in scope.stylesheets_for_cascade_origin(.author) {
				mut mutable_sheet := unsafe { &CSSStyleSheet(sheet) }
				if mutable_sheet.evaluate_media_queries(document) {
					unsafe {
						*changed_ptr = true
					}
				}
			}
		}
		return .@continue
	})

	if !any_media_queries_changed_match_state {
		return
	}
	document_scope.invalidate_rule_cache()
	root.for_each_shadow_including_inclusive_descendant(fn (node &dom.Node) dom.TraversalDecision {
		if shadow_root := node.as_shadow_root() {
			mut scope := css_style_scope_for_shadow_root(shadow_root)
			scope.invalidate_rule_cache()
		}
		return .@continue
	})
	mut mutable_document := unsafe { &dom.Document(document) }
	mut document_node := unsafe { &dom.Node(mutable_document) }
	document_node.invalidate_style(.media_query_changed_match_state)
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
		if loaded_style_sheet := import_rule.loaded_style_sheet {
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
			for sheet in holder.embedded_sheets {
				if found := find_style_sheet_with_url(url, sheet) {
					return found.source_text()
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
	scope.author_style_sheets << parse_css_stylesheet_with_parser(css_text, none)
	scope.invalidate_rule_cache()
}

// Set the page-level user stylesheet used by the user cascade origin.
pub fn set_document_user_style_sheet(document &dom.Document, css_text string) {
	mut scope := css_style_scope_for_document(document)
	scope.user_style_source = css_text
	scope.invalidate_rule_cache()
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
		return unsafe { &StyleComputer(dom_style_computer.css_handle) }
	}
	style_computer := StyleComputer.new(document)
	mutable_document.set_css_animation_timeline_update_hook(dom.DocumentCSSAnimationTimelineUpdateHook{
		target:   voidptr(style_computer)
		callback: style_computer_document_timeline_update_callback
	})
	mutable_document.set_css_animation_event_hook(dom.DocumentCSSAnimationEventHook{
		target:   voidptr(style_computer)
		dispatch: style_computer_dispatch_css_animation_event
	})
	mutable_document.style_computer = &dom.StyleComputer{
		css_handle:                                 voidptr(style_computer)
		invalidation_property_used_in_has_callback: style_computer_invalidation_property_used_in_has_callback
		invalidation_plan_callback:                 style_computer_invalidation_plan_callback
		recompute_style_callback:                   style_computer_recompute_style_callback
		recompute_inherited_style_callback:         style_computer_recompute_inherited_style_callback
		update_animated_style_callback:             style_computer_update_animated_style_callback
		build_registered_properties_cache_callback: style_computer_build_registered_properties_cache_callback
		build_counter_style_cache_callback:         style_computer_build_counter_style_cache_callback
	}
	mutable_document.set_theme_color_hook(dom.DocumentThemeColorHook{
		target:        voidptr(document)
		parse_color:   document_theme_color_parse_callback
		media_matches: document_theme_color_media_matches_callback
	})
	install_document_background_style_hook(document)
	install_document_style_hook(document)
	return style_computer
}

fn document_background_layers_callback(_ voidptr, element &dom.Element) ?[]dom.BackgroundLayerData {
	computed := computed_properties_for_element(element) or { return none }
	layers := computed.background_layers()
	mut result := []dom.BackgroundLayerData{cap: layers.len}
	for index, _ in layers {
		result << dom.BackgroundLayerData{
			computed_properties_handle: voidptr(computed)
			layer_index:                index
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
		target:                     voidptr(document)
		background_color:           document_background_color_callback
		background_layers:          document_background_layers_callback
		background_image_rendering: document_background_image_rendering_callback
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
	}
}

fn style_computer_recompute_style_callback(target voidptr, element &dom.Element) dom.RequiredInvalidationAfterStyleChange {
	style_computer := unsafe { &StyleComputer(target) }
	mut abstract_element := dom.AbstractElement.new(element, none)
	mut did_change_custom_properties := false
	invalidation, _ := style_computer.recompute_style_with_invalidation(mut abstract_element,
		&did_change_custom_properties)
	return required_style_invalidation_to_dom(invalidation)
}

fn style_computer_recompute_inherited_style_callback(target voidptr, element &dom.Element) dom.RequiredInvalidationAfterStyleChange {
	style_computer := unsafe { &StyleComputer(target) }
	mut abstract_element := dom.AbstractElement.new(element, none)
	return required_style_invalidation_to_dom(style_computer.recompute_inherited_style_with_invalidation(mut
		abstract_element))
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

fn pseudo_class_rule_matches_element(style_computer &StyleComputer, element &dom.Element, rule &MatchingRule, shadow_root ?&dom.ShadowRoot) bool {
	rule_root := rule.shadow_root
	from_user_agent_or_user_stylesheet := rule.cascade_origin == .user_agent
		|| rule.cascade_origin == .user
	mut rule_is_relevant_for_current_scope := style_scope_optional_shadow_root_equal(rule_root,
		shadow_root)
	if element.is_shadow_host() {
		if element_shadow_root := element.shadow_root() {
			rule_is_relevant_for_current_scope = rule_is_relevant_for_current_scope
				|| style_scope_optional_shadow_root_equal(rule_root, element_shadow_root)
		}
	}
	rule_is_relevant_for_current_scope = rule_is_relevant_for_current_scope
		|| from_user_agent_or_user_stylesheet
	if !rule_is_relevant_for_current_scope {
		return false
	}

	selector := rule.selector
	if selector.can_use_ancestor_filter()
		&& style_computer.should_reject_with_ancestor_filter(selector) {
		return false
	}

	mut context := MatchContext{}
	if matches(selector, element, none, mut context, none, none, .normal, none) {
		return true
	}
	if element.has_pseudo_element(int(dom.PseudoElement.before))
		&& matches(selector, element, none, mut context, .before, none, .normal, none) {
		return true
	}
	if element.has_pseudo_element(int(dom.PseudoElement.after))
		&& matches(selector, element, none, mut context, .after, none, .normal, none) {
		return true
	}
	return false
}

fn pseudo_class_matches_different_rule_set_after_state_change(document &dom.Document, pseudo_class dom.PseudoClass, new_node ?&dom.Node, element &dom.Element, rules &RuleCache, shadow_root ?&dom.ShadowRoot, style_computer &StyleComputer) bool {
	abstract_element := dom.AbstractElement.new(element, none)
	old_node := document.pseudo_class_state_node(pseudo_class)
	for bucket in rules.matching_rule_buckets(abstract_element) {
		for rule in bucket {
			before := pseudo_class_rule_matches_element(style_computer, element, rule,
				shadow_root)
			mut mutable_document := unsafe { &dom.Document(document) }
			mutable_document.set_pseudo_class_state_without_invalidation(pseudo_class, new_node)
			after := pseudo_class_rule_matches_element(style_computer, element, rule,
				shadow_root)
			mutable_document.set_pseudo_class_state_without_invalidation(pseudo_class, old_node)
			if before != after {
				return true
			}
		}
	}
	return false
}

fn invalidate_elements_affected_by_pseudo_class_recursively(document &dom.Document, pseudo_class dom.PseudoClass, new_node ?&dom.Node, node &dom.Node, rules &RuleCache, shadow_root ?&dom.ShadowRoot, style_computer &StyleComputer) {
	mut element_for_pop := ?&dom.Element(none)
	if element := node.as_element() {
		mut mutable_style_computer := unsafe { &StyleComputer(style_computer) }
		mutable_style_computer.push_ancestor(element)
		element_for_pop = element
		if element.affected_by_pseudo_class(pseudo_class)
			&& pseudo_class_matches_different_rule_set_after_state_change(document,
				pseudo_class, new_node, element, rules, shadow_root, style_computer) {
			mut mutable_element := unsafe { &dom.Element(element) }
			mutable_element.set_needs_style_update(true)
		}
	}

	for child in node.children_as_vector() {
		invalidate_elements_affected_by_pseudo_class_recursively(document, pseudo_class,
			new_node, child, rules, shadow_root, style_computer)
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

	invalidate_elements_affected_by_pseudo_class_recursively(document, pseudo_class,
		new_node, common_ancestor, rules, shadow_root, style_computer)

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
		target:                      voidptr(document)
		callback:                    document_style_update_callback
		invalidate_for_pseudo_class: document_pseudo_class_invalidation_callback
		evaluate_media_rules:        document_evaluate_media_rules_callback
		get_style_sheet_source:      document_get_style_sheet_source_callback
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
	dom_scope.schedule_has_invalidation_callback = style_scope_schedule_has_invalidation_callback
	return scope
}

// The persistent css.StyleScope for `abstract_element`'s document/shadow root: created on first use and
// cached on the DOM-side dom.StyleScope placeholder via its handle, so repeated style computations share
// one scope (and its rule cache), as in Ladybird where the scope is owned by the Document/ShadowRoot.
fn css_style_scope_for(abstract_element dom.AbstractElement) &StyleScope {
	mut dom_scope := abstract_element.style_scope()
	return css_style_scope_from_dom(mut dom_scope, abstract_element.element().as_node())
}

fn css_style_scope_for_document(document &dom.Document) &StyleScope {
	mut dom_scope := document.style_scope()
	return css_style_scope_from_dom(mut dom_scope, unsafe { &dom.Node(document) })
}

fn css_style_scope_for_shadow_root(shadow_root &dom.ShadowRoot) &StyleScope {
	if shadow_root.uses_document_style_sheets() {
		return css_style_scope_for_document(shadow_root.document())
	}
	mut dom_scope := shadow_root.style_scope()
	return css_style_scope_from_dom(mut dom_scope, unsafe { &dom.Node(shadow_root) })
}

fn css_style_scope_for_node(node &dom.Node) &StyleScope {
	if shadow_root := node.as_shadow_root() {
		return css_style_scope_for_shadow_root(shadow_root)
	}
	return css_style_scope_for_document(node.document())
}

fn invalidate_css_style_scope_for_node(node &dom.Node) {
	mut scope := css_style_scope_for_node(node)
	scope.invalidate_rule_cache()
}
