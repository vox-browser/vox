module css

import os

const disable_resolved_edge_reuse = os.getenv('VOX_DISABLE_RESOLVED_EDGE_REUSE') != ''
const resolved_edge_reuse_diagnostics = os.getenv('VOX_RESOLVED_EDGE_REUSE_DIAGNOSTICS') != ''

__global resolved_edge_reuse_reported bool

enum ResolvedBoxEdgeKind {
	unclassified
	live_context
	fixed_edges
	percentage_edges
}

// A derived scalar memo belongs to the immutable typed edge snapshot. Shared
// snapshots may share it: the width and rounding policy identify every input
// of eligible absolute/percentage edges. Relative units and calculations keep
// their live font/viewport/container resolution.
struct ResolvedBoxEdgeMemo {
mut:
	kind     ResolvedBoxEdgeKind
	valid    bool
	basis    CSSPixels
	truncate bool
	edges    ResolvedBoxModelEdges
}

fn resolved_box_edge_kind(cache &ComputedLayoutCache) ResolvedBoxEdgeKind {
	mut kind := ResolvedBoxEdgeKind.fixed_edges
	p := cache.computed_values_padding_
	m := cache.computed_values_margin_
	for value in [p.left(), p.right(), p.top(), p.bottom(), m.left(), m.right(), m.top(), m.bottom()]! {
		resolved := value.length_percentage_ or { continue }
		if resolved.is_percentage() {
			kind = .percentage_edges
			continue
		}
		if !resolved.is_length() || !resolved.length().is_absolute() { return .live_context }
	}
	return kind
}

// Used edges stay in CSSPixels throughout layout. Resolving the complete box
// reads its typed style snapshot once and avoids a property dispatch and a
// fixed-point/double/fixed-point round trip for each individual side.
pub struct ResolvedBoxModelEdges {
pub:
	padding_left   CSSPixels
	padding_right  CSSPixels
	padding_top    CSSPixels
	padding_bottom CSSPixels
	border_left    CSSPixels
	border_right   CSSPixels
	border_top     CSSPixels
	border_bottom  CSSPixels
	margin_left    CSSPixels
	margin_right   CSSPixels
	margin_top     CSSPixels
	margin_bottom  CSSPixels
}

fn (values &ComputedValues) resolve_box_model_length(value LengthPercentageOrAuto, basis CSSPixels) CSSPixels {
	resolved := value.length_percentage_ or { return CSSPixels.new(0) }
	properties := unsafe { &ComputedProperties(values) }
	if resolved.is_length() {
		length := resolved.length()
		if length.is_absolute() { return properties.absolute_layout_length_to_px(length) }
	} else if resolved.is_percentage() {
		return resolved.to_px(LengthResolutionContext{}, basis)
	}
	// Relative units and calculations keep their live font, viewport and query
	// container context, exactly as the individual property accessor does.
	return resolved.to_px(properties.length_resolution_context(), basis)
}

fn (values &ComputedValues) uncached_resolved_box_model_edges(containing_block_width f64) ResolvedBoxModelEdges {
	cache := values.computed_layout_cache()
	padding := cache.computed_values_padding_
	margin := cache.computed_values_margin_
	basis := CSSPixels.nearest_value_for(containing_block_width)
	return ResolvedBoxModelEdges{
		padding_left:   values.resolve_box_model_length(padding.left(), basis)
		padding_right:  values.resolve_box_model_length(padding.right(), basis)
		padding_top:    values.resolve_box_model_length(padding.top(), basis)
		padding_bottom: values.resolve_box_model_length(padding.bottom(), basis)
		border_left:    cache.computed_values_border_left_.width
		border_right:   cache.computed_values_border_right_.width
		border_top:     cache.computed_values_border_top_.width
		border_bottom:  cache.computed_values_border_bottom_.width
		margin_left:    values.resolve_box_model_length(margin.left(), basis)
		margin_right:   values.resolve_box_model_length(margin.right(), basis)
		margin_top:     values.resolve_box_model_length(margin.top(), basis)
		margin_bottom:  values.resolve_box_model_length(margin.bottom(), basis)
	}
}

// Only typed margin/padding and border setters change this snapshot; each
// clears the derived memo after taking the normal copy-on-write owner.
pub fn (values &ComputedValues) resolved_box_model_edges(containing_block_width f64) ResolvedBoxModelEdges {
	if disable_resolved_edge_reuse {
		return values.uncached_resolved_box_model_edges(containing_block_width)
	}
	mut cache := unsafe { &ComputedLayoutCache(values.computed_layout_cache()) }
	if cache.resolved_edge_memo_.kind == .unclassified {
		cache.resolved_edge_memo_.kind = resolved_box_edge_kind(cache)
	}
	if cache.resolved_edge_memo_.kind == .live_context {
		return values.uncached_resolved_box_model_edges(containing_block_width)
	}
	properties := unsafe { &ComputedProperties(values) }
	truncate := properties.absolute_layout_lengths_are_truncated()
	basis := CSSPixels.nearest_value_for(containing_block_width)
	if cache.resolved_edge_memo_.valid && cache.resolved_edge_memo_.truncate == truncate
		&& (cache.resolved_edge_memo_.kind == .fixed_edges || cache.resolved_edge_memo_.basis == basis) {
		if resolved_edge_reuse_diagnostics && !resolved_edge_reuse_reported {
			resolved_edge_reuse_reported = true
			eprintln('Vox box edges: reused resolved absolute/percentage snapshot')
		}
		return cache.resolved_edge_memo_.edges
	}
	edges := values.uncached_resolved_box_model_edges(containing_block_width)
	cache.resolved_edge_memo_.edges = edges
	cache.resolved_edge_memo_.basis = basis
	cache.resolved_edge_memo_.truncate = truncate
	cache.resolved_edge_memo_.valid = true
	return edges
}
