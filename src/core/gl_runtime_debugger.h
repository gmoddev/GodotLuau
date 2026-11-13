#pragma once
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/string.hpp>
class GLDomainHost;
class GLExecutionDomain;
bool GLRuntimeDebuggerAvailable();
godot::Error GLReloadLuauScripts(const godot::Array& Scripts);
void GLConfigureRuntimeDebugger(GLDomainHost& Host, GLExecutionDomain& Domain);
void GLRuntimeDebuggerTick(GLDomainHost& Host);
void GLRuntimeDebuggerShutdown(GLDomainHost& Host);
bool GLCaptureDebuggerCommand(GLDomainHost& Host, const godot::String& Message, const godot::Array& Data);
