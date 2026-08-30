// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

module html

// Compact counterpart of AK::SourceLocation used by parser diagnostics. The
// native default argument captures the C++ call site; V callers may use
// current_at when they need to preserve an explicit location.
pub struct SourceLocation {
pub:
	file string
	line int
}

pub fn SourceLocation.current() SourceLocation {
	return SourceLocation{}
}

pub fn SourceLocation.current_at(file string, line int) SourceLocation {
	return SourceLocation{
		file: file
		line: line
	}
}
