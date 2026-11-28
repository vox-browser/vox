#pragma once

#include <math.h>
#include <stddef.h>
#include <stdint.h>
#include <sys/param.h>
#include "../../cpuraster/scan_workers.h"

typedef struct {
	uint8_t permutation[256];
	double gradient[4][256][2];
} NativeSVGTurbulenceData;

static int native_svg_turbulence_random(int *seed) {
	static int const amplitude = 16807;
	static int const quotient = 127773;
	static int const remainder = 2836;
	int64_t result = (int64_t)amplitude * (*seed % quotient)
		- (int64_t)remainder * (*seed / quotient);
	if (result <= 0) {
		result += 2147483647;
	}
	*seed = (int)result;
	return *seed;
}

static void native_svg_initialize_turbulence(NativeSVGTurbulenceData *data,
	double seed_value) {
	static int const random_maximum = 2147483647;
	int seed;
	if (!isfinite(seed_value) || seed_value >= random_maximum - 1) {
		seed = random_maximum - 1;
	} else if (seed_value <= INT32_MIN) {
		seed = INT32_MIN;
	} else {
		seed = (int)trunc(seed_value);
	}
	if (seed <= 0) {
		seed = -(seed % (random_maximum - 1)) + 1;
	}
	uint16_t noise[4][256][2];
	for (int channel = 0; channel < 4; ++channel) {
		for (int index = 0; index < 256; ++index) {
			data->permutation[index] = (uint8_t)index;
			noise[channel][index][0] = (uint16_t)(native_svg_turbulence_random(&seed) % 512);
			noise[channel][index][1] = (uint16_t)(native_svg_turbulence_random(&seed) % 512);
		}
	}
	for (int index = 255; index > 0; --index) {
		uint8_t value = data->permutation[index];
		int replacement = native_svg_turbulence_random(&seed) % 256;
		data->permutation[index] = data->permutation[replacement];
		data->permutation[replacement] = value;
	}
	for (int channel = 0; channel < 4; ++channel) {
		for (int index = 0; index < 256; ++index) {
			int selected = data->permutation[index];
			float x = ((float)noise[channel][selected][0] - 256.0f) / 256.0f;
			float y = ((float)noise[channel][selected][1] - 256.0f) / 256.0f;
			float length = hypotf(x, y);
			if (length == 0.0) {
				x = 1.0f;
				y = 0.0f;
				length = 1.0f;
			}
			uint16_t encoded_x = (uint16_t)lrintf((x / length + 1.0f) * 32767.5f);
			uint16_t encoded_y = (uint16_t)lrintf((y / length + 1.0f) * 32767.5f);
			data->gradient[channel][index][0] = (double)encoded_x / 32767.5 - 1.0;
			data->gradient[channel][index][1] = (double)encoded_y / 32767.5 - 1.0;
		}
	}
}

static double native_svg_turbulence_lerp(double first, double second,
	double progress) {
	return first + progress * (second - first);
}

static double native_svg_turbulence_noise(NativeSVGTurbulenceData const *data,
	int channel, double x, double y) {
	double floor_x = floor(x);
	double floor_y = floor(y);
	double fraction_x = x - floor_x;
	double fraction_y = y - floor_y;
	int x0 = ((int)floor_x) & 255;
	int x1 = (x0 + 1) & 255;
	int y0 = ((int)floor_y) & 255;
	int y1 = (y0 + 1) & 255;
	int b00 = (data->permutation[x0] + y0) & 255;
	int b10 = (data->permutation[x1] + y0) & 255;
	int b01 = (data->permutation[x0] + y1) & 255;
	int b11 = (data->permutation[x1] + y1) & 255;
	double smooth_x = fraction_x * fraction_x * (3.0 - 2.0 * fraction_x);
	double smooth_y = fraction_y * fraction_y * (3.0 - 2.0 * fraction_y);
	double a = native_svg_turbulence_lerp(
		data->gradient[channel][b00][0] * fraction_x
			+ data->gradient[channel][b00][1] * fraction_y,
		data->gradient[channel][b10][0] * (fraction_x - 1.0)
			+ data->gradient[channel][b10][1] * fraction_y, smooth_x);
	double b = native_svg_turbulence_lerp(
		data->gradient[channel][b01][0] * fraction_x
			+ data->gradient[channel][b01][1] * (fraction_y - 1.0),
		data->gradient[channel][b11][0] * (fraction_x - 1.0)
			+ data->gradient[channel][b11][1] * (fraction_y - 1.0), smooth_x);
	return native_svg_turbulence_lerp(a, b, smooth_y);
}

