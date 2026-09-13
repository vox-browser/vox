// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

module layout

import css
import svg

// SVGLengthValue::from_style_value(). SVG cannot import CSS without creating a
// module cycle, so the CSS-to-SVG boundary owns this otherwise direct mapping.
pub fn svg_length_value_from_style_value(style_value css.StyleValue) ?svg.SvgLengthValue {
	return match style_value {
		css.NumberStyleValue { svg.SvgLengthValue.number(style_value.number()) }
		css.PercentageStyleValue {
			svg.SvgLengthValue.percentage(style_value.percentage().value())
		}
		css.LengthStyleValue {
			length := style_value.length()
			svg.SvgLengthValue.length(length.raw_value(), svg_length_unit_from_css(length.unit()))
		}
		else { none }
	}
}

fn svg_length_unit_from_css(unit css.LengthUnit) svg.LengthUnit {
	return match unit {
		.cap { .cap }
		.ch { .ch }
		.cm { .cm }
		.cqb { .cqb }
		.cqh { .cqh }
		.cqi { .cqi }
		.cqmax { .cqmax }
		.cqmin { .cqmin }
		.cqw { .cqw }
		.dvb { .dvb }
		.dvh { .dvh }
		.dvi { .dvi }
		.dvmax { .dvmax }
		.dvmin { .dvmin }
		.dvw { .dvw }
		.em { .ems }
		.ex { .exs }
		.ic { .ic }
		.in_ { .inches }
		.lh { .lh }
		.lvb { .lvb }
		.lvh { .lvh }
		.lvi { .lvi }
		.lvmax { .lvmax }
		.lvmin { .lvmin }
		.lvw { .lvw }
		.mm { .mm }
		.pc { .pc }
		.pt { .pt }
		.px { .px }
		.q { .q }
		.rcap { .rcap }
		.rch { .rch }
		.rem { .rem }
		.rex { .rex }
		.ric { .ric }
		.rlh { .rlh }
		.svb { .svb }
		.svh { .svh }
		.svi { .svi }
		.svmax { .svmax }
		.svmin { .svmin }
		.svw { .svw }
		.vb { .vb }
		.vh { .vh }
		.vi { .vi }
		.vmax { .vmax }
		.vmin { .vmin }
		.vw { .vw }
	}
}
