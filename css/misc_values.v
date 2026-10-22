module css

import math
import strings
import dom

// --- Display ---
pub enum DisplayOutside as u8 {
	block
	inline_
	run_in
}

pub enum DisplayInside as u8 {
	flow
	flow_root
	table
	flex
	grid
	ruby
	math
	webkit_box
}

pub enum DisplayInternal as u8 {
	table_row_group
	table_header_group
	table_footer_group
	table_row
	table_cell
	table_column_group
	table_column
	table_caption
	ruby_base
	ruby_text
	ruby_base_container
	ruby_text_container
}

pub enum DisplayBox as u8 {
	none_
	contents
}

pub enum DisplayListItem as u8 {
	no
	yes
}

pub enum DisplayType as u8 {
	outside_and_inside
	internal
	box
}

pub enum DisplayShort {
	none_
	contents
	block
	flow
	flow_root
	inline_
	inline_block
	run_in
	list_item
	inline_list_item
	flex
	inline_flex
	grid
	inline_grid
	ruby
	table
	inline_table
	math
}

pub struct Display {
pub mut:
	type_     DisplayType
	outside_  DisplayOutside
	inside_   DisplayInside
	list_item DisplayListItem
	internal_ DisplayInternal
	box_      DisplayBox
}

pub fn Display.new() Display {
	return Display.from_outside_inside(.block, .flow)
}

pub fn Display.from_outside_inside(outside DisplayOutside, inside DisplayInside) Display {
	return Display.from_outside_inside_and_list_item(outside, inside, .no)
}

pub fn Display.from_outside_inside_and_list_item(outside DisplayOutside, inside DisplayInside, list_item DisplayListItem) Display {
	return Display{
		type_: .outside_and_inside
		outside_: outside
		inside_: inside
		list_item: list_item
	}
}

pub fn Display.from_internal(internal DisplayInternal) Display {
	return Display{
		type_: .internal
		internal_: internal
	}
}

pub fn Display.from_box(box DisplayBox) Display {
	return Display{
		type_: .box
		box_: box
	}
}

pub fn (d Display) to_string() string {
	if keyword := d.to_keyword() {
		return string_from_keyword(keyword)
	}
	assert d.type_ == .outside_and_inside

	match d.type_ {
		.outside_and_inside {
			mut parts := []string{}
			if !(d.outside_ == .block && d.inside_ == .flow_root) {
				parts << display_outside_to_string(d.outside_)
			}
			if d.inside_ != .flow {
				parts << display_inside_to_string(d.inside_)
			}
			if d.list_item == .yes {
				parts << 'list-item'
			}
			return parts.join(' ')
		}
		.internal {
			return display_internal_to_string(d.internal_)
		}
		.box {
			return display_box_to_string(d.box_)
		}
	}
}

pub fn Display.from_short(short_ DisplayShort) Display {
	return match short_ {
		.none_ {
			Display.from_box(.none_)
		}
		.contents {
			Display.from_box(.contents)
		}
		.block {
			Display.from_outside_inside(.block, .flow)
		}
		.inline_ {
			Display.from_outside_inside(.inline_, .flow)
		}
		.flow {
			Display.from_outside_inside(.block, .flow)
		}
		.flow_root {
			Display.from_outside_inside(.block, .flow_root)
		}
		.inline_block {
			Display.from_outside_inside(.inline_, .flow_root)
		}
		.run_in {
			Display.from_outside_inside(.run_in, .flow)
		}
		.list_item {
			Display.from_outside_inside_and_list_item(.block, .flow, .yes)
		}
		.inline_list_item {
			Display.from_outside_inside_and_list_item(.inline_, .flow, .yes)
		}
		.flex {
			Display.from_outside_inside(.block, .flex)
		}
		.inline_flex {
			Display.from_outside_inside(.inline_, .flex)
		}
		.grid {
			Display.from_outside_inside(.block, .grid)
		}
		.inline_grid {
			Display.from_outside_inside(.inline_, .grid)
		}
		.ruby {
			Display.from_outside_inside(.inline_, .ruby)
		}
		.table {
			Display.from_outside_inside(.block, .table)
		}
		.inline_table {
			Display.from_outside_inside(.inline_, .table)
		}
		.math {
			// NOTE: The spec ( https://w3c.github.io/mathml-core/#new-display-math-value ) does not
			//       mention what the outside value for `display: math` should be but other browsers
			//       use `inline` so let's go with that.
			Display.from_outside_inside(.inline_, .math)
		}
	}
}

pub fn Display.from_keyword(keyword Keyword) Display {
	keyword_text := string_from_keyword(keyword)
	return display_from_single_keyword_string(keyword_text) or {
		panic('Keyword ${keyword_text} is not a display value')
	}
}

