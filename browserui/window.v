module browserui

import math

pub struct Frame {
pub:
	x      f64
	y      f64
	width  f64
	height f64
}

pub fn (frame Frame) valid() bool {
	return !math.is_nan(frame.x) && !math.is_inf(frame.x, 0) && !math.is_nan(frame.y) && !math.is_inf(frame.y, 0)
		&& !math.is_nan(frame.width) && !math.is_inf(frame.width, 0) && !math.is_nan(frame.height) && !math.is_inf(frame.height, 0)
		&& frame.width >= 100 && frame.height >= 100 && frame.width <= 100000 && frame.height <= 100000
}

pub fn visible_frame(frame Frame, screens []Frame, fallback int, minimum_width f64, minimum_height f64, test_window bool) Frame {
	if screens.len == 0 { return frame }
	mut selected := math.max(0, math.min(screens.len - 1, fallback))
	mut largest := 0.0
	if !test_window {
		for index, screen in screens {
			w := math.max(0.0, math.min(frame.x + frame.width, screen.x + screen.width) - math.max(frame.x, screen.x))
			h := math.max(0.0, math.min(frame.y + frame.height, screen.y + screen.height) - math.max(frame.y, screen.y))
			if w * h > largest {
				largest = w * h
				selected = index
			}
		}
	}
	screen := screens[selected]
	width := math.min(math.max(frame.width, minimum_width), screen.width)
	height := math.min(math.max(frame.height, minimum_height), screen.height)
	return Frame{
		x:      if test_window {
			screen.x + screen.width - width
		} else {
			math.max(screen.x, math.min(frame.x, screen.x + screen.width - width))
		}
		y:      if test_window {
			screen.y + screen.height - height
		} else {
			math.max(screen.y, math.min(frame.y, screen.y + screen.height - height))
		}
		width:  width
		height: height
	}
}

pub fn detached_frame(x f64, y f64, width f64, height f64, screens []Frame) Frame {
	mut left := x - 100
	mut top := y + 48
	for screen in screens {
		if x < screen.x || x >= screen.x + screen.width || y < screen.y || y >= screen.y + screen.height {
			continue
		}
		left = math.max(screen.x, math.min(left, screen.x + screen.width - width))
		top = math.min(screen.y + screen.height, math.max(top, screen.y + height))
		break
	}
	return Frame{ x: left, y: top - height, width: width, height: height }
}

pub struct WindowState {
pub mut:
	normal        Frame
	maximized     bool
	fullscreen    bool
	transitioning bool
	restoring     bool
}

// Events: 0 geometry, 1 will-enter, 2 did-enter, 3 will-exit, 4 did-exit, 5 close.
pub fn (mut state WindowState) update(kind int, frame Frame, zoomed bool, minimized bool) bool {
	if kind in [2, 4] {
		state.fullscreen = kind == 2
		state.transitioning = false
	}
	if kind == 3 {
		state.transitioning = true
		return false
	}
	if state.restoring || state.transitioning { return false }
	if !minimized && !state.fullscreen {
		state.maximized = zoomed
		if !zoomed { state.normal = frame }
	}
	valid := state.normal.valid()
	if kind == 1 { state.transitioning = true }
	return valid
}

pub struct WindowClicks {
mut:
	last i64
	x    f64
	y    f64
}

pub fn (mut clicks WindowClicks) press(now i64, x f64, y f64) bool {
	double_click := clicks.last != 0 && now - clicks.last < 500_000_000 && math.abs(x - clicks.x) < 5 && math.abs(y - clicks.y) < 5
	clicks.last = if double_click { i64(0) } else { now }
	clicks.x = x
	clicks.y = y
	return double_click
}
