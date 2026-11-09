module css

import strings

// GridTrackSize.h depends only on Layout::AvailableSize::is_definite(). A V
// interface preserves that cross-module dependency without introducing the
// CSS -> Layout -> CSS import cycle; layout.AvailableSize satisfies it directly.
pub interface AvailableSize {
	is_definite() bool
}

// --- GridTrackPlacement ---

pub struct GridTrackPlacementAuto {}

pub struct GridTrackPlacementAreaOrLine {
pub mut:
	line_number ?StyleValue
	name        ?string
}

pub struct GridTrackPlacementSpan {
pub mut:
	value StyleValue
	name  ?string
}

pub type GridTrackPlacementValue = GridTrackPlacementAreaOrLine
	| GridTrackPlacementAuto
	| GridTrackPlacementSpan

pub struct GridTrackPlacement {
pub mut:
	value_ GridTrackPlacementValue
}

pub fn GridTrackPlacement.make_auto() GridTrackPlacement {
	return GridTrackPlacement{
		value_: GridTrackPlacementAuto{}
	}
}

pub fn GridTrackPlacement.make_line(line_number ?StyleValue, name ?string) GridTrackPlacement {
	return GridTrackPlacement{
		value_: GridTrackPlacementAreaOrLine{
			line_number: line_number
			name: name
		}
	}
}

pub fn GridTrackPlacement.make_span(value StyleValue, name ?string) GridTrackPlacement {
	return GridTrackPlacement{
		value_: GridTrackPlacementSpan{
			value: value
			name: name
		}
	}
}

pub fn (placement GridTrackPlacement) is_auto() bool {
	return placement.value_ is GridTrackPlacementAuto
}

pub fn (placement GridTrackPlacement) is_span() bool {
	return placement.value_ is GridTrackPlacementSpan
}

pub fn (placement GridTrackPlacement) is_area_or_line() bool {
	return placement.value_ is GridTrackPlacementAreaOrLine
}

pub fn (placement GridTrackPlacement) is_auto_positioned() bool {
	return placement.is_auto() || placement.is_span()
}

pub fn (placement GridTrackPlacement) is_positioned() bool {
	return !placement.is_auto_positioned()
}

pub fn (placement GridTrackPlacement) is_custom_ident() bool {
	value := placement.value_
	if value is GridTrackPlacementAreaOrLine {
		return value.line_number == none
	}
	return false
}

pub fn (placement GridTrackPlacement) has_identifier() bool {
	value := placement.value_
	if value is GridTrackPlacementAreaOrLine {
		return value.name != none
	}
	if value is GridTrackPlacementSpan { return value.name != none }
	return false
}

pub fn (placement GridTrackPlacement) has_line_number() bool {
	value := placement.value_
	if value is GridTrackPlacementAreaOrLine {
		return value.line_number != none
	}
	return false
}

pub fn (placement GridTrackPlacement) identifier() string {
	value := placement.value_
	if value is GridTrackPlacementAreaOrLine {
		if name := value.name {
			return name
		}
	}
	if value is GridTrackPlacementSpan { if name := value.name { return name } }
	panic('VERIFY_NOT_REACHED')
}

