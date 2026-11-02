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

static GDExtensionObjectPtr BoundObject = nullptr;
static GDExtensionClassLibraryPtr BindingToken = nullptr;
static GDExtensionInterfaceObjectFreeInstanceBinding FreeBinding = nullptr;

static void *CreateProbeBinding(void *, void *) { return std::malloc(1); }

static void FreeProbeBinding(void *, void *, void *Binding) {
    std::printf("[Runtime:SanitizerProbe] Binding freed before library unload\n");
    std::fflush(stdout);
    std::free(Binding);
}

static const GDExtensionInstanceBindingCallbacks BindingCallbacks = {CreateProbeBinding, FreeProbeBinding, nullptr};

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
    const char *Mode = std::getenv("GL_NATIVE_SANITIZER_CONTROL");
    if (Level == GDEXTENSION_INITIALIZATION_SCENE && Mode && std::strcmp(Mode, "binding-clean") == 0 && BoundObject) {
        FreeBinding(BoundObject, BindingToken);
        BoundObject = nullptr;
    }
}

extern "C" GL_PROBE_EXPORT int SanitizerProbeTouch() {
    ProbeBody();
    return 73;
}

extern "C" GL_PROBE_EXPORT GDExtensionBool SanitizerProbeInit(
        GDExtensionInterfaceGetProcAddress GetProcAddress, GDExtensionClassLibraryPtr Library,
        GDExtensionInitialization *Initialization) {
    const char *Mode = std::getenv("GL_NATIVE_SANITIZER_CONTROL");
    if (Mode && (std::strcmp(Mode, "binding") == 0 || std::strcmp(Mode, "binding-clean") == 0)) {
        // Isolate an engine-owned object's binding from godot-cpp and GodotLuau.
        auto NewName = reinterpret_cast<GDExtensionInterfaceStringNameNewWithUtf8Chars>(GetProcAddress("string_name_new_with_utf8_chars"));
        auto Destroy = reinterpret_cast<GDExtensionInterfaceVariantGetPtrDestructor>(GetProcAddress("variant_get_ptr_destructor"));
        auto Singleton = reinterpret_cast<GDExtensionInterfaceGlobalGetSingleton>(GetProcAddress("global_get_singleton"));
        auto GetBinding = reinterpret_cast<GDExtensionInterfaceObjectGetInstanceBinding>(GetProcAddress("object_get_instance_binding"));
        FreeBinding = reinterpret_cast<GDExtensionInterfaceObjectFreeInstanceBinding>(GetProcAddress("object_free_instance_binding"));
        alignas(void *) unsigned char Name[sizeof(void *)];
        NewName(Name, "Engine");
        BoundObject = Singleton(Name);
        Destroy(GDEXTENSION_VARIANT_TYPE_STRING_NAME)(Name);
        if (!BoundObject) return false;
        BindingToken = Library;
        if (!GetBinding(BoundObject, BindingToken, &BindingCallbacks)) return false;
        std::printf("[Runtime:SanitizerProbe] Engine singleton binding installed; mode=%s\n", Mode);
        std::fflush(stdout);
    }
    Initialization->minimum_initialization_level = GDEXTENSION_INITIALIZATION_SCENE;
    Initialization->userdata = nullptr;
    Initialization->initialize = Initialize;
    Initialization->deinitialize = Deinitialize;
    return true;
}
