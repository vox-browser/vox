#include "native_graphite_bridge.h"
#include <algorithm>
#include <cassert>
#include <cstdio>
#include <cstring>
#include <dlfcn.h>
#include <vector>
int main(int argc,char** argv){
 assert(argc==2);void* lib=dlopen(argv[1],RTLD_NOW|RTLD_LOCAL);assert(lib);
 auto full=reinterpret_cast<decltype(&vox_graphite_draw_svg_image_pixels)>(dlsym(lib,"vox_graphite_draw_svg_image_pixels"));
 auto region=reinterpret_cast<decltype(&vox_graphite_draw_svg_image_region_pixels)>(dlsym(lib,"vox_graphite_draw_svg_image_region_pixels"));assert(full&&region);
 const int width=128,height=96;const int crops[][4]={{0,0,30,30},{17,13,70,40},{100,70,28,26},{0,0,128,96}};size_t cases=0;
 float segments[]={0,1,2,0,0,0,0,0,0,0,0,0,3,48,37,52,-4,2,60,0,0,0,0,0,1,4,53,0,0,0,0,0,0,0,0,0,5,0,0,0,0,0,0,0,0,0,0,0};
 float stops[]={.9f,.1f,.3f,.8f,0,.1f,.7f,.4f,.65f,1};
 for(int scale:{1,2})for(int bg:{0,1})for(int msaa:{0,1})for(int fractional:{0,1})for(int gradient:{0,1})for(int rounded:{0,1})for(auto const& crop:crops){
  float parent[]={float(scale),0,fractional?.375f:0,0,float(scale),fractional?-.25f:0,0,0,1};
  float viewport[]={2,3,53,57},clip[]={4,5,47,49,3,7,5,2,6,3,2,4};
  VoxGraphitePath paths[2]{};
  for(int n=0;n<2;++n){auto& p=paths[n];p.matrix[0]=p.matrix[4]=p.matrix[8]=1;p.matrix[2]=n*5.25f;p.matrix[5]=n*2.5f;p.segments=segments;p.segment_count=4;p.red=35;p.green=167;p.blue=79;p.alpha=190;p.opacity=.8f;p.has_float_alpha=1;p.stroke=n;p.stroke_width=1.75f;p.line_cap=1;p.line_join=2;p.miter_limit=4;p.gradient=gradient;p.stops=stops;p.stop_count=2;p.gradient_points[2]=50;p.gradient_points[3]=40;p.gradient_matrix[0]=p.gradient_matrix[4]=p.gradient_matrix[8]=1;}
  int x=crop[0],y=crop[1],w=crop[2],h=crop[3],pitch=w*4+13;
  std::vector<uint8_t> actual(1+size_t(pitch)*h,0xA9),expected(size_t(width)*height*4);
  for(int row=0;row<h;++row)for(int col=0;col<w;++col){auto* p=actual.data()+1+size_t(row)*pitch+col*4;p[0]=uint8_t((col*17+row*7)%120);p[1]=uint8_t((col*11+row*13)%120);p[2]=uint8_t((col*5+row*19)%120);p[3]=uint8_t(128+(col+row)%128);}
  for(int row=0;row<h;++row)std::memcpy(expected.data()+(size_t(y+row)*width+x)*4,actual.data()+1+size_t(row)*pitch,size_t(w)*4);
  int flags=(bg?VOX_GRAPHITE_SVG_BACKDROP:0)|(msaa?VOX_GRAPHITE_SVG_FORCE_MSAA:0);
  assert(full(expected.data(),width,height,width*4,flags,paths,2,parent,viewport,rounded?clip:nullptr));
  auto input=actual;
  for(int replay=0;replay<2;++replay){actual=input;VoxGraphitePixelRegion view{x,y,w,h,pitch,actual.data()+1};assert(region(&view,width,height,flags,paths,2,parent,viewport,rounded?clip:nullptr));
   for(int row=0;row<h;++row){if(std::memcmp(actual.data()+1+size_t(row)*pitch,expected.data()+(size_t(y+row)*width+x)*4,size_t(w)*4)){std::fprintf(stderr,"Mismatch scale=%d bg=%d msaa=%d fractional=%d gradient=%d rounded=%d crop=%d,%d,%d,%d\n",scale,bg,msaa,fractional,gradient,rounded,x,y,w,h);return 1;}for(int i=w*4;i<pitch;++i)assert(actual[1+size_t(row)*pitch+i]==0xA9);}assert(actual[0]==0xA9);++cases;}
 }
 std::vector<uint8_t> pixels(256,71),original=pixels;VoxGraphitePixelRegion view{0,0,8,8,32,pixels.data()};float identity[]={1,0,0,0,1,0,0,0,1},viewport[]={0,0,8,8};VoxGraphitePath invalid{};
 assert(!region(&view,width,height,1,&invalid,1,identity,viewport,nullptr));invalid.segments=segments;invalid.segment_count=4;view.x=width;assert(!region(&view,width,height,1,&invalid,1,identity,viewport,nullptr));view.x=0;view.pitch=1;assert(!region(&view,width,height,1,&invalid,1,identity,viewport,nullptr));assert(pixels==original);
 std::printf("PASS %zu exact SVG region comparisons and invalid-input guards\n",cases);
}
