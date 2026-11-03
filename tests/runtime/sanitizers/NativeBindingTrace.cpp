// Diagnostic-only loader for the unchanged production extension. This is not
// linked into GodotLuau and is not an accepted unload implementation.
#include <gdextension_interface.h>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <mutex>
#include <vector>
#ifdef _WIN32
#include <windows.h>
#define GL_TRACE_EXPORT __declspec(dllexport)
#else
#include <dlfcn.h>
#define GL_TRACE_EXPORT __attribute__((visibility("default")))
#endif

struct BindingRecord {
    GDObjectInstanceID Identity;
    void *Token;
    GDExtensionInstanceBindingFreeCallback FreeCallback;
};
static std::vector<BindingRecord> Bindings;
static std::mutex BindingMutex;
static GDExtensionInterfaceGetProcAddress HostProc;
static GDExtensionInterfaceObjectGetInstanceBinding HostGet;
static GDExtensionInterfaceObjectGetInstanceId HostIdentity;
static GDExtensionInterfaceObjectGetInstanceFromId HostResolve;
static GDExtensionInterfaceObjectFreeInstanceBinding HostFree;
static GDExtensionInterfaceObjectGetClassName HostClass;
static GDExtensionInterfaceVariantGetPtrConstructor HostConstructor;
static GDExtensionInterfaceVariantGetPtrDestructor HostDestructor;
static GDExtensionInterfaceStringToUtf8Chars HostUtf8;
static GDExtensionClassLibraryPtr LibraryToken;
static GDExtensionInitialization Production;
#ifdef _WIN32
static HMODULE Library;
#else
static void *Library;
#endif

static void DescribeClass(GDExtensionObjectPtr Object, char *Text, GDExtensionInt Capacity) {
    // Pinned C ABI: String and StringName each occupy one pointer. String's
    // constructor 2 accepts StringName (verified in the pinned extension API).
    alignas(void *) unsigned char Name[sizeof(void *)];
    alignas(void *) unsigned char String[sizeof(void *)];
    if (!HostClass(Object, LibraryToken, Name)) {
        std::snprintf(Text, static_cast<size_t>(Capacity), "<unknown>");
        return;
    }
    GDExtensionConstTypePtr Arguments[] = {Name};
    HostConstructor(GDEXTENSION_VARIANT_TYPE_STRING, 2)(String, Arguments);
    const auto Size = HostUtf8(String, Text, Capacity - 1);
    Text[Size < Capacity ? Size : Capacity - 1] = '\0';
    HostDestructor(GDEXTENSION_VARIANT_TYPE_STRING)(String);
    HostDestructor(GDEXTENSION_VARIANT_TYPE_STRING_NAME)(Name);
}

static void *TraceGet(GDExtensionObjectPtr Object, void *Token,
        const GDExtensionInstanceBindingCallbacks *Callbacks) {
    const bool Created = Callbacks && !HostGet(Object, Token, nullptr);
    void *Result = HostGet(Object, Token, Callbacks);
    if (Created && Result) {
        const auto Identity = HostIdentity(Object);
        std::lock_guard<std::mutex> Lock(BindingMutex);
        Bindings.push_back({Identity, Token, Callbacks->free_callback});
        std::printf("[Runtime:BindingTrace] create id=%llu object=%p token=%p free=%p\n",
                static_cast<unsigned long long>(Identity), Object, Token,
                reinterpret_cast<void *>(Callbacks->free_callback));
        std::fflush(stdout);
    }
    return Result;
}

static GDExtensionInterfaceFunctionPtr TraceProc(const char *Name) {
    if (std::strcmp(Name, "object_get_instance_binding") == 0) {
        return reinterpret_cast<GDExtensionInterfaceFunctionPtr>(TraceGet);
    }
    return HostProc(Name);
}

static void Initialize(void *, GDExtensionInitializationLevel Level) {
    Production.initialize(Production.userdata, Level);
}

