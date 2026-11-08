#include "native/include/native_direct_image_raster.h"
#include <cassert>
#include <limits>
#include <cstdio>
int main() {
    unsigned char pixel = 0;
    VoxGraphiteImage image{};
    image.width=668;image.height=504;image.pitch=668*4;image.pixels=&pixel;
    image.matrix[0]=image.matrix[4]=image.matrix[8]=1;
    image.source[2]=668;image.source[3]=504;
    image.destination[0]=125;image.destination[1]=429;image.destination[2]=578;image.destination[3]=436;
    std::copy_n(image.destination,4,image.clip);std::fill_n(image.clip+4,8,12.f);image.opacity=1;
    auto plan=vox_direct_image_raster_plan(image,1024,768);
    assert(plan);assert(plan->scale==504.f/436);assert(std::ceil(plan->width)==669);assert(std::ceil(plan->height)==504);
    assert(plan->tile_width==704&&plan->tile_height==256&&plan->columns==1&&plan->rows==2);
    assert(339.f*plan->scale!=std::ceil(339.f*plan->scale));
    for(int variant=0;variant<13;variant++) {
      auto bad=image;
      switch(variant) {
        case 0:bad.source[0]=1;break;
        case 1:bad.source[2]=667;break;
        case 2:bad.nearest=1;break;
        case 3:bad.destination[2]=0;break;
        case 4:bad.destination[2]=100;break;
        case 5:bad.matrix[1]=.1;break;
        case 6:bad.opacity=std::numeric_limits<float>::quiet_NaN();break;
        case 7:bad.clip[4]=-1;break;
        case 8:bad.border_width=1;break;
        case 9:bad.has_background_color=1;break;
        case 10:bad.flags=VOX_GRAPHITE_IMAGE_REPEAT_X;break;
        case 11:bad.pitch=4;break;
        case 12:bad.destination[1]=std::numeric_limits<float>::infinity();break;
      }
      assert(!vox_direct_image_raster_plan(bad,1024,768));
    }
    assert(!vox_direct_image_raster_plan(image,20000,768));
    assert(!vox_direct_image_raster_plan(image,1024,0));
    image.destination[0]=-125;image.destination[1]=-429;
    assert(vox_direct_image_raster_plan(image,1024,768));
    puts("Direct-image raster geometry and unsupported-input guards pass");
}