pub fn (d Display) to_keyword() ?Keyword {
	match d.type_ {
		.box {
			return keyword_from_string(display_box_to_string(d.box_))
		}
		.internal {
			return keyword_from_string(display_internal_to_string(d.internal_))
		}
		.outside_and_inside {
			// Following the "most backwards-compatible, then shortest" precedence,
			// equivalent pairs reify through their short display keyword.
			if d.is_webkit_box_inside() {
				return if d.is_inline_outside() {
					Keyword.webkit_inline_box
				} else {
					Keyword.webkit_box
				}
			}
			if d == Display.from_short(.block) {
				return .block
			}
			if d == Display.from_short(.flow_root) {
				return .flow_root
			}
			if d == Display.from_short(.inline_) {
				return .inline_
			}
			if d == Display.from_short(.inline_block) {
				return .inline_block
			}
			if d == Display.from_short(.run_in) {
				return .run_in
			}
			if d == Display.from_short(.list_item) {
				return .list_item
			}
			if d == Display.from_short(.flex) {
				return .flex
			}
			if d == Display.from_short(.inline_flex) {
				return .inline_flex
			}
			if d == Display.from_short(.grid) {
				return .grid
			}
			if d == Display.from_short(.inline_grid) {
				return .inline_grid
			}
			if d == Display.from_short(.ruby) {
				return .ruby
			}
			if d == Display.from_short(.table) {
				return .table
			}
			if d == Display.from_short(.inline_table) {
				return .inline_table
			}
			if d == Display.from_short(.math) {
				return .math
			}
			return none
		}
	}
}

pub fn (d Display) is_internal() bool {
	return d.type_ == .internal
}

pub fn (d Display) internal() DisplayInternal {
	if !d.is_internal() {
		panic('VERIFY_NOT_REACHED')
	}
	return d.internal_
}

pub fn (d Display) is_table_column() bool {
	return d.is_internal() && d.internal() == .table_column
}

pub fn (d Display) is_table_row_group() bool {
	return d.is_internal() && d.internal() == .table_row_group
}

pub fn (d Display) is_table_header_group() bool {
	return d.is_internal() && d.internal() == .table_header_group
}

pub fn (d Display) is_table_footer_group() bool {
	return d.is_internal() && d.internal() == .table_footer_group
}

pub fn (d Display) is_table_row() bool {
	return d.is_internal() && d.internal() == .table_row
}

pub fn (d Display) is_table_cell() bool {
	return d.is_internal() && d.internal() == .table_cell
}

pub fn (d Display) is_table_column_group() bool {
	return d.is_internal() && d.internal() == .table_column_group
}

pub fn (d Display) is_table_caption() bool {
	return d.is_internal() && d.internal() == .table_caption
}

// https://drafts.csswg.org/css-display-3/#internal-table-element
pub fn (d Display) is_internal_table() bool {
	return d.is_internal() && (d.internal() == .table_row_group || d.internal() == .table_header_group || d.internal() == .table_footer_group || d.internal() == .table_row || d.internal() == .table_cell || d.internal() == .table_column_group || d.internal() == .table_column)
}

pub fn (d Display) is_none() bool {
	return d.type_ == .box && d.box_ == .none_
}

pub fn (d Display) is_contents() bool {
	return d.type_ == .box && d.box_ == .contents
}

pub fn (d Display) type_() DisplayType {
	return d.type_
}

pub fn (d Display) is_outside_and_inside() bool {
	return d.type_ == .outside_and_inside
}

pub fn (d Display) outside() DisplayOutside {
	if !d.is_outside_and_inside() {
		panic('VERIFY_NOT_REACHED')
	}
	return d.outside_
}

pub fn (d Display) is_block_outside() bool {
	return d.is_outside_and_inside() && d.outside() == .block
}

pub fn (d Display) is_inline_outside() bool {
	return d.is_outside_and_inside() && d.outside() == .inline_
}

pub fn (d Display) is_inline_block() bool {
	return d.is_inline_outside() && d.is_flow_root_inside()
}

pub fn (d Display) list_item() DisplayListItem {
	if !d.is_outside_and_inside() {
		panic('VERIFY_NOT_REACHED')
	}
	return d.list_item
}

pub fn (d Display) is_list_item() bool {
	return d.is_outside_and_inside() && d.list_item() == .yes
}

pub fn (d Display) inside() DisplayInside {
	if !d.is_outside_and_inside() {
		panic('VERIFY_NOT_REACHED')
	}
	return d.inside_
}

pub fn (d Display) is_flow_inside() bool {
	return d.is_outside_and_inside() && d.inside() == .flow
}

pub fn (d Display) is_flow_root_inside() bool {
	return d.is_outside_and_inside() && d.inside() == .flow_root
}

pub fn (d Display) is_table_inside() bool {
	return d.is_outside_and_inside() && d.inside() == .table
}

