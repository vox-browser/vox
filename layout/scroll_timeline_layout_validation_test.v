module layout

import css
import dom
import html

// GitHub's tab strip reveals its "More" button with a scroll-driven
// animation that only runs while the strip overflows.
fn scroll_timeline_document(content_height int) &dom.Document {
	return html.parse_document('<!doctype html><style>
		#nav { overflow: hidden; width: 120px; height: 20px; --more: none;
			animation: linear detect; animation-timeline: scroll(self); }
		@keyframes detect { 0%, to { --more: block } }
		#more { display: var(--more, block); height: 10px; }
	</style><div id="nav"><div style="height:${content_height}px">tabs</div><div id="more">more</div></div>')
}

fn scroll_timeline_more_display(document &dom.Document) string {
	more := document.get_element_by_id('more') or { panic('missing more') }
	computed := css.computed_properties_for_element(more) or { panic('missing style') }
	return if computed.display().is_none() { 'none' } else { 'shown' }
}

fn test_overflowing_scroll_timeline_applies_within_the_first_layout() {
	mut document := scroll_timeline_document(60)
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	assert document.has_scroll_driven_animations
	assert scroll_timeline_more_display(document) == 'shown'
	more := document.get_element_by_id('more') or { panic('missing more') }
	assert more.as_node().unsafe_layout_node() != none
	assert document.layout_is_up_to_date()
	// The next animation frame samples the same timeline state; nothing changes.
	generation := document.layout_pass_generation
	document.set_needs_animated_style_update()
	document.update_layout(.debugging)
	assert document.layout_pass_generation == generation
	assert scroll_timeline_more_display(document) == 'shown'
}

fn test_inactive_scroll_timeline_leaves_the_base_value() {
	mut document := scroll_timeline_document(10)
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	assert scroll_timeline_more_display(document) == 'none'
	assert document.layout_is_up_to_date()
}
