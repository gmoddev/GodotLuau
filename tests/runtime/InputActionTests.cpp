#include "gl_input_graph.h"
#include <iostream>
#include <stdexcept>

static void Check(bool Value, const char* Name) {
    if (!Value) throw std::runtime_error(Name);
    std::cout << "[Input:Graph] PASS " << Name << '\n';
}
static GLInputGraph::Value Value(const GLInputGraph& Graph, uint64_t Id) {
    for (const auto& Item:Graph.GetStates()) if (Item.Definition.Id==Id) return Item.Current;
    throw std::runtime_error("Missing action");
}
int main() {
    try {
        GLInputGraph Graph;
        std::vector<GLInputGraph::Context> Contexts={{1,1,0,true,true},{2,1,10,false,true}};
        std::vector<GLInputGraph::Action> Actions={{10,1,1,0,true},{11,1,1,0,true},{20,1,2,0,true}};
        std::vector<GLInputGraph::Binding> Bindings(3);
        for (int I=0;I<3;++I) { Bindings[I].Id=100+I; Bindings[I].Revision=1; Bindings[I].ActionId=Actions[I].Id; Bindings[I].Code=32; }
        Check(Graph.Compile(Contexts,Actions,Bindings),"compile digital definitions");
        Graph.Event(0,32,0,true,false);
        Check(Value(Graph,10).Down() && Value(Graph,11).Down() && !Value(Graph,20).Down(),"same-context cofire and disabled context");
        Contexts[1].Enabled=true; ++Contexts[1].Revision; Graph.Compile(Contexts,Actions,Bindings);
        Check(!Value(Graph,10).Down() && !Value(Graph,20).Down(),"context takeover cancels without synthetic press");
        Graph.Event(0,32,0,false,true); Graph.Event(0,32,0,true,false);
        Check(Value(Graph,20).Down() && !Value(Graph,10).Down(),"higher context consumes fresh primary");
        Graph.Event(0,32,0,false,true);
        Check(!Value(Graph,20).Down() && Graph.GetChanges().size()==1 && Graph.GetChanges()[0].Reason[0],"GUI-consumed release cancels held state");
        Graph.Event(0,32,0,true,true); Check(!Value(Graph,20).Down(),"GUI-consumed press has no admission");
        Graph.Cancel("FocusLost"); Graph.Event(0,32,0,true,false,true);
        Check(!Value(Graph,20).Down(),"focus loss and echo cannot resurrect input");
        Graph.Event(0,32,0,false,false); Graph.Event(0,32,0,true,false);
        Bindings[2].Code=70; ++Bindings[2].Revision; Graph.Compile(Contexts,Actions,Bindings);
        Check(!Value(Graph,20).Down(),"runtime rebind retires old admission");
        Bindings[2].Modifiers[0]=304; ++Bindings[2].Revision; Graph.Compile(Contexts,Actions,Bindings);
        Graph.Event(0,70,0,true,false); Graph.Event(0,304,0,true,false);
        Check(!Value(Graph,20).Down(),"modifier after primary is not a fresh chord");
        Graph.Event(0,70,0,false,false); Graph.Event(0,70,0,true,false);
        Check(Value(Graph,20).Down(),"modifier before primary admits chord");
        Graph.Event(0,304,0,false,false); Check(!Value(Graph,20).Down(),"modifier loss neutralizes chord");
        auto Revision=Graph.GetRevision(); Bindings[2].Scale=std::nan("");
        Check(!Graph.Compile(Contexts,Actions,Bindings) && Graph.GetRevision()==Revision,"nonfinite definition fails atomically");
        Bindings[2].Scale=1; Bindings[2].Type=2; Bindings[2].Code=0; Bindings[2].Device=-1; Bindings[2].Modifiers.fill(0); ++Bindings[2].Revision;
        Graph.Compile(Contexts,Actions,Bindings); Graph.Event(2,0,3,true,false);
        Check(Value(Graph,20).Down(),"any-device gamepad button");
        Graph.Disconnect(2); Check(Value(Graph,20).Down(),"unrelated disconnect preserves active device");
        Graph.Disconnect(3); Check(!Value(Graph,20).Down(),"device disconnect neutralizes active button");
        Actions[2].Type=2; ++Actions[2].Revision; Bindings[2].X=1; Bindings[2].Y=1;
        Graph.Compile(Contexts,Actions,Bindings); Graph.Event(2,0,3,false,false); Graph.Event(2,0,3,true,false);
        auto Vector=Value(Graph,20);
        Check(std::abs(std::hypot(Vector.X,Vector.Y)-1)<1e-12,"Vector2 contributions clamp to unit length");
        GLInputGraph Analog;
        std::vector<GLInputGraph::Action> AnalogActions={{10,1,1,2,true},{11,1,1,2,true}};
        std::vector<GLInputGraph::Binding> AnalogBindings(2);
        AnalogBindings[0].Id=100; AnalogBindings[0].Revision=1; AnalogBindings[0].ActionId=10; AnalogBindings[0].Type=3;
        AnalogBindings[1].Id=101; AnalogBindings[1].Revision=1; AnalogBindings[1].ActionId=11; AnalogBindings[1].Type=4;
        Check(Analog.Compile({{1,1,0,true,true}},AnalogActions,AnalogBindings),"compile stick and relative definitions");
        Analog.Stick(0,0,0.1,0,false); Check(!Value(Analog,10).Down(),"stick radial deadzone");
        Analog.Stick(0,0,0.6,0,false); Check(std::abs(Value(Analog,10).X-0.5)<1e-12,"stick rescaled radial output");
        Analog.Cancel("FocusLost"); Analog.Stick(0,0,0.8,0,false);
        Check(!Value(Analog,10).Down(),"held stick cannot reactivate after focus loss");
        Analog.Stick(0,0,0,0,false); Analog.Stick(0,0,0.6,0,false);
        Check(Value(Analog,10).Down(),"stick neutral then crossing admits again");
        Analog.Disconnect(0); Check(!Value(Analog,10).Down(),"stick disconnect neutralizes output");
        Analog.Motion(4,-2,false); Analog.Motion(1,-3,false);
        Check(Value(Analog,11)==GLInputGraph::Value{5,-5},"relative motion sums without unit normalization");
        Analog.SampleFrame(); Analog.Motion(2,1,false); Analog.SamplePhysics();
        bool Physics=false; for (const auto& Item:Analog.GetStates()) if (Item.Definition.Id==11) Physics=Item.PhysicsSample==GLInputGraph::Value{7,-4};
        Check(Physics && Value(Analog,11)==GLInputGraph::Value{2,1},"frame rotation does not drain physics accumulation");
        Analog.SamplePhysics(); for (const auto& Item:Analog.GetStates()) if (Item.Definition.Id==11) Physics=!Item.PhysicsSample.Down();
        Check(Physics && Value(Analog,11).Down(),"physics rotation does not drain frame accumulation");
        Analog.SampleFrame(); Analog.SampleFrame(); Check(!Value(Analog,11).Down(),"idle frame sample becomes neutral");
        Check(!Analog.Motion(std::nan(""),0,false) && !Analog.Stick(16,0,1,0,false),"nonfinite and unsupported device rejection");
        Analog.Motion(10,20,true); Check(!Value(Analog,11).Down(),"GUI-consumed relative motion rejected");
        Contexts.resize(GLInputGraph::MaximumContexts+1); Revision=Graph.GetRevision();
        Check(!Graph.Compile(Contexts,Actions,Bindings) && Graph.GetRevision()==Revision,"bounded context admission");
        return 0;
    } catch (const std::exception& Error) { std::cerr << "[Input:Graph] FAIL " << Error.what() << '\n'; return 1; }
}
