#pragma once

extern int vox_draw_document_gradient_pixels(uint8_t*, int, int, int, int, int, int, VoxGraphitePath*);

// Only transfer destination pixels and normalized geometry here. V owns the
// compositor grid, sample selection, premultiplied gradient and shader draw.
static int native_try_v_css_gradient(VoxGraphitePath draw, const float *matrix,
    float page_x, float page_y, float scroll_y, float canvas_height) {
    if ([[NSGraphicsContext currentContext] CGContext] != native_font_compositing_context
        || native_font_compositing_transparency_depth != 0
        || !draw.segments || draw.segment_count <= 0 || draw.stroke || !draw.stops
        || draw.stop_count < 2 || draw.stop_count > 64 || draw.linear_color_space) return 0;
    if (draw.gradient != 1 && draw.gradient != 2) return 0;
    for (int i=0;i<6;++i) if (!isfinite(matrix[i]) || !isfinite(draw.gradient_points[i])) return 0;
    for (int i=0;i<9;++i) if (!isfinite(draw.gradient_matrix[i])) return 0;
    for (int i=0;i<draw.stop_count*5;++i) if (!isfinite(draw.stops[i])) return 0;
    CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
    CGSize horizontal = CGContextConvertSizeToDeviceSpace(context, CGSizeMake(1,0));
    CGSize vertical = CGContextConvertSizeToDeviceSpace(context, CGSizeMake(0,1));
    double device_scale = fmax(hypot(horizontal.width,horizontal.height),hypot(vertical.width,vertical.height));
    if (!isfinite(device_scale) || device_scale <= 0) return 0;
    float canvas_width = (float)(CGBitmapContextGetWidth(context) / device_scale);
    CGPathRef path = native_create_path_from_data(draw.segments, draw.segment_count);
    if (!path) return 0;
    CGRect bounds = CGPathGetPathBoundingBox(path);
    CGPathRelease(path);
    float left = INFINITY, top = INFINITY, right = -INFINITY, bottom = -INFINITY;
    for (int i = 0; i < 4; ++i) {
        float x = bounds.origin.x + ((i & 1) ? bounds.size.width : 0);
        float y = bounds.origin.y + ((i & 2) ? bounds.size.height : 0);
        float dx = matrix[0]*x + matrix[2]*y + matrix[4];
        float dy = matrix[1]*x + matrix[3]*y + matrix[5];
        left=fminf(left,dx); top=fminf(top,dy); right=fmaxf(right,dx); bottom=fmaxf(bottom,dy);
    }
    int32_t geometry[7]; float scale;
    int prepared = native_text_raster_begin(left, top, right, bottom, canvas_width, canvas_height,
        16, geometry, &scale);
    if (prepared == 2) return 1;
    if (prepared != 1 || !geometry[4]) return 0;
    int w=geometry[2], h=geometry[3], backdrop=geometry[4];
    uint8_t *pixels = calloc((size_t)w*h*4, 1);
    if (!pixels) return 0;
    if (backdrop && !native_text_raster_read_backdrop(pixels, geometry[0], geometry[1], w, h, scale)) {
        free(pixels); return 0;
    }
    float sx=(float)w/geometry[5], sy=(float)h/geometry[6];
    float cropped[9]={matrix[0]*sx,matrix[2]*sx,(matrix[4]-geometry[0])*sx,
        matrix[1]*sy,matrix[3]*sy,(matrix[5]-geometry[1])*sy,0,0,1};
    memcpy(draw.matrix,cropped,sizeof(cropped));
    int drawn=vox_draw_document_gradient_pixels(pixels,w,h,w*4,backdrop,
        (int)lround((geometry[0]-page_x)*scale),
        (int)lround((geometry[1]-page_y+scroll_y)*scale),&draw);
    if (drawn) drawn=native_text_raster_finish(pixels,geometry[0],geometry[1],w,h,
        geometry[5],geometry[6],canvas_height,backdrop);
    free(pixels);
    return drawn;
}

#ifdef VOX_TEST_CSS_GRADIENT_PIXELS
static int vox_test_css_gradient_pixels(uint8_t *pixels, int width, int height, int chrome,
    const VoxGraphitePath *draw) {
    CGColorSpaceRef space=CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef context=CGBitmapContextCreate(pixels,width,height+chrome,8,width*4,space,
        kCGImageAlphaPremultipliedLast|kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space);
    if (!context) return 0;
    CGContextSetRGBFillColor(context,9.0/255.0,11.0/255.0,15.0/255.0,1);
    CGContextFillRect(context,CGRectMake(0,0,width,height+chrome));
    CGContextRef previous=native_font_compositing_context;
    int previous_depth=native_font_compositing_transparency_depth;
    native_font_compositing_context=context;
    native_font_compositing_transparency_depth=0;
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithCGContext:context flipped:NO]];
    float matrix[6]={1,0,0,1,0,chrome};
    int result=native_try_v_css_gradient(*draw,matrix,0,chrome,0,height+chrome);
    [NSGraphicsContext restoreGraphicsState];
    native_font_compositing_context=previous;
    native_font_compositing_transparency_depth=previous_depth;
    CGContextRelease(context);
    return result;
}
#endif
