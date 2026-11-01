// Qualification-only C ABI extension. No godot-cpp, Luau, Game or networking.
#include <gdextension_interface.h>
#include <cstdio>
#include <cstdlib>
#include <cstring>

#ifdef _WIN32
#define GL_PROBE_EXPORT __declspec(dllexport)
#define GL_PROBE_NOINLINE __declspec(noinline)
#else
#define GL_PROBE_EXPORT __attribute__((visibility("default")))
#define GL_PROBE_NOINLINE __attribute__((noinline))
#endif

static GL_PROBE_NOINLINE void ProbeBody() {
    const char *Mode = std::getenv("GL_NATIVE_SANITIZER_CONTROL");
    int *Pointer = static_cast<int *>(std::malloc(sizeof(int)));
    if (!Pointer) std::abort();
    *Pointer = 73;
    if (Mode && std::strcmp(Mode, "leak") == 0) {
        // Deliberately lose the sole reference; Linux LSan must detect this.
        Pointer = nullptr;
        return;
    }
    std::free(Pointer);
    if (Mode && std::strcmp(Mode, "use-after-free") == 0) {
        volatile int Value = *Pointer; // Deliberate detection control, never production.
        std::printf("[Runtime:SanitizerProbe] Unexpected stale read %d\n", Value);
    }
}

static void Initialize(void *, GDExtensionInitializationLevel Level) {
    std::printf("[Runtime:SanitizerProbe] Initialize %d\n", static_cast<int>(Level));
    std::fflush(stdout);
    ProbeBody();
}

static void Deinitialize(void *, GDExtensionInitializationLevel Level) {
    std::printf("[Runtime:SanitizerProbe] Deinitialize %d\n", static_cast<int>(Level));
    std::fflush(stdout);
}

extern "C" GL_PROBE_EXPORT int SanitizerProbeTouch() {
    ProbeBody();
    return 73;
}

extern "C" GL_PROBE_EXPORT GDExtensionBool SanitizerProbeInit(
        GDExtensionInterfaceGetProcAddress, GDExtensionClassLibraryPtr,
        GDExtensionInitialization *Initialization) {
    Initialization->minimum_initialization_level = GDEXTENSION_INITIALIZATION_SCENE;
    Initialization->userdata = nullptr;
    Initialization->initialize = Initialize;
    Initialization->deinitialize = Deinitialize;
    return true;
}
