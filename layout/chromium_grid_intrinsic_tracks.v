module layout

// Blink's GridTrackSizingAlgorithm::ResolveIntrinsicTrackSizes for items that
// do not cross a flexible track. Each group of items with the same span runs
// one contribution step for all of its items before the next step starts, and
// a track grows by the largest increase that any single item planned for it.
// Processing an item's growth limits before the next item's base sizes would
// give an empty spanned track a finite zero limit and spread a later item's
// extra space over tracks that Blink leaves alone.
enum ChromiumGridContribution {
	intrinsic_minimums
	content_based_minimums
	max_content_minimums
	intrinsic_maximums
	max_content_maximums
}

const chromium_grid_contributions = [ChromiumGridContribution.intrinsic_minimums,
	.content_based_minimums, .max_content_minimums, .intrinsic_maximums, .max_content_maximums]

struct ChromiumGridSpanningContribution {
	start       int
	span        int
	minimum     CSSPixels
	min_content CSSPixels
	max_content CSSPixels
}

fn (item ChromiumGridSpanningContribution) size(kind ChromiumGridContribution) CSSPixels {
	return match kind {
		.intrinsic_minimums { item.minimum }
		.content_based_minimums, .intrinsic_maximums { item.min_content }
		.max_content_minimums, .max_content_maximums { item.max_content }
	}
}

fn chromium_grid_is_growth_limit_step(kind ChromiumGridContribution) bool {
	return kind in [.intrinsic_maximums, .max_content_maximums]
}

fn chromium_grid_intrinsic_max(track GridTrack) bool {
	return track.auto_max || track.min_content_max || track.max_content_max || track.fit_content_max
}

fn chromium_grid_max_content_or_auto_max(track GridTrack) bool {
	return track.auto_max || track.max_content_max || track.fit_content_max
}

// IsContributionAppliedToSet. Blink does not yet treat an auto minimum as
// max-content under a max-content constraint.
fn chromium_grid_contribution_applies(track GridTrack, kind ChromiumGridContribution) bool {
	return match kind {
		.intrinsic_minimums { track.minimum_intrinsic }
		.content_based_minimums { track.min_content_min || track.max_content_min }
		.max_content_minimums { track.max_content_min }
		.intrinsic_maximums { chromium_grid_intrinsic_max(track) }
		.max_content_maximums { chromium_grid_max_content_or_auto_max(track) }
	}
}

// ShouldUsedSizeGrowBeyondLimit.
fn chromium_grid_grows_beyond_limit(track GridTrack, kind ChromiumGridContribution) bool {
	return match kind {
		.intrinsic_minimums, .content_based_minimums { chromium_grid_intrinsic_max(track) }
		.max_content_minimums { chromium_grid_max_content_or_auto_max(track) }
		.intrinsic_maximums, .max_content_maximums { false }
	}
}

fn chromium_grid_definite_growth_limit(track GridTrack) i64 {
	return i64(if track.has_growth_limit { track.growth_limit } else { track.base_size }.raw_value())
}

fn chromium_grid_affected_size(track GridTrack, kind ChromiumGridContribution) i64 {
	if chromium_grid_is_growth_limit_step(kind) {
		return chromium_grid_definite_growth_limit(track)
	}
	return i64(track.base_size.raw_value())
}

// GrowthPotentialForSet in raw LayoutUnits; none is infinite potential.
fn chromium_grid_growth_potential(track GridTrack, incurred i64, kind ChromiumGridContribution,
	enforce_infinitely_growable bool) ?i64 {
	if !chromium_grid_is_growth_limit_step(kind) {
		if !track.has_growth_limit { return none }
		potential := i64(track.growth_limit.raw_value()) - i64(track.base_size.raw_value()) - incurred
		return if potential > 0 { potential } else { i64(0) }
	}
	if enforce_infinitely_growable && track.has_growth_limit && !track.infinitely_growable {
		return i64(0)
	}
	if track.fit_content_max && track.has_fit_content_limit {
		potential := i64(track.fit_content_limit.raw_value()) - chromium_grid_definite_growth_limit(track) - incurred
		return if potential > 0 { potential } else { i64(0) }
	}
	return none
}

fn chromium_grid_potential_is_zero(potential ?i64) bool {
	if value := potential { return value == 0 }
	return false
}

