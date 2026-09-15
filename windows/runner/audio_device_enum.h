#pragma once

// Windows WASAPI render-device enumeration bridge for Hiraukan.
// Adapted from KikoFlu's GPL-3.0 Windows USB DAC implementation.
//
// The returned UTF-16 JSON string is allocated with CoTaskMemAlloc and must be
// released with hiraukan_free_string.

#ifdef __cplusplus
extern "C" {
#endif

__declspec(dllexport) wchar_t* hiraukan_enumerate_audio_devices(void);
__declspec(dllexport) void hiraukan_free_string(wchar_t* ptr);

#ifdef __cplusplus
}
#endif
