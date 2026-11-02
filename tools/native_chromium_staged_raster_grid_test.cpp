#include "../native_chromium_raster_grid.h"
#include <cassert>

int main()
{
    unsetenv("VOX_ENABLE_STAGED_RASTER_GRID");
    for (int w : {17, 67, 97, 151}) for (int h : {19, 53, 79, 111})
    for (long x : {0, 1, 11}) for (long y : {0, 1, 13}) for (int padding : {0,7}) {
        VoxChromiumRasterGrid grid{66,50,4,4};
        std::vector<VoxChromiumStagedTile> plan;
        assert(vox_chromium_plan_staged_grid(w,h,x,y,grid,plan));
        std::vector<uint32_t> input(size_t(w)*h+padding);
        for(size_t i=0;i<input.size();++i)input[i]=uint32_t(i*73+19);
        auto expected=input,actual=input;
        std::vector<int> first,second;
        auto renderer=[&](std::vector<int>& order) {
            return [&](auto& tile,long dx,long dy,int cell,int vx,int vy,int tw,int th) {
                order.push_back(cell);
                for(int row=0;row<th;++row)for(int col=0;col<tw;++col) {
                    size_t at=size_t(row)*tw+col;
                    auto value=input[size_t(vy-dy+row)*w+vx-dx+col];
                    assert(tile[at]==value);
                    tile[at]^=uint32_t(cell*97+vx+col+19*(vy+row));
                }
                return true;
            };
        };
        auto reference=renderer(first),candidate=renderer(second);
        assert(vox_draw_chromium_raster_grid_impl<true>(expected,w,h,x,y,grid,reference));
        assert(vox_chromium_draw_staged_grid(actual,w,h,plan,candidate));
        assert(first==second&&expected==actual);
        actual=input;int calls=0;
        auto failure=[&](auto& tile,long,long,int,int,int,int,int) {
            ++calls;std::fill(tile.begin(),tile.end(),0);return calls<int(std::min(plan.size(),size_t(2)));
        };
        assert(!vox_chromium_draw_staged_grid(actual,w,h,plan,failure));assert(actual==input);
    }
    std::vector<VoxChromiumStagedTile> rejected;
    assert(!vox_chromium_plan_staged_grid(100,100,0,0,{3,3,100,100},rejected));
}
