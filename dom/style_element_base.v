// Copyright (c) 2023, Preston Taylor <PrestonLeeTaylor@proton.me>
// Copyright (c) 2025, Lorenz Ackermann <me@lorenzackermann.xyz>
// Copyright (c) 2026, Sam Atkins <sam@ladybird.org>
//
// SPDX-License-Identifier: BSD-2-Clause
//
// Translated from:
// - Libraries/LibWeb/DOM/StyleElementBase.cpp/.h
// - the StyleElementBase overrides of Libraries/LibWeb/HTML/HTMLStyleElement.cpp and
//   Libraries/LibWeb/SVG/SVGStyleElement.cpp

module dom

// CSS::StyleScope and CSS::StyleSheetState are CSS-owned. DOM cannot import CSS, so a style element holds its
// associated CSS style sheet as an opaque handle and reaches the StyleScope and StyleSheetState operations it
// needs through these hooks, which CSS installs.
pub struct StyleSheetScopeHooks {
pub:
	// StyleScope::create_a_css_style_sheet() for a style element's sheet: type text/css, alternate flag unset,
	// origin-clean flag set, and no parent CSS style sheet or owner CSS rule.
	create_a_css_style_sheet fn (scope &Node, css_text string, owner_node &Element, media string, title string, location ?string) voidptr = unsafe { nil }
	remove_a_css_style_sheet fn (scope &Node, sheet voidptr) = unsafe { nil }
	move_sheet               fn (scope &Node, sheet voidptr, destination &Node) = unsafe { nil }
	set_media                fn (sheet voidptr, media string) = unsafe { nil }
	evaluate_media_queries   fn (sheet voidptr, document &Document) bool = unsafe { nil }
	media_list_matches       fn (sheet voidptr) bool = unsafe { nil }
	disabled                 fn (sheet voidptr) bool = unsafe { nil }
	set_disabled             fn (sheet voidptr, disabled bool) = unsafe { nil }
	loading_state            fn (sheet voidptr) CSSStyleSheetLoadingState = unsafe { nil }
}

pub fn install_style_sheet_scope_hooks(hooks StyleSheetScopeHooks) {
	dom_style_sheet_scope_hooks = hooks
}

pub enum StyleElementUpdateSource {
	dynamic
	parser_pop
}

pub enum StyleElementAnyFailed {
	no
	yes
}

@[heap]
pub struct StyleElementBase {
mut:
	element_ &Element = unsafe { nil }

	parser_document_ ?&Document

	// https://www.w3.org/TR/cssom/#associated-css-style-sheet
	associated_css_style_sheet_ voidptr

	style_sheet_scope_ ?&Node

	document_load_event_delayer_ ?DocumentLoadEventDelayer

	style_sheet_update_generation_ u64

	associated_css_style_sheet_was_created_by_parser_                    bool
	associated_css_style_sheet_was_enabled_when_created_by_parser_       bool
	associated_css_style_sheet_media_matches_environment_                bool
	associated_css_style_sheet_load_is_pending_for_script_blocking_      bool
	associated_css_style_sheet_is_blocking_scripts_                      bool
	is_on_parser_stack_of_open_elements_                                 bool
}

// HTMLStyleElement and SVGStyleElement inherit StyleElementBase upstream. Both share Element's layout in V, so the
// mixin state hangs off Element and is created on first use.
pub fn (e &Element) is_style_element_base() bool {
	return e.local_name() == 'style' && (e.is_html_element() || e.is_svg_element())
}

pub fn (e &Element) style_element_base() ?&StyleElementBase {
	if !e.is_style_element_base() {
		return none
	}
	if base := e.style_element_base_ {
		return base
	}
	base := &StyleElementBase{
		element_: unsafe { &Element(e) }
	}
	mut mutable_element := unsafe { &Element(e) }
	mutable_element.style_element_base_ = base
	return base
}

pub fn (base &StyleElementBase) as_element() &Element {
	return base.element_
}

// NB: The HTML parser passes its Badge<HTMLParser> here upstream.
pub fn (mut base StyleElementBase) set_parser_document(document &Document) {
	base.parser_document_ = document
	base.is_on_parser_stack_of_open_elements_ = true
}

// The embedder's discarded resource-discovery tree preserves style text but
// does not create unused CSSOM owners. Actual document parsers use the normal
// pop hook below; non-scripted discovery also needs styles for image planning.
pub fn (mut base StyleElementBase) finish_resource_discovery_parsing() {
	base.is_on_parser_stack_of_open_elements_ = false
}

