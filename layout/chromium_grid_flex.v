module layout

import math

struct ChromiumFlexibleGridTrack {
	base   CSSPixels
	factor f32
}

// Blink's GridTrackSizingAlgorithm::ExpandFlexibleTracks keeps fr sizes in
// float raw LayoutUnits. Freezing a track subtracts its factor from the
// original sum; rebuilding that sum changes the final 1/64px truncation.
fn chromium_expand_flexible_grid_tracks(mut tracks []GridTrack, available CSSPixels, gap CSSPixels) {
	mut flexible := []ChromiumFlexibleGridTrack{}
	mut remaining := available.minus(gap.scaled(f64(grid_gutter_count(tracks, 0, tracks.len - 1))))
	mut factor_sum := f32(0)
	for track in tracks {
		if track.flex > 0 {
			factor := f32(track.flex)
			if math.is_inf(factor, 0) || math.is_nan(factor) {
				expand_flexible_grid_tracks(mut tracks, available, gap)
				return
			}
			factor_sum = f32(factor_sum + factor)
			flexible << ChromiumFlexibleGridTrack{track.base_size, factor}
		} else {
			remaining = remaining.minus(track.base_size)
		}
	}
	if flexible.len == 0 || remaining.raw_value() <= 0 { return }
	if math.is_inf(factor_sum, 0) {
		expand_flexible_grid_tracks(mut tracks, available, gap)
		return
	}
	flexible.sort_with_compare(fn (a &ChromiumFlexibleGridTrack, b &ChromiumFlexibleGridTrack) int {
		left := f32(f32(a.base.raw_value()) * b.factor)
		right := f32(f32(b.base.raw_value()) * a.factor)
		return if left > right {
			-1
		} else if left < right {
			1
		} else {
			0
		}
	})
	mut current := 0
	mut fr_size := f32(0)
	for remaining.raw_value() > 0 && current < flexible.len {
		factor_sum = math.max(factor_sum, f32(1))
		mut next := current
		for next < flexible.len
			&& f32(flexible[next].factor * f32(remaining.raw_value())) <
				f32(f32(flexible[next].base.raw_value()) * factor_sum) {
			next++
		}
		if next == current {
			fr_size = f32(f32(remaining.raw_value()) / factor_sum)
			break
		}
		for index in current .. next {
			factor_sum = f32(factor_sum - flexible[index].factor)
			remaining = remaining.minus(flexible[index].base)
		}
		current = next
	}
	mut leftover := f32(0)
	for index in 0 .. tracks.len {
		if tracks[index].flex <= 0 { continue }
		product := f32(fr_size * f32(tracks[index].flex))
		share := f32(product + leftover)
		// LayoutUnit::FromRawValue truncates after adding float epsilon.
		expanded := CSSPixels.truncated_value_for(f64(f32(share + f32(1.1920928955078125e-7))) / 64)
		if expanded.raw_value() >= tracks[index].base_size.raw_value() {
			tracks[index].base_size = expanded
			leftover = math.max(f32(share - f32(expanded.raw_value())), f32(0))
		}
	}
}
