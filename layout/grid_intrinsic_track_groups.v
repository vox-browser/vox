// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

module layout

struct GridSpanGroupContribution {
	start               int
	span                int
	minimum             CSSPixels
	min_content         CSSPixels
	max_content         CSSPixels
	limited_max_content CSSPixels
}

enum GridSpanGroupPhase {
	minimum
	min_content
	limited_max_content
	max_content
	intrinsic_maximum
	max_content_maximum
}

fn (item GridSpanGroupContribution) contribution(phase GridSpanGroupPhase) CSSPixels {
	return match phase {
		.minimum { item.minimum }
		.min_content, .intrinsic_maximum { item.min_content }
		.limited_max_content { item.limited_max_content }
		.max_content, .max_content_maximum { item.max_content }
	}
}

fn grid_span_group_phase_affects(track GridTrack, phase GridSpanGroupPhase) bool {
	if track.collapsed || track.flexible || track.flex > 0 { return false }
	return match phase {
		.minimum { track.minimum_intrinsic }
		.min_content { track.min_content_min || track.max_content_min }
		.limited_max_content { track.auto_min || track.max_content_min }
		.max_content { track.max_content_min }
		.intrinsic_maximum {
			track.auto_max || track.min_content_max || track.max_content_max || track.fit_content_max
		}
		.max_content_maximum { track.auto_max || track.max_content_max || track.fit_content_max }
	}
}

fn grid_span_group_grows_beyond_limit(track GridTrack, phase GridSpanGroupPhase) bool {
	return match phase {
		.minimum, .min_content, .intrinsic_maximum, .max_content_maximum {
			track.auto_max || track.min_content_max || track.max_content_max || track.fit_content_max
		}
		.limited_max_content, .max_content {
			track.auto_max || track.max_content_max || track.fit_content_max
		}
	}
}

// CSS Grid 12.5.1: each item plans an increase against the same track sizes.
// Apply only the largest increase per track once the entire span group has
// completed this phase. Frozen state belongs to the current item and phase.
fn distribute_grid_span_group_phase(mut tracks []GridTrack, group []GridSpanGroupContribution,
	gap CSSPixels, phase GridSpanGroupPhase) {
	growth_limits := phase in [.intrinsic_maximum, .max_content_maximum]
	mut planned := []CSSPixels{len: tracks.len}
	mut affected_in_group := []bool{len: tracks.len}
	mut incurred := []CSSPixels{len: tracks.len}
	mut frozen := []bool{len: tracks.len}
	for item in group {
		first := if item.start > 0 { item.start } else { 0 }
		last := if item.start + item.span < tracks.len { item.start + item.span } else { tracks.len }
		if first >= last { continue }
		mut affected := []int{}
		// Gutters remain fixed in both base-size and growth-limit distribution.
		mut accounted := gap.scaled(f64(grid_gutter_count(tracks, first, last - 1)))
		for index in first .. last {
			track := tracks[index]
			accounted = accounted.plus(if growth_limits && track.has_growth_limit {
				track.growth_limit
			} else {
				track.base_size
			})
			incurred[index] = CSSPixels.new(0)
			frozen[index] = false
			if grid_span_group_phase_affects(track, phase) {
				affected << index
				affected_in_group[index] = true
			}
		}
		if affected.len == 0 { continue }
		mut remaining := css_pixels_max(item.contribution(phase).minus(accounted), CSSPixels.new(0))
		for remaining.raw_value() > 0 {
			mut unfrozen := 0
			for index in affected {
				if !frozen[index] { unfrozen++ }
			}
			if unfrozen == 0 { break }
			share := CSSPixels.from_raw(if remaining.raw_value() / unfrozen > 0 {
				remaining.raw_value() / unfrozen
			} else { 1 })
			for index in affected {
				if frozen[index] { continue }
				track := tracks[index]
				mut increase := css_pixels_min(share, remaining)
				mut room := ?CSSPixels(none)
				if growth_limits {
					if !track.infinitely_growable && track.has_growth_limit {
						room = if track.fit_content_max && track.has_fit_content_limit {
							css_pixels_max(track.fit_content_limit.minus(track.growth_limit), CSSPixels.new(0))
						} else {
							CSSPixels.new(0)
						}
					}
				} else {
					mut limit := if track.has_growth_limit { ?CSSPixels(track.growth_limit) } else { none }
					if track.fit_content_max && track.has_fit_content_limit {
						limit = if existing := limit {
							css_pixels_min(existing, track.fit_content_limit)
						} else {
							track.fit_content_limit
						}
					}
					if limit_value := limit { room = limit_value.minus(track.base_size) }
				}
				if available_room := room {
					if incurred[index].plus(increase).raw_value() >= available_room.raw_value() {
						frozen[index] = true
						increase = css_pixels_max(available_room.minus(incurred[index]), CSSPixels.new(0))
					}
				}
				incurred[index] = incurred[index].plus(increase)
				remaining = remaining.minus(increase)
			}
		}
		if remaining.raw_value() > 0 {
			mut beyond_limits := []int{}
			for index in affected {
				if grid_span_group_grows_beyond_limit(tracks[index], phase) {
					beyond_limits << index
				}
			}
			if !growth_limits && beyond_limits.len == 0 {
				beyond_limits = affected.clone()
			}
			if beyond_limits.len > 0 {
				share := CSSPixels.from_raw(remaining.raw_value() / beyond_limits.len)
				for index in beyond_limits {
					increase := css_pixels_min(share, remaining)
					incurred[index] = incurred[index].plus(increase)
					remaining = remaining.minus(increase)
				}
			}
		}
		for index in affected { planned[index] = css_pixels_max(planned[index], incurred[index]) }
	}
	for index in 0 .. tracks.len {
		if !affected_in_group[index] { continue }
		if !growth_limits {
			tracks[index].base_size = tracks[index].base_size.plus(planned[index])
			continue
		}
		if tracks[index].has_growth_limit {
			tracks[index].growth_limit = tracks[index].growth_limit.plus(planned[index])
		} else {
			tracks[index].growth_limit = tracks[index].base_size.plus(planned[index])
			tracks[index].has_growth_limit = true
			tracks[index].infinitely_growable = phase == .intrinsic_maximum
		}
		if phase == .max_content_maximum && tracks[index].fit_content_max
			&& tracks[index].has_fit_content_limit {
			tracks[index].growth_limit = css_pixels_max(tracks[index].base_size,
				css_pixels_min(tracks[index].growth_limit, tracks[index].fit_content_limit))
		}
	}
}

fn resolve_grid_intrinsic_span_group(mut tracks []GridTrack, group []GridSpanGroupContribution,
	gap CSSPixels, available AvailableSize) {
	if group.len == 0 { return }
	for phase in [GridSpanGroupPhase.minimum, .min_content, .limited_max_content,
		.max_content, .intrinsic_maximum, .max_content_maximum] {
		if phase == .limited_max_content && !available.is_max_content() { continue }
		// Finish every base-size phase before measuring growth-limit increases.
		if phase == .intrinsic_maximum {
			for index in 0 .. tracks.len {
				if tracks[index].has_growth_limit {
					tracks[index].growth_limit = css_pixels_max(tracks[index].growth_limit, tracks[index].base_size)
				}
			}
		}
		distribute_grid_span_group_phase(mut tracks, group, gap, phase)
	}
	// Infinite-to-finite growth applies only to the following maximum phase
	// of this span group, never to the next group.
	for index in 0 .. tracks.len { tracks[index].infinitely_growable = false }
}
