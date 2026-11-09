module layout

import css

fn grid_line_has_name(lines [][]css.GridLineName, index int, name string) bool {
	if index < 0 || index >= lines.len { return false }
	for candidate in lines[index] { if candidate.name == name { return true } }
	return false
}

fn grid_positioned_line(placement css.GridTrackPlacement, start bool, explicit_line_count int, lines [][]css.GridLineName) ?int {
	if !placement.is_positioned() { return none }
	if !placement.has_identifier() {
		return resolved_grid_line_number(placement, explicit_line_count)
	}
	mut name := placement.identifier()
	if placement.is_custom_ident() {
		area_name := name + if start { '-start' } else { '-end' }
		if _ := get_nth_grid_line_index(lines, area_name, 1) { name = area_name }
	}
	nth := if placement.has_line_number() {
		int(css.int_from_style_value(placement.line_number()))
	} else {
		1
	}
	if index := get_nth_grid_line_index(lines, name, nth) { return index }
	mut matches := 0
	for index in 0 .. lines.len { if grid_line_has_name(lines, index, name) { matches++ } }
	remaining := if nth < 0 { -nth - matches } else { nth - matches }
	// Outside the explicit grid every implicit line is assumed to have the
	// requested name, including when no explicit line has that name at all.
	return if nth < 0 { -remaining } else { explicit_line_count - 1 + remaining }
}

fn grid_named_span_line(lines [][]css.GridLineName, name string, anchor int, count int, forward bool) int {
	step := if forward { 1 } else { -1 }
	mut index := anchor
	mut remaining := count
	for remaining > 0 {
		if forward && index>=lines.len-1 { return index+remaining }
		if !forward && index<=0 { return index-remaining }
		if forward && index < -1 {
			distance := if -index-1<remaining { -index-1 } else { remaining }
			index+=distance
			remaining-=distance
			continue
		}
		if !forward && index>lines.len {
			distance := if index-lines.len<remaining { index-lines.len } else { remaining }
			index-=distance
			remaining-=distance
			continue
		}
		index += step
		if index < 0 || index >= lines.len || grid_line_has_name(lines, index, name) { remaining-- }
	}
	return index
}