typedef struct {
	uint8_t *pixels;
	const NativeSVGTurbulenceData *noise;
	size_t width;
	double base_x, base_y, scale;
	int octaves, fractal;
} NativeSVGTurbulenceRows;

static void native_svg_turbulence_rows(void *context, int32_t first, int32_t end) {
	const NativeSVGTurbulenceRows *job = context;
	const NativeSVGTurbulenceData *noise_table = job->noise;
	const size_t width = job->width;
	const double base_x = job->base_x, base_y = job->base_y, scale = job->scale;
	const int octaves = job->octaves, fractal = job->fractal;
	uint8_t *row = job->pixels + (size_t)first * width * 4;
	for (int32_t pixel_y = first; pixel_y < end; ++pixel_y) {
		double row_coordinate = ((double)pixel_y + 0.5) / scale * base_y;
		for (size_t pixel_x = 0; pixel_x < width; ++pixel_x) {
			double coordinate_x = ((double)pixel_x + 0.5) / scale * base_x;
			double coordinate_y = row_coordinate;
			double color[4] = { 0, 0, 0, 0 };
			double ratio = 1.0;
			for (int octave = 0; octave < octaves; ++octave) {
				for (int channel = 0; channel < 4; ++channel) {
					double noise = native_svg_turbulence_noise(noise_table, channel,
						coordinate_x, coordinate_y);
					color[channel] += (fractal ? noise : fabs(noise)) * ratio;
				}
				coordinate_x *= 2.0;
				coordinate_y *= 2.0;
				ratio *= 0.5;
			}
			if (fractal) {
				for (int channel = 0; channel < 4; ++channel) {
					color[channel] = color[channel] * 0.5 + 0.5;
				}
			}
			double alpha = MIN(1.0, MAX(0.0, color[3]));
			uint8_t *pixel = row + pixel_x * 4;
			for (int channel = 0; channel < 3; ++channel) {
				double component = MIN(1.0, MAX(0.0, color[channel])) * alpha;
				pixel[channel] = (uint8_t)lrint(component * 255.0);
			}
			pixel[3] = (uint8_t)lrint(alpha * 255.0);
		}
		row += width * 4;
	}
}

static void native_svg_render_turbulence_pixels(uint8_t *pixels, size_t width, int32_t height,
	double base_x, double base_y, double octaves, double seed, int mode, double scale) {
	int octave_count = MAX(0, MIN(255, (int)octaves));
	NativeSVGTurbulenceData data;
	native_svg_initialize_turbulence(&data, seed);
	NativeSVGTurbulenceRows job = {pixels, &data, width, base_x, base_y,
		scale > 0.0 ? scale : 1.0, octave_count, mode == 1};
	// Each octave visits all four channels. Share the initialized noise
	// table and assign only whole rows until the workers join.
	const size_t octave_samples_per_worker = 32768;
	size_t pixel_count = width * (size_t)height;
	size_t pixels_per_worker = octave_count ? octave_samples_per_worker / (size_t)octave_count : SIZE_MAX;
	int32_t lanes = (int32_t)MIN(pixel_count / pixels_per_worker,
		(size_t)VOX_SCAN_WORKERS_MAX);
	if (lanes > height) lanes = height;
	if (lanes > 1 && !vox_scan_workers_disabled()) {
		vox_scan_workers_run(&job, height, lanes, native_svg_turbulence_rows);
	} else {
		native_svg_turbulence_rows(&job, 0, height);
	}
}
