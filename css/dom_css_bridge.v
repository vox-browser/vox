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

// Wrap a css.ComputedProperties into a DOM placeholder carrying a handle back to it.
// FIXME: also mirror the concrete layout-facing fields (display/overflow/visibility/opacity/font-weight/
// math) so DOM/layout code that reads them directly off the placeholder stays correct. For now only the
// handle is populated, which is what the CSS pipeline (parent inheritance, round-trip) needs.
fn computed_properties_to_dom(computed &ComputedProperties) &dom.CSSComputedProperties_ {
	return &dom.CSSComputedProperties_{
		css_handle: voidptr(computed)
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
