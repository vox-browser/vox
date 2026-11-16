// Pixel transfer only. V owns SVG/filter geometry, eligibility and raster tiles.
int native_draw_svg_drop_shadow(VoxGraphiteSvgShadow *draw, float width,
                               float height, float page_x, float page_y) {
    if (!draw || [[NSGraphicsContext currentContext] CGContext] != native_font_compositing_context)
        return 0;
    float pad=ceilf(3*draw->shadow[2])+ceilf(draw->shadow[2]/4)+2;
    if (!isfinite(pad) || pad<0 || pad>441) return 0;
    float left=INFINITY,top=INFINITY,right=-INFINITY,bottom=-INFINITY;
    for(int i=0;i<4;++i) {
        float x=draw->bounds[(i&1)?2:0]+((i&1)?pad:-pad);
        float y=draw->bounds[(i&2)?3:1]+((i&2)?pad:-pad);
        float dx=draw->frame[0]*x+draw->frame[1]*y+draw->frame[2];
        float dy=draw->frame[3]*x+draw->frame[4]*y+draw->frame[5];
        float sx=draw->frame[0]*draw->shadow[0]+draw->frame[1]*draw->shadow[1];
        float sy=draw->frame[3]*draw->shadow[0]+draw->frame[4]*draw->shadow[1];
        left=fminf(left,fminf(dx,dx+sx)); right=fmaxf(right,fmaxf(dx,dx+sx));
        top=fminf(top,fminf(dy,dy+sy)); bottom=fmaxf(bottom,fmaxf(dy,dy+sy));
    }
    int32_t geometry[7]={0}; float scale=0;
    int prepared=native_document_text_raster_begin(left,top,right,bottom,width,height,16,geometry,&scale);
    if(getenv("VOX_GG_DIAGNOSTICS"))fprintf(stderr,"VOX_SVG_SHADOW native prepared=%d scale=%f geometry=%d,%d %dx%d logical=%dx%d\n",prepared,prepared==1?scale:0,geometry[0],geometry[1],geometry[2],geometry[3],geometry[5],geometry[6]);
    if(prepared==2)return 1;
    if(prepared!=1 || scale!=1 || geometry[2]!=geometry[5] || geometry[3]!=geometry[6])return 0;
    int w=geometry[2],h=geometry[3];
    if(w<=0 || h<=0 || w>4096 || h>4096 || (size_t)w*h>4*1024*1024)return 0;
    uint8_t *pixels=calloc((size_t)w*h*4,1);
    if(!pixels)return 0;
    if(geometry[4] && !native_document_text_raster_read_backdrop(pixels,geometry[0],geometry[1],w,h,scale)) {free(pixels);return 0;}
    VoxGraphiteSvgShadow local=*draw;
    local.frame[2]-=geometry[0]; local.frame[5]-=geometry[1];
    extern int vox_draw_document_svg_shadow_pixels(uint8_t*,int,int,int,int,int,VoxGraphiteSvgShadow*);
    int drawn=vox_draw_document_svg_shadow_pixels(pixels,w,h,w*4,
        (int)lround(geometry[0]-page_x),(int)lround(geometry[1]-page_y),&local);
    if(getenv("VOX_GG_DIAGNOSTICS"))fprintf(stderr,"VOX_SVG_SHADOW native drawn=%d\n",drawn);
    if(drawn)drawn=native_document_text_raster_finish(pixels,geometry[0],geometry[1],w,h,geometry[5],geometry[6],height,geometry[4]);
    free(pixels);return drawn;
}