pub fn (d Display) is_flex_inside() bool {
	return d.is_outside_and_inside() && (d.inside_ == .flex || d.inside_ == .webkit_box)
}

pub fn (d Display) is_webkit_box_inside() bool {
	return d.is_outside_and_inside() && d.inside() == .webkit_box
}

pub fn (d Display) is_grid_inside() bool {
	return d.is_outside_and_inside() && d.inside() == .grid
}

pub fn (d Display) is_ruby_inside() bool {
	return d.is_outside_and_inside() && d.inside() == .ruby
}

pub fn (d Display) is_math_inside() bool {
	return d.is_outside_and_inside() && d.inside() == .math
}

pub fn display_outside_to_string(value DisplayOutside) string {
	return match value {
		.block { 'block' }
		.inline_ { 'inline' }
		.run_in { 'run-in' }
	}
}

pub fn display_inside_to_string(value DisplayInside) string {
	return match value {
		.flow { 'flow' }
		.flow_root { 'flow-root' }
		.table { 'table' }
		.flex { 'flex' }
		.grid { 'grid' }
		.ruby { 'ruby' }
		.math { 'math' }
		.webkit_box { '-webkit-box' }
	}
}

pub fn display_internal_to_string(value DisplayInternal) string {
	return match value {
		.table_row_group { 'table-row-group' }
		.table_header_group { 'table-header-group' }
		.table_footer_group { 'table-footer-group' }
		.table_row { 'table-row' }
		.table_cell { 'table-cell' }
		.table_column_group { 'table-column-group' }
		.table_column { 'table-column' }
		.table_caption { 'table-caption' }
		.ruby_base { 'ruby-base' }
		.ruby_text { 'ruby-text' }
		.ruby_base_container { 'ruby-base-container' }
		.ruby_text_container { 'ruby-text-container' }
	}
}

pub fn display_box_to_string(value DisplayBox) string {
	return match value {
		.none_ { 'none' }
		.contents { 'contents' }
	}
}

fn display_outside_from_keyword_string(value string) ?DisplayOutside {
	return match value {
		'block' { DisplayOutside.block }
		'inline' { DisplayOutside.inline_ }
		'run-in' { DisplayOutside.run_in }
		else { none }
	}
}

fn display_inside_from_keyword_string(value string) ?DisplayInside {
	return match value {
		'flow' { DisplayInside.flow }
		'flow-root' { DisplayInside.flow_root }
		'table' { DisplayInside.table }
		'flex' { DisplayInside.flex }
		'grid' { DisplayInside.grid }
		'ruby' { DisplayInside.ruby }
		'math' { DisplayInside.math }
		else { none }
	}
}

fn display_internal_from_keyword_string(value string) ?DisplayInternal {
	return match value {
		'table-row-group' { DisplayInternal.table_row_group }
		'table-header-group' { DisplayInternal.table_header_group }
		'table-footer-group' { DisplayInternal.table_footer_group }
		'table-row' { DisplayInternal.table_row }
		'table-cell' { DisplayInternal.table_cell }
		'table-column-group' { DisplayInternal.table_column_group }
		'table-column' { DisplayInternal.table_column }
		'table-caption' { DisplayInternal.table_caption }
		'ruby-base' { DisplayInternal.ruby_base }
		'ruby-text' { DisplayInternal.ruby_text }
		'ruby-base-container' { DisplayInternal.ruby_base_container }
		'ruby-text-container' { DisplayInternal.ruby_text_container }
		else { none }
	}
}

// https://drafts.csswg.org/css-display/#typedef-display-legacy and the single
// <display-outside> / <display-inside> / <display-internal> / <display-box> keywords.
pub fn display_from_single_keyword_string(value string) ?Display {
	if value == 'list-item' {
		return Display.from_short(.list_item)
	}
	if outside := display_outside_from_keyword_string(value) {
		return match outside {
			.block { Display.from_short(.block) }
			.inline_ { Display.from_short(.inline_) }
			.run_in { Display.from_short(.run_in) }
		}
	}
	if inside := display_inside_from_keyword_string(value) {
		return match inside {
			.flow { Display.from_short(.flow) }
			.flow_root { Display.from_short(.flow_root) }
			.table { Display.from_short(.table) }
			.flex { Display.from_short(.flex) }
			.grid { Display.from_short(.grid) }
			.ruby { Display.from_short(.ruby) }
			.math { Display.from_short(.math) }
			.webkit_box { Display.from_outside_inside(.block, .webkit_box) }
		}
	}
	if internal := display_internal_from_keyword_string(value) {
		return Display.from_internal(internal)
	}
	if value == 'contents' {
		return Display.from_short(.contents)
	}
	if value == 'none' {
		return Display.from_short(.none_)
	}
	return match value {
		'-webkit-box' { Display.from_outside_inside(.block, .webkit_box) }
		'-webkit-inline-box' { Display.from_outside_inside(.inline_, .webkit_box) }
		'inline-block' { Display.from_short(.inline_block) }
		'inline-table' { Display.from_short(.inline_table) }
		'inline-flex' { Display.from_short(.inline_flex) }
		'inline-grid' { Display.from_short(.inline_grid) }
		else { none }
	}
}

