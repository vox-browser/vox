#ifndef VOX_WEBGL_NATIVE_METAL_BOUNDARY_H
#define VOX_WEBGL_NATIVE_METAL_BOUNDARY_H
#include <stdint.h>
#include "metal/shader_translation.h"
#include <mach-o/dyld.h>
#include <string.h>
#include "../platform/native_state.h"
VOX_NATIVE_STATE __thread void* vox_metal_service_current;
static void* vox_metal_service_get(void) { return vox_metal_service_current; }
static void vox_metal_service_set(void* value) { vox_metal_service_current = value; }
static int vox_metal_service_no_angle(void) {
    for (uint32_t i = 0; i < _dyld_image_count(); ++i) {
        char const* image = _dyld_get_image_name(i);
        if (strstr(image, "libEGL") || strstr(image, "libGLES") || strstr(image, "libANGLE")) return 0;
    }
    return 1;
}
#endif
