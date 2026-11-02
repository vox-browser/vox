module layout

import css
import painting
import platform

// The layout cache already proves that line geometry and font ownership are
// unchanged. Keep the expensive style-to-paint projection too, rebasing only
// document coordinates when preceding content moves the containing block.
fn retained_inline_paint_inputs_are_current(cache &RetainedInlineLayout) bool {
	if cache.inputs.len == 0
		|| cache.style_environment != cache.inputs[0].node.document().style_environment_version() {
		return false
	}
	for input in cache.inputs {
		if voidptr(input.node.computed_values()) != voidptr(input.style)
			|| input.node.computed_values().mutation_revision() != input.style_revision
			|| input.node.computed_values().has_animated_properties() {
			return false
		}
	}
	return true
}

fn retained_inline_paint_can_share(lines []TextLine) bool {
	for line in lines {
		for fragment in line.fragments {
			if fragment.background_images.len > 0 { return false }
		}
		for decoration in line.box_decorations {
			if decoration.background_images.len > 0 { return false }
		}
	}
	return true
}

fn rebase_retained_inline_fragment_into(fragment &TextFragment, dx f64, dy f64,
	mut output TextFragment) bool {
	x := fragment.x + dx
	y := fragment.y + dy
	if CSSPixels.nearest_value_for(fragment.x).might_be_saturated()
		|| CSSPixels.nearest_value_for(fragment.y).might_be_saturated()
		|| CSSPixels.nearest_value_for(x).might_be_saturated()
		|| CSSPixels.nearest_value_for(y).might_be_saturated() {
		return false
	}
	mut paintable := fragment.paintable_fragment
	if paintable.text_value != '' {
		paintable.offset = painting.Point{paintable.offset.x + dx, paintable.offset.y + dy}
	}
	top := if old_top := fragment.paint_line_top { ?f64(old_top + dy) } else { none }
	// Selection pseudo styles can change without changing line geometry.
	selection := if fragment.layout_handle != unsafe { nil } {
		selection_style(unsafe { &Node(fragment.layout_handle) })
	} else {
		fragment.selection_style
	}
	output = TextFragment{
		...fragment
		text_run_id: if fragment.layout_handle != unsafe { nil } {
			text_run_identity(unsafe { &Node(fragment.layout_handle) })
		} else { fragment.text_run_id }
		x: x
		y: y
		paint_line_top: top
		paintable_fragment: paintable
		selection_style: selection
	}
	return true
}

fn rebase_retained_inline_lines(lines []TextLine, dx f64, dy f64) ?[]TextLine {
	mut result := []TextLine{cap: lines.len}
	for line_index in 0 .. lines.len {
		line := unsafe { &lines[line_index] }
		mut fragments := []TextFragment{cap: line.fragments.len}
		// Initialize final slots directly. Returning and appending an optional
		// kilobyte-sized fragment otherwise copies each retained word repeatedly.
		unsafe { fragments.grow_len(line.fragments.len) }
		for index in 0 .. line.fragments.len {
			if !rebase_retained_inline_fragment_into(unsafe { &line.fragments[index] }, dx, dy,
				mut fragments[index]) { return none }
		}
		mut decorations := []TextFragment{cap: line.box_decorations.len}
		unsafe { decorations.grow_len(line.box_decorations.len) }
		for index in 0 .. line.box_decorations.len {
			if !rebase_retained_inline_fragment_into(unsafe { &line.box_decorations[index] }, dx, dy,
				mut decorations[index]) { return none }
		}
		result << TextLine{
			...line
			x:               line.x + dx
			y:               line.y + dy
			fragments:       fragments
			box_decorations: decorations
		}
	}
	return result
}

fn text_lines_from_typed_layout(container &Node, used &UsedValues, state &LayoutState,
	position css.CSSPixelPoint) []TextLine {
	if !keeps_paint_projection_templates(container.document()) {
		return uncached_text_lines_from_typed_layout(container, used, state, position)
	}
	if mut cached := state.inline_layouts_[u64(voidptr(container))] {
		if retained_inline_paint_inputs_are_current(cached) {
			if cached.paint_ready_ {
				dx := position.x().to_double() - cached.paint_origin_.x().to_double()
				dy := position.y().to_double() - cached.paint_origin_.y().to_double()
				if translated := rebase_retained_inline_lines(cached.paint_lines_, dx, dy) {
					return translated
				}
			}
			// The geometry cache can serve a later tree after this projection's
			// arena has been recycled. Build its immutable template outside it.
			use_document := cache_uses_entered_document_storage(container.document())
			mut retained := if use_document { platform.enter_retained_allocations() } else { platform.RetainedAllocationScope{} }
			persistent := platform.enter_persistent_if(!use_document)
			defer { platform.leave_persistent(persistent); retained.finish() }
			lines := uncached_text_lines_from_typed_layout(container, used, state, position)
			if !cached.paint_ready_ && retained_inline_paint_can_share(lines) {
				if snapshot := rebase_retained_inline_lines(lines, 0, 0) {
					cached.paint_lines_ = snapshot
					cached.paint_origin_ = position
					cached.paint_ready_ = true
				}
			}
			return lines
		}
	}
	return retained_block_text_lines(container, used, state, position)
}