// <display-outside>? && <display-inside>? && list-item?
pub fn display_from_multi_keyword_strings(idents []string) ?Display {
	mut list_item := false
	mut has_inside := false
	mut inside := DisplayInside.flow
	mut has_outside := false
	mut outside := DisplayOutside.block
	for ident in idents {
		if ident == 'list-item' {
			if list_item {
				return none
			}
			list_item = true
			continue
		}
		if inside_value := display_inside_from_keyword_string(ident) {
			if has_inside {
				return none
			}
			has_inside = true
			inside = inside_value
			continue
		}
		if outside_value := display_outside_from_keyword_string(ident) {
			if has_outside {
				return none
			}
			has_outside = true
			outside = outside_value
			continue
		}
		return none
	}

	// The spec does not allow any other inside values to be combined with list-item.
	if list_item && has_inside && inside != .flow && inside != .flow_root {
		return none
	}

	list_item_value := if list_item { DisplayListItem.yes } else { DisplayListItem.no }
	return Display.from_outside_inside_and_list_item(outside, inside, list_item_value)
}

// --- Clip ---
pub enum ClipType {
	auto_
	rect
}

pub struct Clip {
pub mut:
	type_     ClipType
	edge_rect EdgeRect
}

pub fn Clip.new(type_ ClipType, edge_rect EdgeRect) Clip {
	return Clip{
		type_: type_
		edge_rect: edge_rect
	}
}

pub fn Clip.from_rect(edge_rect EdgeRect) Clip {
	return Clip.new(.rect, edge_rect)
}

pub fn Clip.make_auto() Clip {
	return Clip.new(.auto_, EdgeRect{
		top_edge: LengthOrAuto.make_auto()
		right_edge: LengthOrAuto.make_auto()
		bottom_edge: LengthOrAuto.make_auto()
		left_edge: LengthOrAuto.make_auto()
	})
}

pub fn (c Clip) is_auto() bool {
	return c.type_ == .auto_
}

pub fn (c Clip) is_rect() bool {
	return c.type_ == .rect
}

pub fn (c Clip) to_rect() EdgeRect {
	return c.edge_rect
}

// --- Filter ---
pub struct Filter {
pub mut:
	filter_value_list []FilterStyleValue
}

pub fn Filter.new(filter_value_list []FilterStyleValue) Filter {
	return Filter{
		filter_value_list: filter_value_list.clone()
	}
}

pub fn Filter.make_none() Filter {
	return Filter{}
}

pub fn (f Filter) has_filters() bool {
	return f.filter_value_list.len > 0
}

pub fn (f Filter) is_none() bool {
	return !f.has_filters()
}

pub fn (f Filter) filters() []FilterStyleValue {
	if !f.has_filters() {
		panic('VERIFY_NOT_REACHED')
	}
	return f.filter_value_list.clone()
}

// --- EasingFunction ---
pub enum StepPosition {
	jump_start
	jump_end
	jump_none
	jump_both
	start
	end
}

pub struct LinearEasingControlPoint {
pub mut:
	input  ?f64
	output f64
}

pub struct LinearEasingFunction {
pub mut:
	control_points []LinearEasingControlPoint
	stringified    string
}

pub struct CubicBezierEasingFunction {
pub mut:
	x1          f64
	y1          f64
	x2          f64
	y2          f64
	stringified string
}

pub struct StepsEasingFunction {
pub mut:
	interval_count i64
	position       StepPosition
	stringified    string
}

pub type EasingFunctionValue = CubicBezierEasingFunction
	| LinearEasingFunction
	| StepsEasingFunction

pub struct EasingFunction {
pub mut:
	value EasingFunctionValue
}

