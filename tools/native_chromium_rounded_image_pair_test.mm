// Compare the publisher photo's corner pixels with frozen full-uBO Brave data.
#import <Foundation/Foundation.h>
#include "../native/include/native_graphite_bridge.h"
#include <cassert>
#include <cstdio>
#include <cstring>
#include <dlfcn.h>
#include <vector>

int main(int argc,char**argv)
{
    @autoreleasepool {
        assert(argc==4);
        NSData* encoded=[NSData dataWithContentsOfFile:@(argv[1])];assert(encoded);
        NSDictionary* reference=[NSJSONSerialization JSONObjectWithData:
            [NSData dataWithContentsOfFile:@(argv[2])] options:0 error:nil];assert(reference);
        NSArray* points=reference[@"points"];assert(points.count==240);
        void* codec=dlopen("/opt/homebrew/lib/libwebpdecoder.dylib",RTLD_NOW|RTLD_LOCAL);
        if(!codec)codec=dlopen("/usr/local/lib/libwebpdecoder.dylib",RTLD_NOW|RTLD_LOCAL);
        assert(codec);
        auto info=(int(*)(const uint8_t*,size_t,int*,int*))dlsym(codec,"WebPGetInfo");
        auto decode=(uint8_t*(*)(const uint8_t*,size_t,uint8_t*,size_t,int,uint8_t*,size_t,int,
            uint8_t*,size_t,int))dlsym(codec,"WebPDecodeYUVInto");assert(info&&decode);
        int iw=0,ih=0;assert(info((uint8_t const*)encoded.bytes,encoded.length,&iw,&ih));
        assert(iw==780&&ih==438);
        int uv=(iw+1)/2,uh=(ih+1)/2;size_t ys=size_t(iw)*ih,us=size_t(uv)*uh;
        std::vector<uint8_t> source(ys+2*us);
        assert(decode((uint8_t const*)encoded.bytes,encoded.length,source.data(),ys,iw,
            source.data()+ys,us,uv,source.data()+ys+us,us,uv));
        void* library=dlopen(argv[3],RTLD_NOW|RTLD_LOCAL);assert(library);
        auto image=(decltype(&vox_graphite_draw_image_pixels))dlsym(library,"vox_graphite_draw_image_pixels");
        auto shape=(decltype(&vox_graphite_draw_shape_pixels))dlsym(library,"vox_graphite_draw_shape_pixels");
        assert(image&&shape);
        for(int paired:{0,1}) {
            std::vector<uint8_t> pixels(1024*768*4,255);
            VoxGraphiteImage d{};d.matrix[0]=d.matrix[4]=d.matrix[8]=1;
            d.source[2]=d.width=iw;d.source[3]=d.height=ih;
            d.destination[0]=d.clip[0]=24;d.destination[1]=d.clip[1]=88;
            d.destination[2]=d.clip[2]=464;d.destination[3]=d.clip[3]=261;
            for(int i=4;i<12;++i)d.clip[i]=8;
            d.pitch=iw*4;d.opacity=1;d.flags=6|VOX_GRAPHITE_IMAGE_FORCE_MSAA;d.pixels=source.data();
            d.has_background_color=paired;d.background_rgba[0]=245;d.background_rgba[1]=243;
            d.background_rgba[2]=245;d.background_rgba[3]=255;
            if(!paired) {
                VoxGraphiteShape s{};std::memcpy(s.matrix,d.matrix,sizeof(s.matrix));
                std::memcpy(s.rect,d.clip,sizeof(s.rect));s.red=245;s.green=243;s.blue=245;s.alpha=255;
                s.fill=s.anti_alias=s.force_msaa=1;assert(shape(pixels.data(),1024,768,4096,1,&s));
            }
            assert(image(pixels.data(),1024,768,4096,1,&d));
            size_t differences=0;
            for(NSArray* entry in points) {
                int x=[entry[0] intValue],y=[entry[1] intValue];NSArray* expected=entry[2];
                auto* actual=pixels.data()+(y*1024+x)*4;
                if(actual[2]!=[expected[0] intValue]||actual[1]!=[expected[1] intValue]
                    ||actual[0]!=[expected[2] intValue]||actual[3]!=[expected[3] intValue])++differences;
            }
            std::printf("%s: %zu/240 corner pixels differ\n",paired?"paired":"separate",differences);
            assert(differences==(paired?0:14));
        }
    }
}
