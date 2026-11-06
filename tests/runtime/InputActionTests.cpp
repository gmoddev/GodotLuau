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
        Contexts.resize(GLInputGraph::MaximumContexts+1); Revision=Graph.GetRevision();
        Check(!Graph.Compile(Contexts,Actions,Bindings) && Graph.GetRevision()==Revision,"bounded context admission");
        return 0;
    } catch (const std::exception& Error) { std::cerr << "[Input:Graph] FAIL " << Error.what() << '\n'; return 1; }
}
