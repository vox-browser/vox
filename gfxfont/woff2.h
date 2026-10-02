#pragma once
#include <stddef.h>
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
uint8_t* vox_woff2_convert_to_ttf(uint8_t const*, size_t, size_t*);
void vox_woff2_free(void*);
#ifdef __cplusplus
}
#endif
