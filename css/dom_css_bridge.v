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
		display_:            dom.CSSDisplay_{
			is_none_:      display.is_none()
			is_list_item_: display.is_list_item()
		}
		overflow_x_:         overflow_to_dom(computed.overflow_x())
		overflow_y_:         overflow_to_dom(computed.overflow_y())
		content_visibility_: content_visibility_to_dom(computed.content_visibility())
		opacity_:            computed.opacity()
		visibility_:         visibility_to_dom(computed.visibility())
		font_weight_:        computed.font_weight()
		math_depth_:         computed.math_depth()
		math_style_:         math_style_to_dom(computed.math_style())
		css_handle:          voidptr(computed)
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

// --- Document style-update hook ---

// The DOM->CSS callback DOM::Document.update_style() invokes: run the CSS style pass (recompute_style_for_subtree)
// over the document's element tree. `target` is the &dom.Document passed at install time.
fn document_style_update_callback(target voidptr) {
	document := unsafe { &dom.Document(target) }
	root_element := document.document_element() or { return }
	mut style_computer := StyleComputer.new(document)
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

// The persistent css.StyleScope for `abstract_element`'s document/shadow root: created on first use and
// cached on the DOM-side dom.StyleScope placeholder via its handle, so repeated style computations share
// one scope (and its rule cache), as in Ladybird where the scope is owned by the Document/ShadowRoot.
fn css_style_scope_for(abstract_element dom.AbstractElement) &StyleScope {
	mut dom_scope := abstract_element.style_scope()
	if dom_scope.css_handle != unsafe { nil } {
		return unsafe { &StyleScope(dom_scope.css_handle) }
	}
	mut element := abstract_element.element()
	node := element.as_node()
	scope := StyleScope.new(node)
	dom_scope.css_handle = voidptr(scope)
	return scope
}
