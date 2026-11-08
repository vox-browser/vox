#pragma once

// Sokol owns the window and swap chain. Keep its hardware path, with Windows'
// built-in software driver for VMs and machines using the basic display driver.
#if defined(_WIN32) && defined(SOKOL_D3D11)
#include <windows.h>
#include <d3d11.h>
#include <stdio.h>

static void vox_clear_d3d11_outputs(IDXGISwapChain **swap_chain,
    ID3D11Device **device, ID3D11DeviceContext **context) {
#ifdef __cplusplus
    if (context && *context) { (*context)->Release(); *context = NULL; }
    if (device && *device) { (*device)->Release(); *device = NULL; }
    if (swap_chain && *swap_chain) { (*swap_chain)->Release(); *swap_chain = NULL; }
#else
    if (context && *context) { (*context)->lpVtbl->Release(*context); *context = NULL; }
    if (device && *device) { (*device)->lpVtbl->Release(*device); *device = NULL; }
    if (swap_chain && *swap_chain) { (*swap_chain)->lpVtbl->Release(*swap_chain); *swap_chain = NULL; }
#endif
}

static HRESULT WINAPI vox_create_d3d11_device_and_swap_chain(
    IDXGIAdapter *adapter, D3D_DRIVER_TYPE driver, HMODULE software, UINT flags,
    const D3D_FEATURE_LEVEL *levels, UINT level_count, UINT sdk_version,
    const DXGI_SWAP_CHAIN_DESC *description, IDXGISwapChain **swap_chain,
    ID3D11Device **device, D3D_FEATURE_LEVEL *level, ID3D11DeviceContext **context) {
    HRESULT result = D3D11CreateDeviceAndSwapChain(adapter, driver, software,
        flags, levels, level_count, sdk_version, description, swap_chain,
        device, level, context);
    if (SUCCEEDED(result) || adapter || driver != D3D_DRIVER_TYPE_HARDWARE)
        return result;
    vox_clear_d3d11_outputs(swap_chain, device, context);
    // Retain hardware rendering when only the optional SDK debug layer is
    // missing. Sokol can request that layer in development builds.
    if (flags & D3D11_CREATE_DEVICE_DEBUG) {
        flags &= ~D3D11_CREATE_DEVICE_DEBUG;
        result = D3D11CreateDeviceAndSwapChain(adapter, driver, software,
            flags, levels, level_count, sdk_version, description, swap_chain,
            device, level, context);
        if (SUCCEEDED(result)) return result;
        vox_clear_d3d11_outputs(swap_chain, device, context);
    }
    result = D3D11CreateDeviceAndSwapChain(NULL, D3D_DRIVER_TYPE_WARP, NULL,
        flags, levels, level_count, sdk_version,
        description, swap_chain, device, level, context);
    if (SUCCEEDED(result)) {
        fputs("Vox: using Direct3D 11 WARP software rendering\n", stderr);
        fflush(stderr);
    }
    return result;
}

// This header is preincluded before Sokol's implementation, without modifying
// the shared V installation or maintaining a private copy of Sokol.
#define D3D11CreateDeviceAndSwapChain vox_create_d3d11_device_and_swap_chain
#endif
