// LibWeb/Rust/src/layout/rendered_text.rs: source/rendered UTF-16 boundaries.
module platform

pub enum TextMappingBoundary {
	start
	end
}

pub fn rendered_text_offset_for_source_offset(edits []TextMappingEdit, source_base int, offset int, boundary TextMappingBoundary) int {
	mut previous_source_end := source_base
	mut previous_rendered_end := 0
	for edit in edits {
		if offset < edit.source_start { return previous_rendered_end + offset - previous_source_end }
		source_end := edit.source_start + edit.source_length
		rendered_end := edit.rendered_start + edit.rendered_length
		if offset <= source_end {
			if offset == edit.source_start { return edit.rendered_start }
			if offset == source_end { return rendered_end }
			return if boundary == .start { edit.rendered_start } else { rendered_end }
		}
		previous_source_end = source_end
		previous_rendered_end = rendered_end
	}
	return previous_rendered_end + offset - previous_source_end
}

pub fn source_offset_for_rendered_text_offset(edits []TextMappingEdit, source_base int, offset int, boundary TextMappingBoundary) int {
	mut previous_source_end := source_base
	mut previous_rendered_end := 0
	for edit in edits {
		if offset < edit.rendered_start {
			return previous_source_end + offset - previous_rendered_end
		}
		source_end := edit.source_start + edit.source_length
		rendered_end := edit.rendered_start + edit.rendered_length
		if offset == edit.rendered_start {
			if edit.rendered_length > 0 || boundary == .end { return edit.source_start }
		} else if offset < rendered_end {
			return if boundary == .start { edit.source_start } else { source_end }
		} else if offset == rendered_end && boundary == .end {
			return source_end
		}
		previous_source_end = source_end
		previous_rendered_end = rendered_end
	}
	return previous_source_end + offset - previous_rendered_end
}