pub fn (mut base StyleElementBase) did_pop_off_parser_stack_of_open_elements() {
	base.is_on_parser_stack_of_open_elements_ = false
	base.update_a_style_block(.parser_pop)
}

pub fn (mut base StyleElementBase) update_a_style_block_for_dynamic_change() {
	if base.is_on_parser_stack_of_open_elements_ {
		return
	}
	base.update_a_style_block(.dynamic)
}

pub fn (mut base StyleElementBase) style_element_attribute_changed(name string, value ?string) {
	if name == 'media' {
		sheet := base.sheet()
		if sheet != unsafe { nil } {
			if dom_style_sheet_scope_hooks.set_media != unsafe { nil } {
				dom_style_sheet_scope_hooks.set_media(sheet, value or { '' })
			}
			base.associated_style_sheet_media_attribute_changed()
		}
	} else if name == 'type' {
		base.update_a_style_block_for_dynamic_change()
	}
}

pub fn (mut base StyleElementBase) style_element_moved() {
	if base.associated_css_style_sheet_ == unsafe { nil } {
		return
	}

	scope := base.style_sheet_scope_ or { panic('StyleElementBase: sheet without a style sheet scope') }
	destination := base.as_element().as_node().document_or_shadow_root_style_scope_node()
	if dom_style_sheet_scope_hooks.move_sheet != unsafe { nil } {
		dom_style_sheet_scope_hooks.move_sheet(scope, base.associated_css_style_sheet_, destination)
	}
	base.style_sheet_scope_ = destination
}

// The user agent must run the "update a style block" algorithm whenever one of the following conditions occur:
// The element is popped off the stack of open elements of an HTML parser or XML parser.
//
// NOTE: This is basically done by children_changed() today:
// The element's children changed steps run.
//
// NOTE: This is basically done by inserted() and removed_from() today:
// The element is not on the stack of open elements of an HTML parser or XML parser, and it becomes connected or disconnected.
//
// https://html.spec.whatwg.org/multipage/semantics.html#update-a-style-block
pub fn (mut base StyleElementBase) update_a_style_block(update_source StyleElementUpdateSource) {
	mut style_element := unsafe { &Element(base.as_element()) }

	// OPTIMIZATION: Skip parsing CSS if we're in the middle of parsing a HTML fragment.
	//               The style block will be parsed upon insertion into a proper document.
	if style_element.document().is_temporary_document_for_fragment_parsing() {
		return
	}

	// 1. Let element be the style element.
	// 2. If element has an associated CSS style sheet, remove the CSS style sheet in question.
	// NB: Upstream defers the StyleEngine update of a replaced sheet here; V has no StyleEngine.
	if base.associated_css_style_sheet_ != unsafe { nil } {
		if scope := base.style_sheet_scope_ {
			if dom_style_sheet_scope_hooks.remove_a_css_style_sheet != unsafe { nil } {
				dom_style_sheet_scope_hooks.remove_a_css_style_sheet(scope, base.associated_css_style_sheet_)
			}
		}
		base.style_sheet_scope_ = none

		// FIXME: This should probably be handled by StyleSheet::set_owner_node().
		base.associated_css_style_sheet_ = unsafe { nil }
	}

	// AD-HOC: The script-blocking style sheet set tracks elements, but a style element's associated sheet can be
	//         replaced before that sheet's critical subresources finish loading. Keep that set and any queued
	//         completions in sync with the sheet removed above.
	base.style_sheet_update_generation_++
	base.remove_from_script_blocking_style_sheet_set_if_needed()
	base.clear_associated_css_style_sheet_parser_blocking_state()

	// 3. If element is not connected, then return.
	if !style_element.is_connected() {
		return
	}

	// 4. If element's type attribute is present and its value is neither the empty string nor an ASCII case-insensitive match for "text/css", then return.
	if type_attribute := style_element.get_attribute('type') {
		if type_attribute.len > 0 && to_ascii_lowercase(type_attribute) != 'text/css' {
			return
		}
	}

	// 5. If the Should element's inline behavior be blocked by Content Security Policy? algorithm returns "Blocked" when executed upon the style element, "style", and the style element's child text content, then return. [CSP]
	child_text := style_element.as_node().child_text_content()
	if style_element.document().should_block_inline_content(style_element, 'style', child_text) {
		return
	}

	// 6. Create a CSS style sheet with the following properties:
	//        type
	//            text/css
	//        owner node
	//            element
	//        media
	//            The media attribute of element.
	//        title
	//            The title attribute of element, if element is in a document tree, or the empty string otherwise.
	//        alternate flag
	//            Unset.
	//        origin-clean flag
	//            Set.
	//        location
	//        parent CSS style sheet
	//        owner CSS rule
	//            null
	//        disabled flag
	//            Left at its default value.
	//        CSS rules
	//          Left uninitialized.
	create_a_css_style_sheet := dom_style_sheet_scope_hooks.create_a_css_style_sheet
	if create_a_css_style_sheet == unsafe { nil } {
		// Boundary: without the CSS module there is no StyleScope to own the sheet.
		return
	}
	text_content := style_element.as_node().text_content() or { '' }
	media_attribute := style_element.get_attribute('media') or { '' }
	title_attribute := if style_element.as_node().in_a_document_tree() {
		style_element.get_attribute('title') or { '' }
	} else {
		''
	}
	scope := style_element.as_node().document_or_shadow_root_style_scope_node()
	base.style_sheet_scope_ = scope
	base.associated_css_style_sheet_ = create_a_css_style_sheet(scope, text_content, style_element,
		media_attribute, title_attribute, none)

	base.evaluate_associated_style_sheet_media_queries()
	if update_source == .parser_pop {
		base.associated_css_style_sheet_was_created_by_parser_ = true
		base.associated_css_style_sheet_was_enabled_when_created_by_parser_ = !base.sheet_disabled()
		base.associated_css_style_sheet_load_is_pending_for_script_blocking_ = base.associated_css_style_sheet_was_enabled_when_created_by_parser_
			&& base.associated_css_style_sheet_media_matches_environment_
			&& base.sheet_loading_state() == .loading
	}

	// 7. If element contributes a script-blocking style sheet, append element to its node document's script-blocking style sheet set.
	if style_element.contributes_a_script_blocking_style_sheet() {
		mut document := unsafe { &Document(style_element.document()) }
		base.document_load_event_delayer_ = DocumentLoadEventDelayer.new(mut document)
		document.append_to_script_blocking_style_sheet_set(style_element)
		base.associated_css_style_sheet_is_blocking_scripts_ = true
	}

	// FIXME: 8. If element's media attribute's value matches the environment and element is potentially render-blocking, then block rendering on element.

	// AD-HOC: Check if we have already loaded the sheet's resources.
	loading_state := base.sheet_loading_state()
	if loading_state == .loaded || loading_state == .error {
		mut any_failed := StyleElementAnyFailed.no
		if loading_state == .error {
			any_failed = .yes
		}
		base.finished_loading_critical_subresources(any_failed)
	}
}

