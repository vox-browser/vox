// Copyright (c) 2026-present, the Ladybird developers.
//
// SPDX-License-Identifier: BSD-2-Clause

module layout

import css
import painting

fn force_dark_painting_color(color css.Color) painting.Color {
	return painting.Color{color.r, color.g, color.b, color.a}
}

fn force_dark_css_color(color painting.Color) css.Color {
	return css.Color{color.r, color.g, color.b, color.a}
}

fn force_dark_effective_role(command PaintCommand) painting.ForceDarkRole {
	if command.force_dark_role_set {
		return command.force_dark_role
	}
	return match command.paint_phase {
		.background { .background }
		.border, .table_collapsed_border, .outline { .border }
		.foreground { .foreground }
		.overlay { .none_ }
	}
}

fn force_dark_resolved_color_string(value string, role painting.ForceDarkRole,
	backdrop ?painting.Color, mut resolver painting.ForceDarkResolver) string {
	if value == '' || role == .none_ {
		return value
	}
	color := css.parse_color_string(value) or { return value }
	resolved := resolver.resolve_against_backdrop(force_dark_painting_color(color), role,
		backdrop)
	return force_dark_css_color(resolved).serialize()
}

fn force_dark_resolved_css_gradient(gradient LinearGradient, role painting.ForceDarkRole,
	mut resolver painting.ForceDarkResolver) LinearGradient {
	mut colors := []css.Color{cap: gradient.colors.len}
	for color in gradient.colors {
		colors << force_dark_css_color(resolver.resolve(force_dark_painting_color(color), role))
	}
	mut stops := []GradientStop{cap: gradient.stops.len}
	for stop in gradient.stops {
		stops << GradientStop{
			...stop
			color: force_dark_css_color(resolver.resolve(force_dark_painting_color(stop.color),
				role))
		}
	}
	return LinearGradient{
		...gradient
		colors: colors
		stops: stops
	}
}

fn force_dark_resolved_svg_gradient_data(data painting.SVGGradientPaintStyle,
	role painting.ForceDarkRole, mut resolver painting.ForceDarkResolver) painting.SVGGradientPaintStyle {
	mut stops := []painting.ColorStop{cap: data.color_stops.len}
	for stop in data.color_stops {
		stops << painting.ColorStop{
			...stop
			color: resolver.resolve(stop.color, role)
		}
	}
	return painting.SVGGradientPaintStyle{
		...data
		color_stops: stops
	}
}

fn force_dark_resolved_svg_linear_gradient(gradient painting.SVGLinearGradientPaintStyle,
	role painting.ForceDarkRole, mut resolver painting.ForceDarkResolver) painting.SVGLinearGradientPaintStyle {
	return painting.SVGLinearGradientPaintStyle{
		...gradient
		gradient: force_dark_resolved_svg_gradient_data(gradient.gradient, role, mut resolver)
	}
}

fn force_dark_resolved_svg_radial_gradient(gradient painting.SVGRadialGradientPaintStyle,
	role painting.ForceDarkRole, mut resolver painting.ForceDarkResolver) painting.SVGRadialGradientPaintStyle {
	return painting.SVGRadialGradientPaintStyle{
		...gradient
		gradient: force_dark_resolved_svg_gradient_data(gradient.gradient, role, mut resolver)
	}
}

fn resolve_force_dark_paint_command(mut command PaintCommand,
	mut resolver painting.ForceDarkResolver) {
	role := force_dark_effective_role(command)
	if command.kind in ['draw_background_image', 'draw_replaced_image', 'draw_svg_image'] {
		command.apply_force_dark_to_image = role != .none_
	}
	if role == .none_ {
		return
	}
	command.color = force_dark_resolved_color_string(command.color, role,
		command.force_dark_backdrop, mut resolver)
	command.stroke_color = force_dark_resolved_color_string(command.stroke_color, role,
		command.force_dark_backdrop, mut resolver)
	if gradient := command.gradient {
		command.gradient = force_dark_resolved_css_gradient(gradient, role, mut resolver)
	}
	if gradient := command.fill_linear_gradient {
		command.fill_linear_gradient = force_dark_resolved_svg_linear_gradient(gradient, role,
			mut resolver)
	}
	if gradient := command.stroke_linear_gradient {
		command.stroke_linear_gradient = force_dark_resolved_svg_linear_gradient(gradient,
			role, mut resolver)
	}
	if gradient := command.fill_radial_gradient {
		command.fill_radial_gradient = force_dark_resolved_svg_radial_gradient(gradient, role,
			mut resolver)
	}
	if gradient := command.stroke_radial_gradient {
		command.stroke_radial_gradient = force_dark_resolved_svg_radial_gradient(gradient,
			role, mut resolver)
	}
}

// DisplayListRecorder resolves colors while recording upstream. The V paint
// transport retains author colors for cache reuse, then applies the equivalent
// resolver to the assembled immutable command stream.
pub fn resolve_force_dark_paint_commands(commands []PaintCommand,
	settings painting.ForceDarkSettings) []PaintCommand {
	mut resolved := commands.clone()
	mut resolver := painting.ForceDarkResolver.create(settings)
	for mut command in resolved {
		resolve_force_dark_paint_command(mut command, mut resolver)
	}
	return resolved
}
