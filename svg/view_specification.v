// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module svg

// A valid specification may omit viewBox. Keep that distinct from an invalid
// specification, which is instead eligible to name a <view> by its ID.
pub struct ViewSpecification {
pub:
	view_box ?ViewBox
}

pub fn parse_view_specification(fragment string) ?ViewSpecification {
	prefix := 'svgView('
	if !fragment.starts_with(prefix) || !fragment.ends_with(')') { return none }
	attributes := fragment[prefix.len..fragment.len - 1].trim(' \t\n\r\f')
	if attributes.len == 0 { return none }
	mut seen := map[string]bool{}
	mut view_box := ?ViewBox(none)
	for part in attributes.split(';') {
		attribute := part.trim(' \t\n\r\f')
		open := attribute.index('(') or { return none }
		if open == 0 || !attribute.ends_with(')') { return none }
		name := attribute[..open].trim(' \t\n\r\f')
		value := attribute[open + 1..attribute.len - 1]
		if seen[name] { return none }
		seen[name] = true
		match name {
			'viewBox' { view_box = parse_viewbox(value) or { return none } }
			'preserveAspectRatio' { _ = parse_preserve_aspect_ratio(value) or { return none } }
			'transform' { _ = parse_transform(value) or { return none } }
			'zoomAndPan' { if value.trim(' \t\n\r\f') !in ['disable', 'magnify'] { return none } }
			else { return none }
		}
	}
	return ViewSpecification{view_box: view_box}
}