// https://html.spec.whatwg.org/multipage/semantics.html#the-style-element:critical-subresources
pub fn (mut base StyleElementBase) finished_loading_critical_subresources(any_failed StyleElementAnyFailed) {
	// 1. Let element be the style element associated with the style sheet in question.
	element := base.as_element()
	style_sheet_update_generation := base.style_sheet_update_generation_

	// 2. Let success be true.
	mut success := true

	// 3. If the attempts to obtain any of the style sheet's critical subresources failed for any reason
	//    (e.g., DNS error, HTTP 404 response, a connection being prematurely closed, unsupported Content-Type),
	//    set success to false.
	//    Note that content-specific errors, e.g., CSS parse errors or PNG decoding errors, do not affect success.
	if any_failed == .yes {
		success = false
	}

	// 4. Queue an element task on the networking task source given element and the following steps:
	// Documents without an HTML task queue cannot use the completion callback.
	// Check before constructing it, so its captured element has no global
	// executable-closure lifetime when queue_an_element_task would return.
	if hook := element.document().lifecycle_hook_ {
		if hook.queue_an_element_task != unsafe { nil } {
			element.queue_an_element_task(.user_interaction, fn [element, success, style_sheet_update_generation] () {
				mut style_element := unsafe { &Element(element) }
				// AD-HOC: If the associated stylesheet has been replaced or removed since this task was queued, ignore it.
				mut style_element_base := style_element.style_element_base() or { return }
				if style_element_base.style_sheet_update_generation_ != style_sheet_update_generation {
					return
				}

				// 1. If success is true, fire an event named load at element.
				// AD-HOC: these should call fire an event this is not implemented anywhere so we dispatch it ourselves
				if success {
					style_element.dispatch_event_simple('load', false)
				} else {
					// 2. Otherwise, fire an event named error at element.
					style_element.dispatch_event_simple('error', false)
				}
				// 3. If element contributes a script-blocking style sheet:
				if style_element.contributes_a_script_blocking_style_sheet() {
					mut document := unsafe { &Document(style_element.document()) }
					// 1. Assert: element's node document's script-blocking style sheet set contains element.
					assert document.script_blocking_style_sheet_set_contains(style_element)
					assert style_element_base.associated_css_style_sheet_is_blocking_scripts_
					// 2. Remove element from its node document's script-blocking style sheet set.
					document.remove_from_script_blocking_style_sheet_set(style_element)
					style_element_base.associated_css_style_sheet_is_blocking_scripts_ = false
				}
				// 4. Unblock rendering on element.
				style_element.unblock_rendering()
				style_element_base.associated_css_style_sheet_load_is_pending_for_script_blocking_ = false
			})
		}
	}
	if mut delayer := base.document_load_event_delayer_ {
		delayer.finish()
		base.document_load_event_delayer_ = none
	}
}

