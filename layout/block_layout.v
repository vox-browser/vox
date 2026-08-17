module layout

import css

// First slices of the block layout algorithm (Layout/BlockFormattingContext.cpp + FormattingContext.cpp):
// resolve a box's used box-model edges from its computed style, and compute the used width of a
// normal-flow block-level box per CSS 2.1 §10.3.3 (including auto width / auto margins).
//
// DEFERRED: min/max-width clamping, replaced/inline/float/abspos width, over-constrained resolution
// direction (assumes LTR, drops margin-right), border-width vs border-style interaction, and vertical
// layout (heights + child stacking) — later slices.

fn css_px(value f64) CSSPixels {
	return CSSPixels.nearest_value_for(value)
}

// Whether `property_id`'s computed value is the `auto` keyword.
fn property_is_auto(computed &css.ComputedProperties, property_id css.PropertyID) bool {
	value := computed.property(property_id, .yes) or { return false }
	return value.css_text.trim_space().to_lower() == 'auto'
}

// The used border width for one side: 0 if that side's border-style is none/hidden (CSS 2.1 §8.5.3),
// otherwise the resolved border-width.
fn resolve_used_border_width(computed &css.ComputedProperties, width_property css.PropertyID, style_property css.PropertyID, containing_block_width f64) f64 {
	style_value := computed.property(style_property, .yes) or { return 0.0 }
	style_keyword := style_value.css_text.trim_space().to_lower()
	if style_keyword == 'none' || style_keyword == 'hidden' {
		return 0.0
	}
	return computed.length_percentage_to_px(width_property, containing_block_width) or { 0.0 }
}

// Resolve the used margin/border/padding edges from `computed` into `used_values`. `containing_block_width`
// is the percentage basis. `auto` margins resolve to 0 here (compute_block_used_width may reassign them).
fn resolve_box_model_edges(computed &css.ComputedProperties, mut used_values UsedValues, containing_block_width f64) {
	used_values.padding_left = css_px(computed.length_percentage_to_px(.padding_left,
		containing_block_width) or { 0.0 })
	used_values.padding_right = css_px(computed.length_percentage_to_px(.padding_right,
		containing_block_width) or { 0.0 })
	used_values.padding_top = css_px(computed.length_percentage_to_px(.padding_top,
		containing_block_width) or { 0.0 })
	used_values.padding_bottom = css_px(computed.length_percentage_to_px(.padding_bottom,
		containing_block_width) or { 0.0 })

	// CSS 2.1 §8.5.3: the used border width is 0 when the border style is none or hidden.
	used_values.border_left = css_px(resolve_used_border_width(computed, .border_left_width,
		.border_left_style, containing_block_width))
	used_values.border_right = css_px(resolve_used_border_width(computed, .border_right_width,
		.border_right_style, containing_block_width))
	used_values.border_top = css_px(resolve_used_border_width(computed, .border_top_width,
		.border_top_style, containing_block_width))
	used_values.border_bottom = css_px(resolve_used_border_width(computed, .border_bottom_width,
		.border_bottom_style, containing_block_width))

	// auto margins resolve to 0 for now (width computation reassigns them for centering).
	used_values.margin_left = css_px(computed.length_percentage_to_px(.margin_left,
		containing_block_width) or { 0.0 })
	used_values.margin_right = css_px(computed.length_percentage_to_px(.margin_right,
		containing_block_width) or { 0.0 })
	used_values.margin_top = css_px(computed.length_percentage_to_px(.margin_top,
		containing_block_width) or { 0.0 })
	used_values.margin_bottom = css_px(computed.length_percentage_to_px(.margin_bottom,
		containing_block_width) or { 0.0 })
}

