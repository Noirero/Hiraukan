#include "audio_device_enum.h"

#include <windows.h>
#include <mmdeviceapi.h>
#include <combaseapi.h>
#include <propsys.h>

#include <string>

namespace {

static const PROPERTYKEY kPkeyDeviceFriendlyName = {
    {0xa45c254e, 0xdf1c, 0x4efd, {0x80, 0x20, 0x67, 0xd1, 0x46, 0xa8, 0x50, 0xe0}},
    14};
static const PROPERTYKEY kPkeyDeviceDeviceDesc = {
    {0xa45c254e, 0xdf1c, 0x4efd, {0x80, 0x20, 0x67, 0xd1, 0x46, 0xa8, 0x50, 0xe0}},
    2};
static const PROPERTYKEY kPkeyDeviceInterfaceFriendlyName = {
    {0xb3f8fa53, 0x0004, 0x438e, {0x90, 0x03, 0x51, 0xa4, 0x6e, 0x13, 0x9b, 0xfc}},
    6};
static const PROPERTYKEY kPkeyAudioEndpointFormFactor = {
    {0x1da5d803, 0xd492, 0x4edd, {0x8c, 0x23, 0xe0, 0xc0, 0xff, 0xee, 0x7f, 0x0e}},
    0};

std::wstring JsonEscape(const std::wstring& input) {
  std::wstring out;
  out.reserve(input.size() + 8);
  wchar_t buffer[8];
  for (wchar_t c : input) {
    switch (c) {
      case L'"': out += L"\\\""; break;
      case L'\\': out += L"\\\\"; break;
      case L'\n': out += L"\\n"; break;
      case L'\r': out += L"\\r"; break;
      case L'\t': out += L"\\t"; break;
      default:
        if (c < 0x20) {
          swprintf_s(buffer, 8, L"\\u%04x", static_cast<unsigned>(c));
          out += buffer;
        } else {
          out += c;
        }
    }
  }
  return out;
}

std::wstring GetDeviceId(IMMDevice* device) {
  LPWSTR value = nullptr;
  if (FAILED(device->GetId(&value)) || value == nullptr) return L"";
  std::wstring result(value);
  CoTaskMemFree(value);
  return result;
}

std::wstring GetStringProperty(IMMDevice* device, const PROPERTYKEY& key) {
  IPropertyStore* store = nullptr;
  if (FAILED(device->OpenPropertyStore(STGM_READ, &store)) || store == nullptr) {
    return L"";
  }
  std::wstring result;
  PROPVARIANT value;
  PropVariantInit(&value);
  if (SUCCEEDED(store->GetValue(key, &value)) && value.vt == VT_LPWSTR &&
      value.pwszVal != nullptr) {
    result = value.pwszVal;
  }
  PropVariantClear(&value);
  store->Release();
  return result;
}

int GetFormFactor(IMMDevice* device) {
  IPropertyStore* store = nullptr;
  if (FAILED(device->OpenPropertyStore(STGM_READ, &store)) || store == nullptr) {
    return -1;
  }
  int result = -1;
  PROPVARIANT value;
  PropVariantInit(&value);
  if (SUCCEEDED(store->GetValue(kPkeyAudioEndpointFormFactor, &value)) &&
      value.vt == VT_UI4) {
    result = static_cast<int>(value.ulVal);
  }
  PropVariantClear(&value);
  store->Release();
  return result;
}

}  // namespace

extern "C" __declspec(dllexport) wchar_t* hiraukan_enumerate_audio_devices(void) {
  HRESULT hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  const bool initialized_here = SUCCEEDED(hr);
  if (!initialized_here && hr != RPC_E_CHANGED_MODE) return nullptr;

  IMMDeviceEnumerator* enumerator = nullptr;
  hr = CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr, CLSCTX_ALL,
                        __uuidof(IMMDeviceEnumerator),
                        reinterpret_cast<void**>(&enumerator));
  if (FAILED(hr) || enumerator == nullptr) {
    if (initialized_here) CoUninitialize();
    return nullptr;
  }

  std::wstring default_id;
  IMMDevice* default_device = nullptr;
  if (SUCCEEDED(enumerator->GetDefaultAudioEndpoint(eRender, eMultimedia,
                                                    &default_device)) &&
      default_device != nullptr) {
    default_id = GetDeviceId(default_device);
    default_device->Release();
  }

  std::wstring json = L"{\"default\":\"" + JsonEscape(default_id) +
                      L"\",\"devices\":[";
  IMMDeviceCollection* collection = nullptr;
  hr = enumerator->EnumAudioEndpoints(eRender, DEVICE_STATE_ACTIVE, &collection);
  if (SUCCEEDED(hr) && collection != nullptr) {
    UINT count = 0;
    if (SUCCEEDED(collection->GetCount(&count))) {
      bool first = true;
      for (UINT i = 0; i < count; ++i) {
        IMMDevice* device = nullptr;
        if (FAILED(collection->Item(i, &device)) || device == nullptr) continue;
        const std::wstring full_id = GetDeviceId(device);
        const std::wstring name = GetStringProperty(device, kPkeyDeviceFriendlyName);
        const std::wstring desc = GetStringProperty(device, kPkeyDeviceDeviceDesc);
        const std::wstring iface =
            GetStringProperty(device, kPkeyDeviceInterfaceFriendlyName);
        const int form_factor = GetFormFactor(device);
        const bool is_default = !full_id.empty() && full_id == default_id;
        if (!first) json += L",";
        first = false;
        json += L"{\"fullId\":\"" + JsonEscape(full_id) +
                L"\",\"name\":\"" + JsonEscape(name) +
                L"\",\"desc\":\"" + JsonEscape(desc) +
                L"\",\"iface\":\"" + JsonEscape(iface) +
                L"\",\"formFactor\":" + std::to_wstring(form_factor) +
                L",\"isDefault\":" + (is_default ? L"true" : L"false") + L"}";
        device->Release();
      }
    }
    collection->Release();
  }
  json += L"]}";

  enumerator->Release();
  if (initialized_here) CoUninitialize();

  const size_t chars = json.size() + 1;
  wchar_t* out =
      static_cast<wchar_t*>(CoTaskMemAlloc(chars * sizeof(wchar_t)));
  if (out == nullptr) return nullptr;
  wcscpy_s(out, chars, json.c_str());
  return out;
}

extern "C" __declspec(dllexport) void hiraukan_free_string(wchar_t* ptr) {
  if (ptr != nullptr) CoTaskMemFree(ptr);
}
