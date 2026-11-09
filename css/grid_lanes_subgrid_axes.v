module css

import dom

// Grid lanes provide shared tracks only in the lanes axis. A child grid's
// orthogonal writing mode maps that physical axis to its own rows or columns.
fn adjust_grid_lanes_subgrid_axes(mut properties ComputedProperties, element dom.AbstractElement) {
	if !properties.display().is_grid_inside() { return }
	mut parent := element.element_to_inherit_style_from()
	for {
		current := parent or { return }
		placeholder := current.computed_properties() or { return }
		style := computed_properties_from_dom(placeholder) or { return }
		if style.display().is_contents() {
			parent = current.element_to_inherit_style_from()
			continue
		}
		if !style.display().is_grid_lanes_inside() { return }
		direction := if value := style.property(.grid_lanes_direction, .yes) {
			value.css_text.split(' ')[0]
		} else {
			'normal'
		}
		columns := if direction == 'column' {
			true
		} else if direction == 'row' {
			false
		} else {
			!style.grid_template_columns().is_empty() || style.grid_template_rows().is_empty()
		}
		physical_horizontal := columns == (style.writing_mode() == .horizontal_tb)
		child_columns := physical_horizontal == (properties.writing_mode() == .horizontal_tb)
		ignored := if child_columns {
			PropertyID.grid_template_rows
		} else {
			PropertyID.grid_template_columns
		}
		template := if ignored == .grid_template_rows {
			properties.grid_template_rows()
		} else {
			properties.grid_template_columns()
		}
		if template.is_subgrid() {
			properties.set_property(ignored, dom_style_value_from_value_logic(StyleValue(GridTrackSizeListStyleValue.make_none())), .no, .no)
		}
		return
	}
}