// https://drafts.csswg.org/css-easing/#linear-easing-function-output
pub fn (f LinearEasingFunction) evaluate_at(input_progress f64, before_flag bool) f64 {
	// To calculate linear easing output progress for a given linear easing function func,
	// an input progress value inputProgress, and an optional before flag (defaulting to false),
	// perform the following:

	// 1. Let points be func's control points.

	// 2. If points holds only a single item, return the output progress value of that item.
	if f.control_points.len == 1 {
		return f.control_points[0].output
	}

	first_input := f.control_points[0].input or { 0.0 }
	// 3. If inputProgress matches the input progress value of the first point in points,
	// and the before flag is true, return the first point's output progress value.
	if input_progress == first_input && before_flag {
		return f.control_points[0].output
	}

	// 4. If inputProgress matches the input progress value of at least one point in points,
	// return the output progress value of the last such point.
	mut maybe_match := ?LinearEasingControlPoint(none)
	for point in f.control_points {
		input := point.input or { continue }
		if input_progress == input {
			maybe_match = point
		}
	}
	if matched := maybe_match {
		return matched.output
	}

	// 5. Otherwise, find two control points in points, A and B, which will be used for interpolation:
	mut point_a := LinearEasingControlPoint{}
	mut point_b := LinearEasingControlPoint{}
	last_input := f.control_points[f.control_points.len - 1].input or { 1.0 }

	if input_progress < first_input {
		// 1. If inputProgress is smaller than any input progress value in points,
		// let A and B be the first two items in points.
		// If A and B have the same input progress value, return A's output progress value.
		point_a = f.control_points[0]
		point_b = f.control_points[1]
		a_input := point_a.input or { 0.0 }
		b_input := point_b.input or { 0.0 }
		if a_input == b_input {
			return point_a.output
		}
	} else if input_progress > last_input {
		// 2. If inputProgress is larger than any input progress value in points,
		// let A and B be the last two items in points.
		// If A and B have the same input progress value, return B's output progress value.
		point_a = f.control_points[f.control_points.len - 2]
		point_b = f.control_points[f.control_points.len - 1]
		a_input := point_a.input or { 0.0 }
		b_input := point_b.input or { 0.0 }
		if a_input == b_input {
			return point_b.output
		}
	} else {
		// 3. Otherwise, let A be the last control point whose input progress value is smaller than inputProgress,
		// and let B be the first control point whose input progress value is larger than inputProgress.
		for point in f.control_points {
			input := point.input or { continue }
			if input < input_progress {
				point_a = point
			}
			if input > input_progress {
				point_b = point
				break
			}
		}
	}

	// 6. Linearly interpolate (or extrapolate) inputProgress along the line defined by A and B, and return the result.
	a_input := point_a.input or { 0.0 }
	b_input := point_b.input or { 1.0 }
	factor := (input_progress - a_input) / (b_input - a_input)
	return point_a.output + factor * (point_b.output - point_a.output)
}

fn cubic_bezier_at(x1 f64, x2 f64, t f64) f64 {
	a := 1.0 - 3.0 * x2 + 3.0 * x1
	b := 3.0 * x2 - 6.0 * x1
	c := 3.0 * x1
	t2 := t * t
	t3 := t2 * t
	return (a * t3) + (b * t2) + (c * t)
}

fn cubic_bezier_derivative_at(x1 f64, x2 f64, t f64) f64 {
	a := 1.0 - 3.0 * x2 + 3.0 * x1
	b := 3.0 * x2 - 6.0 * x1
	c := 3.0 * x1
	return 3.0 * a * t * t + 2.0 * b * t + c
}

// https://www.w3.org/TR/css-easing-1/#cubic-bezier-algo
pub fn (f CubicBezierEasingFunction) evaluate_at(input_progress f64, before_flag bool) f64 {
	_ = before_flag

	// For input progress values outside the range [0, 1], the curve is extended infinitely using tangent of the curve
	// at the closest endpoint as follows:

	// - For input progress values less than zero,
	if input_progress < 0.0 {
		// 1. If the x value of P1 is greater than zero, use a straight line that passes through P1 and P0 as the
		//    tangent.
		if f.x1 > 0.0 {
			return f.y1 / f.x1 * input_progress
		}

		// 2. Otherwise, if the x value of P2 is greater than zero, use a straight line that passes through P2 and P0 as
		//    the tangent.
		if f.x2 > 0.0 {
			return f.y2 / f.x2 * input_progress
		}

		// 3. Otherwise, let the output progress value be zero for all input progress values in the range [-infinity, 0).
		return 0.0
	}

	// - For input progress values greater than one,
	if input_progress > 1.0 {
		// 1. If the x value of P2 is less than one, use a straight line that passes through P2 and P3 as the tangent.
		if f.x2 < 1.0 {
			return (1.0 - f.y2) / (1.0 - f.x2) * (input_progress - 1.0) + 1.0
		}

		// 2. Otherwise, if the x value of P1 is less than one, use a straight line that passes through P1 and P3 as the
		//    tangent.
		if f.x1 < 1.0 {
			return (1.0 - f.y1) / (1.0 - f.x1) * (input_progress - 1.0) + 1.0
		}

		// 3. Otherwise, let the output progress value be one for all input progress values in the range (1, infinity].
		return 1.0
	}

	// Note: The spec does not specify the precise algorithm for calculating values in the range [0, 1]:
	//       "The evaluation of this curve is covered in many sources such as [FUND-COMP-GRAPHICS]."

	// We use Newton-Raphson iteration to solve for the parameter t where x(t) = input_progress,
	// then return y(t). Falls back to bisection when Newton-Raphson doesn't converge.
	epsilon := 1e-7
	x := input_progress

	// Newton-Raphson iteration.
	mut t := x
	for _ in 0 .. 8 {
		x_at_t := cubic_bezier_at(f.x1, f.x2, t) - x
		if math.abs(x_at_t) < epsilon {
			return cubic_bezier_at(f.y1, f.y2, t)
		}
		dx := cubic_bezier_derivative_at(f.x1, f.x2, t)
		if math.abs(dx) < 1e-12 {
			break
		}
		t -= x_at_t / dx
	}

	// Bisection fallback.
	mut lo := 0.0
	mut hi := 1.0
	t = x
	for _ in 0 .. 64 {
		x_at_t := cubic_bezier_at(f.x1, f.x2, t)
		if math.abs(x_at_t - x) < epsilon {
			return cubic_bezier_at(f.y1, f.y2, t)
		}
		if x > x_at_t {
			lo = t
		} else {
			hi = t
		}
		t = (lo + hi) / 2.0
	}

	return cubic_bezier_at(f.y1, f.y2, t)
}

