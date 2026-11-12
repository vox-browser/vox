#pragma once
extern int32_t vox_document_sampled_png_pixels(uint8_t*,int32_t,int32_t,int32_t,int32_t,
    int32_t,int32_t,uint8_t*,int32_t,int32_t,int32_t,int32_t,float,float,float,float,float*);

int native_draw_sampled_png(const uint8_t *source,int source_width,int source_height,int natural_width,int natural_height,
    float x,float y,float width,float height,const float *clip,float page_x,float page_y,float scroll_y,
    float canvas_width,float canvas_height) {
    CGContextRef context=[[NSGraphicsContext currentContext] CGContext];
    if (context!=native_font_compositing_context || native_font_compositing_transparency_depth
        || !source || !clip || source_width<=0 || source_height<=0 || source_width>4096 || source_height>4096
        || (int64_t)source_width*source_height>4*1024*1024
        || !isfinite(x) || !isfinite(y) || !isfinite(width) || !isfinite(height)
        || width<=0 || height<=0) return 0;
    for (int i=0;i<12;++i) if (!isfinite(clip[i]) || (i>=4 && clip[i]<0)) return 0;
    if (clip[2]<=0 || clip[3]<=0) return 0;
    float left=page_x+x,top=page_y-scroll_y+y;
    int32_t geometry[7];float scale;
    int prepared=native_text_raster_begin(left,top,left+width,top+height,
        canvas_width,canvas_height,16,geometry,&scale);
    if (prepared==2) return 1;
    if (prepared!=1 || scale!=1 || !geometry[4]) return 0;
    int w=geometry[2],h=geometry[3];
    uint8_t *pixels=calloc((size_t)w*h*4,1);
    if (!pixels) return 0;
    float local_clip[12];memcpy(local_clip,clip,sizeof(local_clip));
    local_clip[0]+=page_x-geometry[0];local_clip[1]+=page_y-scroll_y-geometry[1];
    int drawn=native_text_raster_read_backdrop(pixels,geometry[0],geometry[1],w,h,scale);
    if (drawn) drawn=vox_document_sampled_png_pixels(pixels,w,h,w*4,1,
        (int32_t)(geometry[0]-page_x),(int32_t)(geometry[1]-page_y+scroll_y),
        (uint8_t*)source,source_width,source_height,natural_width,natural_height,left-geometry[0],top-geometry[1],width,height,local_clip);
    if (drawn) drawn=native_text_raster_finish(pixels,geometry[0],geometry[1],w,h,
        geometry[5],geometry[6],canvas_height,1);
    free(pixels);return drawn;
}
