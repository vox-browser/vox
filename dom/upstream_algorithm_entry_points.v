// Copyright (c) 2026, libweb_v contributors
//
// SPDX-License-Identifier: BSD-2-Clause
//
// File-local and header-template algorithms from Libraries/LibWeb/DOM.
module dom

pub fn obtain_a_browsing_context_to_use_for_a_navigation_response(params &NavigationParams) &BrowsingContext {
	context := params.browsing_context or { return &BrowsingContext{} }
	if !params.needs_a_browsing_context_group_switch {
		// The report-only branch changes a virtual group identifier in C++. The
		// translated BrowsingContext does not expose that unobservable token.
		return context
	}
	// Creating the replacement top-level context is an HTML/embedder boundary.
	// Preserve the observable active document while giving the navigation a
	// distinct browsing-context identity.
	return &BrowsingContext{
		active_document_: context.active_document_
	}
}

pub fn relayout_svg_root(root &SVGSVGBox) {
	if root.relayout_callback != unsafe { nil } {
		root.relayout_callback(root)
	}
}

pub fn propagate_scrollbar_width_to_viewport(root_element &Element, mut viewport LayoutViewport) {
	properties := root_element.el_computed_properties() or { return }
	viewport.scrollbar_width = properties.scrollbar_width_
}

fn merge_required_invalidation(mut target RequiredInvalidationAfterStyleChange, source RequiredInvalidationAfterStyleChange) {
	target.relayout = target.relayout || source.relayout
	target.rebuild_layout_tree = target.rebuild_layout_tree || source.rebuild_layout_tree
	target.repaint = target.repaint || source.repaint
}

pub fn update_style_recursively(node &Node, needs_inherited_style_update bool, recompute_elements_depending_on_custom_properties bool, parent_display_changed bool) RequiredInvalidationAfterStyleChange {
	mut result := RequiredInvalidationAfterStyleChange{}
	mut inherited_update := needs_inherited_style_update
	mut display_changed := parent_display_changed

	if element := node.as_element() {
		mut mutable_element := unsafe { &Element(element) }
		old_display_none := if properties := element.el_computed_properties() {
			properties.display().is_none()
		} else {
			true
		}
		should_recompute := node.needs_style_update() || node.entire_subtree_needs_style_update_ || parent_display_changed || (recompute_elements_depending_on_custom_properties && (element.style_uses_var_css_function || element.style_uses_inherit_css_function)) || element.style_uses_if_css_function
		if should_recompute {
			invalidation := mutable_element.recompute_style()
			merge_required_invalidation(mut result, invalidation)
			inherited_update = true
		} else if needs_inherited_style_update {
			invalidation := mutable_element.recompute_inherited_style()
			merge_required_invalidation(mut result, invalidation)
		}
		new_display_none := if properties := element.el_computed_properties() {
			properties.display().is_none()
		} else {
			true
		}
		display_changed = old_display_none != new_display_none
	}

	for child in node.children {
		child_invalidation := update_style_recursively(child, inherited_update,
			recompute_elements_depending_on_custom_properties, display_changed)
		merge_required_invalidation(mut result, child_invalidation)
	}
	mut mutable_node := unsafe { &Node(node) }
	mutable_node.set_needs_style_update_internal(false)
	mutable_node.set_child_needs_style_update(false)
	mutable_node.set_entire_subtree_needs_style_update(false)
	return result
}

fn intersect_rectangles(a Rect, b Rect) Rect {
	left := if a.x > b.x { a.x } else { b.x }
	top := if a.y > b.y { a.y } else { b.y }
	right_a := a.x + a.width
	right_b := b.x + b.width
	right := if right_a < right_b { right_a } else { right_b }
	bottom_a := a.y + a.height
	bottom_b := b.y + b.height
	bottom := if bottom_a < bottom_b { bottom_a } else { bottom_b }
	if right <= left || bottom <= top {
		return Rect{
			x: left
			y: top
		}
	}
	return Rect{
		x: left
		y: top
		width: right - left
		height: bottom - top
	}
}

