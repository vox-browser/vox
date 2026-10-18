module layout

import css
import dom
import html

fn animated_descendant_style(document &dom.Document, id string) &css.ComputedValues {
	element := document.get_element_by_id(id) or { panic('missing ${id}') }
	computed := css.computed_properties_for_element(element) or { panic('missing ${id} style') }
	return unsafe { &css.ComputedValues(computed) }
}

// An animated inherited value reaches descendant styles and paint on every
// sample, even though their own base values do not change.
fn test_animated_inherited_values_reach_descendant_styles() {
	mut document := html.parse_document('<!doctype html><style>
@keyframes ink{from{color:red}to{color:blue}}
#ink{animation:ink 1s linear infinite}
</style><div id="ink">plain<b id="bold">bold</b></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 200)
	for frame in 1 .. 4 {
		document.update_animations_and_send_events(f64(frame) * 230.0)
		document.update_layout(.html_event_loop_rendering_update)
		list := document.record_display_list() or { panic('missing frame paint') }
		ink := animated_descendant_style(document, 'ink').color()
		assert animated_descendant_style(document, 'bold').color() == ink, 'frame ${frame}'
		texts := display_list_commands(list).filter(it.kind == 'draw_text')
		assert texts.len == 2
		assert texts[0].color == texts[1].color, 'frame ${frame}'
	}
}
