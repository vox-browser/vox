module css

// Small translated subset of Gfx::Color used by CSS style values.
pub struct Color {
pub mut:
	r u8
	g u8
	b u8
	a u8 = 255
}

pub fn Color.rgb(r u8, g u8, b u8) Color {
	return Color{
		r: r
		g: g
		b: b
		a: 255
	}
}

pub fn Color.rgba(r u8, g u8, b u8, a u8) Color {
	return Color{
		r: r
		g: g
		b: b
		a: a
	}
}

pub enum ValueType {
	anchor
	anchor_size
	angle
	angle_percentage
	background_position
	basic_shape
	color
	corner_shape
	counter
	counter_style
	custom_ident
	dashed_ident
	easing_function
	filter_value_list
	fit_content
	flex
	font_style
	font_variant_alternates
	font_variant_east_asian
	font_variant_ligatures
	font_variant_numeric
	frequency
	frequency_percentage
	image
	integer
	length
	length_percentage
	number
	opacity
	opentype_tag
	paint
	percentage
	position
	ratio
	rect
	resolution
	scroll_function
	string
	time
	time_percentage
	transform_function
	transform_list
	url
	view_function
	view_timeline_inset
}

pub fn value_type_from_string(value string) ?ValueType {
	return match to_ascii_lowercase(value) {
		'anchor-size' { ValueType.anchor_size }
		'angle' { ValueType.angle }
		'angle-percentage' { ValueType.angle_percentage }
		'background-position' { ValueType.background_position }
		'basic-shape' { ValueType.basic_shape }
		'color' { ValueType.color }
		'counter' { ValueType.counter }
		'counter-style' { ValueType.counter_style }
		'custom-ident' { ValueType.custom_ident }
		'dashed-ident' { ValueType.dashed_ident }
		'easing-function' { ValueType.easing_function }
		'filter-value-list' { ValueType.filter_value_list }
		'fit-content' { ValueType.fit_content }
		'flex' { ValueType.flex }
		'font-variant-alternates' { ValueType.font_variant_alternates }
		'font-variant-east-asian' { ValueType.font_variant_east_asian }
		'font-variant-ligatures' { ValueType.font_variant_ligatures }
		'font-variant-numeric' { ValueType.font_variant_numeric }
		'frequency' { ValueType.frequency }
		'frequency-percentage' { ValueType.frequency_percentage }
		'image' { ValueType.image }
		'integer' { ValueType.integer }
		'length' { ValueType.length }
		'length-percentage' { ValueType.length_percentage }
		'number' { ValueType.number }
		'opacity' { ValueType.opacity }
		'opentype-tag' { ValueType.opentype_tag }
		'paint' { ValueType.paint }
		'percentage' { ValueType.percentage }
		'position' { ValueType.position }
		'ratio' { ValueType.ratio }
		'rect' { ValueType.rect }
		'resolution' { ValueType.resolution }
		'scroll-function' { ValueType.scroll_function }
		'string' { ValueType.string }
		'time' { ValueType.time }
		'time-percentage' { ValueType.time_percentage }
		'transform-function' { ValueType.transform_function }
		'transform-list' { ValueType.transform_list }
		'url' { ValueType.url }
		'view-function' { ValueType.view_function }
		'view-timeline-inset' { ValueType.view_timeline_inset }
		else { none }
	}
}

pub fn value_type_to_string(value_type ValueType) string {
	return match value_type {
		.anchor { 'Anchor' }
		.anchor_size { 'AnchorSize' }
		.angle { 'Angle' }
		.angle_percentage { 'AnglePercentage' }
		.background_position { 'BackgroundPosition' }
		.basic_shape { 'BasicShape' }
		.color { 'Color' }
		.corner_shape { 'CornerShape' }
		.counter { 'Counter' }
		.counter_style { 'CounterStyle' }
		.custom_ident { 'CustomIdent' }
		.dashed_ident { 'DashedIdent' }
		.easing_function { 'EasingFunction' }
		.filter_value_list { 'FilterValueList' }
		.fit_content { 'FitContent' }
		.flex { 'Flex' }
		.font_style { 'FontStyle' }
		.font_variant_alternates { 'FontVariantAlternates' }
		.font_variant_east_asian { 'FontVariantEastAsian' }
		.font_variant_ligatures { 'FontVariantLigatures' }
		.font_variant_numeric { 'FontVariantNumeric' }
		.frequency { 'Frequency' }
		.frequency_percentage { 'FrequencyPercentage' }
		.image { 'Image' }
		.integer { 'Integer' }
		.length { 'Length' }
		.length_percentage { 'LengthPercentage' }
		.number { 'Number' }
		.opacity { 'Opacity' }
		.opentype_tag { 'OpenTypeTag' }
		.paint { 'Paint' }
		.percentage { 'Percentage' }
		.position { 'Position' }
		.ratio { 'Ratio' }
		.rect { 'Rect' }
		.resolution { 'Resolution' }
		.scroll_function { 'ScrollFunction' }
		.string { 'String' }
		.time { 'Time' }
		.time_percentage { 'TimePercentage' }
		.transform_function { 'TransformFunction' }
		.transform_list { 'TransformList' }
		.url { 'Url' }
		.view_function { 'ViewFunction' }
		.view_timeline_inset { 'ViewTimelineInset' }
	}
}