// https://www.w3.org/TR/css-easing-1/#step-easing-algo
pub fn (f StepsEasingFunction) evaluate_at(input_progress f64, before_flag bool) f64 {
	mut current_step := math.floor(input_progress * f64(f.interval_count))

	// 2. If the step position property is one of:
	//    - jump-start,
	//    - jump-both,
	//    increment current step by one.
	if f.position == .jump_start || f.position == .start || f.position == .jump_both {
		current_step += 1
	}

	// 3. If both of the following conditions are true:
	//    - the before flag is set, and
	//    - input progress value x steps mod 1 equals zero (that is, if input progress value x steps is integral), then
	//    decrement current step by one.
	step_progress := input_progress * f64(f.interval_count)
	if before_flag && math.trunc(step_progress) == step_progress {
		current_step -= 1
	}

	// 4. If input progress value >= 0 and current step < 0, let current step be zero.
	if input_progress >= 0.0 && current_step < 0.0 {
		current_step = 0.0
	}

	// 5. Calculate jumps based on the step position as follows:

	//    jump-start or jump-end -> steps
	//    jump-none -> steps - 1
	//    jump-both -> steps + 1
	mut jumps := f.interval_count
	if f.position == .jump_none {
		jumps--
	} else if f.position == .jump_both {
		jumps++
	}

	// 6. If input progress value <= 1 and current step > jumps, let current step be jumps.
	if input_progress <= 1.0 && current_step > f64(jumps) {
		current_step = f64(jumps)
	}

	// 7. The output progress value is current step / jumps.
	return current_step / f64(jumps)
}

// https://drafts.csswg.org/css-easing/#linear-canonicalization
fn canonicalize_linear_easing_function_control_points(control_points []LinearEasingControlPoint) []LinearEasingControlPoint {
	// To canonicalize a linear() function's control points, perform the following:
	mut canonicalized_control_points := control_points.clone()

	// 1. If the first control point lacks an input progress value, set its input progress value to 0.
	if canonicalized_control_points.len > 0 && canonicalized_control_points[0].input == none {
		canonicalized_control_points[0].input = 0.0
	}

	// 2. If the last control point lacks an input progress value, set its input progress value to 1.
	if canonicalized_control_points.len > 0 && canonicalized_control_points[canonicalized_control_points.len - 1].input == none {
		canonicalized_control_points[canonicalized_control_points.len - 1].input = 1.0
	}

	// 3. If any control point has an input progress value that is less than
	// the input progress value of any preceding control point,
	// set its input progress value to the largest input progress value of any preceding control point.
	mut largest_input := 0.0
	for mut control_point in canonicalized_control_points {
		if input := control_point.input {
			if input < largest_input {
				control_point.input = largest_input
			} else {
				largest_input = input
			}
		}
	}

	// 4. If any control point still lacks an input progress value,
	// then for each contiguous run of such control points,
	// set their input progress values so that they are evenly spaced
	// between the preceding and following control points with input progress values.
	mut run_start_idx := ?int(none)
	for idx in 0 .. canonicalized_control_points.len {
		control_point := canonicalized_control_points[idx]
		if control_point.input != none && run_start_idx != none {
			start_idx := run_start_idx
			start_input := canonicalized_control_points[start_idx - 1].input or { 0.0 }
			end_input := canonicalized_control_points[idx].input or { 1.0 }
			run_stop_count := idx - start_idx + 1
			delta := (end_input - start_input) / f64(run_stop_count)
			for run_idx in 0 .. run_stop_count {
				canonicalized_control_points[run_idx + start_idx - 1].input = start_input + delta * f64(run_idx)
			}
			run_start_idx = none
		} else if control_point.input == none && run_start_idx == none {
			// Note: this stop is the start of a run
			run_start_idx = idx
		}
	}

	return canonicalized_control_points
}

