#pragma once
extern int32_t vox_document_repeated_background_pixels(uint8_t*,int32_t,int32_t,int32_t,
 int32_t,int32_t,uint8_t*,int32_t,int32_t,float,float,float*,uint8_t*,VoxGraphiteShape*);

// Transfer the native backdrop; V owns repeat sampling, clip and border composition.
// Other image formats, transforms and effect scopes retain the existing painter.
static int native_try_v_repeated_background(gg__Image *image,
 float x,float y,float width,float height,float bx,float by,float bw,float bh,
 float cx,float cy,float cw,float ch,float a,float b,float c,float d,float e,float f,
 float page_x,float page_y,float scroll_y,float canvas_width,float canvas_height,
 float opacity,int nearest,const float *radii,int flags) {
 CGContextRef context=[[NSGraphicsContext currentContext] CGContext];
 if(context!=native_font_compositing_context || native_font_compositing_transparency_depth
  || !image || !image->data || image->path.len || image->nr_channels!=6
  || image->width<=0 || image->height<=0 || image->width>4096 || image->height>4096
  || (int64_t)image->width*image->height>4*1024*1024 || width!=image->width || height!=image->height
  || a!=1 || d!=1 || b || c || opacity!=1 || nearest || flags!=192 || !radii
  || bx!=cx || by!=cy || bw!=cw || bh!=ch || cw<=0 || ch<=0
  || native_pattern_background[3]!=255 || native_pattern_border.alpha!=255
  || native_pattern_border.thickness<=0) return 0;
 float values[]={x,y,cx,cy,cw,ch,e,f};
 for(int i=0;i<8;++i) if(!isfinite(values[i]) || values[i]!=floorf(values[i])) return 0;
 float half=native_pattern_border.thickness*.5f;
 const float *br=native_pattern_border.rect;
 if(fabsf(br[0]-half-cx)>1e-5f || fabsf(br[1]-half-cy)>1e-5f
  || fabsf(br[2]+2*half-cw)>1e-5f || fabsf(br[3]+2*half-ch)>1e-5f) return 0;
 float left=page_x+cx+e,top=page_y-scroll_y+cy+f;
 int32_t geometry[7];float scale;
 int prepared=native_text_raster_begin(left,top,left+cw,top+ch,canvas_width,canvas_height,16,geometry,&scale);
 if(prepared==2) return 1;
 if(prepared!=1 || scale!=1 || !geometry[4]) return 0;
 int w=geometry[2],h=geometry[3];
 uint8_t *pixels=malloc((size_t)w*h*4);
 if(!pixels) return 0;
 float clip[12]={left-geometry[0],top-geometry[1],cw,ch};
 memcpy(clip+4,radii,8*sizeof(float));
 VoxGraphiteShape border=native_pattern_border;
 float matrix[9]={1,0,page_x+e-geometry[0],0,1,page_y-scroll_y+f-geometry[1],0,0,1};
 memcpy(border.matrix,matrix,sizeof(matrix));
 int drawn=native_text_raster_read_backdrop(pixels,geometry[0],geometry[1],w,h,scale);
 if(drawn) drawn=vox_document_repeated_background_pixels(pixels,w,h,w*4,
  (int32_t)(geometry[0]-page_x),(int32_t)(geometry[1]-page_y+scroll_y),image->data,image->width,image->height,
  page_x+x+e-geometry[0],page_y-scroll_y+y+f-geometry[1],clip,native_pattern_background,&border);
 if(drawn) drawn=native_text_raster_finish(pixels,geometry[0],geometry[1],w,h,geometry[5],geometry[6],canvas_height,1);
 free(pixels);return drawn;
}