pub fn compute_intersection(target &Element, _ &IntersectionObserver, _ ?&PaintableBox_, root_bounds Rect) Rect {
	mut intersection := intersect_rectangles(target.get_bounding_client_rect(), root_bounds)
	mut ancestor := target.as_node().parent()
	for {
		container := ancestor or { break }
		if element := container.as_element() {
			if element.is_scroll_container() {
				intersection = intersect_rectangles(intersection, element.get_bounding_client_rect())
			}
		}
		ancestor = container.parent()
	}
	return intersection
}

pub fn is_potentially_named_element(element &Element) bool {
	return element.is_html_element() && element.local_name() in ['embed', 'form', 'iframe', 'img',
		'object']
}

pub fn is_potentially_named_element_by_id(element &Element) bool {
	return element.is_html_element() && element.local_name() in ['img', 'object']
}

pub fn insert_in_tree_order(mut elements []&Element, element &Element) {
	if element in elements {
		return
	}
	for index, existing in elements {
		if existing.as_node().compare_document_position(element.as_node()) & document_position_following != 0 {
			elements.insert(index, element)
			return
		}
	}
	elements << element
}

pub fn is_exposed(element &Element) bool {
	// This intentionally matches upstream's current FIXME-backed behavior.
	return element.is_html_element() && element.local_name() in ['embed', 'object']
}

pub fn is_named_element_with_name(element &Element, name string) bool {
	if !element.is_html_element() {
		return false
	}
	local_name := element.local_name()
	if local_name in ['embed', 'form', 'iframe', 'img', 'object'] && (local_name !in ['embed',
		'object'] || is_exposed(element)) {
		if element.get_name() or { '' } == name {
			return true
		}
	}
	if local_name == 'object' && is_exposed(element) && element.id() or { '' } == name {
		return true
	}
	return local_name == 'img' && element.id() or { '' } == name && element.get_name() or {
		''
	} != ''
}

pub fn named_elements_with_name(document &Document, name string) []&Element {
	mut result := []&Element{}
	for element in document.potentially_named_elements {
		if is_named_element_with_name(element, name) {
			result << element
		}
	}
	return result
}

pub fn calculate_depth_for_node(node &Node) int {
	mut depth := 0
	mut current := ?&Node(node)
	for {
		candidate := current or { break }
		depth++
		current = candidate.parent()
	}
	return depth
}

pub fn find_style_sheet_with_url(url string, style_sheet &CSSStyleSheet) ?&CSSStyleSheet {
	if style_sheet.url == url {
		return style_sheet
	}
	for imported_style_sheet in style_sheet.imported_style_sheets {
		if found := find_style_sheet_with_url(url, imported_style_sheet) {
			return found
		}
	}
	return none
}

pub fn calculate_get_animations(document &Document) ![]&Animation {
	return document.get_animations()
}

pub fn compute_required_invalidation(old_style &CSSComputedProperties_, new_style &CSSComputedProperties_, _ &FontComputer) RequiredInvalidationAfterStyleChange {
	mut invalidation := RequiredInvalidationAfterStyleChange{}
	if old_style.font_weight() != new_style.font_weight() || old_style.math_depth() != new_style.math_depth() || old_style.math_style() != new_style.math_style() {
		invalidation.relayout = true
	}
	old_display := old_style.display()
	new_display := new_style.display()
	if old_display.is_none_ != new_display.is_none_ || old_display.is_list_item_ != new_display.is_list_item_ || old_display.is_contents_ != new_display.is_contents_ || old_display.is_inline_outside_ != new_display.is_inline_outside_ || old_display.is_flow_inside_ != new_display.is_flow_inside_ {
		invalidation.rebuild_layout_tree = true
	}
	if old_style.overflow_x() != new_style.overflow_x() || old_style.overflow_y() != new_style.overflow_y() || old_style.content_visibility() != new_style.content_visibility() {
		invalidation.relayout = true
	}
	if old_style.opacity() != new_style.opacity() || old_style.visibility() != new_style.visibility() {
		invalidation.repaint = true
	}
	return invalidation
}

