module css

// SVG geometry, paint resources, grid templates, filters and transforms are
// absent on most layout styles. Their exact empty/default values live once;
// published styles only allocate this record after a nondefault write.
@[heap]
struct ComputedLayoutRareData {
mut:
	computed_values_grid_template_columns_         GridTrackSizeList
	computed_values_grid_template_rows_            GridTrackSizeList
	computed_values_grid_template_areas_           GridTemplateAreas
	computed_values_mask_                          ?MaskReference
	computed_values_mask_image_                    ?ImageStyleValue
	computed_values_clip_path_                     ?ClipPathReference
	computed_values_backdrop_filter_               Filter
	computed_values_filter_                        Filter
	computed_values_rotate_                        ?TransformationData
	computed_values_scale_                         ?TransformationData
	computed_values_perspective_                   ?CSSPixels
	computed_values_perspective_origin_            Position
	computed_values_transformations_               []TransformationData
	computed_values_transform_box_                 TransformBox
	computed_values_transform_origin_              TransformOrigin
	computed_values_transform_style_               TransformStyle
	computed_values_translate_                     ?TransformationData
	computed_values_cx_                            LengthPercentage
	computed_values_cy_                            LengthPercentage
	computed_values_r_                             LengthPercentage
	computed_values_x_                             LengthPercentage
	computed_values_y_                             LengthPercentage
}

fn make_initial_computed_layout_rare_data() ComputedLayoutRareData {
	return ComputedLayoutRareData{}
}

__global initial_computed_layout_rare_data = make_initial_computed_layout_rare_data()

fn (cache &ComputedLayoutCache) rare_data() &ComputedLayoutRareData {
	if cache.rare_data_ != unsafe { nil } { return cache.rare_data_ }
	return &initial_computed_layout_rare_data
}

// The owning hot snapshot is already detached by ensure_computed_layout_cache.
// Its write flag is cleared on every copy and when a bulk write is published,
// so replacing one rare field cannot modify another style's shared snapshot.
fn (mut cache ComputedLayoutCache) ensure_rare_data() &ComputedLayoutRareData {
	if !cache.rare_data_writable_ {
		previous := cache.rare_data()
		cache.rare_data_ = &ComputedLayoutRareData{ ...previous }
		cache.rare_data_writable_ = true
	}
	return cache.rare_data_
}
