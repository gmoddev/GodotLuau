#ifndef GL_INPUT_GRAPH_H
#define GL_INPUT_GRAPH_H

#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <vector>

// Disposable local projection of InputContext/Action/Binding Nodes. Godot owns
// physical event routing; this class is the sole semantic state evaluator.
class GLInputGraph {
public:
    static constexpr size_t MaximumContexts = 32, MaximumActions = 256, MaximumBindings = 1024;
    static constexpr int MaximumDevices = 16, KeyboardSlots = 512, MouseBase = 512, GamepadBase = 528;
    static constexpr int PhysicalSlots = GamepadBase + MaximumDevices * 32;
    enum ValueType { Bool, Scalar, Vector };
    enum SourceType { Key, MouseButton, GamepadButton };
    struct Context { uint64_t Id=0, Revision=0; int Priority=0; bool Enabled=true, Consume=true; };
    struct Action { uint64_t Id=0, Revision=0, ContextId=0; int Type=Bool; bool Enabled=true; };
    struct Binding {
        uint64_t Id=0, Revision=0, ActionId=0;
        int Type=Key, Code=0, Device=0, Priority=0;
        bool Enabled=true, Consume=false, ExactModifiers=false;
        std::array<int,4> Modifiers{};
        double Scale=1, X=1, Y=0;
    };
    struct Value {
        double X=0, Y=0;
        bool operator==(const Value& Other) const { return X==Other.X && Y==Other.Y; }
        bool Down() const { return X!=0 || Y!=0; }
    };
    struct State { Action Definition; Context Scope; Value Current; };
    struct Transition { uint64_t Id=0; int Type=Bool; Value Before, After; const char* Reason=""; };
    struct Row { Binding Definition; size_t ActionIndex=0; uint16_t Admitted=0; };

    GLInputGraph() {
        States.reserve(MaximumActions); Rows.reserve(MaximumBindings); Changes.reserve(MaximumActions);
    }
    const std::vector<State>& GetStates() const { return States; }
    const std::vector<Transition>& GetChanges() const { return Changes; }
    size_t GetEvaluatedBindings() const { return EvaluatedBindings; }
    uint64_t GetRevision() const { return Revision; }
    size_t GetBindingCount() const { return Rows.size(); }

    static int Slot(int Type, int Code, int Device) {
        if (Type==Key && Code>0 && Code<KeyboardSlots) return Code;
        if (Type==MouseButton && Code>=1 && Code<=8) return MouseBase+Code;
        if (Type==GamepadButton && Code>=0 && Code<32 && Device>=0 && Device<MaximumDevices) return GamepadBase+Device*32+Code;
        return -1;
    }
    static bool IsModifier(int Code) { return Code>=303 && Code<=310; }

