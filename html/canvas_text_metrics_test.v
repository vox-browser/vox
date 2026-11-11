// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

module html

import dom
import math
import platform

fn test_canvas_em_square_uses_font_size_and_handles_zero_font_height() {
	// Font ascenders and descenders can span more than the CSS font size.
	metrics := platform.FontPixelMetrics{size: 80, ascent: 90, descent: 30}
	ascent, descent := canvas_em_square_ascent_and_descent(metrics)
	assert ascent == 60
	assert descent == 20
	assert canvas_text_baseline_offset(.top, metrics) == 60
	assert canvas_text_baseline_offset(.middle, metrics) == 20
	assert canvas_text_baseline_offset(.bottom, metrics) == -20
	assert canvas_text_baseline_offset(.hanging, metrics) == 72
	assert canvas_text_baseline_offset(.ideographic, metrics) == -30
	assert canvas_text_baseline_offset(.alphabetic, metrics) == 0
	zero_ascent, zero_descent := canvas_em_square_ascent_and_descent(platform.FontPixelMetrics{size: 80})
	assert zero_ascent == 40
	assert zero_descent == 40
}

fn test_canvas_measure_text_and_drawing_use_the_same_em_square_baselines() {
	mut canvas := OffscreenCanvas.create(1, 1)!
	mut context := canvas.get_context(.canvas_2d, none)!
	context.set_font('80px serif')
	alphabetic := context.measure_text('Hello')
	font_height := alphabetic.font_bounding_box_ascent() + alphabetic.font_bounding_box_descent()
	assert font_height > 0
	assert math.abs(alphabetic.em_height_ascent() + alphabetic.em_height_descent() - 80) < 0.0001
	expected_ascent := 80 * alphabetic.font_bounding_box_ascent() / font_height
	assert math.abs(alphabetic.em_height_ascent() - expected_ascent) < 0.0001
	assert alphabetic.alphabetic_baseline() == 0
	for baseline in [CanvasTextBaseline.top, .middle, .bottom, .hanging, .ideographic, .alphabetic] {
		context.drawing_state.text_baseline = baseline
		metrics := context.measure_text('Hello')
		offset := alphabetic.em_height_ascent() - metrics.em_height_ascent()
		assert math.abs(metrics.em_height_ascent() + metrics.em_height_descent() - 80) < 0.0001
		assert math.abs(metrics.alphabetic_baseline() + offset) < 0.0001
		assert math.abs(metrics.font_bounding_box_ascent() - (alphabetic.font_bounding_box_ascent() - offset)) < 0.0001
		assert math.abs(metrics.font_bounding_box_descent() - (alphabetic.font_bounding_box_descent() + offset)) < 0.0001
		assert math.abs(metrics.hanging_baseline() - (alphabetic.hanging_baseline() - offset)) < 0.0001
		assert math.abs(metrics.ideographic_baseline() - (alphabetic.ideographic_baseline() - offset)) < 0.0001
		assert metrics.width() == alphabetic.width()
		match baseline {
			.top {
				assert math.abs(metrics.em_height_ascent()) < 0.0001
				assert math.abs(metrics.em_height_descent() - 80) < 0.0001
			}
			.middle {
				assert math.abs(metrics.em_height_ascent() - 40) < 0.0001
				assert math.abs(metrics.em_height_descent() - 40) < 0.0001
			}
			.bottom {
				assert math.abs(metrics.em_height_ascent() - 80) < 0.0001
				assert math.abs(metrics.em_height_descent()) < 0.0001
			}
			.hanging { assert math.abs(metrics.hanging_baseline()) < 0.0001 }
			.ideographic { assert math.abs(metrics.ideographic_baseline()) < 0.0001 }
			.alphabetic { assert metrics.alphabetic_baseline() == 0 }
		}
		run := canvas_text_run(context.drawing_state, 'Hello', 0)
		transform := canvas_text_transform(context.drawing_state, run.font(), metrics.width(), none)
		assert math.abs(transform.f + metrics.alphabetic_baseline()) < 0.0001
	}
}

fn test_html_canvas_exposes_em_metrics_for_empty_and_nonempty_text() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'canvas')!
	mut context := html_canvas_element_get_context(unsafe { &dom.HTMLCanvasElement(element) }, '2d', none)!
	context.set_font('80px serif')
	context.drawing_state.text_baseline = .middle
	for text in ['', 'Hello', ' \t\n'] {
		metrics := context.measure_text(text)
		assert math.abs(metrics.em_height_ascent() - 40) < 0.0001
		assert math.abs(metrics.em_height_descent() - 40) < 0.0001
	}
}