// https://drafts.csswg.org/css-easing-2/#linear-easing-function
pub fn EasingFunction.linear() EasingFunction {
	// Equivalent to linear(0, 1)
	return EasingFunction{
		value: LinearEasingFunction{
			control_points: [
				LinearEasingControlPoint{
					input: 0.0
					output: 0.0
				},
				LinearEasingControlPoint{
					input: 1.0
					output: 1.0
				},
			]
			stringified: 'linear'
		}
	}
}

// https://drafts.csswg.org/css-easing-2/#valdef-cubic-bezier-easing-function-ease-in
pub fn EasingFunction.ease_in() EasingFunction {
	// Equivalent to cubic-bezier(0.42, 0, 1, 1).
	return EasingFunction{
		value: CubicBezierEasingFunction{
			x1: 0.42
			y1: 0
			x2: 1
			y2: 1
			stringified: 'ease-in'
		}
	}
}

// https://drafts.csswg.org/css-easing-2/#valdef-cubic-bezier-easing-function-ease-out
pub fn EasingFunction.ease_out() EasingFunction {
	// Equivalent to cubic-bezier(0, 0, 0.58, 1).
	return EasingFunction{
		value: CubicBezierEasingFunction{
			x1: 0
			y1: 0
			x2: 0.58
			y2: 1
			stringified: 'ease-out'
		}
	}
}

// https://drafts.csswg.org/css-easing-2/#valdef-cubic-bezier-easing-function-ease-in-out
pub fn EasingFunction.ease_in_out() EasingFunction {
	// Equivalent to cubic-bezier(0.42, 0, 0.58, 1).
	return EasingFunction{
		value: CubicBezierEasingFunction{
			x1: 0.42
			y1: 0
			x2: 0.58
			y2: 1
			stringified: 'ease-in-out'
		}
	}
}

// https://drafts.csswg.org/css-easing-2/#valdef-cubic-bezier-easing-function-ease
pub fn EasingFunction.ease() EasingFunction {
	// Equivalent to cubic-bezier(0.25, 0.1, 0.25, 1).
	return EasingFunction{
		value: CubicBezierEasingFunction{
			x1: 0.25
			y1: 0.1
			x2: 0.25
			y2: 1
			stringified: 'ease'
		}
	}
}

pub fn EasingFunction.from_css_style_value(style_value StyleValue) EasingFunction {
	if style_value is EasingStyleValue {
		function := style_value.function()
		return match function {
			EasingLinear {
				mut resolved_control_points := []LinearEasingControlPoint{}
				for control_point in function.stops {
					output := number_from_style_value(control_point.output, none)

					input := if existing_input := control_point.input {
						?f64(Percentage.from_style_value_logic(existing_input).as_fraction())
					} else {
						?f64(none)
					}

					resolved_control_points << LinearEasingControlPoint{
						input: input
						output: output
					}
				}

				// https://drafts.csswg.org/css-easing-2/#funcdef-linear
				// If an argument lacks a <percentage>, its input progress value is initially empty. This is corrected
				// at used value time by linear() canonicalization.
				resolved_control_points = canonicalize_linear_easing_function_control_points(resolved_control_points)

				EasingFunction{
					value: LinearEasingFunction{
						control_points: resolved_control_points
						stringified: function.serialize(.resolved_value)
					}
				}
			}
			EasingCubicBezier {
				resolved_x1 := number_from_style_value(function.x1, none)
				resolved_y1 := number_from_style_value(function.y1, none)
				resolved_x2 := number_from_style_value(function.x2, none)
				resolved_y2 := number_from_style_value(function.y2, none)

				EasingFunction{
					value: CubicBezierEasingFunction{
						x1: resolved_x1
						y1: resolved_y1
						x2: resolved_x2
						y2: resolved_y2
						stringified: function.serialize(.normal)
					}
				}
			}
			EasingSteps {
				EasingFunction{
					value: StepsEasingFunction{
						interval_count: int_from_style_value(function.number_of_intervals)
						position: function.position
						stringified: function.serialize(.resolved_value)
					}
				}
			}
		}
	}

	return match style_value.serialize(.normal) {
		'linear' { EasingFunction.linear() }
		'ease-in' { EasingFunction.ease_in() }
		'ease-out' { EasingFunction.ease_out() }
		'ease-in-out' { EasingFunction.ease_in_out() }
		'ease' { EasingFunction.ease() }
		else { panic('VERIFY_NOT_REACHED') }
	}
}