    bool Compile(const std::vector<Context>& Contexts, const std::vector<Action>& Actions, const std::vector<Binding>& Bindings) {
        if (Contexts.size()>MaximumContexts || Actions.size()>MaximumActions || Bindings.size()>MaximumBindings) return false;
        std::vector<State> NextStates; NextStates.reserve(MaximumActions);
        std::vector<Row> NextRows; NextRows.reserve(MaximumBindings);
        for (const auto& Definition : Actions) {
            auto Scope=std::find_if(Contexts.begin(),Contexts.end(),[&](const Context& Item){return Item.Id==Definition.ContextId;});
            if (Scope==Contexts.end() || Definition.Type<Bool || Definition.Type>Vector) return false;
            State Next{Definition,*Scope,{}};
            for (const auto& Old : States) if (Old.Definition.Id==Definition.Id) { Next.Current=Old.Current; break; }
            NextStates.push_back(Next);
        }
        std::sort(NextStates.begin(),NextStates.end(),[](const State& A,const State& B){
            if (A.Scope.Priority!=B.Scope.Priority) return A.Scope.Priority>B.Scope.Priority;
            if (A.Scope.Id!=B.Scope.Id) return A.Scope.Id<B.Scope.Id;
            return A.Definition.Id<B.Definition.Id;
        });
        for (const auto& Definition : Bindings) {
            auto Found=std::find_if(NextStates.begin(),NextStates.end(),[&](const State& Item){return Item.Definition.Id==Definition.ActionId;});
            if (Found==NextStates.end() || Slot(Definition.Type,Definition.Code,Definition.Device<0?0:Definition.Device)<0 ||
                Definition.Device < -1 || !std::isfinite(Definition.Scale) || !std::isfinite(Definition.X) || !std::isfinite(Definition.Y) ||
                std::abs(Definition.Scale)>1000 || std::abs(Definition.X)>1000 || std::abs(Definition.Y)>1000) return false;
            for (int Modifier : Definition.Modifiers) if (Modifier && (!IsModifier(Modifier) || (Definition.Type==Key && Modifier==Definition.Code))) return false;
            Row Next{Definition,static_cast<size_t>(Found-NextStates.begin()),0};
            for (const auto& Old : Rows) if (Old.Definition.Id==Definition.Id && Old.Definition.Revision==Definition.Revision) {
                const auto& Previous=States[Old.ActionIndex];
                if (Previous.Definition.Id==Found->Definition.Id && Previous.Definition.Revision==Found->Definition.Revision &&
                    Previous.Scope.Id==Found->Scope.Id && Previous.Scope.Revision==Found->Scope.Revision &&
                    Previous.Scope.Enabled==Found->Scope.Enabled) Next.Admitted=Old.Admitted;
                break;
            }
            NextRows.push_back(Next);
        }
        States.swap(NextStates); Rows.swap(NextRows);
        std::sort(Rows.begin(),Rows.end(),[&](const Row& Left,const Row& Right){
            const auto& A=States[Left.ActionIndex].Scope; const auto& B=States[Right.ActionIndex].Scope;
            if (A.Priority!=B.Priority) return A.Priority>B.Priority;
            if (A.Id!=B.Id) return A.Id<B.Id;
            if (Left.Definition.Priority!=Right.Definition.Priority) return Left.Definition.Priority>Right.Definition.Priority;
            return Left.Definition.Id<Right.Definition.Id;
        });
        ++Revision;
        Evaluate(-1,false,false,"DefinitionChanged");
        return true;
    }

    void Event(int Type, int Code, int Device, bool Pressed, bool Processed, bool Repeat=false) {
        const int Physical=Slot(Type,Code,Device);
        Changes.clear();
        if (Physical<0) return;
        const bool Fresh=Pressed && !Repeat && !Down[Physical];
        Down[Physical]=Pressed;
        if (!Pressed || Processed) Eligible[Physical]=false;
        else if (Fresh) Eligible[Physical]=true;
        Evaluate(Physical,Fresh && !Processed,Processed,Processed?"GuiConsumed":"");
    }
    void Cancel(const char* Reason) {
        Down.fill(false); Eligible.fill(false);
        for (auto& Item : Rows) Item.Admitted=0;
        Evaluate(-1,false,false,Reason);
    }
    void Disconnect(int Device) {
        if (Device<0 || Device>=MaximumDevices) return;
        for (int Code=0;Code<32;++Code) Down[GamepadBase+Device*32+Code]=Eligible[GamepadBase+Device*32+Code]=false;
        for (auto& Item : Rows) if (Item.Definition.Type==GamepadButton) Item.Admitted &= ~(uint16_t(1)<<Device);
        Evaluate(-1,false,false,"DeviceDisconnected");
    }

private:
    std::vector<State> States;
    std::vector<Row> Rows;
    std::vector<Transition> Changes;
    std::array<bool,PhysicalSlots> Down{}, Eligible{};
    size_t EvaluatedBindings=0;
    uint64_t Revision=0;