pub fn (placement GridTrackPlacement) line_number() StyleValue {
	value := placement.value_
	if value is GridTrackPlacementAreaOrLine {
		if line_number := value.line_number {
			return line_number
		}
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (placement GridTrackPlacement) span() StyleValue {
	value := placement.value_
	if value is GridTrackPlacementSpan {
		return value.value
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (placement GridTrackPlacement) serialize(mode SerializationMode) string {
	value := placement.value_
	return match value {
		GridTrackPlacementAuto {
			'auto'
		}
		GridTrackPlacementAreaOrLine {
			if line_number := value.line_number {
				if name := value.name {
					'${line_number.serialize(mode)} ${serialize_an_identifier(name)}'
				} else {
					line_number.serialize(mode)
				}
			} else if name := value.name {
				serialize_an_identifier(name)
			} else {
				''
			}
		}
		GridTrackPlacementSpan {
			mut serialized := 'span'

			if value.name == none || !value.value.is_integer()
				|| value.value.as_integer().integer() != 1 {
				serialized += ' ${value.value.serialize(mode)}'
			}

			if name := value.name {
				serialized += ' ${name}'
			}

			serialized
		}
	}
}

pub fn (placement GridTrackPlacement) to_string() string {
	return placement.serialize(.normal)
}

pub fn (placement GridTrackPlacement) to_string_with_mode(mode SerializationMode) string {
	return placement.serialize(mode)
}

pub fn (placement GridTrackPlacement) absolutized(context ComputationContext) GridTrackPlacement {
	value := placement.value_
	return match value {
		GridTrackPlacementAuto {
			placement
		}
		GridTrackPlacementAreaOrLine {
			absolutized_line_number := if existing_line_number := value.line_number {
				?StyleValue(existing_line_number.absolutized(context))
			} else {
				?StyleValue(none)
			}
			GridTrackPlacement{
				value_: GridTrackPlacementAreaOrLine{
					line_number: absolutized_line_number
					name: value.name
				}
			}
		}
		GridTrackPlacementSpan {
			GridTrackPlacement{
				value_: GridTrackPlacementSpan{
					value: value.value.absolutized(context)
					name: value.name
				}
			}
		}
	}
}

// --- GridTrackSize ---

pub type GridSizeValue = CalculatedStyleValue | Flex | Size

pub struct GridSize {
pub mut:
	value_ GridSizeValue
}

pub fn GridSize.from_size(size Size) GridSize {
	return GridSize{
		value_: size
	}
}

pub fn GridSize.from_flex(flex_factor Flex) GridSize {
	return GridSize{
		value_: flex_factor
	}
}

pub fn GridSize.from_calculated(calculated CalculatedStyleValue) GridSize {
	return GridSize{
		value_: calculated
	}
}

pub fn GridSize.make_auto() GridSize {
	return GridSize.from_size(Size.make_auto())
}

pub fn (grid_size GridSize) is_auto(available_size AvailableSize) bool {
	value := grid_size.value_
	if value is Size {
		if value.is_auto() {
			return true
		}
		if value.is_fit_content() {
			return false
		}
		if value.contains_percentage() {
			return !available_size.is_definite()
		}
		return false
	}

	return false
}

pub fn (grid_size GridSize) is_fixed(available_size AvailableSize) bool {
	value := grid_size.value_
	if value is Size {
		if !value.is_length_percentage() {
			return false
		}
		if value.contains_percentage() {
			return available_size.is_definite()
		}
		return true
	}

	return false
}

pub fn (grid_size GridSize) is_flexible_length() bool {
	return grid_size.value_ is Flex || grid_size.value_ is CalculatedStyleValue
}

pub fn (grid_size GridSize) is_fit_content() bool {
	value := grid_size.value_
	if value is Size {
		return value.is_fit_content()
	}

	return false
}

pub fn (grid_size GridSize) is_max_content() bool {
	value := grid_size.value_
	if value is Size {
		return value.is_max_content()
	}

	return false
}

pub fn (grid_size GridSize) is_min_content() bool {
	value := grid_size.value_
	if value is Size {
		return value.is_min_content()
	}

	return false
}

pub fn (grid_size GridSize) css_size() Size {
	value := grid_size.value_
	if value is Size {
		return value
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (grid_size GridSize) flex_factor() f64 {
	value := grid_size.value_
	if value is Flex {
		return value.to_fr()
	}
	if value is CalculatedStyleValue {
		return value.resolve_flex(CalculationResolutionContext{}) or {
			panic('calculated grid flex did not resolve')
		}.to_fr()
	}
	panic('VERIFY_NOT_REACHED')
}

// https://www.w3.org/TR/css-grid-2/#layout-algorithm
// An intrinsic sizing function (min-content, max-content, auto, fit-content()).
pub fn (grid_size GridSize) is_intrinsic(available_size AvailableSize) bool {
	value := grid_size.value_
	return match value {
		Size {
			value.is_auto() || value.is_max_content() || value.is_min_content()
				|| value.is_fit_content()
				|| (value.contains_percentage() && !available_size.is_definite())
		}
		Flex {
			false
		}
		CalculatedStyleValue {
			false
		}
	}
}

pub fn (grid_size GridSize) is_definite() bool {
	value := grid_size.value_
	return match value {
		Size { value.is_length_percentage() }
		Flex { false }
		CalculatedStyleValue { false }
	}
}

pub fn (grid_size GridSize) serialize(mode SerializationMode) string {
	value := grid_size.value_
	return match value {
		Size { value.serialize(mode) }
		Flex { value.serialize(mode) }
		CalculatedStyleValue { value.serialize(mode) }
	}
}

pub fn (grid_size GridSize) to_string() string {
	return grid_size.serialize(.normal)
}

pub fn (grid_size GridSize) to_string_with_mode(mode SerializationMode) string {
	return grid_size.serialize(mode)
}

fn absolutize_length_percentage(length_percentage LengthPercentage, context ComputationContext) ?LengthPercentage {
	if length_percentage.is_length() {
		if length := length_percentage.length().absolutize(context.length_resolution_context) {
			return LengthPercentage.from_length(length)
		}
		return none
	}

	if length_percentage.is_calculated() {
		return LengthPercentage.from_style_value_logic(length_percentage.calculated().absolutized(context))
	}

	return none
}

pub fn (grid_size GridSize) absolutized(context ComputationContext) GridSize {
	value := grid_size.value_
	return match value {
		Size {
			if value.is_length_percentage() {
				if result := absolutize_length_percentage(value.length_percentage(), context) {
					return GridSize.from_size(Size.make_length_percentage(result))
				}
			}

			if value.is_fit_content() {
				if available_space := value.fit_content_available_space() {
					if result := absolutize_length_percentage(available_space, context) {
						return GridSize.from_size(Size.make_fit_content(result))
					}
				}
			}

			GridSize.from_size(value)
		}
		Flex {
			GridSize.from_flex(value)
		}
		CalculatedStyleValue {
			absolutized := value.absolutized(context)
			match absolutized {
				CalculatedStyleValue { GridSize.from_calculated(absolutized) }
				FlexStyleValue { GridSize.from_flex(absolutized.flex()) }
				else { GridSize.from_calculated(value) }
			}
		}
	}
}

pub struct GridMinMax {
pub mut:
	min_grid_size_ GridSize
	max_grid_size_ GridSize
}

pub fn GridMinMax.new(min_grid_size GridSize, max_grid_size GridSize) GridMinMax {
	return GridMinMax{
		min_grid_size_: min_grid_size
		max_grid_size_: max_grid_size
	}
}

pub fn (minmax GridMinMax) min_grid_size() GridSize {
	return minmax.min_grid_size_
}

pub fn (minmax GridMinMax) max_grid_size() GridSize {
	return minmax.max_grid_size_
}

pub fn (minmax GridMinMax) serialize(mode SerializationMode) string {
	return 'minmax(${minmax.min_grid_size_.serialize(mode)}, ${minmax.max_grid_size_.serialize(mode)})'
}

pub fn (minmax GridMinMax) to_string() string {
	return minmax.serialize(.normal)
}

pub fn (minmax GridMinMax) to_string_with_mode(mode SerializationMode) string {
	return minmax.serialize(mode)
}

pub fn (minmax GridMinMax) absolutized(context ComputationContext) GridMinMax {
	return GridMinMax{
		min_grid_size_: minmax.min_grid_size_.absolutized(context)
		max_grid_size_: minmax.max_grid_size_.absolutized(context)
	}
}

pub struct GridLineName {
pub mut:
	name     string
	implicit bool
}

pub struct GridArea {
pub mut:
	row_start    uint
	row_end      uint = 1
	column_start uint
	column_end   uint = 1
}

pub struct GridTemplateAreas {
pub mut:
	areas        map[string]GridArea
	row_count    uint
	column_count uint
}

pub fn (areas GridTemplateAreas) is_empty() bool {
	return areas.row_count == 0
}

pub struct GridLineNames {
pub mut:
	names_ []GridLineName
}

pub fn (mut line_names GridLineNames) append(name string) {
	line_names.names_ << GridLineName{
		name: name
	}
}

pub fn (line_names GridLineNames) is_empty() bool {
	return line_names.names_.len == 0
}

pub fn (line_names GridLineNames) names() []GridLineName {
	return line_names.names_
}

pub fn (line_names GridLineNames) serialize() string {
	mut names := []string{}
	for name in line_names.names_ {
		names << name.name
	}
	return '[${names.join(' ')}]'
}

pub fn (line_names GridLineNames) to_string() string {
	return line_names.serialize()
}

pub type GridTrackSizeListItem = ExplicitGridTrack | GridLineNames

pub struct GridTrackSizeList {
pub mut:
	list_                    []GridTrackSizeListItem
	is_subgrid_              bool
	preserve_line_name_sets_ bool
}

pub fn GridTrackSizeList.make_none() GridTrackSizeList {
	return GridTrackSizeList{}
}

pub fn GridTrackSizeList.make_line_name_list() GridTrackSizeList {
	return GridTrackSizeList{
		preserve_line_name_sets_: true
	}
}

pub fn GridTrackSizeList.make_subgrid() GridTrackSizeList {
	return GridTrackSizeList{
		is_subgrid_: true
		preserve_line_name_sets_: true
	}
}

pub fn (track_size_list GridTrackSizeList) is_subgrid() bool {
	return track_size_list.is_subgrid_
}

pub fn (track_size_list GridTrackSizeList) track_list() []ExplicitGridTrack {
	mut track_list := []ExplicitGridTrack{}
	for item in track_size_list.list_ {
		if item is ExplicitGridTrack {
			track_list << item
		}
	}
	return track_list
}

pub fn (track_size_list GridTrackSizeList) list() []GridTrackSizeListItem {
	return track_size_list.list_
}

pub fn (track_size_list GridTrackSizeList) is_empty() bool {
	return !track_size_list.is_subgrid_ && track_size_list.list_.len == 0
}

pub fn (mut track_size_list GridTrackSizeList) append(item GridTrackSizeListItem) {
	match item {
		GridLineNames {
			track_size_list.append_line_names(item)
		}
		ExplicitGridTrack {
			track_size_list.append_explicit_track(item)
		}
	}
}

pub fn (mut track_size_list GridTrackSizeList) append_line_names(line_names GridLineNames) {
	if track_size_list.preserve_line_name_sets_ {
		track_size_list.list_ << GridTrackSizeListItem(line_names)
		return
	}
	if track_size_list.list_.len > 0 {
		last_index := track_size_list.list_.len - 1
		last := track_size_list.list_[last_index]
		if last is GridLineNames {
			mut last_line_names := last
			for name in line_names.names() {
				last_line_names.append(name.name)
			}
			track_size_list.list_[last_index] = GridTrackSizeListItem(last_line_names)
			return
		}
	}
	track_size_list.list_ << GridTrackSizeListItem(line_names)
}

pub fn (mut track_size_list GridTrackSizeList) append_explicit_track(explicit_track ExplicitGridTrack) {
	track_size_list.list_ << GridTrackSizeListItem(explicit_track)
}

pub fn (track_size_list GridTrackSizeList) serialize(mode SerializationMode) string {
	mut prefix := ''
	if track_size_list.is_subgrid_ {
		prefix = 'subgrid'
		if track_size_list.list_.len == 0 {
			return prefix
		}
		prefix += ' '
	}
	if track_size_list.list_.len == 0 {
		return 'none'
	}

	mut parts := []string{}
	for item in track_size_list.list_ {
		match item {
			ExplicitGridTrack {
				parts << item.serialize(mode)
			}
			GridLineNames {
				parts << item.serialize()
			}
		}
	}
	return prefix + parts.join(' ')
}

pub fn (track_size_list GridTrackSizeList) to_string() string {
	return track_size_list.serialize(.normal)
}

pub fn (track_size_list GridTrackSizeList) to_string_with_mode(mode SerializationMode) string {
	return track_size_list.serialize(mode)
}

pub fn (track_size_list GridTrackSizeList) absolutized(context ComputationContext) GridTrackSizeList {
	mut result := GridTrackSizeList{
		is_subgrid_: track_size_list.is_subgrid_
		preserve_line_name_sets_: track_size_list.preserve_line_name_sets_
	}
	for item in track_size_list.list_ {
		match item {
			ExplicitGridTrack {
				result.append_explicit_track(item.absolutized(context))
			}
			GridLineNames {
				result.append_line_names(item)
			}
		}
	}
	return result
}

pub enum GridRepeatType {
	auto_fit
	auto_fill
	fixed
}

pub struct GridRepeatParams {
pub mut:
	type_ GridRepeatType
	count ?StyleValue
}

pub struct GridRepeat {
pub mut:
	type_                GridRepeatType
	grid_track_size_list GridTrackSizeList
	repeat_count_        ?StyleValue
}

pub fn GridRepeat.new(grid_repeat_type GridRepeatType, grid_track_size_list GridTrackSizeList, repeat_count ?StyleValue) GridRepeat {
	return GridRepeat{
		type_: grid_repeat_type
		grid_track_size_list: grid_track_size_list
		repeat_count_: repeat_count
	}
}

pub fn GridRepeat.from_params(grid_track_size_list GridTrackSizeList, params GridRepeatParams) GridRepeat {
	return GridRepeat.new(params.type_, grid_track_size_list, params.count)
}

pub fn (repeat GridRepeat) is_auto_fill() bool {
	return repeat.type_ == .auto_fill
}

pub fn (repeat GridRepeat) is_auto_fit() bool {
	return repeat.type_ == .auto_fit
}

pub fn (repeat GridRepeat) is_fixed() bool {
	return repeat.type_ == .fixed
}

pub fn (repeat GridRepeat) repeat_count() uint {
	if !repeat.is_fixed() {
		panic('VERIFY_NOT_REACHED')
	}
	count := repeat.repeat_count_ or { panic('VERIFY_NOT_REACHED') }
	return uint(int_from_style_value(count))
}

pub fn (repeat GridRepeat) grid_track_size_list() GridTrackSizeList {
	return repeat.grid_track_size_list
}

pub fn (repeat GridRepeat) type_() GridRepeatType {
	return repeat.type_
}

pub fn (repeat GridRepeat) serialize(mode SerializationMode) string {
	repeat_prefix := match repeat.type_ {
		.auto_fit { 'auto-fit' }
		.auto_fill { 'auto-fill' }
		.fixed {
			count := repeat.repeat_count_ or { panic('VERIFY_NOT_REACHED') }
			count.serialize(mode)
		}
	}

	return 'repeat(${repeat_prefix}, ${repeat.grid_track_size_list.serialize(mode)})'
}

pub fn (repeat GridRepeat) to_string() string {
	return repeat.serialize(.normal)
}

pub fn (repeat GridRepeat) to_string_with_mode(mode SerializationMode) string {
	return repeat.serialize(mode)
}

pub fn (repeat GridRepeat) absolutized(context ComputationContext) GridRepeat {
	return GridRepeat{
		type_: repeat.type_
		grid_track_size_list: repeat.grid_track_size_list.absolutized(context)
		repeat_count_: if count := repeat.repeat_count_ {
			?StyleValue(count.absolutized(context))
		} else {
			?StyleValue(none)
		}
	}
}

pub type ExplicitGridTrackValue = GridMinMax | GridRepeat | GridSize

pub struct ExplicitGridTrack {
pub mut:
	value_ ExplicitGridTrackValue
}

pub fn ExplicitGridTrack.new(value ExplicitGridTrackValue) ExplicitGridTrack {
	return ExplicitGridTrack{
		value_: value
	}
}

pub fn ExplicitGridTrack.from_repeat(repeat GridRepeat) ExplicitGridTrack {
	return ExplicitGridTrack.new(ExplicitGridTrackValue(repeat))
}

pub fn ExplicitGridTrack.from_minmax(minmax GridMinMax) ExplicitGridTrack {
	return ExplicitGridTrack.new(ExplicitGridTrackValue(minmax))
}

pub fn ExplicitGridTrack.from_grid_size(grid_size GridSize) ExplicitGridTrack {
	return ExplicitGridTrack.new(ExplicitGridTrackValue(grid_size))
}

pub fn (track ExplicitGridTrack) is_repeat() bool {
	return track.value_ is GridRepeat
}

pub fn (track ExplicitGridTrack) repeat() GridRepeat {
	value := track.value_
	if value is GridRepeat {
		return value
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (track ExplicitGridTrack) is_minmax() bool {
	return track.value_ is GridMinMax
}

pub fn (track ExplicitGridTrack) minmax() GridMinMax {
	value := track.value_
	if value is GridMinMax {
		return value
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (track ExplicitGridTrack) is_default() bool {
	return track.value_ is GridSize
}

pub fn (track ExplicitGridTrack) grid_size() GridSize {
	value := track.value_
	if value is GridSize {
		return value
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (track ExplicitGridTrack) serialize(mode SerializationMode) string {
	value := track.value_
	return match value {
		GridRepeat { value.serialize(mode) }
		GridMinMax { value.serialize(mode) }
		GridSize { value.serialize(mode) }
	}
}

pub fn (track ExplicitGridTrack) to_string() string {
	return track.serialize(.normal)
}

pub fn (track ExplicitGridTrack) to_string_with_mode(mode SerializationMode) string {
	return track.serialize(mode)
}

pub fn (track ExplicitGridTrack) absolutized(context ComputationContext) ExplicitGridTrack {
	value := track.value_
	return match value {
		GridRepeat { ExplicitGridTrack.from_repeat(value.absolutized(context)) }
		GridMinMax { ExplicitGridTrack.from_minmax(value.absolutized(context)) }
		GridSize { ExplicitGridTrack.from_grid_size(value.absolutized(context)) }
	}
}

// --- GridAutoFlowStyleValue ---

pub enum GridAutoFlowAxis {
	row
	column
}

pub enum GridAutoFlowDense {
	no
	yes
}

pub struct GridAutoFlowStyleValue {
pub mut:
	row_   bool
	dense_ bool
}

pub fn GridAutoFlowStyleValue.create(axis GridAutoFlowAxis, dense GridAutoFlowDense) GridAutoFlowStyleValue {
	return GridAutoFlowStyleValue{
		row_:   axis == .row
		dense_: dense == .yes
	}
}

pub fn (style_value GridAutoFlowStyleValue) is_row() bool {
	return style_value.row_
}

pub fn (style_value GridAutoFlowStyleValue) is_column() bool {
	return !style_value.row_
}

pub fn (style_value GridAutoFlowStyleValue) is_dense() bool {
	return style_value.dense_
}

pub fn (style_value GridAutoFlowStyleValue) serialize(mode SerializationMode) string {
	_ = mode
	mut builder := strings.new_builder(0)
	if style_value.row_ && !style_value.dense_ {
		builder.write_string('row')
	} else if !style_value.row_ {
		builder.write_string('column')
	}
	if style_value.dense_ {
		if !style_value.row_ {
			builder.write_u8(` `)
		}
		builder.write_string('dense')
	}
	return builder.str()
}

pub fn (style_value GridAutoFlowStyleValue) to_string() string {
	return style_value.serialize(.normal)
}

pub fn (style_value GridAutoFlowStyleValue) properties_equal(other GridAutoFlowStyleValue) bool {
	return style_value.row_ == other.row_ && style_value.dense_ == other.dense_
}

// --- GridTrackPlacementStyleValue ---

pub struct GridTrackPlacementStyleValue {
pub mut:
	grid_track_placement_ []GridTrackPlacement = [GridTrackPlacement{}]
}

pub fn GridTrackPlacementStyleValue.create(grid_track_placement GridTrackPlacement) GridTrackPlacementStyleValue {
	return GridTrackPlacementStyleValue{
		grid_track_placement_: [grid_track_placement]
	}
}

pub fn (style_value GridTrackPlacementStyleValue) grid_track_placement() GridTrackPlacement {
	return style_value.grid_track_placement_[0]
}

pub fn (style_value GridTrackPlacementStyleValue) serialize(mode SerializationMode) string {
	return style_value.grid_track_placement_[0].serialize(mode)
}

pub fn (style_value GridTrackPlacementStyleValue) to_string() string {
	return style_value.serialize(.normal)
}

pub fn (style_value GridTrackPlacementStyleValue) absolutized(context ComputationContext) GridTrackPlacementStyleValue {
	absolutized_placement := style_value.grid_track_placement_[0].absolutized(context)
	if absolutized_placement == style_value.grid_track_placement_[0] {
		return style_value
	}
	return GridTrackPlacementStyleValue.create(absolutized_placement)
}

pub fn (style_value GridTrackPlacementStyleValue) properties_equal(other GridTrackPlacementStyleValue) bool {
	return style_value.grid_track_placement_[0] == other.grid_track_placement_[0]
}

// --- GridTrackSizeListStyleValue ---

pub struct GridTrackSizeListStyleValue {
pub mut:
	grid_track_size_list_ GridTrackSizeList
}

pub fn GridTrackSizeListStyleValue.create(grid_track_size_list GridTrackSizeList) GridTrackSizeListStyleValue {
	return GridTrackSizeListStyleValue{
		grid_track_size_list_: grid_track_size_list
	}
}

pub fn GridTrackSizeListStyleValue.make_auto() GridTrackSizeListStyleValue {
	return GridTrackSizeListStyleValue.create(GridTrackSizeList{})
}

pub fn GridTrackSizeListStyleValue.make_none() GridTrackSizeListStyleValue {
	return GridTrackSizeListStyleValue.create(GridTrackSizeList{})
}

pub fn (style_value GridTrackSizeListStyleValue) grid_track_size_list() GridTrackSizeList {
	return style_value.grid_track_size_list_
}

pub fn (style_value GridTrackSizeListStyleValue) serialize(mode SerializationMode) string {
	return style_value.grid_track_size_list_.serialize(mode)
}

pub fn (style_value GridTrackSizeListStyleValue) to_string() string {
	return style_value.serialize(.normal)
}

pub fn (style_value GridTrackSizeListStyleValue) absolutized(context ComputationContext) GridTrackSizeListStyleValue {
	absolutized := style_value.grid_track_size_list_.absolutized(context)
	if absolutized == style_value.grid_track_size_list_ {
		return style_value
	}
	return GridTrackSizeListStyleValue.create(absolutized)
}

pub fn (style_value GridTrackSizeListStyleValue) properties_equal(other GridTrackSizeListStyleValue) bool {
	return style_value.grid_track_size_list_ == other.grid_track_size_list_
}

// --- GridTemplateAreaStyleValue ---

pub struct GridTemplateAreaStyleValue {
pub mut:
	grid_areas_   map[string]GridArea
	row_count_    uint
	column_count_ uint
}

pub fn GridTemplateAreaStyleValue.create(grid_areas map[string]GridArea, row_count uint, column_count uint) GridTemplateAreaStyleValue {
	return GridTemplateAreaStyleValue{
		grid_areas_:   grid_areas
		row_count_:    row_count
		column_count_: column_count
	}
}

pub fn (style_value GridTemplateAreaStyleValue) grid_areas() map[string]GridArea {
	return style_value.grid_areas_
}

pub fn (style_value GridTemplateAreaStyleValue) row_count() uint {
	return style_value.row_count_
}

pub fn (style_value GridTemplateAreaStyleValue) column_count() uint {
	return style_value.column_count_
}

pub fn (style_value GridTemplateAreaStyleValue) cell_name_at(row uint, column uint) string {
	for name, area in style_value.grid_areas_ {
		if row >= area.row_start && row < area.row_end && column >= area.column_start
			&& column < area.column_end {
			return name
		}
	}
	return '.'
}

pub fn (style_value GridTemplateAreaStyleValue) serialize(mode SerializationMode) string {
	_ = mode
	if style_value.row_count_ == 0 {
		return 'none'
	}

	mut builder := strings.new_builder(0)
	for y in 0 .. style_value.row_count_ {
		if y != 0 {
			builder.write_u8(` `)
		}
		mut row_builder := strings.new_builder(0)
		for x in 0 .. style_value.column_count_ {
			if x != 0 {
				row_builder.write_u8(` `)
			}
			row_builder.write_string(style_value.cell_name_at(y, x))
		}
		builder.write_string(serialize_a_string(row_builder.str()))
	}
	return builder.str()
}

pub fn (style_value GridTemplateAreaStyleValue) to_string() string {
	return style_value.serialize(.normal)
}

pub fn (style_value GridTemplateAreaStyleValue) properties_equal(other GridTemplateAreaStyleValue) bool {
	return style_value.row_count_ == other.row_count_
		&& style_value.column_count_ == other.column_count_
		&& style_value.grid_areas_ == other.grid_areas_
}
