module css

import dom

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
		}
		overflow_x_:                     overflow_to_dom(computed.overflow_x())
		overflow_y_:                     overflow_to_dom(computed.overflow_y())
		content_visibility_:             content_visibility_to_dom(computed.content_visibility())
		opacity_:                        computed.opacity()
		visibility_:                     visibility_to_dom(computed.visibility())
		font_weight_:                    computed.font_weight()
		math_depth_:                     computed.math_depth()
		math_style_:                     math_style_to_dom(computed.math_style())
		attempted_pseudo_class_matches_: computed.attempted_pseudo_class_matches()
		css_handle:                      voidptr(computed)
	}
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
	sheets []&CSSStyleSheet
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
		return unsafe { &StyleComputer(dom_style_computer.css_handle) }
	}
	style_computer := StyleComputer.new(document)
	mutable_document.style_computer = &dom.StyleComputer{
		css_handle:                                 voidptr(style_computer)
		invalidation_property_used_in_has_callback: style_computer_invalidation_property_used_in_has_callback
		invalidation_plan_callback:                 style_computer_invalidation_plan_callback
	}
	mutable_document.set_theme_color_hook(dom.DocumentThemeColorHook{
		target:        voidptr(document)
		parse_color:   document_theme_color_parse_callback
		media_matches: document_theme_color_media_matches_callback
	})
	install_document_style_hook(document)
	return style_computer
}

// The DOM->CSS callback DOM::Document.update_style() invokes: run the CSS style pass (recompute_style_for_subtree)
// over the document's element tree. `target` is the &dom.Document passed at install time.
fn document_style_update_callback(target voidptr) {
	document := unsafe { &dom.Document(target) }
	root_element := document.document_element() or { return }
	mut style_computer := css_style_computer_for(document)
	recompute_style_for_subtree(mut style_computer, root_element.as_node())
}

// Register the CSS style pass as DOM::Document.update_style()'s hook, so a plain doc.update_style() call
// styles the whole tree. (dom cannot import css, so it calls back through this fn(voidptr), following the
// same pattern as the CSSMediaQueryList registrations.)
pub fn install_document_style_hook(document &dom.Document) {
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.set_style_update_hook(dom.DocumentStyleUpdateHook{
		target:   voidptr(document)
		callback: document_style_update_callback
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
