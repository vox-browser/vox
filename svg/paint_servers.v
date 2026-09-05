module svg

pub struct Stop {
pub:
	offset  f64
	color   u32
	opacity f64 = 1
}

pub fn normalized_stops(stops []Stop) []Stop {
	mut result := []Stop{cap: stops.len}
	mut previous := 0.0
	for stop in stops {
		offset := clamp(stop.offset, previous, 1)
		result << Stop{
			...stop
			offset: offset
			opacity: clamp(stop.opacity, 0, 1)
		}
		previous = offset
	}
	return result
}

pub struct LinearGradient {
pub:
	id        string
	href      string
	x1        ?NumberPercentage
	y1        ?NumberPercentage
	x2        ?NumberPercentage
	y2        ?NumberPercentage
	units     ?Units
	spread    ?SpreadMethod
	transform ?[]Transform
	stops     []Stop
}

pub struct ResolvedLinearGradient {
pub:
	x1        NumberPercentage
	y1        NumberPercentage
	x2        NumberPercentage
	y2        NumberPercentage
	units     Units
	spread    SpreadMethod
	transform []Transform
	stops     []Stop
}

pub fn resolve_linear_gradient(id string, gradients map[string]LinearGradient) ?ResolvedLinearGradient {
	mut seen := map[string]bool{}
	return resolve_linear_gradient_inner(id, gradients, mut seen)
}

fn resolve_linear_gradient_inner(id string, gradients map[string]LinearGradient, mut seen map[string]bool) ?ResolvedLinearGradient {
	if seen[id] {
		return none
	}
	seen[id] = true
	gradient := gradients[id] or { return none }
	parent_id := gradient.href.trim_left('#')
	parent := if parent_id.len > 0 {
		resolve_linear_gradient_inner(parent_id, gradients, mut seen)
	} else {
		none
	}
	return ResolvedLinearGradient{
		x1: gradient.x1 or {
			if inherited := parent { inherited.x1 } else { percentage(0) }
		}
		y1: gradient.y1 or {
			if inherited := parent { inherited.y1 } else { percentage(0) }
		}
		x2: gradient.x2 or {
			if inherited := parent { inherited.x2 } else { percentage(100) }
		}
		y2: gradient.y2 or {
			if inherited := parent { inherited.y2 } else { percentage(0) }
		}
		units: gradient.units or {
			if inherited := parent { inherited.units } else { Units.object_bounding_box }
		}
		spread: gradient.spread or {
			if inherited := parent { inherited.spread } else { SpreadMethod.pad }
		}
		transform: gradient.transform or {
			if inherited := parent { inherited.transform } else { []Transform{} }
		}
		stops: if gradient.stops.len > 0 {
			normalized_stops(gradient.stops)
		} else if inherited := parent {
			inherited.stops
		} else {
			[]
		}
	}
}

pub struct RadialGradient {
pub:
	cx f64 = 0.5
	cy f64 = 0.5
	r  f64 = 0.5
	fx ?f64
	fy ?f64
	fr f64
}

pub fn (gradient RadialGradient) resolved_focal_point() Point {
	return Point{
		x: gradient.fx or { gradient.cx }
		y: gradient.fy or { gradient.cy }
	}
}

pub struct LinkedRadialGradient {
pub:
	id        string
	href      string
	cx        ?NumberPercentage
	cy        ?NumberPercentage
	r         ?NumberPercentage
	fx        ?NumberPercentage
	fy        ?NumberPercentage
	fr        ?NumberPercentage
	units     ?Units
	spread    ?SpreadMethod
	transform ?[]Transform
	stops     []Stop
}

pub struct ResolvedRadialGradient {
pub:
	cx        NumberPercentage
	cy        NumberPercentage
	r         NumberPercentage
	fx        NumberPercentage
	fy        NumberPercentage
	fr        NumberPercentage
	units     Units
	spread    SpreadMethod
	transform []Transform
	stops     []Stop
}

pub fn resolve_radial_gradient(id string, gradients map[string]LinkedRadialGradient) ?ResolvedRadialGradient {
	mut seen := map[string]bool{}
	return resolve_radial_gradient_inner(id, gradients, mut seen)
}

