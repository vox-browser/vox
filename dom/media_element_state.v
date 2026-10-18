// SPDX-License-Identifier: BSD-2-Clause
// Cycle-breaking query for CSS/SelectorMatching.cpp's actual media state facts.
module dom

pub enum MediaElementPseudoClass {
	paused
	playing
	seeking
	muted
	buffering
	stalled
}

pub type MediaElementStateQuery = fn (&Element, MediaElementPseudoClass) bool

pub type MediaElementResourceAttributeChangedHook = fn (&Element)

pub type MediaElementSourceAttributeChangedHook = fn (&Element, ?string)

pub type MediaElementControlsAttributeChangedHook = fn (&Element, ?string)

pub fn (mut document Document) set_media_element_state_query(query MediaElementStateQuery) {
	document.media_element_state_query_ = query
}

pub fn (mut document Document) set_media_element_resource_attribute_changed_hook(hook MediaElementResourceAttributeChangedHook) {
	document.media_element_resource_attribute_changed_hook_ = hook
}

pub fn (mut document Document) set_media_element_source_attribute_changed_hook(hook MediaElementSourceAttributeChangedHook) {
	document.media_element_source_attribute_changed_hook_ = hook
}

pub fn (mut document Document) set_media_element_controls_attribute_changed_hook(hook MediaElementControlsAttributeChangedHook) {
	document.media_element_controls_attribute_changed_hook_ = hook
}

// HTML installs a query which resolves the concrete owner on first use. No
// cached CSS facts or synthetic media model are stored on Element.
pub fn (element &Element) matches_media_pseudo_class(pseudo_class MediaElementPseudoClass) bool {
	if !element.is_html_element() || element.local_name() !in ['audio', 'video'] {
		return false
	}
	query := element.document().media_element_state_query_ or { return false }
	return query(element, pseudo_class)
}
