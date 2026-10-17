module layout

// Inputs for Blink's auto-layout colspan distribution. Percent columns carry
// their intrinsic percentage; columns where no cell begins are mergeable and
// receive no share of a spanning cell.
struct ChromiumTableColumnConstraints {
	constrained []bool
	percent     []f64
	has_percent []bool
	mergeable   []bool
}

// LayoutUnit::MulDiv(): the 64-bit product is divided with truncation.
fn chromium_layout_mul_div(value CSSPixels, multiplier CSSPixels, divisor CSSPixels) CSSPixels {
	return CSSPixels.from_raw(int(i64(value.raw_value()) * i64(multiplier.raw_value()) / i64(divisor.raw_value())))
}

fn chromium_layout_div(value CSSPixels, divisor int) CSSPixels {
	return CSSPixels.from_raw(value.raw_value() / divisor)
}

fn chromium_resolve_percent_width(constraints ChromiumTableColumnConstraints, column int, minimum CSSPixels, target CSSPixels) CSSPixels {
	return css_pixels_max(minimum, CSSPixels.truncated_value_for(constraints.percent[column] * target.to_double() / 100.0))
}

// Blink's DistributeInlineSizeToComputedInlineSizeAuto(): the CSS Tables
// width distribution guesses, applied to the columns a cell spans. Auto
// columns absorb any size above the specified guess before fixed columns do.
fn chromium_distribute_inline_size_auto(target_inline_size CSSPixels, columns []int, min_widths []CSSPixels, max_widths []CSSPixels, constraints ChromiumTableColumnConstraints, treat_target_size_as_constrained bool) []CSSPixels {
	mut percent_count := 0
	mut fixed_count := 0
	mut auto_count := 0
	mut guesses := []CSSPixels{len: 4, init: CSSPixels.new(0)}
	mut increases := []CSSPixels{len: 4, init: CSSPixels.new(0)}
	mut total_auto_max := CSSPixels.new(0)
	mut total_fixed_max := CSSPixels.new(0)
	for column in columns {
		if constraints.mergeable[column] {
			continue
		}
		minimum := min_widths[column]
		maximum := max_widths[column]
		if constraints.has_percent[column] {
			percent_count++
			percent_size := chromium_resolve_percent_width(constraints, column, minimum, target_inline_size)
			guesses[0] = guesses[0].plus(minimum)
			guesses[1] = guesses[1].plus(percent_size)
			guesses[2] = guesses[2].plus(percent_size)
			guesses[3] = guesses[3].plus(percent_size)
			increases[1] = increases[1].plus(percent_size.minus(minimum))
		} else if constraints.constrained[column] {
			fixed_count++
			total_fixed_max = total_fixed_max.plus(maximum)
			guesses[0] = guesses[0].plus(minimum)
			guesses[1] = guesses[1].plus(minimum)
			guesses[2] = guesses[2].plus(maximum)
			guesses[3] = guesses[3].plus(maximum)
			increases[2] = increases[2].plus(maximum.minus(minimum))
		} else {
			auto_count++
			total_auto_max = total_auto_max.plus(maximum)
			guesses[0] = guesses[0].plus(minimum)
			guesses[1] = guesses[1].plus(minimum)
			guesses[2] = guesses[2].plus(minimum)
			guesses[3] = guesses[3].plus(maximum)
			increases[3] = increases[3].plus(maximum.minus(minimum))
		}
	}
	mut sizes := []CSSPixels{len: columns.len, init: CSSPixels.new(0)}
	target := css_pixels_max(target_inline_size, guesses[0])
	mut starting_guess := 4
	for guess in 0 .. 4 {
		if guesses[guess].raw_value() >= target.raw_value() {
			starting_guess = guess
			break
		}
	}
	mut last := -1
	mut remaining := CSSPixels.new(0)
	match starting_guess {
		0 {
			for index, column in columns {
				if !constraints.mergeable[column] {
					sizes[index] = min_widths[column]
				}
			}
		}
		1 {
			distributable := target.minus(guesses[0])
			remaining = distributable
			for index, column in columns {
				if constraints.mergeable[column] {
					continue
				}
				if constraints.has_percent[column] {
					last = index
					increase := chromium_resolve_percent_width(constraints, column, min_widths[column],
						target).minus(min_widths[column])
					delta := if increases[1].raw_value() > 0 {
						chromium_layout_mul_div(distributable, increase, increases[1])
					} else {
						chromium_layout_div(distributable, percent_count)
					}
					remaining = remaining.minus(delta)
					sizes[index] = min_widths[column].plus(delta)
				} else {
					sizes[index] = min_widths[column]
				}
			}
		}
		2 {
			distributable := target.minus(guesses[1])
			remaining = distributable
			for index, column in columns {
				if constraints.mergeable[column] {
					continue
				}
				if constraints.has_percent[column] {
					sizes[index] = chromium_resolve_percent_width(constraints, column, min_widths[column],
						target)
				} else if constraints.constrained[column] {
					last = index
					increase := max_widths[column].minus(min_widths[column])
					delta := if increases[2].raw_value() > 0 {
						chromium_layout_mul_div(distributable, increase, increases[2])
					} else {
						chromium_layout_div(distributable, fixed_count)
					}
					remaining = remaining.minus(delta)
					sizes[index] = min_widths[column].plus(delta)
				} else {
					sizes[index] = min_widths[column]
				}
			}
		}
		3 {
			distributable := target.minus(guesses[2])
			exact := target.raw_value() == guesses[3].raw_value()
			remaining = if exact { CSSPixels.new(0) } else { distributable }
			for index, column in columns {
				if constraints.mergeable[column] {
					continue
				}
				if constraints.has_percent[column] {
					sizes[index] = chromium_resolve_percent_width(constraints, column, min_widths[column],
						target)
				} else if constraints.constrained[column] || exact {
					sizes[index] = max_widths[column]
				} else {
					last = index
					increase := max_widths[column].minus(min_widths[column])
					delta := if increases[3].raw_value() > 0 {
						chromium_layout_mul_div(distributable, increase, increases[3])
					} else {
						chromium_layout_div(distributable, auto_count)
					}
					remaining = remaining.minus(delta)
					sizes[index] = min_widths[column].plus(delta)
				}
			}
		}
		else {
			distributable := target.minus(guesses[3])
			remaining = distributable
			grow_fixed := auto_count == 0 && fixed_count > 0 && treat_target_size_as_constrained
			for index, column in columns {
				if constraints.mergeable[column] {
					continue
				}
				if constraints.has_percent[column] {
					sizes[index] = chromium_resolve_percent_width(constraints, column, min_widths[column],
						target)
					if auto_count == 0 && !grow_fixed {
						// Blink skips the leftover when the last percent column is
						// the first spanned column.
						last = if index == 0 { -1 } else { index }
						total_percent := chromium_total_percent(constraints, columns)
						delta := if total_percent != 0 {
							CSSPixels.truncated_value_for(distributable.to_double() * constraints.percent[column] / total_percent)
						} else {
							chromium_layout_div(distributable, percent_count)
						}
						remaining = remaining.minus(delta)
						sizes[index] = sizes[index].plus(delta)
					}
				} else if constraints.constrained[column] {
					sizes[index] = max_widths[column]
					if grow_fixed {
						last = index
						delta := if total_fixed_max.raw_value() > 0 {
							chromium_layout_mul_div(distributable, max_widths[column], total_fixed_max)
						} else {
							chromium_layout_div(distributable, fixed_count)
						}
						remaining = remaining.minus(delta)
						sizes[index] = sizes[index].plus(delta)
					}
				} else {
					last = index
					delta := if total_auto_max.raw_value() > 0 {
						chromium_layout_mul_div(distributable, max_widths[column], total_auto_max)
					} else {
						chromium_layout_div(distributable, auto_count)
					}
					remaining = remaining.minus(delta)
					sizes[index] = max_widths[column].plus(delta)
				}
			}
		}
	}
	if remaining.raw_value() != 0 && last >= 0 {
		sizes[last] = sizes[last].plus(remaining)
	}
	return sizes
}

