#ifndef VOX_NATIVE_GG_D3D11_TRANSFER_H
#define VOX_NATIVE_GG_D3D11_TRANSFER_H

// Included by Sokol's D3D11 backend. The immediate context serializes copies
// and Map waits for readback, so one staging texture can serve later calls.
static ID3D11Texture2D* vox_gg_d3d11_readback_texture(UINT width, UINT height, DXGI_FORMAT format) {
    if (_sg.d3d11.vox_readback &&
        _sg.d3d11.vox_readback_width >= width &&
        _sg.d3d11.vox_readback_height >= height &&
        _sg.d3d11.vox_readback_format == format) {
        return _sg.d3d11.vox_readback;
    }
    D3D11_TEXTURE2D_DESC desc = {0};
    desc.Width = width;
    desc.Height = height;
    desc.MipLevels = 1;
    desc.ArraySize = 1;
    desc.Format = format;
    desc.SampleDesc.Count = 1;
    desc.Usage = D3D11_USAGE_STAGING;
    desc.CPUAccessFlags = D3D11_CPU_ACCESS_READ;
    ID3D11Texture2D* replacement = NULL;
    if (FAILED(_sg_d3d11_CreateTexture2D(_sg.d3d11.dev, &desc, NULL, &replacement)) || !replacement) {
        return NULL;
    }
    // Match the Metal readback cache budget. Larger transfers keep their
    // staging allocation only until the pixels have been copied out.
    if ((uint64_t)width * height * 4 > 4u * 1024u * 1024u) {
        return replacement;
    }
    if (_sg.d3d11.vox_readback) {
        _sg_d3d11_Release(_sg.d3d11.vox_readback);
    }
    _sg.d3d11.vox_readback = replacement;
    _sg.d3d11.vox_readback_width = width;
    _sg.d3d11.vox_readback_height = height;
    _sg.d3d11.vox_readback_format = format;
    return replacement;
}

static bool vox_gg_d3d11_transfer(_sg_image_t* img, int x, int y, int width, int height,
                                 void* pixels, int pitch, bool write) {
    if (img->cmn.pixel_format != SG_PIXELFORMAT_BGRA8 &&
        img->cmn.pixel_format != SG_PIXELFORMAT_RGBA8) {
        return false;
    }
    ID3D11DeviceContext* context = _sg.d3d11.ctx;
    D3D11_BOX region = {(UINT)x, (UINT)y, 0, (UINT)(x + width), (UINT)(y + height), 1};
    if (write) {
        D3D11_TEXTURE2D_DESC desc;
        #if defined(__cplusplus)
        img->d3d11.tex2d->GetDesc(&desc);
        #else
        img->d3d11.tex2d->lpVtbl->GetDesc(img->d3d11.tex2d, &desc);
        #endif
        if (desc.Usage != D3D11_USAGE_DEFAULT) {
            return false;
        }
        _sg_d3d11_UpdateSubresource(context, img->d3d11.res, 0, &region, pixels, (UINT)pitch, 0);
        return true;
    }
    ID3D11Texture2D* texture = vox_gg_d3d11_readback_texture((UINT)width, (UINT)height, img->d3d11.format);
    if (!texture) {
        return false;
    }
    const bool transient = texture != _sg.d3d11.vox_readback;
    ID3D11Resource* staging = (ID3D11Resource*)texture;
    #if defined(__cplusplus)
    context->CopySubresourceRegion(staging, 0, 0, 0, 0, img->d3d11.res, 0, &region);
    #else
    context->lpVtbl->CopySubresourceRegion(context, staging, 0, 0, 0, 0, img->d3d11.res, 0, &region);
    #endif
    D3D11_MAPPED_SUBRESOURCE mapped;
    const bool mapped_ok = SUCCEEDED(_sg_d3d11_Map(context, staging, 0, D3D11_MAP_READ, 0, &mapped));
    if (mapped_ok) {
        const size_t row_bytes = (size_t)width * 4;
        if ((size_t)pitch == row_bytes && mapped.RowPitch == row_bytes) {
            memcpy(pixels, mapped.pData, row_bytes * (size_t)height);
        } else {
            for (int row = 0; row < height; ++row) {
                memcpy((uint8_t*)pixels + (size_t)row * (size_t)pitch,
                       (const uint8_t*)mapped.pData + (size_t)row * mapped.RowPitch, row_bytes);
            }
        }
        _sg_d3d11_Unmap(context, staging, 0);
    }
    if (transient) {
        _sg_d3d11_Release(texture);
    }
    return mapped_ok;
}

#endif
