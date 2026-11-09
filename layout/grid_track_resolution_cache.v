module layout

import css
import dom
import os
import platform

const disable_grid_track_resolution_reuse = os.getenv('VOX_DISABLE_GRID_TRACK_RESOLUTION_REUSE') != ''
const grid_track_resolution_diagnostics = os.getenv('VOX_GRID_TRACK_RESOLUTION_DIAGNOSTICS') != ''

__global grid_track_resolution_reuse_reported bool

struct GridTrackResolutionKey {
	columns bool
	available CSSPixels
	gap CSSPixels
	definite bool
	implicit_before int
	required int
	repeat_adjustment CSSPixels
	font_policy dom.FontRenderingPolicy
}

@[heap]
struct GridTrackResolutionCache {
	style &css.ComputedValues
	revision u64
	key GridTrackResolutionKey
	tracks []GridTrack
}

// Resolve only tracks whose lengths cannot read fonts, viewport, root metrics
// or another element. Plain percentages read the separately keyed basis.
// Calculated lengths retain their ordinary resolver, even when constant.
fn grid_track_length_is_context_free(value css.LengthPercentage) bool {
	return value.is_percentage() || (value.is_length() && value.length().is_absolute())
}

fn grid_track_size_is_context_free(size css.GridSize) bool {
	if size.is_flexible_length() { return true }
	value := size.css_size()
	if length := value.length_percentage_ { return grid_track_length_is_context_free(length) }
	return !value.is_calculated()
}

fn grid_track_list_is_context_free(list css.GridTrackSizeList) bool {
	if list.is_subgrid() { return false }
	for track in list.track_list() {
		if track.is_repeat() {
			if !grid_track_list_is_context_free(track.repeat().grid_track_size_list()) { return false }
		} else if track.is_minmax() {
			size := track.minmax()
			if !grid_track_size_is_context_free(size.min_grid_size())
				|| !grid_track_size_is_context_free(size.max_grid_size()) { return false }
		} else if !grid_track_size_is_context_free(track.grid_size()) { return false }
	}
	return true
}

// Repeated grid probes start from identical unexpanded track definitions.
// Cache the context-free initial tracks, before sizing/collapse mutates them.
// Selecting both lists here keeps the key tied to the current container style.
fn resolve_grid_axis_tracks_in_state(mut state LayoutState, container &Node, columns bool,
	available CSSPixels, gap CSSPixels, definite bool, implicit_before int, required int) []GridTrack {
	computed := container.computed_values()
	list := grid_template_with_used_repeat_counts(state,container,grid_axis_template(container,columns),available,gap,definite,columns)
	implicit := grid_axis_implicit_tracks(container, columns)
	mut pool := state.measurement_chunk_pool_
	if disable_grid_track_resolution_reuse || pool == unsafe { nil } || pool.closed || grid_lanes_repeat_reads_items(container,list,available) {
		return resolve_grid_tracks_for_axis(container, list, implicit, available, gap, definite, implicit_before, required, columns)
	}
	key := GridTrackResolutionKey{
		columns: columns
 repeat_adjustment:grid_repeat_used_box_adjustment(state,container,columns)
		available: available
		gap: gap
		definite: definite
		implicit_before: implicit_before
		required: required
		font_policy: container.document().font_rendering_policy()
	}
	revision := computed.mutation_revision()
	node_key := u64(voidptr(container))
	previous := pool.grid_track_resolutions_[node_key] or { []&GridTrackResolutionCache{} }
	for cached in previous {
		if cached.key != key || voidptr(cached.style) != voidptr(computed)
			|| cached.revision != revision || computed.has_animated_properties() { continue }
		if grid_track_resolution_diagnostics && !grid_track_resolution_reuse_reported {
			grid_track_resolution_reuse_reported = true
			eprintln('Vox grid tracks: reused owned context-free initial tracks')
		}
		return cached.tracks.clone()
	}
	tracks := resolve_grid_tracks_for_axis(container, list, implicit, available, gap, definite, implicit_before, required, columns)
	if revision == 0 || computed.has_animated_properties()
		|| !grid_track_list_is_context_free(list) || !grid_track_list_is_context_free(implicit) { return tracks }
	mut retained := platform.enter_retained_allocations()
	defer { retained.finish() }
	cached := &GridTrackResolutionCache{
		style: computed
		revision: revision
		key: key
		tracks: tracks.clone()
	}
	mut entries := pool.grid_track_resolutions_[node_key] or { []&GridTrackResolutionCache{} }
	if entries.len == 8 { entries.delete(0) }
	entries << cached
	pool.grid_track_resolutions_[node_key] = entries
	return tracks
}
