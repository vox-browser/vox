#ifndef VOX_NATIVE_CSS_DROP_SHADOW_DARWIN_H
#define VOX_NATIVE_CSS_DROP_SHADOW_DARWIN_H

static void native_css_drop_shadow_color_matrix(CGFloat matrix[20],
    CGFloat red, CGFloat green, CGFloat blue, CGFloat alpha) {
    memset(matrix, 0, sizeof(CGFloat) * 20);
    // CIColorMatrix operates on unpremultiplied channels. The shadow
    // color is constant; only its opacity follows the blurred alpha mask.
    matrix[4] = red;
    matrix[9] = green;
    matrix[14] = blue;
    matrix[18] = alpha;
}

#endif
