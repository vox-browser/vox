// Copyright (c) 2025, Jonathan Gamble <gamblej@gmail.com>
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Page/ElementResizeAction.{h,cpp}.
module page

import math

pub enum ResizeMode {
	none
	both
	horizontal
	vertical
	inline
	block
}

pub enum WritingMode {
	horizontal_tb
	vertical_rl
	vertical_lr
	sideways_rl
	sideways_lr
}

pub struct ResizeConstraints {
pub:
	mode                  ResizeMode
	writing_mode          WritingMode = .horizontal_tb
	rtl                   bool
	min_width             ?f64
	max_width             ?f64
	min_height            ?f64
	max_height            ?f64
	content_box           bool
	horizontal_noncontent f64
	vertical_noncontent   f64
	gripper_size          f64 = 15
}

pub struct ElementResizeAction {
pub:
	pointer_down_origin PixelPoint
	initial_border_size PixelSize
}

pub fn (action ElementResizeAction) handle_pointer_move(pointer PixelPoint, constraints ResizeConstraints) ?PixelSize {
	if constraints.mode == .none {
		return none
	}
	horizontal_writing := constraints.writing_mode == .horizontal_tb
	resize_x := constraints.mode in [.both, .horizontal]
		|| (constraints.mode == .inline && horizontal_writing)
		|| (constraints.mode == .block && !horizontal_writing)
	resize_y := constraints.mode in [.both, .vertical]
		|| (constraints.mode == .inline && !horizontal_writing)
		|| (constraints.mode == .block && horizontal_writing)
	mut dx := if resize_x { pointer.x - action.pointer_down_origin.x } else { 0 }
	dy := if resize_y { pointer.y - action.pointer_down_origin.y } else { 0 }
	if (horizontal_writing && constraints.rtl)
		|| constraints.writing_mode in [.vertical_rl, .sideways_rl] {
		dx = -dx
	}
	mut width := math.max(constraints.gripper_size, action.initial_border_size.width + dx)
	mut height := math.max(constraints.gripper_size, action.initial_border_size.height + dy)
	if min_width := constraints.min_width {
		width = math.max(width, min_width)
	}
	if max_width := constraints.max_width {
		width = math.min(width, max_width)
	}
	if min_height := constraints.min_height {
		height = math.max(height, min_height)
	}
	if max_height := constraints.max_height {
		height = math.min(height, max_height)
	}
	if constraints.content_box {
		width -= constraints.horizontal_noncontent
		height -= constraints.vertical_noncontent
	}
	return PixelSize{
		width:  math.max(0.0, width)
		height: math.max(0.0, height)
	}
}
