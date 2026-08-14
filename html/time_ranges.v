// Copyright (c) 2023, Tim Flynn <trflynn89@serenityos.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/HTML/TimeRanges.cpp.
module html

struct TimeRange {
	start f64
	end   f64
}

pub struct TimeRanges {
mut:
	ranges []TimeRange
}

pub fn (ranges &TimeRanges) length() u32 {
	return u32(ranges.ranges.len)
}

pub fn (ranges &TimeRanges) start(index u32) !f64 {
	if index >= u32(ranges.ranges.len) {
		return error('Index argument is greater than or equal to the number of ranges represented by this TimeRanges object')
	}
	return ranges.ranges[index].start
}

pub fn (ranges &TimeRanges) end(index u32) !f64 {
	if index >= u32(ranges.ranges.len) {
		return error('Index argument is greater than or equal to the number of ranges represented by this TimeRanges object')
	}
	return ranges.ranges[index].end
}

pub fn (mut ranges TimeRanges) add_range(start f64, end f64) {
	ranges.ranges << TimeRange{start, end}
}

pub fn (ranges &TimeRanges) in_range(point f64) bool {
	for range_ in ranges.ranges {
		if point >= range_.start && point <= range_.end {
			return true
		}
	}
	return false
}