fn resolve_radial_gradient_inner(id string, gradients map[string]LinkedRadialGradient, mut seen map[string]bool) ?ResolvedRadialGradient {
	if seen[id] {
		return none
	}
	seen[id] = true
	gradient := gradients[id] or { return none }
	parent_id := gradient.href.trim_left('#')
	parent := if parent_id.len > 0 {
		resolve_radial_gradient_inner(parent_id, gradients, mut seen)
	} else {
		none
	}
	cx := gradient.cx or {
		if inherited := parent { inherited.cx } else { percentage(50) }
	}

	cy := gradient.cy or {
		if inherited := parent { inherited.cy } else { percentage(50) }
	}

	return ResolvedRadialGradient{
		cx: cx
		cy: cy
		r: resolved_radial_radius(gradient.r, parent, false)
		fx: gradient.fx or {
			if inherited := parent { inherited.fx } else { cx }
		}
		fy: gradient.fy or {
			if inherited := parent { inherited.fy } else { cy }
		}
		fr: resolved_radial_radius(gradient.fr, parent, true)
		units: gradient.units or {
			if inherited := parent { inherited.units } else { Units.object_bounding_box }
		}
		spread: gradient.spread or {
			if inherited := parent { inherited.spread } else { SpreadMethod.pad }
		}
		transform: gradient.transform or {
			if inherited := parent { inherited.transform } else { []Transform{} }
		}
		stops: if gradient.stops.len > 0 {
			normalized_stops(gradient.stops)
		} else if inherited := parent {
			inherited.stops
		} else {
			[]
		}
	}
}

fn resolved_radial_radius(value ?NumberPercentage, parent ?ResolvedRadialGradient, focal bool) NumberPercentage {
	if radius := value {
		if radius.value >= 0 {
			return radius
		}
	}
	if inherited := parent {
		return if focal { inherited.fr } else { inherited.r }
	}
	return if focal { percentage(0) } else { percentage(50) }
}

pub struct Pattern {
pub:
	id            string
	href          string
	x             ?NumberPercentage
	y             ?NumberPercentage
	width         ?NumberPercentage
	height        ?NumberPercentage
	units         ?Units
	content_units ?Units
	transform     ?[]Transform
	viewbox       ?ViewBox
	has_children  bool
}

pub fn pattern_content_id(id string, patterns map[string]Pattern) ?string {
	mut current := id
	mut seen := map[string]bool{}
	for current.len > 0 {
		if seen[current] {
			return none
		}
		seen[current] = true
		pattern := patterns[current] or { return none }
		if pattern.has_children {
			return current
		}
		current = pattern.href.trim_left('#')
	}
	return none
}

pub struct ResolvedPattern {
pub:
	x             NumberPercentage
	y             NumberPercentage
	width         NumberPercentage
	height        NumberPercentage
	units         Units
	content_units Units
	transform     []Transform
	viewbox       ?ViewBox
	content_id    ?string
}

pub fn resolve_pattern(id string, patterns map[string]Pattern) ?ResolvedPattern {
	mut seen := map[string]bool{}
	return resolve_pattern_inner(id, patterns, mut seen)
}

fn resolve_pattern_inner(id string, patterns map[string]Pattern, mut seen map[string]bool) ?ResolvedPattern {
	if seen[id] {
		return none
	}
	seen[id] = true
	pattern := patterns[id] or { return none }
	parent_id := pattern.href.trim_left('#')
	parent := if parent_id.len > 0 {
		resolve_pattern_inner(parent_id, patterns, mut seen)
	} else {
		none
	}
	return ResolvedPattern{
		x: pattern.x or {
			if inherited := parent { inherited.x } else { number(0) }
		}
		y: pattern.y or {
			if inherited := parent { inherited.y } else { number(0) }
		}
		width: pattern.width or {
			if inherited := parent { inherited.width } else { number(0) }
		}
		height: pattern.height or {
			if inherited := parent { inherited.height } else { number(0) }
		}
		units: pattern.units or {
			if inherited := parent { inherited.units } else { Units.object_bounding_box }
		}
		content_units: pattern.content_units or {
			if inherited := parent { inherited.content_units } else { Units.user_space_on_use }
		}
		transform: pattern.transform or {
			if inherited := parent { inherited.transform } else { []Transform{} }
		}
		viewbox: inherited_pattern_viewbox(pattern, parent)
		content_id: inherited_pattern_content_id(id, pattern, parent)
	}
}

fn inherited_pattern_viewbox(pattern Pattern, parent ?ResolvedPattern) ?ViewBox {
	if box := pattern.viewbox {
		return box
	}
	if inherited := parent {
		if box := inherited.viewbox {
			return box
		}
	}
	return none
}

fn inherited_pattern_content_id(id string, pattern Pattern, parent ?ResolvedPattern) ?string {
	if pattern.has_children {
		return id
	}
	if inherited := parent {
		if content_id := inherited.content_id {
			return content_id
		}
	}
	return none
}

fn clamp(value f64, minimum f64, maximum f64) f64 {
	return if value < minimum {
		minimum
	} else if value > maximum {
		maximum
	} else {
		value
	}
}
