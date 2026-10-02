// ViewTransition.cpp capture geometry and Layout::Node computed-style reads.
module layout

fn layout_view_transition_properties(target voidptr) map[string]string {
	node := unsafe { &Node(target) }
	styled := node.as_node_with_style() or { return {} }
	values := styled.computed_values()
	backdrop := values.property(.backdrop_filter, .yes)
	return {
		'writing-mode':    values.writing_mode().str().replace('_', '-')
		'direction':       values.direction().str()
		'mix-blend-mode':  values.mix_blend_mode().str().replace('_', '-')
		'backdrop-filter': if value := backdrop {
			value.css_text
		} else {
			'none'
		}
		'color-scheme':    values.color_scheme().str()
	}
}
