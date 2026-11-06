#ifndef GL_MEMORY_ACCOUNT_H
#define GL_MEMORY_ACCOUNT_H

#include <cstddef>
#include <cstdlib>
#include <limits>

// Lua allocator context. Must outlive lua_close; contains no VM pointer and
// performs no Lua calls, logging, container allocation or exception throwing.
struct GLMemoryAccount {
    enum class Failure { None, Quota, Overflow, InvalidInput, HostAllocation };
    size_t Live = 0;
    size_t Peak = 0;
    size_t Limit = 0; // zero is explicit accounting-only mode
    size_t Rejections = 0;
    bool InvalidAccounting = false;
    Failure LastFailure = Failure::None;

    static void* Allocate(void* Context, void* Pointer, size_t OldSize, size_t NewSize) noexcept {
        auto& Account = *static_cast<GLMemoryAccount*>(Context);
        if ((Pointer == nullptr) != (OldSize == 0) || OldSize > Account.Live) {
            Account.InvalidAccounting = true;
            Account.LastFailure = Failure::InvalidInput;
            ++Account.Rejections;
            return nullptr;
        }
        if (NewSize == 0) {
            std::free(Pointer);
            Account.Live -= OldSize;
            return nullptr;
        }
        size_t Retained = Account.Live - OldSize;
        if (NewSize > (std::numeric_limits<size_t>::max)() - Retained) {
            Account.LastFailure = Failure::Overflow;
            ++Account.Rejections;
            return nullptr;
        }
        if (NewSize > OldSize && Account.Limit && (Retained > Account.Limit || NewSize > Account.Limit - Retained)) {
            Account.LastFailure = Failure::Quota;
            ++Account.Rejections;
            return nullptr;
        }
        void* Result = std::realloc(Pointer, NewSize);
        if (!Result) { Account.LastFailure = Failure::HostAllocation; ++Account.Rejections; return nullptr; }
        Account.Live = Retained + NewSize;
        if (Account.Live > Account.Peak) Account.Peak = Account.Live;
        return Result;
    }
};

#endif