static void Deinitialize(void *, GDExtensionInitializationLevel Level) {
    Production.deinitialize(Production.userdata, Level);
    if (Level != Production.minimum_initialization_level) return;
    const char *Mode = std::getenv("GL_NATIVE_TRACE_MODE");
    const bool Retire = Mode && std::strcmp(Mode, "retire") == 0;
    // Snapshot under the trace mutex; callbacks must not run under that lock.
    std::vector<BindingRecord> Snapshot;
    {
        std::lock_guard<std::mutex> Lock(BindingMutex);
        Snapshot.swap(Bindings);
    }
    unsigned Live = 0;
    for (const auto &Record : Snapshot) {
        auto Object = HostResolve(Record.Identity);
        if (!Object || !HostGet(Object, Record.Token, nullptr)) continue;
        ++Live;
        char Class[128] = {};
        DescribeClass(Object, Class, sizeof(Class));
        std::printf("[Runtime:BindingTrace] survivor class=%s id=%llu object=%p token=%p free=%p action=%s\n", Class,
                static_cast<unsigned long long>(Record.Identity), Object, Record.Token,
                reinterpret_cast<void *>(Record.FreeCallback), Retire ? "retire" : "observe");
        std::fflush(stdout);
        if (Retire) HostFree(Object, Record.Token);
    }
    std::printf("[Runtime:BindingTrace] after-production level=%d survivors=%u\n", static_cast<int>(Level), Live);
    std::fflush(stdout);
}

extern "C" GL_TRACE_EXPORT GDExtensionBool NativeBindingTraceInit(
        GDExtensionInterfaceGetProcAddress GetProc, GDExtensionClassLibraryPtr Token,
        GDExtensionInitialization *Initialization) {
    const char *Path = std::getenv("GL_NATIVE_TRACE_EXTENSION");
    const char *Mode = std::getenv("GL_NATIVE_TRACE_MODE");
    if (!Path || !Mode || (std::strcmp(Mode, "observe") && std::strcmp(Mode, "retire"))) return false;
    HostProc = GetProc;
    HostGet = reinterpret_cast<GDExtensionInterfaceObjectGetInstanceBinding>(GetProc("object_get_instance_binding"));
    HostIdentity = reinterpret_cast<GDExtensionInterfaceObjectGetInstanceId>(GetProc("object_get_instance_id"));
    HostResolve = reinterpret_cast<GDExtensionInterfaceObjectGetInstanceFromId>(GetProc("object_get_instance_from_id"));
    HostFree = reinterpret_cast<GDExtensionInterfaceObjectFreeInstanceBinding>(GetProc("object_free_instance_binding"));
    HostClass = reinterpret_cast<GDExtensionInterfaceObjectGetClassName>(GetProc("object_get_class_name"));
    HostConstructor = reinterpret_cast<GDExtensionInterfaceVariantGetPtrConstructor>(GetProc("variant_get_ptr_constructor"));
    HostDestructor = reinterpret_cast<GDExtensionInterfaceVariantGetPtrDestructor>(GetProc("variant_get_ptr_destructor"));
    HostUtf8 = reinterpret_cast<GDExtensionInterfaceStringToUtf8Chars>(GetProc("string_to_utf8_chars"));
    LibraryToken = Token;
#ifdef _WIN32
    Library = LoadLibraryA(Path);
    auto Entry = Library ? reinterpret_cast<GDExtensionInitializationFunction>(GetProcAddress(Library, "luau_extension_init")) : nullptr;
#else
    // Match the sanitized host: no RTLD_DEEPBIND and no altered ASan runtime.
    Library = dlopen(Path, RTLD_NOW | RTLD_LOCAL);
    auto Entry = Library ? reinterpret_cast<GDExtensionInitializationFunction>(dlsym(Library, "luau_extension_init")) : nullptr;
#endif
    if (!Entry || !Entry(TraceProc, Token, &Production)) return false;
    Initialization->userdata = nullptr;
    Initialization->minimum_initialization_level = Production.minimum_initialization_level;
    Initialization->initialize = Initialize;
    Initialization->deinitialize = Deinitialize;
    return true;
}

// Close the delegated library only when the diagnostic library itself unloads.
// Holding it until process exit would mask the very callback defect under test.
struct LibraryLifetime {
    ~LibraryLifetime() {
        if (!Library) return;
#ifdef _WIN32
        FreeLibrary(Library);
#else
        dlclose(Library);
#endif
    }
};
static LibraryLifetime Lifetime;
