// Retain both WebP draw paths against a frozen full-uBO Brave interior crop.
// The source/frozen site fidelity failure is independent of this diagnostic.
#import <Foundation/Foundation.h>
#include "../native_graphite_bridge.h"
#include <cassert>
#include <cstdio>
#include <dlfcn.h>
#include <vector>

int main(int argc,char**argv)
{
    @autoreleasepool {
        assert(argc==4);
        NSData* encoded=[NSData dataWithContentsOfFile:@(argv[1])];assert(encoded);
        NSDictionary* reference=[NSJSONSerialization JSONObjectWithData:
            [NSData dataWithContentsOfFile:@(argv[2])] options:0 error:nil];assert(reference);
        NSData* expected=[[NSData alloc] initWithBase64EncodedString:reference[@"comparison_rgb_base64"] options:0];
        NSArray* viewport=reference[@"viewport"],*roi=reference[@"comparison_rect"],*rect=reference[@"draw_rect"];
        int width=[viewport[0] intValue],height=[viewport[1] intValue];
        int x=[roi[0] intValue],y=[roi[1] intValue],rw=[roi[2] intValue],rh=[roi[3] intValue];
        assert(width==1024&&height==768&&rw>0&&rh>0&&x>=0&&y>=0&&x+rw<=width&&y+rh<=height);
        assert(expected.length==size_t(rw)*rh*3);
        void* codec=dlopen("/opt/homebrew/lib/libwebpdecoder.dylib",RTLD_NOW|RTLD_LOCAL);
        if(!codec)codec=dlopen("/usr/local/lib/libwebpdecoder.dylib",RTLD_NOW|RTLD_LOCAL);
        assert(codec);
        auto info=(int(*)(const uint8_t*,size_t,int*,int*))dlsym(codec,"WebPGetInfo");
        auto rgb=(uint8_t*(*)(const uint8_t*,size_t,uint8_t*,size_t,int))dlsym(codec,"WebPDecodeRGBAInto");
        auto yuv=(uint8_t*(*)(const uint8_t*,size_t,uint8_t*,size_t,int,uint8_t*,size_t,int,
            uint8_t*,size_t,int))dlsym(codec,"WebPDecodeYUVInto");assert(info&&rgb&&yuv);
        int iw=0,ih=0;assert(info((uint8_t const*)encoded.bytes,encoded.length,&iw,&ih));
        assert(iw==[reference[@"image_width"] intValue]&&ih==[reference[@"image_height"] intValue]);
        int uv=(iw+1)/2,uh=(ih+1)/2;size_t ys=size_t(iw)*ih,us=size_t(uv)*uh;
        void* library=dlopen(argv[3],RTLD_NOW|RTLD_LOCAL);assert(library);
        auto draw=(decltype(&vox_graphite_draw_image_pixels))dlsym(library,"vox_graphite_draw_image_pixels");assert(draw);
        for(int mode:{0,1}) {
            std::vector<uint8_t> source(mode?ys+2*us:ys*4);
            if(mode)assert(yuv((uint8_t const*)encoded.bytes,encoded.length,source.data(),ys,iw,
                source.data()+ys,us,uv,source.data()+ys+us,us,uv));
            else assert(rgb((uint8_t const*)encoded.bytes,encoded.length,source.data(),source.size(),iw*4));
            std::vector<uint8_t> pixels(size_t(width)*height*4,255);
            VoxGraphiteImage d{};d.matrix[0]=d.matrix[4]=d.matrix[8]=1;
            d.source[2]=d.width=iw;d.source[3]=d.height=ih;
            for(int i=0;i<4;++i)d.destination[i]=d.clip[i]=[rect[i] floatValue];
            for(int i=4;i<12;++i)d.clip[i]=[reference[@"radius"] floatValue];
            d.pitch=iw*4;d.opacity=1;d.flags=2|(mode?4:0)|VOX_GRAPHITE_IMAGE_FORCE_MSAA;
            d.pixels=source.data();d.has_background_color=1;
            d.background_rgba[0]=245;d.background_rgba[1]=243;d.background_rgba[2]=245;d.background_rgba[3]=255;
            assert(draw(pixels.data(),width,height,width*4,1,&d));
            auto* rgb_expected=(uint8_t const*)expected.bytes;
            int differences=0;
            for(int row=0;row<rh;++row)for(int column=0;column<rw;++column) {
                auto* actual=pixels.data()+((y+row)*width+x+column)*4;
                auto* sample=rgb_expected+(row*rw+column)*3;
                differences+=actual[2]!=sample[0]||actual[1]!=sample[1]||actual[0]!=sample[2]||actual[3]!=255;
            }
            auto key=mode?@"yuv_control_different_pixels":@"rgb_different_pixels";
            std::printf("%s: %d/%d interior pixels differ\n",mode?"YUV control":"RGB",differences,rw*rh);
            assert(differences==[reference[key] intValue]);
        }
    }
}
