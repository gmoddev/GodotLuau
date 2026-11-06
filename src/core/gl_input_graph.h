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
    static constexpr int StickBase=GamepadBase+MaximumDevices*32, PointerSlot=StickBase+MaximumDevices*2;
    static constexpr int PhysicalSlots = PointerSlot+1;
    enum ValueType { Bool, Scalar, Vector };
    enum SourceType { Key, MouseButton, GamepadButton, GamepadStick, MouseMotion };
    struct Context { uint64_t Id=0, Revision=0; int Priority=0; bool Enabled=true, Consume=true; };
    struct Action { uint64_t Id=0, Revision=0, ContextId=0; int Type=Bool; bool Enabled=true; };
    struct Binding {
        uint64_t Id=0, Revision=0, ActionId=0;
        int Type=Key, Code=0, Device=0, Priority=0;
        bool Enabled=true, Consume=false, ExactModifiers=false;
        std::array<int,4> Modifiers{};
        double Scale=1, X=1, Y=0, Deadzone=0.2;
    };
    struct Value {
        double X=0, Y=0;
        bool operator==(const Value& Other) const { return X==Other.X && Y==Other.Y; }
        bool Down() const { return X!=0 || Y!=0; }
    };
    struct State {
        Action Definition; Context Scope; Value Current;
        bool Relative=false;
        Value FrameDelta, PhysicsDelta, PhysicsSample;
    };
    struct Transition { uint64_t Id=0; int Type=Bool; Value Before, After; const char* Reason=""; };
    struct Row { Binding Definition; size_t ActionIndex=0; uint16_t Admitted=0, Armed=0; };

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
        if (Type==GamepadStick && Code>=0 && Code<2 && Device>=0 && Device<MaximumDevices) return StickBase+Device*2+Code;
        if (Type==MouseMotion) return PointerSlot;
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
                std::abs(Definition.Scale)>1000 || std::abs(Definition.X)>1000 || std::abs(Definition.Y)>1000 ||
                !std::isfinite(Definition.Deadzone) || Definition.Deadzone<0 || Definition.Deadzone>0.95 ||
                (Definition.Type>=GamepadStick && Found->Definition.Type!=Vector)) return false;
            for (int Modifier : Definition.Modifiers) if (Modifier && (!IsModifier(Modifier) || (Definition.Type==Key && Modifier==Definition.Code))) return false;
            Row Next{Definition,static_cast<size_t>(Found-NextStates.begin()),0};
            if (Definition.Type==GamepadStick) for (int Device=0;Device<MaximumDevices;++Device) {
                int Physical=Slot(GamepadStick,Definition.Code,Device);
                if (!ContinuousBlocked[Physical] && Length(Continuous[Physical])<=Definition.Deadzone) Next.Armed|=uint16_t(1)<<Device;
            }
            for (const auto& Old : Rows) if (Old.Definition.Id==Definition.Id && Old.Definition.Revision==Definition.Revision) {
                const auto& Previous=States[Old.ActionIndex];
                if (Previous.Definition.Id==Found->Definition.Id && Previous.Definition.Revision==Found->Definition.Revision &&
                    Previous.Scope.Id==Found->Scope.Id && Previous.Scope.Revision==Found->Scope.Revision &&
                    Previous.Scope.Enabled==Found->Scope.Enabled) { Next.Admitted=Old.Admitted; Next.Armed=Old.Armed; }
                break;
            }
            NextRows.push_back(Next);
        }
        for (auto& State:NextStates) {
            bool Level=false;
            for (const auto& Row:NextRows) if (Row.Definition.ActionId==State.Definition.Id) {
                State.Relative |= Row.Definition.Type==MouseMotion;
                Level |= Row.Definition.Type!=MouseMotion;
            }
            if (State.Relative && Level) return false;
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
        ContinuousBlocked.fill(true);
        for (auto& Item : Rows) Item.Admitted=Item.Armed=0;
        for (auto& Item:States) Item.FrameDelta=Item.PhysicsDelta=Item.PhysicsSample={};
        Evaluate(-1,false,false,Reason);
    }
    void Disconnect(int Device) {
        if (Device<0 || Device>=MaximumDevices) return;
        for (int Code=0;Code<32;++Code) Down[GamepadBase+Device*32+Code]=Eligible[GamepadBase+Device*32+Code]=false;
        for (int Stick=0;Stick<2;++Stick) { int Physical=Slot(GamepadStick,Stick,Device); Continuous[Physical]={}; ContinuousBlocked[Physical]=true; }
        for (auto& Item : Rows) if (Item.Definition.Type==GamepadButton || Item.Definition.Type==GamepadStick) {
            Item.Admitted &= ~(uint16_t(1)<<Device); Item.Armed &= ~(uint16_t(1)<<Device);
        }
        Evaluate(-1,false,false,"DeviceDisconnected");
    }
    bool Stick(int Device, int Index, double X, double Y, bool Processed) {
        int Physical=Slot(GamepadStick,Index,Device);
        if (Physical<0 || !std::isfinite(X) || !std::isfinite(Y) || std::abs(X)>1 || std::abs(Y)>1) return false;
        PreviousContinuous[Physical]=Continuous[Physical]; Continuous[Physical]={X,Y};
        if (Processed) ContinuousBlocked[Physical]=true;
        Evaluate(Physical,false,Processed,Processed?"GuiConsumed":""); return true;
    }
    bool Motion(double X, double Y, bool Processed) {
        if (!std::isfinite(X) || !std::isfinite(Y) || std::abs(X)>8192 || std::abs(Y)>8192) return false;
        Continuous[PointerSlot]={X,Y}; Evaluate(PointerSlot,false,Processed,Processed?"GuiConsumed":""); return true;
    }
    // Samples are non-consuming to readers. Only the native frame/tick fence
    // rotates accumulators; physics and rendering never drain one another.
    void SampleFrame() {
        Changes.clear();
        for (auto& Item:States) if (Item.Relative) {
            Change(Item,Item.FrameDelta,""); Item.FrameDelta={};
        }
    }
    void SamplePhysics() {
        for (auto& Item:States) { Item.PhysicsSample=Item.Relative?Item.PhysicsDelta:Item.Current; if (Item.Relative) Item.PhysicsDelta={}; }
    }

