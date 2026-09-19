// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the process-wide viewport scrollbar controls in
// Libraries/LibWeb/Painting/BoxViews.{h,cpp}.
@[has_globals]
module painting

__global paint_viewport_scrollbars = true

pub fn set_paint_viewport_scrollbars(enabled bool) {
	paint_viewport_scrollbars = enabled
}

pub fn should_paint_viewport_scrollbars() bool {
	return paint_viewport_scrollbars
}
