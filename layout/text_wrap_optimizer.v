module layout

import platform

struct ScoredWrapPoint {
	item_index int
	start      f64
	end        f64
}

// Keep the existing shaper's legal break opportunities and advances. The
// bounded score search applies only to short, ordinary text paragraphs; floats,
// bidi, indentation, preserved whitespace and intrinsic probes retain their
// existing line breaker. No narrowed width leaks into alignment or used sizes.
fn optimized_text_wrap_breaks(container &BlockContainer, iterator &InlineLevelIterator,
	builder &LineBuilder, mode LayoutMode, width_only bool,
	space AvailableSpace, context ?&BlockFormattingContext) []int {
	style := container.computed_values()
	if mode != .normal || width_only || !space.width.is_definite()
		|| style.text_wrap_mode() != .wrap
		|| (style.text_wrap_style() != .balance && style.text_wrap_style() != .pretty)
		|| style.writing_mode() != .horizontal_tb || style.direction() != .ltr
		|| !iterator.is_unidirectional_left_to_right
		|| builder.text_indent.raw_value() != 0 || style.text_align() == .justify
		|| style.text_overflow() == .ellipsis || style.white_space_collapse() != .collapse
		|| style.word_break() != .normal || style.overflow_wrap() != .normal
		|| style.hyphens() == .auto_ {
		return []int{}
	}
	if bfc := context {
		if bfc.floating_boxes.len > 0 || bfc.has_line_clamp()
			|| bfc.laying_out_invisible_clamped_content {
			return []int{}
		}
	}
	for child in unsafe { &Node(container) }.children() {
		text := child.as_text_node() or { return []int{} }
		if text.text_for_rendering().contains('\u00ad') { return []int{} }
	}
	if iterator.items.len > 256 { return []int{} }
	scratch := platform.begin_thread_scratch('text wrap scores')
	defer { scratch.finish() }
	plan := score_text_wrap_items(iterator.items, space.width.to_px_or_zero().to_double(),
		style.text_wrap_style() == .balance)
	$if prealloc {
		scratch.leave()
		return plan.clone()
	}
	return plan
}

fn score_text_wrap_items(items []InlineLevelItem, width f64, balance bool) []int {
	if width <= 0 { return []int{} }
	mut points := []ScoredWrapPoint{}
	defer { $if !prealloc {
		unsafe { points.free() }
	} }
	mut position := f64(0)
	mut trimmed := f64(0)
	mut after_space := false
	mut space_item_index := 0
	for index, item in items {
		if item.type_ != .text || item.width.raw_value() < 0
			|| item.margin_start.raw_value() != 0 || item.margin_end.raw_value() != 0
			|| item.padding_start.raw_value() != 0 || item.padding_end.raw_value() != 0
			|| item.border_start.raw_value() != 0 || item.border_end.raw_value() != 0 {
			return []int{}
		}
		if !item.is_all_whitespace {
			if points.len == 0 || item.can_break_before || after_space {
				points << ScoredWrapPoint{if after_space { space_item_index } else { index }, position, trimmed}
			}
			position += item.width.to_double()
			trimmed = position
			after_space = false
		} else {
			if !item.is_collapsible_whitespace { return []int{} }
			if !after_space { space_item_index = index }
			position += item.width.to_double()
			after_space = true
		}
	}
	if points.len < 2 || points.len > 128 { return []int{} }
	points << ScoredWrapPoint{items.len, position, trimmed}
	last := points.len - 1
	mut greedy := []int{len: 1}
	defer { $if !prealloc {
		unsafe { greedy.free() }
	} }
	mut start := 0
	for start < last {
		mut end := start + 1
		if points[end].end - points[start].start > width { return []int{} }
		for end < last && points[end + 1].end - points[start].start <= width { end++ }
		greedy << end
		start = end
		if greedy.len > 7 { return []int{} }
	}
	lines := greedy.len - 1
	if lines < 2 { return []int{} }
	last_start := greedy[greedy.len - 2]
	// Blink's pretty heuristic targets a short final line with a single word.
	if !balance && (last - last_start > 1
		|| points[last].end - points[last_start].start >= width / 3) {
		return []int{}
	}
	stride := points.len
	mut scores := []f64{len: (lines + 1) * stride, init: 1e100}
	mut previous := []int{len: scores.len, init: -1}
	defer {
		$if !prealloc {
			unsafe { scores.free() }
			unsafe { previous.free() }
		}
	}
	scores[0] = 0
	for line in 1 .. lines + 1 {
		for end in 1 .. points.len {
			for begin in 0 .. end {
				used := points[end].end - points[begin].start
				if used > width || scores[(line - 1) * stride + begin] == 1e100 { continue }
				slack := width - used
				mut cost := if balance || end != last { slack * slack } else { f64(0) }
				if !balance && end == last && end - begin == 1 { cost += 40000 }
				score := scores[(line - 1) * stride + begin] + cost
				at := line * stride + end
				if score <= scores[at] {
					scores[at] = score
					previous[at] = begin
				}
			}
		}
	}
	mut result := []int{}
	mut end := last
	for line := lines; line > 0; line-- {
		begin := previous[line * stride + end]
		if begin < 0 { return []int{} }
		if begin > 0 { result << points[begin].item_index }
		end = begin
	}
	result.reverse_in_place()
	return result
}
