# GL-054 native development contract

Implementation on `feature/gl-054-engine-production`; qualification status and
identities are in the [campaign journal](gl-054-engine-development.md). This is a
feature-branch extension of ADR-015/016/017, not an integrated-main guarantee.

## Collections and effects

Metadata typed arrays preserve their exact engine element type. Primitive inputs
require dense sequences and validate each element; object/resource inputs require
the exact live executing SceneScope owner for every handle. Inputs reject holes,
named keys, invalid elements and more than 1,024 entries before invocation.
Resource handles returned by queries remain immutable. Node-array query results
are dense frozen projections of live owned nodes; unrelated native bodies are
omitted. Native boolean overlap queries describe the engine query, while returned
handle collections describe that authorized projection. No world-wide identity
capability is granted by collision observations.

Nested general Variant dictionaries still contain only bounded pure values;
raw Object, RID, Callable and Signal values remain unsupported. Direct references
and typed collections use the existing authority-aware dispatcher, not the pure
converter. Typed-array/StringName outputs use Luau strings with metadata retaining
the native element distinction. New vector/path/empty-array defaults are parsed
from a narrow verified grammar, never executed as code.

New area, shape-cast, navigation, image, layered-texture, particles, lights, decals,
tile-pattern and CodeEdit APIs remain exact policy selections. Read the generated
catalog for method names, receiver inheritance, arguments and bounds; construction
alone does not establish a complete engine family. Shape force-updates and all
navigation-agent methods require a runtime physics callback and a synchronized
map. Unsupported lightweight hosts cannot qualify positive navigation behavior.

Images accept exact 1..16 by 1..16 RGB8/RGBA8 pixel data without mipmaps. Texture
uploads require initialized non-mipmapped images, at most 1,048,576 pixels; updates
must preserve dimensions/format. Layered uploads require 1..16 matching images
with the same total pixel bound. These checks precede the engine mutation. CPU
particles start inactive; enabling emission in EditorPreview is denied. Existing
node/resource/owner budgets and retirement remain unchanged.

## Error inspection

An active Godot editor debugger selects pinned Luau full debug information for
user chunks and project modules when their existing domain is created. Ordinary
runs retain the prior line/name-only compilation. EditorPreview also uses full
information. Optimization, scheduler, memory/deadline policies and ownership do
not change.

The existing `godotluau:runtime_error` editor message retains its first three
string fields and optionally adds a schema-1 dictionary. It copies at most 16
frames and eight locals per frame, with 128-byte names, 1,024-byte source names
and 256-byte string values. Primitive values are copied; tables, functions,
threads and native userdata are opaque. No metamethod, object property, registry
reference, source evaluation or recursive table traversal is performed. The
message labels Server, Client or EditorPreview and the owner generation. Memory
failure skips VM inspection. Snapshots remain historical after owner retirement.

The Luau Authoring panel displays copied frames/locals. Explicit frame activation
opens a project-local Luau source; runtime failure itself does not change focus or
show a dialog. Existing three-field messages remain accepted. Diagnostic readers
receive independent copies.

This is error-time inspection, not a paused debugger. Breakpoints, stepping,
resuming a suspended frame, live table/object evaluation and upvalue editing are
not implemented. Godot's ScriptLanguage stack hook remains empty because there is
no safely suspended domain/frame to advertise. A live debugger would require an
explicit scheduler suspension/ownership contract and coordinated Godot debugger
session control; this campaign does not fake that contract with a stored trace.
