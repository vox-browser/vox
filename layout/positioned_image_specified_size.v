module layout

import dom
import os

const retain_positioned_image_load_layout = os.getenv('VOX_RETAIN_POSITIONED_IMAGE_LOAD_LAYOUT') != ''
const positioned_image_specified_size_diagnostics = os.getenv('VOX_POSITIONED_IMAGE_SPECIFIED_SIZE_DIAGNOSTICS') != ''

__global positioned_image_specified_size_reported_document dom.UniqueNodeID

// The existing positioned-image guard excludes intrinsic constraints and
// verifies the committed percentage bases. With both axes specified, or an
// author-only ratio supplying the automatic height, natural dimensions cannot
// change this out-of-flow box's size, including at its first image completion.
fn positioned_image_has_independent_specified_size(node &Node, state &LayoutState) bool {
	if retain_positioned_image_load_layout
		|| !positioned_image_geometry_is_independent_of_natural_width(node, state) {
		return false
	}
	computed := node.computed_values()
	if computed.writing_mode() != .horizontal_tb { return false }
	styled := node.as_node_with_style() or { return false }
	used := state.try_get(styled) or { return false }
	basis := used.containing_block_used_values() or { return false }
	if !computed.height().is_auto() {
		return used.has_definite_height()
			&& positioned_image_size_is_definite(computed.height(), basis.has_definite_height())
	}
	aspect := computed.aspect_ratio()
	if aspect.use_natural_aspect_ratio_if_available { return false }
	ratio := aspect.preferred_ratio or { return false }
	// Bounded positive components exclude degenerate/nonfinite ratios and
	// extreme arithmetic; those cases retain ordinary layout.
	return ratio.numerator() > 0 && ratio.numerator() <= 1_000_000
		&& ratio.denominator() > 0 && ratio.denominator() <= 1_000_000
}

fn report_positioned_image_specified_size(node &Node) {
	if !positioned_image_specified_size_diagnostics { return }
	document := node.document()
	identity := document.as_node().unique_id()
	if positioned_image_specified_size_reported_document != identity {
		positioned_image_specified_size_reported_document = identity
		eprintln('Vox positioned image: preserved specified geometry on intrinsic update; document=${document.url.serialize()}')
	}
}