pub fn (mut base StyleElementBase) associated_style_sheet_media_attribute_changed() {
	base.evaluate_associated_style_sheet_media_queries()
	if !base.as_element().contributes_a_script_blocking_style_sheet() {
		base.remove_from_script_blocking_style_sheet_set_if_needed()
		base.associated_css_style_sheet_load_is_pending_for_script_blocking_ = false
	}
}

// https://html.spec.whatwg.org/multipage/semantics.html#contributes-a-script-blocking-style-sheet
pub fn (base &StyleElementBase) style_element_contributes_a_script_blocking_style_sheet() bool {
	// An element el in the context of a Document of an HTML parser or XML parser contributes a script-blocking style
	// sheet if all of the following are true:
	element := base.as_element()

	// el was created by that Document's parser.
	parser_document := base.parser_document_ or { return false }
	if voidptr(parser_document) != voidptr(element.document()) {
		return false
	}

	if !base.associated_css_style_sheet_was_created_by_parser_ {
		return false
	}

	// el is either a style element or a link element that was an external resource link that contributes to the
	// styling processing model when the el was created by the parser.
	// NB: This is a style element, so all good!

	// el's media attribute's value matches the environment.
	if !base.associated_css_style_sheet_media_matches_environment_ {
		return false
	}

	// el's style sheet was enabled when the element was created by the parser.
	if !base.associated_css_style_sheet_was_enabled_when_created_by_parser_ {
		return false
	}

	// FIXME: The last time the event loop reached step 1, el's root was that Document.

	// FIXME: The user agent hasn't given up on loading that particular style sheet yet.
	//        A user agent may give up on loading a style sheet at any time.

	// AD-HOC: Once this parser-created stylesheet has finished loading or stopped blocking scripts, it no longer
	//         contributes a script-blocking stylesheet even though it is still the current associated stylesheet.
	// FIXME: May not be needed once the other clauses above are implemented.
	if !base.associated_css_style_sheet_load_is_pending_for_script_blocking_ {
		return false
	}

	return true
}

fn (mut base StyleElementBase) evaluate_associated_style_sheet_media_queries() {
	if base.associated_css_style_sheet_ == unsafe { nil } {
		base.associated_css_style_sheet_media_matches_environment_ = false
		return
	}

	if dom_style_sheet_scope_hooks.evaluate_media_queries != unsafe { nil } {
		dom_style_sheet_scope_hooks.evaluate_media_queries(base.associated_css_style_sheet_,
			base.as_element().document())
	}
	base.associated_css_style_sheet_media_matches_environment_ = dom_style_sheet_scope_hooks.media_list_matches != unsafe { nil }
		&& dom_style_sheet_scope_hooks.media_list_matches(base.associated_css_style_sheet_)
}

fn (mut base StyleElementBase) remove_from_script_blocking_style_sheet_set_if_needed() {
	if !base.associated_css_style_sheet_is_blocking_scripts_ {
		return
	}

	element := base.as_element()
	mut document := unsafe { &Document(element.document()) }
	if document.script_blocking_style_sheet_set_contains(element) {
		document.remove_from_script_blocking_style_sheet_set(element)
	}

	base.associated_css_style_sheet_is_blocking_scripts_ = false
	if mut delayer := base.document_load_event_delayer_ {
		delayer.finish()
		base.document_load_event_delayer_ = none
	}
}

