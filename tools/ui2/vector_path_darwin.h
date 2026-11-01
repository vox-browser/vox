#pragma once
#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#include <stdint.h>

// UI2 backend primitive only: no browser geometry, control classes or actions.
static char ui2_vector_layer_key, ui2_vector_points_key, ui2_vector_closed_key;
static CGColorRef ui2_vector_color(uint32_t rgb) {
    return CGColorCreateSRGB(((rgb >> 16) & 255) / 255.0,
        ((rgb >> 8) & 255) / 255.0, (rgb & 255) / 255.0, 1);
}
static void ui2_embedded_vector_path(void *handle, const double *xy, int32_t count,
    bool closed, bool filled, uint32_t fill, uint32_t stroke, double line_width) {
    NSView *view=(__bridge NSView *)handle;
    CAShapeLayer *layer=objc_getAssociatedObject(view,&ui2_vector_layer_key);
    if (count < 2) { if (layer) layer.hidden=YES; return; }
    view.wantsLayer=YES;
    if (!layer) {
        layer=[CAShapeLayer layer];
        objc_setAssociatedObject(view,&ui2_vector_layer_key,layer,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (layer.superlayer != view.layer) [view.layer addSublayer:layer];
    [CATransaction begin]; [CATransaction setDisableActions:YES];
    layer.hidden=NO;
    layer.frame=view.bounds;
    // Paths use UI2 top-left coordinates, including on unflipped native controls.
    NSData *data=[NSData dataWithBytes:xy length:(NSUInteger)count*2*sizeof(double)];
    NSData *previous=objc_getAssociatedObject(view,&ui2_vector_points_key);
    if (![previous isEqualToData:data] || [objc_getAssociatedObject(view,&ui2_vector_closed_key) boolValue] != closed) {
        CGMutablePathRef path=CGPathCreateMutable();
        CGPathMoveToPoint(path,NULL,xy[0],xy[1]);
        for (int32_t i=1;i<count;++i) CGPathAddLineToPoint(path,NULL,xy[2*i],xy[2*i+1]);
        if (closed) CGPathCloseSubpath(path);
        layer.path=path; CGPathRelease(path);
        objc_setAssociatedObject(view,&ui2_vector_closed_key,@(closed),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(view,&ui2_vector_points_key,data,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    layer.geometryFlipped=!view.isFlipped;
    CGColorRef fill_color=ui2_vector_color(fill), stroke_color=ui2_vector_color(stroke);
    layer.fillColor=filled && closed ? fill_color : NULL;
    layer.strokeColor=line_width>0 ? stroke_color : NULL;
    layer.lineWidth=line_width;
    layer.contentsScale=view.window.backingScaleFactor ?: 1;
    CGColorRelease(fill_color); CGColorRelease(stroke_color);
    [CATransaction commit];
}