private:
    std::vector<State> States;
    std::vector<Row> Rows;
    std::vector<Transition> Changes;
    std::array<bool,PhysicalSlots> Down{}, Eligible{};
    std::array<Value,PhysicalSlots> Continuous{}, PreviousContinuous{};
    std::array<bool,PhysicalSlots> ContinuousBlocked{};
    size_t EvaluatedBindings=0;
    uint64_t Revision=0;

    static double Length(Value V) { return std::hypot(V.X,V.Y); }
    static Value BoundedDelta(Value V) {
        V.X=(std::max)(-32768.0,(std::min)(32768.0,V.X)); V.Y=(std::max)(-32768.0,(std::min)(32768.0,V.Y)); return V;
    }
    void Change(State& Item, Value Next, const char* Reason) {
        if (!(Item.Current==Next)) { Changes.push_back({Item.Definition.Id,Item.Definition.Type,Item.Current,Next,Reason}); Item.Current=Next; }
    }

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
        std::array<Value,MaximumActions> Physics{};
        std::array<uint64_t,PhysicalSlots> Winners{};
        std::array<const char*,MaximumActions> Cancelled{};
        for (size_t Index=0;Index<States.size();++Index) if (States[Index].Relative && !Reason[0]) {
            Values[Index]=EventSlot==PointerSlot?States[Index].FrameDelta:States[Index].Current;
            Physics[Index]=States[Index].PhysicsDelta;
        }
        for (auto& Item : Rows) {
            ++EvaluatedBindings;
            const auto& Definition=Item.Definition; const auto& Action=States[Item.ActionIndex];
            const bool Enabled=Definition.Enabled && Action.Definition.Enabled && Action.Scope.Enabled;
            const bool Pad=Definition.Type==GamepadButton || Definition.Type==GamepadStick;
            const int First=Pad && Definition.Device<0?0:Definition.Device;
            const int Last=Pad && Definition.Device<0?MaximumDevices-1:First;
            bool Active=false;
            for (int Device=First;Device<=Last;++Device) {
                const int Physical=Slot(Definition.Type,Definition.Code,Device<0?0:Device);
                const uint16_t Bit=uint16_t(1)<<(Pad?Device:0);
                const bool WasAdmitted=(Item.Admitted&Bit)!=0;
                const bool ChordHeld=Chord(Definition);
                const bool Analog=Definition.Type==GamepadStick, Pointer=Definition.Type==MouseMotion;
                const double Magnitude=Analog?Length(Continuous[Physical]):0;
                if (Analog && EventSlot==Physical && Magnitude<=Definition.Deadzone && !Processed) {
                    ContinuousBlocked[Physical]=false; Item.Armed|=Bit;
                }
                const bool Held=Analog?Magnitude>Definition.Deadzone && !ContinuousBlocked[Physical]:Pointer?EventSlot==PointerSlot && !Processed:Eligible[Physical];
                const bool Matched=Enabled && Held && ChordHeld;
                const bool Suppressed=Matched && Winners[Physical] && Winners[Physical]!=Action.Scope.Id;
                if (Pointer) {
                    if (!Enabled || !ChordHeld) {
                        Values[Item.ActionIndex]={}; Physics[Item.ActionIndex]={};
                        if (Action.Current.Down()) Cancelled[Item.ActionIndex]=!Enabled?"Disabled":"ChordLost";
                    } else if (Matched && !Suppressed) {
                        Values[Item.ActionIndex].X+=Continuous[Physical].X*Definition.Scale;
                        Values[Item.ActionIndex].Y+=Continuous[Physical].Y*Definition.Scale;
                        Physics[Item.ActionIndex].X+=Continuous[Physical].X*Definition.Scale;
                        Physics[Item.ActionIndex].Y+=Continuous[Physical].Y*Definition.Scale;
                    }
                    if (Matched && !Suppressed && (Action.Scope.Consume || Definition.Consume)) Winners[Physical]=Action.Scope.Id;
                    continue;
                }
                if (!Matched || Suppressed || (Processed && EventSlot==Physical)) Item.Admitted &= ~Bit;
                else if (EventSlot==Physical && (Analog?bool(Item.Armed&Bit) && Length(PreviousContinuous[Physical])<=Definition.Deadzone:Fresh)) Item.Admitted |= Bit;
                if (Analog && (Suppressed || !Enabled || !ChordHeld || (Processed && EventSlot==Physical))) Item.Armed &= ~Bit;
                if (WasAdmitted && !(Item.Admitted&Bit)) {
                    if (Reason[0]) Cancelled[Item.ActionIndex]=Reason;
                    else if (Suppressed) Cancelled[Item.ActionIndex]="Suppressed";
                    else if (!Enabled) Cancelled[Item.ActionIndex]="Disabled";
                    else if (!ChordHeld) Cancelled[Item.ActionIndex]="ChordLost";
                }
                if (Matched && !Suppressed && (Action.Scope.Consume || Definition.Consume)) Winners[Physical]=Action.Scope.Id;
                if (Analog && (Item.Admitted&Bit)) {
                    double Amount=((std::min)(1.0,Magnitude)-Definition.Deadzone)/(1-Definition.Deadzone)*Definition.Scale/Magnitude;
                    Values[Item.ActionIndex].X+=Continuous[Physical].X*Amount; Values[Item.ActionIndex].Y+=Continuous[Physical].Y*Amount;
                } else if (!Analog) Active |= (Item.Admitted&Bit)!=0;
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
            else if (Item.Relative) {
                Next=BoundedDelta(Next); Item.PhysicsDelta=BoundedDelta(Physics[Index]);
                if (EventSlot==PointerSlot || Reason[0] || Cancelled[Index]) Item.FrameDelta=Next;
            } else if (Item.Definition.Type==Vector) {
                const double Length=std::hypot(Next.X,Next.Y);
                if (Length>1) { Next.X/=Length; Next.Y/=Length; }
            }
            if (!(Item.Current==Next)) {
                const bool Retired=Item.Current.Down() && !Next.Down() && Reason[0];
                const char* Cancellation=Cancelled[Index]?Cancelled[Index]:(Retired?Reason:"");
                Change(Item,Next,Cancellation);
            }
        }
    }
};
#endif
