#pragma once
#ifdef LADYBIRD_V_HAS_SKIA_TEXT
extern int ladybird_v_skia_draw_contoured_box(CGContextRef,const float*,const float*,
    const float*,const float*,float,float,float,float,float,uint8_t,uint8_t,uint8_t,uint8_t,int,float,int);
extern void ladybird_v_skia_set_contoured_box_reference(const float*);
#endif
void native_set_contoured_box_reference(const float* reference)
{
#ifdef LADYBIRD_V_HAS_SKIA_TEXT
    ladybird_v_skia_set_contoured_box_reference(reference);
#endif
}
int native_draw_contoured_box_srgb(const float* target,const float* shapes,
    const float* cutout,const float* matrix,float page_x,float page_y,float scroll_y,
    float width,float height,gg__Color color,int mode,float amount)
{
#ifdef LADYBIRD_V_HAS_SKIA_TEXT
    CGContextRef context=[[NSGraphicsContext currentContext] CGContext];
    return ladybird_v_skia_draw_contoured_box(context,target,shapes,cutout,matrix,
        page_x,page_y,scroll_y,width,height,color.r,color.g,color.b,color.a,mode,amount,
        context==native_font_compositing_context&&native_font_compositing_transparency_depth==0);
#else
    return 0;
#endif
}