// DistributeExtraSpaceToSets with equal shares. Every Vox track is its own
// set, so each set contributes one share.
// An empty beyond-limit list grows the sorted sets themselves, as Blink passes
// the same vector it has just sorted.
fn chromium_grid_distribute_equally(tracks []GridTrack, sets_to_grow []int, beyond_limit_sets []int,
	extra_space i64, kind ChromiumGridContribution, mut incurred []i64) {
	mut extra := extra_space
	mut growable := 0
	for index in sets_to_grow {
		incurred[index] = 0
		if !chromium_grid_potential_is_zero(chromium_grid_growth_potential(tracks[index], 0, kind, true)) {
			growable++
		}
	}
	mut order := sets_to_grow.clone()
	if growable > 0 || chromium_grid_is_growth_limit_step(kind) {
		// Non-decreasing growth potential, ignoring "infinitely growable";
		// infinite potentials last. A stable insertion keeps tied tracks in
		// order, as std::sort does for these small ranges.
		for i in 1 .. order.len {
			current := order[i]
			current_potential := chromium_grid_growth_potential(tracks[current], 0, kind, false)
			mut j := i
			for j > 0 {
				previous_potential := chromium_grid_growth_potential(tracks[order[j - 1]], 0, kind, false)
				if !chromium_grid_potential_less(current_potential, previous_potential) { break }
				order[j] = order[j - 1]
				j--
			}
			order[j] = current
		}
	}
	mut share_sum := growable
	for index in order {
		if growable == 0 { break }
		potential := chromium_grid_growth_potential(tracks[index], incurred[index], kind, true)
		if chromium_grid_potential_is_zero(potential) { continue }
		mut share := i64(0)
		if share_sum == 1 {
			share = extra
			growable = 1
		} else {
			share = extra / i64(share_sum)
		}
		if value := potential { share = if share < value { share } else { value } }
		growable--
		share_sum--
		extra -= share
		incurred[index] = share
	}
	beyond_limit := if beyond_limit_sets.len == 0 { order } else { beyond_limit_sets }
	if extra == 0 { return }
	// Distribute space beyond limits: base sizes may grow indefinitely, growth
	// limits up to their fit-content argument.
	growable = 0
	for index in beyond_limit {
		if chromium_grid_beyond_limit_potential(tracks[index], incurred[index], kind) != 0 { growable++ }
	}
	share_sum = growable
	for index in beyond_limit {
		if growable == 0 { break }
		potential := chromium_grid_beyond_limit_potential(tracks[index], incurred[index], kind)
		if potential == 0 { continue }
		mut share := if share_sum == 1 { extra } else { extra / i64(share_sum) }
		if share_sum == 1 { growable = 1 }
		if potential > 0 { share = if share < potential { share } else { potential } }
		growable--
		share_sum--
		extra -= share
		incurred[index] += share
	}
}

// Beyond-limit potential: -1 is infinite.
fn chromium_grid_beyond_limit_potential(track GridTrack, incurred i64, kind ChromiumGridContribution) i64 {
	if !chromium_grid_is_growth_limit_step(kind) { return -1 }
	if potential := chromium_grid_growth_potential(track, incurred, kind, false) { return potential }
	return -1
}

fn chromium_grid_potential_less(left ?i64, right ?i64) bool {
	if l := left {
		if r := right { return l < r }
		return true
	}
	return false
}

// IncreaseTrackSizesToAccommodateGridItems for one contribution step.
fn chromium_grid_increase_tracks_for_group(mut tracks []GridTrack, group []ChromiumGridSpanningContribution,
	gap CSSPixels, kind ChromiumGridContribution) {
	mut planned := []i64{len: tracks.len, init: -1}
	mut incurred := []i64{len: tracks.len}
	for item in group {
		first := if item.start > 0 { item.start } else { 0 }
		last := if item.start + item.span < tracks.len { item.start + item.span } else { tracks.len }
		if first >= last { continue }
		mut spanned := i64(gap.raw_value()) * i64(last - first - 1)
		mut sets_to_grow := []int{}
		mut beyond_limit := []int{}
		for index in first .. last {
			spanned += chromium_grid_affected_size(tracks[index], kind)
			if chromium_grid_contribution_applies(tracks[index], kind) {
				if planned[index] < 0 { planned[index] = 0 }
				sets_to_grow << index
				if chromium_grid_grows_beyond_limit(tracks[index], kind) { beyond_limit << index }
			}
		}
		if sets_to_grow.len == 0 { continue }
		extra := i64(item.size(kind).raw_value()) - spanned
		if extra <= 0 { continue }
		chromium_grid_distribute_equally(tracks, sets_to_grow, beyond_limit, extra, kind, mut incurred)
		for index in sets_to_grow {
			if incurred[index] > planned[index] { planned[index] = incurred[index] }
		}
	}
	// GrowAffectedSizeByPlannedIncrease.
	for index in 0 .. tracks.len {
		tracks[index].infinitely_growable = false
		if planned[index] < 0 { continue }
		increase := CSSPixels.from_raw(int(planned[index]))
		match kind {
			.intrinsic_minimums, .content_based_minimums, .max_content_minimums {
				tracks[index].base_size = tracks[index].base_size.plus(increase)
				if tracks[index].has_growth_limit
					&& tracks[index].growth_limit.raw_value() < tracks[index].base_size.raw_value() {
					tracks[index].growth_limit = tracks[index].base_size
				}
			}
			.intrinsic_maximums, .max_content_maximums {
				if kind == .intrinsic_maximums {
					tracks[index].infinitely_growable = !tracks[index].has_growth_limit
				}
				tracks[index].growth_limit = CSSPixels.from_raw(int(chromium_grid_definite_growth_limit(tracks[index]) + planned[index]))
				tracks[index].has_growth_limit = true
			}
		}
	}
}

fn chromium_grid_resolve_spanning_group(mut tracks []GridTrack, group []ChromiumGridSpanningContribution,
	gap CSSPixels) {
	if group.len == 0 { return }
	for kind in chromium_grid_contributions {
		chromium_grid_increase_tracks_for_group(mut tracks, group, gap, kind)
	}
}
