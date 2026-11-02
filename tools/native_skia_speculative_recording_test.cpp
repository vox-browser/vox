// Authored for the opt-in renderer; execution deferred until the FPS target.
#include "../native_skia_text_darwin.cpp"
#include <cassert>

int main()
{
    s_raster_layer_width = 512; s_raster_layer_height = 384;
    auto color = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto context = CGBitmapContextCreate(nullptr, 1024, 768, 8, 4096, color,
        CGBitmapInfo(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(color);
    assert(context && !speculative_picture_context_eligible(context));
    CGContextScaleCTM(context, 2, 2);
    assert(speculative_picture_context_eligible(context));
    s_shared_clips[context].unsupported = true;
    assert(!speculative_picture_context_eligible(context));
    s_shared_clips.clear();
    SharedClip clip; clip.matrix = SkMatrix::I();
    clip.rect.setRectXY(SkRect::MakeWH(512, 384), 10, 10);
    s_shared_clips[context].clips.push_back(clip);
    assert(!speculative_picture_context_eligible(context));
    s_shared_clips.clear();
    clip.rect = SkRRect::MakeRect(SkRect::MakeWH(512, 384));
    s_shared_clips[context].clips.push_back(clip);
    assert(speculative_picture_context_eligible(context));
    s_shared_clips[context].clips.back().matrix = SkMatrix::Translate(.25f, 0);
    assert(!speculative_picture_context_eligible(context));
    s_shared_clips.clear();
    CGContextSaveGState(context);
    CGContextClipToRect(context, CGRectMake(.25, 0, 500, 380));
    assert(!speculative_picture_context_eligible(context));
    CGContextRestoreGState(context);
    assert(speculative_picture_context_eligible(context));
    CGContextTranslateCTM(context, 1, 0);
    assert(!speculative_picture_context_eligible(context));
    CGContextRelease(context);
}
