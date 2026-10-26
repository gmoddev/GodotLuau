#ifndef GL_STACKGUARD_H
#define GL_STACKGUARD_H

// ════════════════════════════════════════════════════════════════════
//  Guardia de PILA del puente Lua <-> Godot.
//
//  El problema: un script puede encadenar recursion a traves del puente
//  (indexar -> metamétodo en C++ -> volver a Lua -> indexar...). Cada nivel
//  gasta MUCHISIMA mas pila de C que un nivel de Lua puro, asi que el limite de
//  llamadas de Luau no llega a saltar: el proceso se queda sin pila y se cae con
//  un segfault, sin mensaje y sin nada que mirar.
//
//  Aqui se mide cuanta pila queda ANTES de seguir bajando. Si queda poca, se
//  lanza un error de Lua normal ("stack overflow") en vez de reventar: el script
//  culpable muere con su linea y su traza, como en Roblox, y el juego sigue.
//
//  Windows/Linux use real per-thread OS bounds and a native frame/return slot.
//  Address-taken locals are unsuitable when ASan moves them to its fake stack.
// ════════════════════════════════════════════════════════════════════

#include "lua.h"
#include "lualib.h"

#include <cstddef>
#include <cstdint>
#if defined(_MSC_VER)
#include <intrin.h>
#elif defined(__linux__)
#include <pthread.h>
#endif

// Se declara a mano en vez de incluir <windows.h>: esa cabecera define macros
// (MIN/MAX/small/IN/OUT...) que rompen la compilacion del resto del proyecto.
#if defined(_WIN32)
extern "C" __declspec(dllimport) void __stdcall
GetCurrentThreadStackLimits(uint64_t* LowLimit, uint64_t* HighLimit);
#endif

// Margen que se reserva: por debajo de esto se corta. Un nivel del puente puede
// gastar bastante, asi que hace falta holgura para desenrollar con seguridad.
static const size_t GL_STACK_MARGIN = 256 * 1024;

// Direccion del fondo de la pila del hilo actual (0 si no se puede saber).
static inline char* gl_stack_floor() {
#if defined(_WIN32)
    uint64_t low = 0, high = 0;
    GetCurrentThreadStackLimits(&low, &high);
    return (char*)(uintptr_t)low;
#elif defined(__linux__)
    pthread_attr_t Attributes;
    if (pthread_getattr_np(pthread_self(), &Attributes) != 0) return nullptr;
    void* Address = nullptr;
    size_t Size = 0;
    int Result = pthread_attr_getstack(&Attributes, &Address, &Size);
    pthread_attr_destroy(&Attributes);
    return Result == 0 ? static_cast<char*>(Address) : nullptr;
#else
    return nullptr;
#endif
}

// Sin API del sistema: se recuerda la direccion mas alta vista y se pone un
// presupuesto fijo desde ahi.
static inline char*& gl_stack_high_water() {
    static thread_local char* hi = nullptr;
    return hi;
}

// true si queda poca pila para seguir bajando.
static inline bool gl_stack_exhausted(void* here) {
    uintptr_t Current = reinterpret_cast<uintptr_t>(here);
    static thread_local char* Floor = gl_stack_floor();
    if (Floor) return Current <= reinterpret_cast<uintptr_t>(Floor) + GL_STACK_MARGIN;
    char*& hi = gl_stack_high_water();
    if (!hi || Current > reinterpret_cast<uintptr_t>(hi)) { hi = static_cast<char*>(here); return false; }
    // Presupuesto de 1 MB de crecimiento por el puente: mas que eso ya es
    // recursion patologica en cualquier juego real.
    return reinterpret_cast<uintptr_t>(hi) - Current > (1024u * 1024u);
}

// ASan can move address-taken locals to a fake stack. A frame/return slot stays
// on the real OS stack and must be used for a native stack-limit comparison.
static inline void* GLStackPointer() {
#if defined(_MSC_VER)
    return _AddressOfReturnAddress();
#elif defined(__GNUC__) || defined(__clang__)
    return __builtin_frame_address(0);
#else
    return nullptr;
#endif
}

// Se pone al entrar en los metamétodos del puente. Si la pila esta al limite,
// corta con un error de Lua (que SI se puede capturar y reportar).
#define GL_STACK_GUARD(L)                                                        \
    do {                                                                         \
        void* _gl_probe = GLStackPointer();                                      \
        if (_gl_probe && gl_stack_exhausted(_gl_probe)) {                         \
            luaL_error((L), "stack overflow (demasiada recursion en el script)"); \
        }                                                                        \
    } while (0)

#endif // GL_STACKGUARD_H