// CSS 2.1 §10.3.3: compute the used content width (and resolve auto margins) of a normal-flow block-level
// box, given its containing block's width. Assumes resolve_box_model_edges already ran.
fn compute_block_used_width(computed &css.ComputedProperties, mut used_values UsedValues, containing_block_width f64) {
	// Non-content horizontal edges (border + padding).
	edges := used_values.border_left.to_double() + used_values.padding_left.to_double() +
		used_values.padding_right.to_double() + used_values.border_right.to_double()

	width_is_auto := property_is_auto(computed, .width)
	margin_left_auto := property_is_auto(computed, .margin_left)
	margin_right_auto := property_is_auto(computed, .margin_right)

	// §10.3.3 tentative content width.
	mut width := 0.0
	if width_is_auto {
		// auto width fills the containing block; auto margins are treated as 0.
		margin_left := if margin_left_auto { 0.0 } else { used_values.margin_left.to_double() }
		margin_right := if margin_right_auto { 0.0 } else { used_values.margin_right.to_double() }
		width = containing_block_width - margin_left - margin_right - edges
		if width < 0.0 {
			width = 0.0
		}
		if margin_left_auto {
			used_values.margin_left = css_px(0.0)
		}
		if margin_right_auto {
			used_values.margin_right = css_px(0.0)
		}
	} else {
		width = computed.length_percentage_to_px(.width, containing_block_width) or { 0.0 }
	}

	// §10.4: clamp to [min-width, max-width].
	clamped := clamp_to_min_max(computed, .min_width, .max_width, width, containing_block_width)
	used_values.set_content_width(css_px(clamped))

	// Resolve auto margins against the used (now definite) width — for an explicit width, or an auto width
	// that clamping shrank below the fill.
	if !width_is_auto || clamped != width {
		resolve_auto_margins(computed, mut used_values, containing_block_width, clamped)
	}
}

// Resolve auto left/right margins to absorb the remaining inline space (centering when both are auto),
// given a definite content `width` (CSS 2.1 §10.3.3).
fn resolve_auto_margins(computed &css.ComputedProperties, mut used_values UsedValues, containing_block_width f64, width f64) {
	edges := used_values.border_left.to_double() + used_values.padding_left.to_double() +
		used_values.padding_right.to_double() + used_values.border_right.to_double()
	margin_left_auto := property_is_auto(computed, .margin_left)
	margin_right_auto := property_is_auto(computed, .margin_right)
	fixed_margin_left := if margin_left_auto { 0.0 } else { used_values.margin_left.to_double() }
	fixed_margin_right := if margin_right_auto { 0.0 } else { used_values.margin_right.to_double() }
	remaining := containing_block_width - width - edges - fixed_margin_left - fixed_margin_right

	if margin_left_auto && margin_right_auto {
		half := remaining / 2.0
		used_values.margin_left = css_px(half)
		used_values.margin_right = css_px(half)
	} else if margin_left_auto {
		used_values.margin_left = css_px(remaining)
	} else if margin_right_auto {
		used_values.margin_right = css_px(remaining)
	}
	// FIXME: over-constrained (no auto) — CSS 2.1 ignores margin-right in LTR; not adjusted here.
}

// Clamp `value` to [min, max] resolved from `min_property`/`max_property` (CSS 2.1 §10.4/§10.7). A `none`
// max (or a keyword/auto min/max) does not constrain; min defaults to 0.
fn clamp_to_min_max(computed &css.ComputedProperties, min_property css.PropertyID, max_property css.PropertyID, value f64, percentage_basis f64) f64 {
	mut result := value
	if max := computed.length_percentage_to_px(max_property, percentage_basis) {
		if result > max {
			result = max
		}
	}
	min := computed.length_percentage_to_px(min_property, percentage_basis) or { 0.0 }
	if result < min {
		result = min
	}
	return result
}