    bool Chord(const Binding& Definition) const {
        for (int Code : Definition.Modifiers) if (Code && !Eligible[Code]) return false;
        if (Definition.ExactModifiers) for (int Code=303;Code<=310;++Code) {
            if (Definition.Type==Key && Definition.Code==Code) continue;
            const bool Required=std::find(Definition.Modifiers.begin(),Definition.Modifiers.end(),Code)!=Definition.Modifiers.end();
            if (Eligible[Code]!=Required) return false;
        }
        return true;
    }
    void Evaluate(int EventSlot, bool Fresh, bool Processed, const char* Reason) {
        Changes.clear();
        std::array<Value,MaximumActions> Values{};
        std::array<uint64_t,PhysicalSlots> Winners{};
        std::array<const char*,MaximumActions> Cancelled{};
        for (auto& Item : Rows) {
            ++EvaluatedBindings;
            const auto& Definition=Item.Definition; const auto& Action=States[Item.ActionIndex];
            const bool Enabled=Definition.Enabled && Action.Definition.Enabled && Action.Scope.Enabled;
            const int First=Definition.Type==GamepadButton && Definition.Device<0?0:Definition.Device;
            const int Last=Definition.Type==GamepadButton && Definition.Device<0?MaximumDevices-1:First;
            bool Active=false;
            for (int Device=First;Device<=Last;++Device) {
                const int Physical=Slot(Definition.Type,Definition.Code,Device<0?0:Device);
                const uint16_t Bit=uint16_t(1)<<(Definition.Type==GamepadButton?Device:0);
                const bool WasAdmitted=(Item.Admitted&Bit)!=0;
                const bool ChordHeld=Chord(Definition);
                const bool Matched=Enabled && Eligible[Physical] && ChordHeld;
                const bool Suppressed=Matched && Winners[Physical] && Winners[Physical]!=Action.Scope.Id;
                if (!Matched || Suppressed || (Processed && EventSlot==Physical)) Item.Admitted &= ~Bit;
                else if (Fresh && EventSlot==Physical) Item.Admitted |= Bit;
                if (WasAdmitted && !(Item.Admitted&Bit)) {
                    if (Reason[0]) Cancelled[Item.ActionIndex]=Reason;
                    else if (Suppressed) Cancelled[Item.ActionIndex]="Suppressed";
                    else if (!Enabled) Cancelled[Item.ActionIndex]="Disabled";
                    else if (!ChordHeld) Cancelled[Item.ActionIndex]="ChordLost";
                }
                if (Matched && !Suppressed && (Action.Scope.Consume || Definition.Consume)) Winners[Physical]=Action.Scope.Id;
                Active |= (Item.Admitted&Bit)!=0;
            }
            if (Active) {
                auto& Value=Values[Item.ActionIndex];
                if (Action.Definition.Type==Bool) Value.X=1;
                else if (Action.Definition.Type==Scalar) Value.X+=Definition.Scale;
                else { Value.X+=Definition.X*Definition.Scale; Value.Y+=Definition.Y*Definition.Scale; }
            }
        }
        for (size_t Index=0;Index<States.size();++Index) {
            auto& Item=States[Index]; auto Next=Values[Index];
            if (Item.Definition.Type==Scalar) Next.X=(std::max)(-1.0,(std::min)(1.0,Next.X));
            else if (Item.Definition.Type==Vector) {
                const double Length=std::hypot(Next.X,Next.Y);
                if (Length>1) { Next.X/=Length; Next.Y/=Length; }
            }
            if (!(Item.Current==Next)) {
                const bool Retired=Item.Current.Down() && !Next.Down() && Reason[0];
                const char* Cancellation=Cancelled[Index]?Cancelled[Index]:(Retired?Reason:"");
                Changes.push_back({Item.Definition.Id,Item.Definition.Type,Item.Current,Next,Cancellation});
                Item.Current=Next;
            }
        }
    }
};
#endif