fn (mut base StyleElementBase) clear_associated_css_style_sheet_parser_blocking_state() {
	base.associated_css_style_sheet_was_created_by_parser_ = false
	base.associated_css_style_sheet_was_enabled_when_created_by_parser_ = false
	base.associated_css_style_sheet_media_matches_environment_ = false
	base.associated_css_style_sheet_load_is_pending_for_script_blocking_ = false
	base.associated_css_style_sheet_is_blocking_scripts_ = false
}

// https://www.w3.org/TR/cssom/#dom-linkstyle-sheet
pub fn (base &StyleElementBase) sheet() voidptr {
	// The sheet attribute must return the associated CSS style sheet for the node or null if there is no associated CSS style sheet.
	return base.associated_css_style_sheet_
}

fn (base &StyleElementBase) sheet_disabled() bool {
	if base.associated_css_style_sheet_ == unsafe { nil } || dom_style_sheet_scope_hooks.disabled == unsafe { nil } {
		return false
	}
	return dom_style_sheet_scope_hooks.disabled(base.associated_css_style_sheet_)
}

fn (base &StyleElementBase) sheet_loading_state() CSSStyleSheetLoadingState {
	if base.associated_css_style_sheet_ == unsafe { nil }
		|| dom_style_sheet_scope_hooks.loading_state == unsafe { nil } {
		return .loaded
	}
	return dom_style_sheet_scope_hooks.loading_state(base.associated_css_style_sheet_)
}

// https://html.spec.whatwg.org/multipage/semantics.html#dom-style-disabled
pub fn (base &StyleElementBase) disabled() bool {
	// 1. If this does not have an associated CSS style sheet, return false.
	if base.sheet() == unsafe { nil } {
		return false
	}

	// 2. If this's associated CSS style sheet's disabled flag is set, return true.
	if base.sheet_disabled() {
		return true
	}

	// 3. Return false.
	return false
}

// https://html.spec.whatwg.org/multipage/semantics.html#dom-style-disabled
pub fn (mut base StyleElementBase) set_disabled(disabled bool) {
	// 1. If this does not have an associated CSS style sheet, return.
	if base.sheet() == unsafe { nil } {
		return
	}

	// 2. If the given value is true, set this's associated CSS style sheet's disabled flag.
	//    Otherwise, unset this's associated CSS style sheet's disabled flag.
	if dom_style_sheet_scope_hooks.set_disabled != unsafe { nil } {
		dom_style_sheet_scope_hooks.set_disabled(base.sheet(), disabled)
	}
}

pub fn (base &StyleElementBase) retarget_style_load_event_delayer(mut new_document Document) {
	if mut delayer := base.document_load_event_delayer_ {
		delayer.finish()
		mut mutable_base := unsafe { &StyleElementBase(base) }
		mutable_base.document_load_event_delayer_ = DocumentLoadEventDelayer.new(mut new_document)
	}
}

pub fn (base &StyleElementBase) visit_style_element_edges(mut visitor CellVisitor) {
	if scope := base.style_sheet_scope_ {
		visitor.visit(scope)
	}
}

// Node::document_or_shadow_root_style_scope(), identified by the node that owns the scope.
pub fn (n &Node) document_or_shadow_root_style_scope_node() &Node {
	root := n.root()
	if shadow_root := root.as_shadow_root() {
		if !shadow_root.uses_document_style_sheets() {
			return root
		}
	}
	return unsafe { &Node(n.document()) }
}

// https://html.spec.whatwg.org/multipage/semantics.html#contributes-a-script-blocking-style-sheet
// NB: HTMLStyleElement and SVGStyleElement override Element::contributes_a_script_blocking_style_sheet() upstream.
//     HTMLLinkElement's override lives with its HTML model.
pub fn (element &Element) contributes_a_script_blocking_style_sheet() bool {
	if base := element.style_element_base() {
		return base.style_element_contributes_a_script_blocking_style_sheet()
	}
	return false
}

// https://html.spec.whatwg.org/multipage/webappapis.html#queue-an-element-task
// NB: The event loop is HTML-owned; documents without an HTML window have no event loop to queue on.
pub fn (element &Element) queue_an_element_task(source TaskSource, steps fn ()) {
	document := element.document()
	hook := document.lifecycle_hook_ or { return }
	if hook.queue_an_element_task == unsafe { nil } {
		return
	}
	hook.queue_an_element_task(hook.target, element, source, steps)
}