pub fn determine_the_scroll_into_view_position(target &Element, block ScrollLogicalPosition, inline_ ScrollLogicalPosition, scrolling_box &Node) CSSPixelPoint_ {
	if !scrolling_box.is_document() {
		return CSSPixelPoint_{}
	}
	target_rect := target.get_bounding_client_rect()
	scrolling_rect := scrolling_box.document().viewport_rect()
	element_edge_a := target_rect.y
	element_edge_b := target_rect.y + target_rect.height
	element_edge_c := target_rect.x
	element_edge_d := target_rect.x + target_rect.width
	scrolling_height := scrolling_rect.height
	scrolling_width := scrolling_rect.width
	mut x := 0.0
	mut y := 0.0

	match block {
		.start { y = element_edge_a }
		.end_ { y = element_edge_a + target_rect.height - scrolling_height }
		.center { y = element_edge_a + target_rect.height / 2.0 - scrolling_height / 2.0 }
		.nearest {
			if !(element_edge_a <= 0 && element_edge_b >= scrolling_height) {
				if (element_edge_a <= 0 && target_rect.height < scrolling_height) || (element_edge_b >= scrolling_height && target_rect.height > scrolling_height) {
					y = element_edge_a
				} else if (element_edge_b >= scrolling_height && target_rect.height < scrolling_height) || (element_edge_a <= 0 && target_rect.height > scrolling_height) {
					y = element_edge_a + target_rect.height - scrolling_height
				}
			}
		}
	}
	match inline_ {
		.start { x = element_edge_c }
		.end_ { x = element_edge_d + target_rect.width - scrolling_width }
		.center { x = element_edge_c + target_rect.width / 2.0 - scrolling_width / 2.0 }
		.nearest {
			if !(element_edge_c <= 0 && element_edge_d >= scrolling_width) {
				if (element_edge_c <= 0 && target_rect.width < scrolling_width) || (element_edge_d >= scrolling_width && target_rect.width > scrolling_width) {
					x = element_edge_c
				} else if (element_edge_d >= scrolling_width && target_rect.width < scrolling_width) || (element_edge_c <= 0 && target_rect.width > scrolling_width) {
					x = element_edge_d + target_rect.width - scrolling_width
				}
			}
		}
	}
	return CSSPixelPoint_{
		x_: x
		y_: y
	}
}

pub fn scroll_an_element_into_view(target &Element, _ ScrollBehavior, block ScrollLogicalPosition, inline_ ScrollLogicalPosition, container ?&Element) &Promise {
	mut ancestor := target.as_node().parent()
	for {
		scrolling_box := ancestor or { break }
		if scrolling_box.is_document() {
			position := determine_the_scroll_into_view_position(target, block, inline_, scrolling_box)
			document := scrolling_box.document()
			if document.window != unsafe { nil } {
				mut window := unsafe { &Window(document.window) }
				window.scroll_x_ = position.x()
				window.scroll_y_ = position.y() + document.viewport_rect().y
			}
		} else if element := scrolling_box.as_element() {
			if element.is_scroll_container() {
				position := determine_the_scroll_into_view_position(target, block, inline_, scrolling_box)
				mut mutable_element := unsafe { &Element(element) }
				mutable_element.set_scroll_offset(none, position)
			}
		}
		if stop_at := container {
			if scrolling_box.is_shadow_including_inclusive_ancestor_of(stop_at.as_node()) {
				break
			}
		}
		ancestor = scrolling_box.parent()
	}
	return Promise.resolved(js_undefined())
}

pub fn prefetch_inline_style_image_resources(style &CSSStyleProperties_, document &Document) {
	if style.prefetch_resources != unsafe { nil } {
		style.prefetch_resources(style.prefetch_resources_target, document)
	}
}

pub fn request_fullscreen_error_to_string(error_ RequestFullscreenError) string {
	return match error_ {
		.false_ { '' }
		.true_ { 'Fullscreen request failed' }
		.element_ready_check_failed { 'Element ready check failed' }
		.unsupported_element { 'Not supported element' }
		.no_transient_user_activation { 'No transient user activation available to consume' }
		.element_node_doc_is_not_pending_doc { "Element's node document is not pending doc" }
	}
}

pub fn schedule_a_selectionchange_event(mut target Document, _ &Document) {
	if target.has_scheduled_selectionchange_event() {
		return
	}
	target.set_scheduled_selectionchange_event(true)
}

pub fn fire_a_selectionchange_event(mut target Document, _ &Document) {
	target.set_scheduled_selectionchange_event(false)
	event := Event.create('selectionchange', EventInit{})
	target.global_event_handlers_to_event_target('selectionchange').dispatch_event(event)
}