fn chromium_total_percent(constraints ChromiumTableColumnConstraints, columns []int) f64 {
	mut total := 0.0
	for column in columns {
		if !constraints.mergeable[column] && constraints.has_percent[column] {
			total += constraints.percent[column]
		}
	}
	return total
}

// Blink's DistributeColspanCellToColumnsAuto(), run for every spanning cell
// ordered by span and then start column. Each cell's minimum and maximum, less
// the border spacing between its non-mergeable columns, is distributed with
// the width distribution guesses and raises the columns it spans in turn.
fn compute_chromium_spanning_table_column_measures(mut min_widths []CSSPixels, mut max_widths []CSSPixels, placements []TableCellPlacement, cell_measures []TableCellIntrinsicWidthMeasures, spacing CSSPixels, constraints ChromiumTableColumnConstraints) {
	mut order := []int{}
	for index, placement in placements {
		if placement.column_span > 1 && placement.column < min_widths.len {
			order << index
		}
	}
	order.sort_with_compare(fn [placements] (a &int, b &int) int {
		first := placements[*a]
		second := placements[*b]
		if first.column_span != second.column_span {
			return first.column_span - second.column_span
		}
		if first.column != second.column {
			return first.column - second.column
		}
		return *a - *b
	})
	for placement_index in order {
		placement := placements[placement_index]
		end_column := if placement.column + placement.column_span < min_widths.len {
			placement.column + placement.column_span
		} else {
			min_widths.len
		}
		columns := []int{len: end_column - placement.column, init: placement.column + index}
		mut inner_spacing := CSSPixels.new(0)
		mut first := true
		for column in columns {
			if constraints.mergeable[column] {
				continue
			}
			if first {
				first = false
			} else {
				inner_spacing = inner_spacing.plus(spacing)
			}
		}
		measures := cell_measures[placement_index]
		cell_min := css_pixels_max(measures.outer_min_width.minus(inner_spacing), CSSPixels.new(0))
		cell_max := css_pixels_max(measures.outer_max_width.minus(inner_spacing), CSSPixels.new(0))
		minimums := chromium_distribute_inline_size_auto(cell_min, columns, min_widths, max_widths,
			constraints, true)
		for index, column in columns {
			min_widths[column] = css_pixels_max(min_widths[column], minimums[index])
		}
		cell_is_constrained := placement.cell.computed_values().size_value(.width).is_length()
		maximums := chromium_distribute_inline_size_auto(cell_max, columns, min_widths, max_widths,
			constraints, cell_is_constrained)
		for index, column in columns {
			max_widths[column] = css_pixels_max(css_pixels_max(min_widths[column], max_widths[column]),
				maximums[index])
		}
	}
}