// Lay out `box` as a block formatting context root (BlockFormattingContext::run for a normal block
// container), writing geometry into `state`: resolve the box's width, lay out its block-level descendants in
// normal flow (its BFC), then compute the box's height. `containing_block_width` is the content width of the
// box's containing block. As a BFC root, the box's own margins do not collapse with its children (CSS 2.1
// §8.3.1); child stacking and margin collapsing happen inside the context (layout_block_level_box). Used as
// a standalone entry point (e.g. by tests); the document path goes through layout_viewport.
//
// DEFERRED: inline/flex/grid/table/replaced/float/abspos content, and writing modes.
pub fn layout_block_flow(mut state LayoutState, box &NodeWithStyle, containing_block_width f64, containing_block_height ?f64) {
	computed := box.computed_values()
	mut used_values := state.get_mutable(box)
	resolve_box_model_edges(computed, mut used_values, containing_block_width)
	compute_block_used_width(computed, mut used_values, containing_block_width)
	content_width := used_values.content_width().to_double()

	// This box's definite content height, if any (an explicit length, or a percentage resolved against the
	// containing block's definite height). Children resolve their own percentage heights against it.
	definite_content_height := resolve_definite_content_height(computed, containing_block_height)

	box_as_node := unsafe { &Node(box) }

	// Establish the content height from the box's children. FIXME: mixed block+inline content (which needs
	// anonymous block boxes) is not handled — a box with any inline (text) child is laid out as an inline
	// formatting context, otherwise as a block formatting context.
	mut content_height_from_children := 0.0
	if box_has_inline_content(box_as_node) {
		// Inline formatting context (first slice): lay the inline content out as a single line box of the
		// computed line-height. FIXME: no text measurement, line breaking/wrapping, multiple lines,
		// baselines, or per-fragment positioning yet.
		content_height_from_children = computed_line_height_px(computed)
	} else {
		// Block formatting context: lay out the block children, collapsing adjacent-sibling and parent-child
		// vertical margins (CSS 2.1 §8.3.1). `box` is treated as the BFC root, whose own margins (per §8.3.1)
		// do not collapse with its children — that is handled per-child inside the context.
		mut block_formatting_context := BlockFormattingContext{}
		content_height_from_children = block_formatting_context.layout_block_level_children(mut state,
			box, content_width, definite_content_height)
	}

	// Height (CSS 2.1 §10.6): use the definite height if the box has one, else the content height from
	// its children (auto).
	mut height := definite_content_height or { content_height_from_children }
	// §10.7: clamp to [min-height, max-height] (a percentage min/max against the containing block height).
	height = clamp_to_min_max(computed, .min_height, .max_height, height, containing_block_height or {
		0.0
	})
	used_values.set_content_height(css_px(height))
	// Like BlockFormattingContext::resolve_used_height_if_not_treated_as_auto,
	// definiteness is established by resolving the computed height, not by the
	// generic UsedValues setter. An auto height remains indefinite.
	if definite_content_height != none {
		used_values.set_has_definite_height(true)
	}
}

// This box's definite content height, or none if it's auto (or a percentage against an indefinite
// containing-block height). CSS 2.1 §10.5: a percentage height resolves against the containing block's
// height only when that height is itself definite; otherwise the height is treated as auto.
fn resolve_definite_content_height(computed &css.ComputedProperties, containing_block_height ?f64) ?f64 {
	if property_is_auto(computed, .height) {
		return none
	}
	if property_is_percentage(computed, .height) {
		basis := containing_block_height or { return none }
		return computed.length_percentage_to_px(.height, basis)
	}
	return computed.length_percentage_to_px(.height, 0.0)
}

// Whether `property_id`'s computed value is a percentage.
fn property_is_percentage(computed &css.ComputedProperties, property_id css.PropertyID) bool {
	value := computed.property(property_id, .yes) or { return false }
	return value.css_text.trim_space().ends_with('%')
}

// Whether `box_node` has inline-level (text) content that establishes an inline formatting context.
// FIXME: also detect inline-level element boxes, not just text nodes.
fn box_has_inline_content(box_node &Node) bool {
	for child in box_node.children() {
		if child.is_text_node() {
			return true
		}
	}
	return false
}

// The computed line-height in px. FIXME: read the line-height property (normal / <number> / <length>);
// currently approximates `normal` as 1.2 * font-size.
fn computed_line_height_px(computed &css.ComputedProperties) f64 {
	return computed.resolved_font_size_px() * 1.2
}

// Lay out the Viewport — the layout tree's root and the initial containing block. Its content box is pinned
// to the viewport rectangle (definite width AND height); then its child (the root element box) is laid out
// within a fresh block formatting context. Faithful to Document::update_layout's root-formatting-context
// setup (Document.cpp) + BlockFormattingContext::layout_viewport: the viewport state's content size is set
// to the viewport rect, so the ICB (document element) fills the viewport width and root-level percentage
// heights resolve against the definite viewport height. Unlike a normal block, the viewport's own dimensions
// are NOT computed from its style — they are the viewport rect.
pub fn layout_viewport(mut state LayoutState, viewport &Viewport, viewport_width f64, viewport_height f64) {
	viewport_node_with_style := unsafe { &NodeWithStyle(viewport) }
	mut viewport_used_values := state.get_mutable(viewport_node_with_style)
	viewport_used_values.set_content_width(css_px(viewport_width))
	viewport_used_values.set_content_height(css_px(viewport_height))
	viewport_used_values.set_has_definite_height(true)

	mut block_formatting_context := BlockFormattingContext{}
	block_formatting_context.layout_block_level_children(mut state, viewport_node_with_style,
		viewport_width, viewport_height)
}
