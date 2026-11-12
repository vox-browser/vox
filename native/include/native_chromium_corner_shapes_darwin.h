#pragma once

void native_set_contoured_box_reference(const float* reference)
{
    native_v_shape_state.has_contour_reference = reference != NULL;
    if (reference) memcpy(native_v_shape_state.contour_reference, reference, 12 * sizeof(float));
}

// Only transport the retained descriptor and destination pixels. Contour
// geometry, clipping, border layers and filtering are implemented in V.
int native_draw_contoured_box_srgb(const float* target, const float* parameters,
    const float* cutout, const float* affine, float page_x, float page_y, float scroll_y,
    float width, float height, gg__Color color, int mode, float amount)
{
    VoxGraphiteShape shape = native_v_shape_state;
    native_v_shape_state.has_contour_reference = 0;
    native_v_shape_state.has_float_color = 0;
    native_v_shape_state.has_underlay = 0;
    native_v_shape_state.has_float_underlay_color = 0;
    if (!target || !parameters || !affine || mode < 0 || mode > 2) return 0;
    memcpy(shape.rect, target, 12 * sizeof(float));
    memcpy(shape.contour_parameters, parameters, 4 * sizeof(float));
    shape.fill = 11 + mode;
    shape.thickness = amount;
    shape.anti_alias = 1;
    shape.force_msaa = 0;
    shape.red = color.r; shape.green = color.g; shape.blue = color.b; shape.alpha = color.a;
    shape.has_underlay = mode == 1 && shape.has_underlay;
    if (mode == 2 && cutout) memcpy(shape.underlay_rect, cutout, 12 * sizeof(float));
    const float matrix[6] = {affine[0], affine[1], affine[2], affine[3],
        page_x + affine[4], page_y - scroll_y + affine[5]};
    return native_try_v_document_shape(shape, matrix, width, height, page_x, page_y, scroll_y);
}
