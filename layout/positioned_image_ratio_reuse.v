module layout

import css
import os

const disable_positioned_image_ratio_reuse = os.getenv('VOX_DISABLE_POSITIONED_IMAGE_RATIO_REUSE') != ''
const disable_positioned_definite_image_reuse = os.getenv('VOX_DISABLE_POSITIONED_DEFINITE_IMAGE_REUSE') != ''
const positioned_definite_image_reuse_diagnostics = os.getenv('VOX_POSITIONED_DEFINITE_IMAGE_REUSE_DIAGNOSTICS') != ''

const positioned_image_ratio_reuse_diagnostics = os.getenv('VOX_POSITIONED_IMAGE_RATIO_REUSE_DIAGNOSTICS') != ''

__global positioned_image_ratio_reuse_reported bool
__global positioned_definite_image_reuse_reported bool

fn positioned_image_size_is_definite(size css.Size, definite_basis bool) bool {
	return size.is_length() || (size.is_percentage() && definite_basis)
		|| (size.is_calculated() && (!size.contains_percentage() || definite_basis))
}

// An out-of-flow image cannot contribute its natural width to its parent's
// intrinsic size. With a definite specified width and ordinary constraints,
// its automatic height depends on the natural ratio, not the natural width.
// Consult the committed containing-block basis, never just a numeric height.
fn positioned_image_geometry_is_independent_of_natural_width(node &Node, state &LayoutState) bool {
	return !disable_positioned_image_ratio_reuse
		&& positioned_image_has_definite_width_and_constraints(node, state)
}

fn positioned_image_has_definite_width_and_constraints(node &Node, state &LayoutState) bool {
	if !node.is_absolutely_positioned() || state == unsafe { nil } { return false }
	styled := node.as_node_with_style() or { return false }
	used := state.try_get(styled) or { return false }
	basis := used.containing_block_used_values() or { return false }
	computed := node.computed_values()
	if !used.has_definite_width()
		|| !positioned_image_size_is_definite(computed.width(), basis.has_definite_width()) {
		return false
	}
	if !computed.height().is_auto()
		&& !positioned_image_size_is_definite(computed.height(), basis.has_definite_height()) {
		return false
	}
	for minimum in [computed.min_width(), computed.min_height()] {
		if !minimum.is_auto() && !positioned_image_size_is_definite(minimum, false) {
			return false
		}
	}
	for maximum in [computed.max_width(), computed.max_height()] {
		if !maximum.is_none() && !positioned_image_size_is_definite(maximum, false) {
			return false
		}
	}
	return true
}

fn positioned_image_natural_ratios_match(previous css.SizeWithAspectRatio, current css.SizeWithAspectRatio) bool {
	if previous.aspect_ratio == none || current.aspect_ratio == none { return false }
	w1 := previous.width or { return false }
	h1 := previous.height or { return false }
	w2 := current.width or { return false }
	h2 := current.height or { return false }
	// Bound the exact cross-products rather than rounding a floating ratio.
	for dimension in [w1, h1, w2, h2] {
		if dimension.raw_value() <= 0
			|| dimension.raw_value() > CSSPixels.new(1_000_000).raw_value() { return false }
	}
	return i64(w1.raw_value()) * i64(h2.raw_value()) == i64(w2.raw_value()) * i64(h1.raw_value())
}

fn report_positioned_image_ratio_reuse() {
	if positioned_image_ratio_reuse_diagnostics && !positioned_image_ratio_reuse_reported {
		positioned_image_ratio_reuse_reported = true
		eprintln('Vox image ratio reuse: preserved positioned image geometry')
	}
}

// Both specified axes resolve independently of the decoded image. An
// out-of-flow image contributes no automatic minimum to its parent's tracks,
// so a first decode or a changed natural ratio only changes its paint input.
fn positioned_image_geometry_is_independent_of_natural_size(node &Node, state &LayoutState) bool {
	if disable_positioned_definite_image_reuse
		|| !positioned_image_has_definite_width_and_constraints(node, state) { return false }
	styled := node.as_node_with_style() or { return false }
	used := state.try_get(styled) or { return false }
	basis := used.containing_block_used_values() or { return false }
	return used.has_definite_height()
		&& positioned_image_size_is_definite(node.computed_values().height(), basis.has_definite_height())
}

fn report_positioned_definite_image_reuse() {
	if positioned_definite_image_reuse_diagnostics && !positioned_definite_image_reuse_reported {
		positioned_definite_image_reuse_reported = true
		eprintln('Vox definite image reuse: repainted positioned raster without intrinsic layout')
	}
}