pub fn EasingFunction.from_style_value(style_value &dom.StyleValue) EasingFunction {
	if style_value.css_text.len == 0 {
		return EasingFunction.ease()
	}

	if typed := typed_style_value_logic_from_dom(style_value) {
		if typed is EasingStyleValue {
			return EasingFunction.from_css_style_value(typed)
		}
		if typed is KeywordStyleValue {
			return match typed.serialize(.normal) {
				'linear', 'ease-in', 'ease-out', 'ease-in-out', 'ease' {
					EasingFunction.from_css_style_value(typed)
				}
				else { EasingFunction.ease() }
			}
		}
		return EasingFunction.ease()
	}

	mut parser := Parser.from_css_text(style_value.css_text)
	mut tokens := ComponentValueStream.new(parser.component_values)
	if easing := parser.parse_easing_value(mut tokens) {
		if !tokens.has_more_tokens() {
			return EasingFunction.from_css_style_value(easing)
		}
	}

	mut keyword_parser := Parser.from_css_text(style_value.css_text)
	mut keyword_tokens := ComponentValueStream.new(keyword_parser.component_values)
	if keyword := keyword_parser.parse_keyword_value(mut keyword_tokens) {
		if !keyword_tokens.has_more_tokens() {
			return match keyword.serialize(.normal) {
				'linear', 'ease-in', 'ease-out', 'ease-in-out', 'ease' {
					EasingFunction.from_css_style_value(keyword)
				}
				else {
					EasingFunction.ease()
				}
			}
		}
	}

	return EasingFunction.ease()
}

// parse_easing_function is the public CSS/Animations boundary used by the
// Web Animations translation. It accepts exactly one <easing-function> and
// rejects trailing tokens and CSS-wide keywords, matching
// AnimationEffect::parse_easing_string().
pub fn parse_easing_function(text string) ?EasingFunction {
	mut parser := Parser.from_css_text(text)
	mut tokens := ComponentValueStream.new(parser.component_values)
	if easing := parser.parse_easing_value(mut tokens) {
		if !tokens.has_more_tokens() {
			return EasingFunction.from_css_style_value(easing)
		}
	}
	return none
}

pub fn (f EasingFunction) evaluate_at(input_progress f64, before_flag bool) f64 {
	value := f.value
	return match value {
		LinearEasingFunction { value.evaluate_at(input_progress, before_flag) }
		CubicBezierEasingFunction { value.evaluate_at(input_progress, before_flag) }
		StepsEasingFunction { value.evaluate_at(input_progress, before_flag) }
	}
}

pub fn (f EasingFunction) to_string() string {
	value := f.value
	return match value {
		LinearEasingFunction { value.stringified }
		CubicBezierEasingFunction { value.stringified }
		StepsEasingFunction { value.stringified }
	}
}

pub fn make_linear_easing_function(control_points []LinearEasingControlPoint, stringified string) EasingFunction {
	return EasingFunction{
		value: LinearEasingFunction{
			control_points: canonicalize_linear_easing_function_control_points(control_points)
			stringified: stringified
		}
	}
}

// --- PreferredColorScheme ---
pub enum PreferredColorScheme {
	auto_
	light
	dark
}

pub fn preferred_color_scheme_from_string(value string) PreferredColorScheme {
	if value.to_lower() == 'light' {
		return .light
	}
	if value.to_lower() == 'dark' {
		return .dark
	}
	return .auto_
}

pub fn preferred_color_scheme_to_string(value PreferredColorScheme) string {
	return match value {
		.light { 'light' }
		.dark { 'dark' }
		.auto_ { 'auto' }
	}
}

// --- PreferredContrast ---
pub enum PreferredContrast {
	auto_
	less
	more
	no_preference
}

pub fn preferred_contrast_from_string(value string) PreferredContrast {
	lower_value := value.to_lower()
	if lower_value == 'less' {
		return .less
	}
	if lower_value == 'more' {
		return .more
	}
	if lower_value == 'no-preference' {
		return .no_preference
	}
	return .auto_
}

pub fn preferred_contrast_to_string(value PreferredContrast) string {
	return match value {
		.auto_ { 'auto' }
		.less { 'less' }
		.more { 'more' }
		.no_preference { 'no-preference' }
	}
}

// --- PreferredMotion ---
pub enum PreferredMotion {
	auto_
	no_preference
	reduce
}

pub fn preferred_motion_from_string(value string) PreferredMotion {
	lower_value := value.to_lower()
	if lower_value == 'no-preference' {
		return .no_preference
	}
	if lower_value == 'reduce' {
		return .reduce
	}
	return .auto_
}

pub fn preferred_motion_to_string(value PreferredMotion) string {
	return match value {
		.auto_ { 'auto' }
		.no_preference { 'no-preference' }
		.reduce { 'reduce' }
	}
}

pub fn split_whitespace(value string) []string {
	return value.fields()
}

pub fn join_with_single_space(parts []string) string {
	mut builder := strings.new_builder(parts.len * 8)
	for index, part in parts {
		if index > 0 {
			builder.write_u8(` `)
		}
		builder.write_string(part)
	}
	return builder.str()
}
