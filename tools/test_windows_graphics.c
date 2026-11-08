// Run on the interactive Windows desktop, inside windows_runtime_guard.
#define COBJMACROS
#define SOKOL_D3D11
#include "../native/include/native_browser_windows_graphics.h"
#include <assert.h>

static void test_driver(D3D_DRIVER_TYPE driver) {
    HWND window = CreateWindowExW(0, L"STATIC", L"Vox graphics test",
        WS_OVERLAPPEDWINDOW, 0, 0, 320, 240, NULL, NULL, GetModuleHandleW(NULL), NULL);
    assert(window);
    DXGI_SWAP_CHAIN_DESC description = {0};
    description.BufferDesc.Width = 16;
    description.BufferDesc.Height = 16;
    description.BufferDesc.Format = DXGI_FORMAT_B8G8R8A8_UNORM;
    description.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
    description.BufferCount = 1;
    description.SampleDesc.Count = 1;
    description.OutputWindow = window;
    description.Windowed = TRUE;
    D3D_FEATURE_LEVEL requested[] = {D3D_FEATURE_LEVEL_11_1, D3D_FEATURE_LEVEL_11_0};
    D3D_FEATURE_LEVEL actual;
    IDXGISwapChain *swap_chain = NULL;
    ID3D11Device *device = NULL;
    ID3D11DeviceContext *context = NULL;
    UINT flags = D3D11_CREATE_DEVICE_BGRA_SUPPORT;
    if (driver == D3D_DRIVER_TYPE_HARDWARE) flags |= D3D11_CREATE_DEVICE_DEBUG;
    assert(SUCCEEDED(D3D11CreateDeviceAndSwapChain(NULL, driver, NULL, flags,
        requested, 2, D3D11_SDK_VERSION, &description, &swap_chain,
        &device, &actual, &context)));
    assert(actual >= D3D_FEATURE_LEVEL_11_0);
    ID3D11Texture2D *buffer = NULL;
    assert(SUCCEEDED(IDXGISwapChain_GetBuffer(swap_chain, 0, &IID_ID3D11Texture2D,
        (void **)&buffer)));
    ID3D11RenderTargetView *view = NULL;
    assert(SUCCEEDED(ID3D11Device_CreateRenderTargetView(device,
        (ID3D11Resource *)buffer, NULL, &view)));
    const float color[] = {0.25f, 0.5f, 0.75f, 1.0f};
    ID3D11DeviceContext_ClearRenderTargetView(context, view, color);
    D3D11_TEXTURE2D_DESC texture;
    ID3D11Texture2D_GetDesc(buffer, &texture);
    texture.Usage = D3D11_USAGE_STAGING;
    texture.BindFlags = 0;
    texture.CPUAccessFlags = D3D11_CPU_ACCESS_READ;
    ID3D11Texture2D *readback = NULL;
    assert(SUCCEEDED(ID3D11Device_CreateTexture2D(device, &texture, NULL, &readback)));
    ID3D11DeviceContext_CopyResource(context, (ID3D11Resource *)readback,
        (ID3D11Resource *)buffer);
    D3D11_MAPPED_SUBRESOURCE pixels;
    assert(SUCCEEDED(ID3D11DeviceContext_Map(context, (ID3D11Resource *)readback,
        0, D3D11_MAP_READ, 0, &pixels)));
    const unsigned char *pixel = pixels.pData;
    assert(pixel[0] >= 190 && pixel[0] <= 192);
    assert(pixel[1] >= 127 && pixel[1] <= 129);
    assert(pixel[2] >= 63 && pixel[2] <= 65 && pixel[3] == 255);
    ID3D11DeviceContext_Unmap(context, (ID3D11Resource *)readback, 0);
    ID3D11Texture2D_Release(readback);
    ID3D11RenderTargetView_Release(view);
    ID3D11Texture2D_Release(buffer);
    vox_clear_d3d11_outputs(&swap_chain, &device, &context);
    DestroyWindow(window);
}

int main(void) {
    test_driver(D3D_DRIVER_TYPE_HARDWARE);
    test_driver(D3D_DRIVER_TYPE_WARP);
    puts("Windows Direct3D 11 default and WARP creation, clear and pixel readback: passed");
    return 0;
}
