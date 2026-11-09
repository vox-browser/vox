#ifndef VOX_LINUX_FONTSTASH_CALLBACKS_H
#define VOX_LINUX_FONTSTASH_CALLBACKS_H

#include <stdint.h>
#include "fontstash.h"

/* V's pointer parameters cannot express Fontstash's const-qualified buffers.
 * Keep the actual C callback signatures, and adapt only the read-only views
 * passed into GG. These GG callbacks borrow/store the buffers without writing
 * to them; their owner and lifetime remain Fontstash's. */
void vox_gg_fontstash_render_update(void*, int32_t*, uint8_t*);
void vox_gg_fontstash_render_draw(void*, float*, float*, uint32_t*, int32_t);

static void vox_gg_fontstash_update(void* owner, int* rect, const unsigned char* data)
{
    vox_gg_fontstash_render_update(owner, rect, (uint8_t*)data);
}

static void vox_gg_fontstash_draw(void* owner, const float* vertices,
                                const float* coordinates, const unsigned int* colors,
                                int count)
{
    vox_gg_fontstash_render_draw(owner, (float*)vertices, (float*)coordinates,
                                (uint32_t*)colors, count);
}

static void vox_gg_fontstash_callbacks(FONSparams* params)
{
    params->renderUpdate = vox_gg_fontstash_update;
    params->renderDraw = vox_gg_fontstash_draw;
}

#endif
