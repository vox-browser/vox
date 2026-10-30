#ifndef VOX_NATIVE_IMAGE_COLOR_PROFILE_H
#define VOX_NATIVE_IMAGE_COLOR_PROFILE_H

// Positive [0]: legacy inverse gamma, primaries flag and eight chromaticities.
// [0] == -1: seven transfer-function coefficients and a 3x3 D50 gamut matrix.
// Plain values keep the engine and compatibility backends' Skia ABIs separate.
enum { VOX_IMAGE_COLOR_PROFILE_VALUES = 17 };
typedef struct {
    float values[VOX_IMAGE_COLOR_PROFILE_VALUES];
} VoxImageColorProfile;

#endif
