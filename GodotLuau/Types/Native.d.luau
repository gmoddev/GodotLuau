-- Generated approved native definitions. Load as a definitions file, never require it.
-- Policy SHA256: 73e7ebf557e89a25b8b48fd81d07e7b15ff0774f86ee4bba6b2c85ed67620cd6
export type NativeVector2 = { X: number, Y: number }
declare class NativeVector3
    X: number
    Y: number
    Z: number
    Lerp: (self: NativeVector3, Other: NativeVector3, Alpha: number) -> NativeVector3
end
declare class NativeColor3
    R: number
    G: number
    B: number
end
declare Vector3: { new: (number, number, number) -> NativeVector3 }
declare Vector2: { new: (number, number) -> NativeVector2 }
declare Color3: { new: (number, number, number) -> NativeColor3 }
export type NativeConnection = { Disconnect: (self: NativeConnection) -> (), Connected: boolean }
export type NativeVector2i = {X: number, Y: number}
export type NativeVector3i = {X: number, Y: number, Z: number}
export type NativeVector4 = {X: number, Y: number, Z: number, W: number}
export type NativeVector4i = NativeVector4
export type NativeQuaternion = NativeVector4
export type NativeColor4 = {R: number, G: number, B: number, A: number}
export type NativeRect2 = {Position: NativeVector2, Size: NativeVector2}
export type NativeRect2i = {Position: NativeVector2i, Size: NativeVector2i}
export type NativeAABB = {Position: NativeVector3, Size: NativeVector3}
export type NativePlane = {Normal: NativeVector3, D: number}
export type NativeBasis = {X: NativeVector3, Y: NativeVector3, Z: NativeVector3}
export type NativeTransform2D = {X: NativeVector2, Y: NativeVector2, Origin: NativeVector2}
export type NativeTransform3D = {Basis: NativeBasis, Origin: NativeVector3}
export type NativeVariant = nil | boolean | number | string | NativeVector3 | NativeColor3 | NativeVector2 | NativeVector4 | NativeColor4 | NativeRect2 | NativeAABB | NativePlane | NativeBasis | NativeTransform2D | NativeTransform3D | {NativeVariant} | {[string]: NativeVariant}
declare class NativeObject
end
declare class NativeNode extends NativeObject
    Name: string
    Parent: NativeNode?
    ClassName: string
    Destroy: (self: NativeNode) -> ()
    IsA: (self: NativeNode, Class: string) -> boolean
    FindFirstChild: (self: NativeNode, Name: string, Recursive: boolean?) -> NativeNode?
    GetChildren: (self: NativeNode) -> {NativeNode}
    GetDescendants: (self: NativeNode) -> {NativeNode}
end
declare class NativeRefCounted extends NativeObject
end
declare class NativeAnimationMixer extends NativeNode
end
declare class NativeAudioStreamPlayer extends NativeNode
    Stream: NativeAudioStream?
    VolumeDb: number
    PitchScale: number
end
declare class NativeCanvasItem extends NativeNode
    Visible: boolean
    Modulate: NativeColor3
    ModulateRGBA: NativeColor4
    SelfModulateRGBA: NativeColor4
end
declare class NativeCanvasLayer extends NativeNode
    Layer: number
end
declare class NativeNavigationAgent3D extends NativeNode
    TargetPosition: NativeVector3
    NavigationLayers: number
    PathDesiredDistance: number
    TargetDesiredDistance: number
    PathMaxDistance: number
end
declare class NativeNode3D extends NativeNode
    Position: NativeVector3
    RotationDegrees: NativeVector3
    Scale: NativeVector3
    Visible: boolean
end
declare class NativeResource extends NativeRefCounted
end
declare class MutableNativeResource extends NativeResource
end
declare class NativeTimer extends NativeNode
    WaitTime: number
    OneShot: boolean
    Autostart: boolean
    Paused: boolean
    ProcessCallback: number
    TimeLeft: number
end
declare class NativeWorldEnvironment extends NativeNode
    Environment: NativeEnvironment?
end
declare class NativeAnimation extends NativeResource
end
declare class MutableNativeAnimation extends NativeAnimation
end
declare class NativeAnimationLibrary extends NativeResource
end
declare class MutableNativeAnimationLibrary extends NativeAnimationLibrary
end
declare class NativeAnimationPlayer extends NativeAnimationMixer
    SpeedScale: number
    CurrentAnimationPosition: number
    CurrentAnimationLength: number
end
declare class NativeAudioStream extends NativeResource
end
declare class MutableNativeAudioStream extends NativeAudioStream
end
declare class NativeAudioStreamPlayer3D extends NativeNode3D
    Stream: NativeAudioStream?
    VolumeDb: number
    PitchScale: number
    Autoplay: boolean
    StreamPaused: boolean
end
declare class NativeCamera3D extends NativeNode3D
    Fov: number
    Near: number
    Far: number
end
declare class NativeCollisionObject3D extends NativeNode3D
    CollisionLayer: number
    CollisionMask: number
end
declare class NativeCollisionShape3D extends NativeNode3D
    Shape: NativeShape3D?
    Disabled: boolean
end
declare class NativeControl extends NativeCanvasItem
    Position: NativeVector2
    Size: NativeVector2
    MinSize: NativeVector2
    MouseFilter: number
    FontSize: number
    Font: NativeFont?
    OffsetLeft: number
    OffsetRight: number
    OffsetTop: number
    OffsetBottom: number
    AnchorLeft: number
    AnchorRight: number
    AnchorTop: number
    AnchorBottom: number
    GrowHorizontal: number
    GrowVertical: number
    FocusMode: number
    LayoutMode: number
    ClipContents: boolean
    Theme: NativeTheme?
    TooltipText: string
end
declare class NativeEnvironment extends NativeResource
end
declare class MutableNativeEnvironment extends NativeEnvironment
end
declare class NativeFont extends NativeResource
end
declare class MutableNativeFont extends NativeFont
end
declare class NativeGradient extends NativeResource
end
declare class MutableNativeGradient extends NativeGradient
end
declare class NativeMaterial extends NativeResource
end
declare class MutableNativeMaterial extends NativeMaterial
end
declare class NativeMesh extends NativeResource
end
declare class MutableNativeMesh extends NativeMesh
end
declare class NativeMultiMesh extends NativeResource
end
declare class MutableNativeMultiMesh extends NativeMultiMesh
end
declare class NativeNavigationMesh extends NativeResource
end
declare class MutableNativeNavigationMesh extends NativeNavigationMesh
end
declare class NativeNavigationRegion3D extends NativeNode3D
    NavigationMesh: NativeNavigationMesh?
    Enabled: boolean
    NavigationLayers: number
end
declare class NativeNode2D extends NativeCanvasItem
    Position: NativeVector2
    RotationDegrees: number
    Scale: NativeVector2
    GlobalPosition: NativeVector2
    GlobalRotation: number
    ZIndex: number
    YSortEnabled: boolean
end
declare class NativePackedScene extends NativeResource
end
declare class MutableNativePackedScene extends NativePackedScene
end
declare class NativePhysicsMaterial extends NativeResource
end
declare class MutableNativePhysicsMaterial extends NativePhysicsMaterial
end
declare class NativeRayCast3D extends NativeNode3D
    Enabled: boolean
    ExcludeParent: boolean
    HitFromInside: boolean
    CollideWithAreas: boolean
    CollideWithBodies: boolean
    CollisionMask: number
    TargetPosition: NativeVector3
end
declare class NativeShader extends NativeResource
end
declare class MutableNativeShader extends NativeShader
end
declare class NativeShape2D extends NativeResource
end
declare class MutableNativeShape2D extends NativeShape2D
end
declare class NativeShape3D extends NativeResource
end
declare class MutableNativeShape3D extends NativeShape3D
end
declare class NativeSkeleton3D extends NativeNode3D
end
declare class NativeSpriteFrames extends NativeResource
end
declare class MutableNativeSpriteFrames extends NativeSpriteFrames
end
declare class NativeStyleBox extends NativeResource
end
declare class MutableNativeStyleBox extends NativeStyleBox
end
declare class NativeTexture extends NativeResource
end
declare class MutableNativeTexture extends NativeTexture
end
declare class NativeTheme extends NativeResource
end
declare class MutableNativeTheme extends NativeTheme
end
declare class NativeVisualInstance3D extends NativeNode3D
end
declare class NativeAnimatedSprite2D extends NativeNode2D
    SpriteFrames: NativeSpriteFrames?
    Animation: string
    SpeedScale: number
    Centered: boolean
    Offset: NativeVector2
    FlipH: boolean
    FlipV: boolean
    Frame: number
    FrameProgress: number
end
declare class NativeArrayMesh extends NativeMesh
end
declare class MutableNativeArrayMesh extends NativeArrayMesh
end
declare class NativeAudioStreamPlayer2D extends NativeNode2D
    Stream: NativeAudioStream?
    VolumeDb: number
    PitchScale: number
    Autoplay: boolean
    StreamPaused: boolean
end
declare class NativeBaseButton extends NativeControl
    Disabled: boolean
    ToggleMode: boolean
    ButtonPressed: boolean
end
declare class NativeBaseMaterial3D extends NativeMaterial
end
declare class MutableNativeBaseMaterial3D extends NativeBaseMaterial3D
end
declare class NativeBoxShape3D extends NativeShape3D
end
declare class MutableNativeBoxShape3D extends NativeBoxShape3D
end
declare class NativeCamera2D extends NativeNode2D
    Enabled: boolean
    Zoom: NativeVector2
    Offset: NativeVector2
    PositionSmoothingEnabled: boolean
    PositionSmoothingSpeed: number
end
declare class NativeCapsuleShape2D extends NativeShape2D
end
declare class MutableNativeCapsuleShape2D extends NativeCapsuleShape2D
end
declare class NativeCapsuleShape3D extends NativeShape3D
end
declare class MutableNativeCapsuleShape3D extends NativeCapsuleShape3D
end
declare class NativeCircleShape2D extends NativeShape2D
end
declare class MutableNativeCircleShape2D extends NativeCircleShape2D
end
declare class NativeCollisionObject2D extends NativeNode2D
    CollisionLayer: number
    CollisionMask: number
    InputPickable: boolean
end
declare class NativeCollisionShape2D extends NativeNode2D
    Shape: NativeShape2D?
    Disabled: boolean
    OneWayCollision: boolean
end
declare class NativeColorRect extends NativeControl
    Color: NativeColor3
end
declare class NativeContainer extends NativeControl
end
declare class NativeCylinderShape3D extends NativeShape3D
end
declare class MutableNativeCylinderShape3D extends NativeCylinderShape3D
end
declare class NativeGeometryInstance3D extends NativeVisualInstance3D
    Material: NativeMaterial?
end
declare class NativeItemList extends NativeControl
    SelectMode: number
    AllowReselect: boolean
    FixedColumnWidth: number
    MaxColumns: number
    IconMode: number
    FixedIconSize: NativeVector2i
    ItemCount: number
end
declare class NativeLabel extends NativeControl
    Text: string
end
declare class NativeLight3D extends NativeVisualInstance3D
    Color: NativeColor3
    Energy: number
    ShadowEnabled: boolean
end
declare class NativeLineEdit extends NativeControl
    Text: string
    PlaceholderText: string
end
declare class NativeMultiMeshInstance2D extends NativeNode2D
    Multimesh: NativeMultiMesh?
end
declare class NativePanel extends NativeControl
end
declare class NativePhysicsBody3D extends NativeCollisionObject3D
end
declare class NativePrimitiveMesh extends NativeMesh
end
declare class MutableNativePrimitiveMesh extends NativePrimitiveMesh
end
declare class NativeRange extends NativeControl
    MinValue: number
    MaxValue: number
    Value: number
    Step: number
end
declare class NativeRayCast2D extends NativeNode2D
    Enabled: boolean
    ExcludeParent: boolean
    HitFromInside: boolean
    CollideWithAreas: boolean
    CollideWithBodies: boolean
    CollisionMask: number
    TargetPosition: NativeVector2
end
declare class NativeRectangleShape2D extends NativeShape2D
end
declare class MutableNativeRectangleShape2D extends NativeRectangleShape2D
end
declare class NativeRichTextLabel extends NativeControl
    Text: string
    BbcodeEnabled: boolean
    FitContent: boolean
    ScrollActive: boolean
end
declare class NativeSegmentShape2D extends NativeShape2D
end
declare class MutableNativeSegmentShape2D extends NativeSegmentShape2D
end
declare class NativeSeparator extends NativeControl
end
declare class NativeShaderMaterial extends NativeMaterial
end
declare class MutableNativeShaderMaterial extends NativeShaderMaterial
end
declare class NativeSphereShape3D extends NativeShape3D
end
declare class MutableNativeSphereShape3D extends NativeSphereShape3D
end
declare class NativeSprite2D extends NativeNode2D
    Texture: NativeTexture2D?
    Centered: boolean
    Offset: NativeVector2
    FlipH: boolean
    FlipV: boolean
    Hframes: number
    Vframes: number
    FrameCoords: NativeVector2i
    RegionEnabled: boolean
    RegionRect: NativeRect2
    RegionFilterClipEnabled: boolean
end
declare class NativeStyleBoxEmpty extends NativeStyleBox
end
declare class MutableNativeStyleBoxEmpty extends NativeStyleBoxEmpty
end
declare class NativeStyleBoxFlat extends NativeStyleBox
end
declare class MutableNativeStyleBoxFlat extends NativeStyleBoxFlat
end
declare class NativeStyleBoxLine extends NativeStyleBox
end
declare class MutableNativeStyleBoxLine extends NativeStyleBoxLine
end
declare class NativeTextEdit extends NativeControl
    Text: string
    Editable: boolean
    PlaceholderText: string
    WrapMode: number
end
declare class NativeTexture2D extends NativeTexture
end
declare class MutableNativeTexture2D extends NativeTexture2D
end
declare class NativeTextureRect extends NativeControl
    Texture: NativeTexture2D?
    ExpandMode: number
    StretchMode: number
end
declare class NativeArea2D extends NativeCollisionObject2D
    Monitoring: boolean
    Monitorable: boolean
    Gravity: number
    GravityDirection: NativeVector2
end
declare class NativeAspectRatioContainer extends NativeContainer
    Ratio: number
    StretchMode: number
end
declare class NativeBoxContainer extends NativeContainer
    Separation: number
end
declare class NativeBoxMesh extends NativePrimitiveMesh
end
declare class MutableNativeBoxMesh extends NativeBoxMesh
end
declare class NativeButton extends NativeBaseButton
    Text: string
    Icon: NativeTexture2D?
end
declare class NativeCapsuleMesh extends NativePrimitiveMesh
end
declare class MutableNativeCapsuleMesh extends NativeCapsuleMesh
end
declare class NativeCenterContainer extends NativeContainer
end
declare class NativeCharacterBody3D extends NativePhysicsBody3D
    Velocity: NativeVector3
    UpDirection: NativeVector3
    MaxSlides: number
    FloorMaxAngle: number
    FloorSnapLength: number
    SafeMargin: number
    FloorStopOnSlope: boolean
    FloorConstantSpeed: boolean
    SlideOnCeiling: boolean
end
declare class NativeCylinderMesh extends NativePrimitiveMesh
end
declare class MutableNativeCylinderMesh extends NativeCylinderMesh
end
declare class NativeDirectionalLight3D extends NativeLight3D
end
declare class NativeGradientTexture1D extends NativeTexture2D
end
declare class MutableNativeGradientTexture1D extends NativeGradientTexture1D
end
declare class NativeGradientTexture2D extends NativeTexture2D
end
declare class MutableNativeGradientTexture2D extends NativeGradientTexture2D
end
declare class NativeGridContainer extends NativeContainer
    Columns: number
end
declare class NativeHSeparator extends NativeSeparator
end
declare class NativeLabel3D extends NativeGeometryInstance3D
    Text: string
    Billboard: number
    FontSize: number
    Font: NativeFont?
end
declare class NativeMarginContainer extends NativeContainer
end
declare class NativeMeshInstance3D extends NativeGeometryInstance3D
    Mesh: NativeMesh?
end
declare class NativeMultiMeshInstance3D extends NativeGeometryInstance3D
    Multimesh: NativeMultiMesh?
end
declare class NativeOmniLight3D extends NativeLight3D
    Range: number
end
declare class NativePanelContainer extends NativeContainer
end
declare class NativePhysicsBody2D extends NativeCollisionObject2D
end
declare class NativePlaneMesh extends NativePrimitiveMesh
end
declare class MutableNativePlaneMesh extends NativePlaneMesh
end
declare class NativeProgressBar extends NativeRange
end
declare class NativeRigidBody3D extends NativePhysicsBody3D
    Mass: number
    GravityScale: number
    Freeze: boolean
end
declare class NativeScrollContainer extends NativeContainer
end
declare class NativeSlider extends NativeRange
end
declare class NativeSphereMesh extends NativePrimitiveMesh
end
declare class MutableNativeSphereMesh extends NativeSphereMesh
end
declare class NativeSplitContainer extends NativeContainer
end
declare class NativeSpotLight3D extends NativeLight3D
    Range: number
end
declare class NativeSpriteBase3D extends NativeGeometryInstance3D
    PixelSize: number
end
declare class NativeStandardMaterial3D extends NativeBaseMaterial3D
end
declare class MutableNativeStandardMaterial3D extends NativeStandardMaterial3D
end
declare class NativeStaticBody3D extends NativePhysicsBody3D
end
declare class NativeTabContainer extends NativeContainer
    CurrentTab: number
    TabsVisible: boolean
end
declare class NativeTextureProgressBar extends NativeRange
    TextureUnder: NativeTexture2D?
    TextureOver: NativeTexture2D?
    TextureProgress: NativeTexture2D?
    FillMode: number
    TintUnder: NativeColor4
    TintOver: NativeColor4
    TintProgress: NativeColor4
end
declare class NativeVSeparator extends NativeSeparator
end
declare class NativeCharacterBody2D extends NativePhysicsBody2D
    Velocity: NativeVector2
    UpDirection: NativeVector2
    MaxSlides: number
    FloorMaxAngle: number
    FloorSnapLength: number
    SafeMargin: number
    FloorStopOnSlope: boolean
    FloorConstantSpeed: boolean
    SlideOnCeiling: boolean
end
declare class NativeCheckBox extends NativeButton
end
declare class NativeCheckButton extends NativeButton
end
declare class NativeHBoxContainer extends NativeBoxContainer
end
declare class NativeHSlider extends NativeSlider
end
declare class NativeHSplitContainer extends NativeSplitContainer
end
declare class NativeQuadMesh extends NativePlaneMesh
end
declare class MutableNativeQuadMesh extends NativeQuadMesh
end
declare class NativeRigidBody2D extends NativePhysicsBody2D
    Mass: number
    PhysicsMaterialOverride: NativePhysicsMaterial?
    GravityScale: number
    LinearVelocity: NativeVector2
    AngularVelocity: number
    LinearDamp: number
    AngularDamp: number
    LockRotation: boolean
    Freeze: boolean
    ContactMonitor: boolean
    MaxContactsReported: number
    Sleeping: boolean
end
declare class NativeSoftBody3D extends NativeMeshInstance3D
    Mesh: NativeArrayMesh?
    CollisionLayer: number
    CollisionMask: number
    SimulationPrecision: number
    TotalMass: number
end
declare class NativeSprite3D extends NativeSpriteBase3D
    Texture: NativeTexture2D?
end
declare class NativeStaticBody2D extends NativePhysicsBody2D
    PhysicsMaterialOverride: NativePhysicsMaterial?
    ConstantLinearVelocity: NativeVector2
    ConstantAngularVelocity: number
end
declare class NativeVBoxContainer extends NativeBoxContainer
end
declare class NativeVSlider extends NativeSlider
end
declare class NativeVSplitContainer extends NativeSplitContainer
end
export type NativeAnimatedSprite2DProperties = {
    Name: (string)?,
    Position: (NativeVector2)?,
    RotationDegrees: (number)?,
    Scale: (NativeVector2)?,
    Visible: (boolean)?,
    Modulate: (NativeColor3)?,
    GlobalPosition: (NativeVector2)?,
    GlobalRotation: (number)?,
    ZIndex: (number)?,
    YSortEnabled: (boolean)?,
    ModulateRGBA: (NativeColor4)?,
    SelfModulateRGBA: (NativeColor4)?,
    SpriteFrames: (NativeSpriteFrames?)?,
    Animation: (string)?,
    SpeedScale: (number)?,
    Centered: (boolean)?,
    Offset: (NativeVector2)?,
    FlipH: (boolean)?,
    FlipV: (boolean)?,
    Frame: nil,
    FrameProgress: nil,
}
export type NativeAnimationProperties = {
    Length: (number)?,
    LoopMode: (number)?,
}
export type NativeAnimationLibraryProperties = {
}
export type NativeAnimationMixerProperties = {
    Name: (string)?,
}
export type NativeAnimationPlayerProperties = {
    Name: (string)?,
    SpeedScale: (number)?,
    CurrentAnimationPosition: nil,
    CurrentAnimationLength: nil,
}
export type NativeArea2DProperties = {
    Name: (string)?,
    Position: (NativeVector2)?,
    RotationDegrees: (number)?,
    Scale: (NativeVector2)?,
    Visible: (boolean)?,
    Modulate: (NativeColor3)?,
    GlobalPosition: (NativeVector2)?,
    GlobalRotation: (number)?,
    ZIndex: (number)?,
    YSortEnabled: (boolean)?,
    ModulateRGBA: (NativeColor4)?,
    SelfModulateRGBA: (NativeColor4)?,
    CollisionLayer: (number)?,
    CollisionMask: (number)?,
    InputPickable: (boolean)?,
    Monitoring: (boolean)?,
    Monitorable: (boolean)?,
    Gravity: (number)?,
    GravityDirection: (NativeVector2)?,
}
export type NativeArrayMeshProperties = {
}
export type NativeAspectRatioContainerProperties = {
    Name: (string)?,
    Visible: (boolean)?,
    Position: (NativeVector2)?,
    Size: (NativeVector2)?,
    MinSize: (NativeVector2)?,
    MouseFilter: (number)?,
    Modulate: (NativeColor3)?,
    FontSize: (number)?,
    FullRect: (boolean)?,
    Font: (NativeFont?)?,
    OffsetLeft: (number)?,
    OffsetRight: (number)?,
    OffsetTop: (number)?,
    OffsetBottom: (number)?,
    AnchorLeft: (number)?,
    AnchorRight: (number)?,
    AnchorTop: (number)?,
    AnchorBottom: (number)?,
    GrowHorizontal: (number)?,
    GrowVertical: (number)?,
    FocusMode: (number)?,
    LayoutMode: (number)?,
    ClipContents: (boolean)?,
    ModulateRGBA: (NativeColor4)?,
    SelfModulateRGBA: (NativeColor4)?,
    Theme: (NativeTheme?)?,
    TooltipText: (string)?,
    Ratio: (number)?,
    StretchMode: (number)?,
}
export type NativeAudioStreamProperties = {
}
export type NativeAudioStreamPlayerProperties = {
    Name: (string)?,
    Stream: (NativeAudioStream?)?,
    VolumeDb: (number)?,
    PitchScale: (number)?,
}
export type NativeAudioStreamPlayer2DProperties = {
    Name: (string)?,
    Position: (NativeVector2)?,
    RotationDegrees: (number)?,
    Scale: (NativeVector2)?,
    Visible: (boolean)?,
    Modulate: (NativeColor3)?,
    GlobalPosition: (NativeVector2)?,
    GlobalRotation: (number)?,
    ZIndex: (number)?,
    YSortEnabled: (boolean)?,
    ModulateRGBA: (NativeColor4)?,
    SelfModulateRGBA: (NativeColor4)?,
    Stream: (NativeAudioStream?)?,
    VolumeDb: (number)?,
    PitchScale: (number)?,
    Autoplay: (boolean)?,
    StreamPaused: (boolean)?,
}
export type NativeAudioStreamPlayer3DProperties = {
    Name: (string)?,
    Position: (NativeVector3)?,
    RotationDegrees: (NativeVector3)?,
    Scale: (NativeVector3)?,
    Visible: (boolean)?,
    Stream: (NativeAudioStream?)?,
    VolumeDb: (number)?,
    PitchScale: (number)?,
    Autoplay: (boolean)?,
    StreamPaused: (boolean)?,
}
export type NativeBaseButtonProperties = {
    Name: (string)?,
    Visible: (boolean)?,
    Position: (NativeVector2)?,
    Size: (NativeVector2)?,
    MinSize: (NativeVector2)?,
    MouseFilter: (number)?,
    Modulate: (NativeColor3)?,
    FontSize: (number)?,
    FullRect: (boolean)?,
    Font: (NativeFont?)?,
    Disabled: (boolean)?,
    ToggleMode: (boolean)?,
    ButtonPressed: (boolean)?,
    OffsetLeft: (number)?,
    OffsetRight: (number)?,
    OffsetTop: (number)?,
    OffsetBottom: (number)?,
    AnchorLeft: (number)?,
    AnchorRight: (number)?,
    AnchorTop: (number)?,
    AnchorBottom: (number)?,
    GrowHorizontal: (number)?,
    GrowVertical: (number)?,
    FocusMode: (number)?,
    LayoutMode: (number)?,
    ClipContents: (boolean)?,
    ModulateRGBA: (NativeColor4)?,
    SelfModulateRGBA: (NativeColor4)?,
    Theme: (NativeTheme?)?,
    TooltipText: (string)?,
}
export type NativeBaseMaterial3DProperties = {
    AlbedoTexture: (NativeTexture2D?)?,
    Metallic: (number)?,
    Transparency: (number)?,
}
export type NativeBoxContainerProperties = {
    Name: (string)?,
    Visible: (boolean)?,
    Position: (NativeVector2)?,
    Size: (NativeVector2)?,
    MinSize: (NativeVector2)?,
    MouseFilter: (number)?,
    Modulate: (NativeColor3)?,
    FontSize: (number)?,
    FullRect: (boolean)?,
    Separation: (number)?,
    Font: (NativeFont?)?,
    OffsetLeft: (number)?,
    OffsetRight: (number)?,
    OffsetTop: (number)?,
    OffsetBottom: (number)?,
    AnchorLeft: (number)?,
    AnchorRight: (number)?,
    AnchorTop: (number)?,
    AnchorBottom: (number)?,
    GrowHorizontal: (number)?,
    GrowVertical: (number)?,
    FocusMode: (number)?,
    LayoutMode: (number)?,
    ClipContents: (boolean)?,
    ModulateRGBA: (NativeColor4)?,
    SelfModulateRGBA: (NativeColor4)?,
    Theme: (NativeTheme?)?,
    TooltipText: (string)?,
}
export type NativeBoxMeshProperties = {
    Size: (NativeVector3)?,
}
export type NativeBoxShape3DProperties = {
    Size: (NativeVector3)?,
}
export type NativeButtonProperties = {
    Name: (string)?,
    Visible: (boolean)?,
    Position: (NativeVector2)?,
    Size: (NativeVector2)?,
    MinSize: (NativeVector2)?,
    MouseFilter: (number)?,
    Modulate: (NativeColor3)?,
    FontSize: (number)?,
    FullRect: (boolean)?,
    Text: (string)?,
    Font: (NativeFont?)?,
    Icon: (NativeTexture2D?)?,
    Disabled: (boolean)?,
    ToggleMode: (boolean)?,
    ButtonPressed: (boolean)?,
    OffsetLeft: (number)?,
    OffsetRight: (number)?,
    OffsetTop: (number)?,
    OffsetBottom: (number)?,
    AnchorLeft: (number)?,
    AnchorRight: (number)?,
    AnchorTop: (number)?,
    AnchorBottom: (number)?,
    GrowHorizontal: (number)?,
    GrowVertical: (number)?,
    FocusMode: (number)?,
    LayoutMode: (number)?,
    ClipContents: (boolean)?,
    ModulateRGBA: (NativeColor4)?,
    SelfModulateRGBA: (NativeColor4)?,
    Theme: (NativeTheme?)?,
    TooltipText: (string)?,
}
export type NativeCamera2DProperties = {
    Name: (string)?,
    Position: (NativeVector2)?,
    RotationDegrees: (number)?,
    Scale: (NativeVector2)?,
    Visible: (boolean)?,
    Modulate: (NativeColor3)?,
    GlobalPosition: (NativeVector2)?,
    GlobalRotation: (number)?,
    ZIndex: (number)?,
    YSortEnabled: (boolean)?,
    ModulateRGBA: (NativeColor4)?,
    SelfModulateRGBA: (NativeColor4)?,
    Enabled: (boolean)?,
    Zoom: (NativeVector2)?,
    Offset: (NativeVector2)?,
    PositionSmoothingEnabled: (boolean)?,
    PositionSmoothingSpeed: (number)?,
}
export type NativeCamera3DProperties = {
    Name: (string)?,
    Position: (NativeVector3)?,
    RotationDegrees: (NativeVector3)?,
    Scale: (NativeVector3)?,
    Visible: (boolean)?,
    Fov: (number)?,
    Near: (number)?,
    Far: (number)?,
}
export type NativeCanvasItemProperties = {
    Name: (string)?,
    Visible: (boolean)?,
    Modulate: (NativeColor3)?,
    ModulateRGBA: (NativeColor4)?,
    SelfModulateRGBA: (NativeColor4)?,
}
export type NativeCanvasLayerProperties = {
    Name: (string)?,
    Layer: (number)?,
}
export type NativeCapsuleMeshProperties = {
    Radius: (number)?,
    Height: (number)?,
    RadialSegments: (number)?,
    Rings: (number)?,
}
export type NativeCapsuleShape2DProperties = {
    Radius: (number)?,
    Height: (number)?,
}
export type NativeCapsuleShape3DProperties = {
    Radius: (number)?,
    Height: (number)?,
}
export type NativeCenterContainerProperties = {
    Name: (string)?,
    Visible: (boolean)?,
    Position: (NativeVector2)?,
    Size: (NativeVector2)?,
    MinSize: (NativeVector2)?,
    MouseFilter: (number)?,
    Modulate: (NativeColor3)?,
    FontSize: (number)?,
    FullRect: (boolean)?,
    Font: (NativeFont?)?,
    OffsetLeft: (number)?,
    OffsetRight: (number)?,
    OffsetTop: (number)?,
    OffsetBottom: (number)?,
    AnchorLeft: (number)?,
    AnchorRight: (number)?,
    AnchorTop: (number)?,
    AnchorBottom: (number)?,
    GrowHorizontal: (number)?,
    GrowVertical: (number)?,
    FocusMode: (number)?,
    LayoutMode: (number)?,
    ClipContents: (boolean)?,
    ModulateRGBA: (NativeColor4)?,
    SelfModulateRGBA: (NativeColor4)?,
    Theme: (NativeTheme?)?,
    TooltipText: (string)?,
}
export type NativeCharacterBody2DProperties = {
    Name: (string)?,
    Position: (NativeVector2)?,
    RotationDegrees: (number)?,
    Scale: (NativeVector2)?,
    Visible: (boolean)?,
    Modulate: (NativeColor3)?,
    GlobalPosition: (NativeVector2)?,
    GlobalRotation: (number)?,
    ZIndex: (number)?,
    YSortEnabled: (boolean)?,
    ModulateRGBA: (NativeColor4)?,
    SelfModulateRGBA: (NativeColor4)?,
    CollisionLayer: (number)?,
    CollisionMask: (number)?,
    InputPickable: (boolean)?,
    Velocity: (NativeVector2)?,
    UpDirection: (NativeVector2)?,
    MaxSlides: (number)?,
    FloorMaxAngle: (number)?,
    FloorSnapLength: (number)?,
    SafeMargin: (number)?,
    FloorStopOnSlope: (boolean)?,
    FloorConstantSpeed: (boolean)?,
    SlideOnCeiling: (boolean)?,
}
export type NativeCharacterBody3DProperties = {
    Name: (string)?,
    Position: (NativeVector3)?,
    RotationDegrees: (NativeVector3)?,
    Scale: (NativeVector3)?,
    Visible: (boolean)?,
    CollisionLayer: (number)?,
    CollisionMask: (number)?,
    Velocity: (NativeVector3)?,
    UpDirection: (NativeVector3)?,
    MaxSlides: (number)?,
    FloorMaxAngle: (number)?,
    FloorSnapLength: (number)?,
    SafeMargin: (number)?,
    FloorStopOnSlope: (boolean)?,
    FloorConstantSpeed: (boolean)?,
    SlideOnCeiling: (boolean)?,
}
export type NativeCheckBoxProperties = {
    Name: (string)?,
    Visible: (boolean)?,
    Position: (NativeVector2)?,
    Size: (NativeVector2)?,
    MinSize: (NativeVector2)?,
    MouseFilter: (number)?,
    Modulate: (NativeColor3)?,
    FontSize: (number)?,
    FullRect: (boolean)?,
    Text: (string)?,
    Font: (NativeFont?)?,
    Icon: (NativeTexture2D?)?,
    Disabled: (boolean)?,
    ToggleMode: (boolean)?,
    ButtonPressed: (boolean)?,
    OffsetLeft: (number)?,
    OffsetRight: (number)?,
    OffsetTop: (number)?,
    OffsetBottom: (number)?,
    AnchorLeft: (number)?,
    AnchorRight: (number)?,
    AnchorTop: (number)?,
    AnchorBottom: (number)?,
    GrowHorizontal: (number)?,
    GrowVertical: (number)?,
    FocusMode: (number)?,
    LayoutMode: (number)?,
    ClipContents: (boolean)?,
    ModulateRGBA: (NativeColor4)?,
    SelfModulateRGBA: (NativeColor4)?,
    Theme: (NativeTheme?)?,
    TooltipText: (string)?,
}
export type NativeCheckButtonProperties = {
    Name: (string)?,
    Visible: (boolean)?,
    Position: (NativeVector2)?,
    Size: (NativeVector2)?,
    MinSize: (NativeVector2)?,
    MouseFilter: (number)?,
    Modulate: (NativeColor3)?,
    FontSize: (number)?,
    FullRect: (boolean)?,
    Text: (string)?,
    Font: (NativeFont?)?,
    Icon: (NativeTexture2D?)?,
    Disabled: (boolean)?,
    ToggleMode: (boolean)?,
    ButtonPressed: (boolean)?,
    OffsetLeft: (number)?,
    OffsetRight: (number)?,
    OffsetTop: (number)?,
    OffsetBottom: (number)?,
    AnchorLeft: (number)?,
    AnchorRight: (number)?,
    AnchorTop: (number)?,
    AnchorBottom: (number)?,
    GrowHorizontal: (number)?,
    GrowVertical: (number)?,
    FocusMode: (number)?,
    LayoutMode: (number)?,
    ClipContents: (boolean)?,
    ModulateRGBA: (NativeColor4)?,
    SelfModulateRGBA: (NativeColor4)?,
    Theme: (NativeTheme?)?,
    TooltipText: (string)?,
}
export type NativeCircleShape2DProperties = {
    Radius: (number)?,
}
export type NativeCollisionObject2DProperties = {
    Name: (string)?,
    Position: (NativeVector2)?,
    RotationDegrees: (number)?,
    Scale: (NativeVector2)?,
    Visible: (boolean)?,
    Modulate: (NativeColor3)?,
    GlobalPosition: (NativeVector2)?,
    GlobalRotation: (number)?,
    ZIndex: (number)?,
    YSortEnabled: (boolean)?,
    ModulateRGBA: (NativeColor4)?,
    SelfModulateRGBA: (NativeColor4)?,
    CollisionLayer: (number)?,
    CollisionMask: (number)?,
    InputPickable: (boolean)?,
}
export type NativeCollisionObject3DProperties = {
    Name: (string)?,
    Position: (NativeVector3)?,
    RotationDegrees: (NativeVector3)?,
    Scale: (NativeVector3)?,
    Visible: (boolean)?,
    CollisionLayer: (number)?,
    CollisionMask: (number)?,
}
export type NativeCollisionShape2DProperties = {
    Name: (string)?,
    Position: (NativeVector2)?,
    RotationDegrees: (number)?,
    Scale: (NativeVector2)?,
    Visible: (boolean)?,
    Modulate: (NativeColor3)?,
    GlobalPosition: (NativeVector2)?,
    GlobalRotation: (number)?,
    ZIndex: (number)?,
    YSortEnabled: (boolean)?,
    ModulateRGBA: (NativeColor4)?,
    SelfModulateRGBA: (NativeColor4)?,
    Shape: (NativeShape2D?)?,
    Disabled: (boolean)?,
    OneWayCollision: (boolean)?,
}
export type NativeCollisionShape3DProperties = {
    Name: (string)?,
    Position: (NativeVector3)?,
    RotationDegrees: (NativeVector3)?,
    Scale: (NativeVector3)?,
    Visible: (boolean)?,
    Shape: (NativeShape3D?)?,
    Disabled: (boolean)?,
}
export type NativeColorRectProperties = {
    Name: (string)?,
    Visible: (boolean)?,
    Position: (NativeVector2)?,
    Size: (NativeVector2)?,
    MinSize: (NativeVector2)?,
    MouseFilter: (number)?,
    Modulate: (NativeColor3)?,
    FontSize: (number)?,
    FullRect: (boolean)?,
    Color: (NativeColor3)?,
    Font: (NativeFont?)?,
    OffsetLeft: (number)?,
    OffsetRight: (number)?,
    OffsetTop: (number)?,
    OffsetBottom: (number)?,
    AnchorLeft: (number)?,
    AnchorRight: (number)?,
    AnchorTop: (number)?,
    AnchorBottom: (number)?,
    GrowHorizontal: (number)?,
    GrowVertical: (number)?,
    FocusMode: (number)?,
    LayoutMode: (number)?,
    ClipContents: (boolean)?,
    ModulateRGBA: (NativeColor4)?,
    SelfModulateRGBA: (NativeColor4)?,
    Theme: (NativeTheme?)?,
    TooltipText: (string)?,
}
export type NativeContainerProperties = {
    Name: (string)?,
    Visible: (boolean)?,
    Position: (NativeVector2)?,
    Size: (NativeVector2)?,
    MinSize: (NativeVector2)?,
    MouseFilter: (number)?,
    Modulate: (NativeColor3)?,
    FontSize: (number)?,
    FullRect: (boolean)?,
    Font: (NativeFont?)?,
    OffsetLeft: (number)?,
    OffsetRight: (number)?,
    OffsetTop: (number)?,
    OffsetBottom: (number)?,
    AnchorLeft: (number)?,
    AnchorRight: (number)?,
    AnchorTop: (number)?,
    AnchorBottom: (number)?,
    GrowHorizontal: (number)?,
    GrowVertical: (number)?,
    FocusMode: (number)?,
    LayoutMode: (number)?,
    ClipContents: (boolean)?,
    ModulateRGBA: (NativeColor4)?,
    SelfModulateRGBA: (NativeColor4)?,
    Theme: (NativeTheme?)?,
    TooltipText: (string)?,
}
export type NativeControlProperties = {
    Name: (string)?,
    Visible: (boolean)?,
    Position: (NativeVector2)?,
    Size: (NativeVector2)?,
    MinSize: (NativeVector2)?,
    MouseFilter: (number)?,
    Modulate: (NativeColor3)?,
    FontSize: (number)?,
    FullRect: (boolean)?,
    Font: (NativeFont?)?,
    OffsetLeft: (number)?,
    OffsetRight: (number)?,
    OffsetTop: (number)?,
    OffsetBottom: (number)?,
    AnchorLeft: (number)?,
    AnchorRight: (number)?,
    AnchorTop: (number)?,
    AnchorBottom: (number)?,
    GrowHorizontal: (number)?,
    GrowVertical: (number)?,
    FocusMode: (number)?,
    LayoutMode: (number)?,
    ClipContents: (boolean)?,
    ModulateRGBA: (NativeColor4)?,
    SelfModulateRGBA: (NativeColor4)?,
    Theme: (NativeTheme?)?,
    TooltipText: (string)?,
}
export type NativeCylinderMeshProperties = {
    TopRadius: (number)?,
    BottomRadius: (number)?,
    Height: (number)?,
    RadialSegments: (number)?,
    Rings: (number)?,
}
export type NativeCylinderShape3DProperties = {
    Radius: (number)?,
    Height: (number)?,
}
export type NativeDirectionalLight3DProperties = {
    Name: (string)?,
    Position: (NativeVector3)?,
    RotationDegrees: (NativeVector3)?,
    Scale: (NativeVector3)?,
    Visible: (boolean)?,
    Color: (NativeColor3)?,
    Energy: (number)?,
    ShadowEnabled: (boolean)?,
}
export type NativeEnvironmentProperties = {
    BackgroundMode: (number)?,
    BackgroundColor: (NativeColor3)?,
    AmbientLightSource: (number)?,
    AmbientLightColor: (NativeColor3)?,
    AmbientLightEnergy: (number)?,
}
export type NativeFontProperties = {
}
export type NativeGeometryInstance3DProperties = {
    Name: (string)?,
    Position: (NativeVector3)?,
    RotationDegrees: (NativeVector3)?,
    Scale: (NativeVector3)?,
    Visible: (boolean)?,
    Material: (NativeMaterial?)?,
}
export type NativeGradientProperties = {
}
export type NativeGradientTexture1DProperties = {
    Gradient: (NativeGradient?)?,
    Width: (number)?,
}
export type NativeGradientTexture2DProperties = {
    Gradient: (NativeGradient?)?,
    Width: (number)?,
    Height: (number)?,
    Fill: (number)?,
    FillFrom: (NativeVector2)?,
    FillTo: (NativeVector2)?,
}
export type NativeGridContainerProperties = {
    Name: (string)?,
    Visible: (boolean)?,
    Position: (NativeVector2)?,
    Size: (NativeVector2)?,
    MinSize: (NativeVector2)?,
    MouseFilter: (number)?,
    Modulate: (NativeColor3)?,
    FontSize: (number)?,
    FullRect: (boolean)?,
    Font: (NativeFont?)?,
    Columns: (number)?,
    OffsetLeft: (number)?,
    OffsetRight: (number)?,
    OffsetTop: (number)?,
    OffsetBottom: (number)?,
    AnchorLeft: (number)?,
    AnchorRight: (number)?,
    AnchorTop: (number)?,
    AnchorBottom: (number)?,
    GrowHorizontal: (number)?,
    GrowVertical: (number)?,
    FocusMode: (number)?,
    LayoutMode: (number)?,
    ClipContents: (boolean)?,
    ModulateRGBA: (NativeColor4)?,
    SelfModulateRGBA: (NativeColor4)?,
    Theme: (NativeTheme?)?,
    TooltipText: (string)?,
}
export type NativeHBoxContainerProperties = {
    Name: (string)?,
    Visible: (boolean)?,
    Position: (NativeVector2)?,
    Size: (NativeVector2)?,
    MinSize: (NativeVector2)?,
    MouseFilter: (number)?,
    Modulate: (NativeColor3)?,
    FontSize: (number)?,
    FullRect: (boolean)?,
    Separation: (number)?,
    Font: (NativeFont?)?,
    OffsetLeft: (number)?,
    OffsetRight: (number)?,
    OffsetTop: (number)?,
    OffsetBottom: (number)?,
    AnchorLeft: (number)?,
    AnchorRight: (number)?,
    AnchorTop: (number)?,
    AnchorBottom: (number)?,
    GrowHorizontal: (number)?,
    GrowVertical: (number)?,
    FocusMode: (number)?,
    LayoutMode: (number)?,
    ClipContents: (boolean)?,
    ModulateRGBA: (NativeColor4)?,
    SelfModulateRGBA: (NativeColor4)?,
    Theme: (NativeTheme?)?,
    TooltipText: (string)?,
}
export type NativeHSeparatorProperties = {
    Name: (string)?,
    Visible: (boolean)?,
    Position: (NativeVector2)?,
    Size: (NativeVector2)?,
    MinSize: (NativeVector2)?,
    MouseFilter: (number)?,
    Modulate: (NativeColor3)?,
    FontSize: (number)?,
    FullRect: (boolean)?,
    Font: (NativeFont?)?,
    OffsetLeft: (number)?,
    OffsetRight: (number)?,
    OffsetTop: (number)?,
    OffsetBottom: (number)?,
    AnchorLeft: (number)?,
    AnchorRight: (number)?,
    AnchorTop: (number)?,
    AnchorBottom: (number)?,
    GrowHorizontal: (number)?,
    GrowVertical: (number)?,
    FocusMode: (number)?,
    LayoutMode: (number)?,
    ClipContents: (boolean)?,
    ModulateRGBA: (NativeColor4)?,
    SelfModulateRGBA: (NativeColor4)?,
    Theme: (NativeTheme?)?,
    TooltipText: (string)?,
}
export type NativeHSliderProperties = {
    Name: (string)?,
    Visible: (boolean)?,
    Position: (NativeVector2)?,
    Size: (NativeVector2)?,
    MinSize: (NativeVector2)?,
    MouseFilter: (number)?,
    Modulate: (NativeColor3)?,
    FontSize: (number)?,
    FullRect: (boolean)?,
    Font: (NativeFont?)?,
    MinValue: (number)?,
    MaxValue: (number)?,
    Value: (number)?,
    Step: (number)?,
    OffsetLeft: (number)?,
    OffsetRight: (number)?,
    OffsetTop: (number)?,
    OffsetBottom: (number)?,
    AnchorLeft: (number)?,
    AnchorRight: (number)?,
    AnchorTop: (number)?,
    AnchorBottom: (number)?,
    GrowHorizontal: (number)?,
    GrowVertical: (number)?,
    FocusMode: (number)?,
    LayoutMode: (number)?,
    ClipContents: (boolean)?,
    ModulateRGBA: (NativeColor4)?,
    SelfModulateRGBA: (NativeColor4)?,
    Theme: (NativeTheme?)?,
    TooltipText: (string)?,
}
export type NativeHSplitContainerProperties = {
    Name: (string)?,
    Visible: (boolean)?,
    Position: (NativeVector2)?,
    Size: (NativeVector2)?,
    MinSize: (NativeVector2)?,
    MouseFilter: (number)?,
    Modulate: (NativeColor3)?,
    FontSize: (number)?,
    FullRect: (boolean)?,
    Font: (NativeFont?)?,
    OffsetLeft: (number)?,
    OffsetRight: (number)?,
    OffsetTop: (number)?,
    OffsetBottom: (number)?,
    AnchorLeft: (number)?,
    AnchorRight: (number)?,
    AnchorTop: (number)?,
    AnchorBottom: (number)?,
    GrowHorizontal: (number)?,
    GrowVertical: (number)?,
    FocusMode: (number)?,
    LayoutMode: (number)?,
    ClipContents: (boolean)?,
    ModulateRGBA: (NativeColor4)?,
    SelfModulateRGBA: (NativeColor4)?,
    Theme: (NativeTheme?)?,
    TooltipText: (string)?,
}
export type NativeItemListProperties = {
    Name: (string)?,
    Visible: (boolean)?,
    Position: (NativeVector2)?,
    Size: (NativeVector2)?,
    MinSize: (NativeVector2)?,
    MouseFilter: (number)?,
    Modulate: (NativeColor3)?,
    FontSize: (number)?,
    FullRect: (boolean)?,
    Font: (NativeFont?)?,
    OffsetLeft: (number)?,
    OffsetRight: (number)?,
    OffsetTop: (number)?,
    OffsetBottom: (number)?,
    AnchorLeft: (number)?,
    AnchorRight: (number)?,
    AnchorTop: (number)?,
    AnchorBottom: (number)?,
    GrowHorizontal: (number)?,
    GrowVertical: (number)?,
    FocusMode: (number)?,
    LayoutMode: (number)?,
    ClipContents: (boolean)?,
    ModulateRGBA: (NativeColor4)?,
    SelfModulateRGBA: (NativeColor4)?,
    Theme: (NativeTheme?)?,
    TooltipText: (string)?,
    SelectMode: (number)?,
    AllowReselect: (boolean)?,
    FixedColumnWidth: (number)?,
    MaxColumns: (number)?,
    IconMode: (number)?,
    FixedIconSize: (NativeVector2i)?,
    ItemCount: nil,
}
export type NativeLabelProperties = {
    Name: (string)?,
    Visible: (boolean)?,
    Position: (NativeVector2)?,
    Size: (NativeVector2)?,
    MinSize: (NativeVector2)?,
    MouseFilter: (number)?,
    Modulate: (NativeColor3)?,
    FontSize: (number)?,
    FullRect: (boolean)?,
    Text: (string)?,
    Font: (NativeFont?)?,
    OffsetLeft: (number)?,
    OffsetRight: (number)?,
    OffsetTop: (number)?,
    OffsetBottom: (number)?,
    AnchorLeft: (number)?,
    AnchorRight: (number)?,
    AnchorTop: (number)?,
    AnchorBottom: (number)?,
    GrowHorizontal: (number)?,
    GrowVertical: (number)?,
    FocusMode: (number)?,
    LayoutMode: (number)?,
    ClipContents: (boolean)?,
    ModulateRGBA: (NativeColor4)?,
    SelfModulateRGBA: (NativeColor4)?,
    Theme: (NativeTheme?)?,
    TooltipText: (string)?,
}
export type NativeLabel3DProperties = {
    Name: (string)?,
    Position: (NativeVector3)?,
    RotationDegrees: (NativeVector3)?,
    Scale: (NativeVector3)?,
    Visible: (boolean)?,
    Material: (NativeMaterial?)?,
    Text: (string)?,
    Billboard: (number)?,
    FontSize: (number)?,
    Font: (NativeFont?)?,
}
export type NativeLight3DProperties = {
    Name: (string)?,
    Position: (NativeVector3)?,
    RotationDegrees: (NativeVector3)?,
    Scale: (NativeVector3)?,
    Visible: (boolean)?,
    Color: (NativeColor3)?,
    Energy: (number)?,
    ShadowEnabled: (boolean)?,
}
export type NativeLineEditProperties = {
    Name: (string)?,
    Visible: (boolean)?,
    Position: (NativeVector2)?,
    Size: (NativeVector2)?,
    MinSize: (NativeVector2)?,
    MouseFilter: (number)?,
    Modulate: (NativeColor3)?,
    FontSize: (number)?,
    FullRect: (boolean)?,
    Text: (string)?,
    PlaceholderText: (string)?,
    Font: (NativeFont?)?,
    OffsetLeft: (number)?,
    OffsetRight: (number)?,
    OffsetTop: (number)?,
    OffsetBottom: (number)?,
    AnchorLeft: (number)?,
    AnchorRight: (number)?,
    AnchorTop: (number)?,
    AnchorBottom: (number)?,
    GrowHorizontal: (number)?,
    GrowVertical: (number)?,
    FocusMode: (number)?,
    LayoutMode: (number)?,
    ClipContents: (boolean)?,
    ModulateRGBA: (NativeColor4)?,
    SelfModulateRGBA: (NativeColor4)?,
    Theme: (NativeTheme?)?,
    TooltipText: (string)?,
}
export type NativeMarginContainerProperties = {
    Name: (string)?,
    Visible: (boolean)?,
    Position: (NativeVector2)?,
    Size: (NativeVector2)?,
    MinSize: (NativeVector2)?,
    MouseFilter: (number)?,
    Modulate: (NativeColor3)?,
    FontSize: (number)?,
    FullRect: (boolean)?,
    Font: (NativeFont?)?,
    OffsetLeft: (number)?,
    OffsetRight: (number)?,
    OffsetTop: (number)?,
    OffsetBottom: (number)?,
    AnchorLeft: (number)?,
    AnchorRight: (number)?,
    AnchorTop: (number)?,
    AnchorBottom: (number)?,
    GrowHorizontal: (number)?,
    GrowVertical: (number)?,
    FocusMode: (number)?,
    LayoutMode: (number)?,
    ClipContents: (boolean)?,
    ModulateRGBA: (NativeColor4)?,
    SelfModulateRGBA: (NativeColor4)?,
    Theme: (NativeTheme?)?,
    TooltipText: (string)?,
}
export type NativeMaterialProperties = {
}
export type NativeMeshProperties = {
}
export type NativeMeshInstance3DProperties = {
    Name: (string)?,
    Position: (NativeVector3)?,
    RotationDegrees: (NativeVector3)?,
    Scale: (NativeVector3)?,
    Visible: (boolean)?,
    Mesh: (NativeMesh?)?,
    Material: (NativeMaterial?)?,
}
export type NativeMultiMeshProperties = {
    TransformFormat: (number)?,
    UseColors: (boolean)?,
    InstanceCount: (number)?,
    VisibleInstanceCount: (number)?,
    Mesh: (NativeMesh?)?,
    CustomAabb: (NativeAABB)?,
}
export type NativeMultiMeshInstance2DProperties = {
    Name: (string)?,
    Position: (NativeVector2)?,
    RotationDegrees: (number)?,
    Scale: (NativeVector2)?,
    Visible: (boolean)?,
    Modulate: (NativeColor3)?,
    GlobalPosition: (NativeVector2)?,
    GlobalRotation: (number)?,
    ZIndex: (number)?,
    YSortEnabled: (boolean)?,
    ModulateRGBA: (NativeColor4)?,
    SelfModulateRGBA: (NativeColor4)?,
    Multimesh: (NativeMultiMesh?)?,
}
export type NativeMultiMeshInstance3DProperties = {
    Name: (string)?,
    Position: (NativeVector3)?,
    RotationDegrees: (NativeVector3)?,
    Scale: (NativeVector3)?,
    Visible: (boolean)?,
    Material: (NativeMaterial?)?,
    Multimesh: (NativeMultiMesh?)?,
}
export type NativeNavigationAgent3DProperties = {
    Name: (string)?,
    TargetPosition: (NativeVector3)?,
    NavigationLayers: (number)?,
    PathDesiredDistance: (number)?,
    TargetDesiredDistance: (number)?,
    PathMaxDistance: (number)?,
}
export type NativeNavigationMeshProperties = {
}
export type NativeNavigationRegion3DProperties = {
    Name: (string)?,
    Position: (NativeVector3)?,
    RotationDegrees: (NativeVector3)?,
    Scale: (NativeVector3)?,
    Visible: (boolean)?,
    NavigationMesh: (NativeNavigationMesh?)?,
    Enabled: (boolean)?,
    NavigationLayers: (number)?,
}
export type NativeNodeProperties = {
    Name: (string)?,
}
export type NativeNode2DProperties = {
    Name: (string)?,
    Position: (NativeVector2)?,
    RotationDegrees: (number)?,
    Scale: (NativeVector2)?,
    Visible: (boolean)?,
    Modulate: (NativeColor3)?,
    GlobalPosition: (NativeVector2)?,
    GlobalRotation: (number)?,
    ZIndex: (number)?,
    YSortEnabled: (boolean)?,
    ModulateRGBA: (NativeColor4)?,
    SelfModulateRGBA: (NativeColor4)?,
}
export type NativeNode3DProperties = {
    Name: (string)?,
    Position: (NativeVector3)?,
    RotationDegrees: (NativeVector3)?,
    Scale: (NativeVector3)?,
    Visible: (boolean)?,
}
export type NativeObjectProperties = {
}
export type NativeOmniLight3DProperties = {
    Name: (string)?,
    Position: (NativeVector3)?,
    RotationDegrees: (NativeVector3)?,
    Scale: (NativeVector3)?,
    Visible: (boolean)?,
    Color: (NativeColor3)?,
    Energy: (number)?,
    ShadowEnabled: (boolean)?,
    Range: (number)?,
}
export type NativePackedSceneProperties = {
}
export type NativePanelProperties = {
    Name: (string)?,
    Visible: (boolean)?,
    Position: (NativeVector2)?,
    Size: (NativeVector2)?,
    MinSize: (NativeVector2)?,
    MouseFilter: (number)?,
    Modulate: (NativeColor3)?,
    FontSize: (number)?,
    FullRect: (boolean)?,
    Font: (NativeFont?)?,
    OffsetLeft: (number)?,
    OffsetRight: (number)?,
    OffsetTop: (number)?,
    OffsetBottom: (number)?,
    AnchorLeft: (number)?,
    AnchorRight: (number)?,
    AnchorTop: (number)?,
    AnchorBottom: (number)?,
    GrowHorizontal: (number)?,
    GrowVertical: (number)?,
    FocusMode: (number)?,
    LayoutMode: (number)?,
    ClipContents: (boolean)?,
    ModulateRGBA: (NativeColor4)?,
    SelfModulateRGBA: (NativeColor4)?,
    Theme: (NativeTheme?)?,
    TooltipText: (string)?,
}
export type NativePanelContainerProperties = {
    Name: (string)?,
    Visible: (boolean)?,
    Position: (NativeVector2)?,
    Size: (NativeVector2)?,
    MinSize: (NativeVector2)?,
    MouseFilter: (number)?,
    Modulate: (NativeColor3)?,
    FontSize: (number)?,
    FullRect: (boolean)?,
    Font: (NativeFont?)?,
    OffsetLeft: (number)?,
    OffsetRight: (number)?,
    OffsetTop: (number)?,
    OffsetBottom: (number)?,
    AnchorLeft: (number)?,
    AnchorRight: (number)?,
    AnchorTop: (number)?,
    AnchorBottom: (number)?,
    GrowHorizontal: (number)?,
    GrowVertical: (number)?,
    FocusMode: (number)?,
    LayoutMode: (number)?,
    ClipContents: (boolean)?,
    ModulateRGBA: (NativeColor4)?,
    SelfModulateRGBA: (NativeColor4)?,
    Theme: (NativeTheme?)?,
    TooltipText: (string)?,
}
export type NativePhysicsBody2DProperties = {
    Name: (string)?,
    Position: (NativeVector2)?,
    RotationDegrees: (number)?,
    Scale: (NativeVector2)?,
    Visible: (boolean)?,
    Modulate: (NativeColor3)?,
    GlobalPosition: (NativeVector2)?,
    GlobalRotation: (number)?,
    ZIndex: (number)?,
    YSortEnabled: (boolean)?,
    ModulateRGBA: (NativeColor4)?,
    SelfModulateRGBA: (NativeColor4)?,
    CollisionLayer: (number)?,
    CollisionMask: (number)?,
    InputPickable: (boolean)?,
}
export type NativePhysicsBody3DProperties = {
    Name: (string)?,
    Position: (NativeVector3)?,
    RotationDegrees: (NativeVector3)?,
    Scale: (NativeVector3)?,
    Visible: (boolean)?,
    CollisionLayer: (number)?,
    CollisionMask: (number)?,
}
export type NativePhysicsMaterialProperties = {
    Friction: (number)?,
    Rough: (boolean)?,
    Bounce: (number)?,
    Absorbent: (boolean)?,
}
export type NativePlaneMeshProperties = {
    Size: (NativeVector2)?,
}
export type NativePrimitiveMeshProperties = {
}
export type NativeProgressBarProperties = {
    Name: (string)?,
    Visible: (boolean)?,
    Position: (NativeVector2)?,
    Size: (NativeVector2)?,
    MinSize: (NativeVector2)?,
    MouseFilter: (number)?,
    Modulate: (NativeColor3)?,
    FontSize: (number)?,
    FullRect: (boolean)?,
    Font: (NativeFont?)?,
    MinValue: (number)?,
    MaxValue: (number)?,
    Value: (number)?,
    Step: (number)?,
    OffsetLeft: (number)?,
    OffsetRight: (number)?,
    OffsetTop: (number)?,
    OffsetBottom: (number)?,
    AnchorLeft: (number)?,
    AnchorRight: (number)?,
    AnchorTop: (number)?,
    AnchorBottom: (number)?,
    GrowHorizontal: (number)?,
    GrowVertical: (number)?,
    FocusMode: (number)?,
    LayoutMode: (number)?,
    ClipContents: (boolean)?,
    ModulateRGBA: (NativeColor4)?,
    SelfModulateRGBA: (NativeColor4)?,
    Theme: (NativeTheme?)?,
    TooltipText: (string)?,
}
export type NativeQuadMeshProperties = {
    Size: (NativeVector2)?,
}
export type NativeRangeProperties = {
    Name: (string)?,
    Visible: (boolean)?,
    Position: (NativeVector2)?,
    Size: (NativeVector2)?,
    MinSize: (NativeVector2)?,
    MouseFilter: (number)?,
    Modulate: (NativeColor3)?,
    FontSize: (number)?,
    FullRect: (boolean)?,
    Font: (NativeFont?)?,
    MinValue: (number)?,
    MaxValue: (number)?,
    Value: (number)?,
    Step: (number)?,
    OffsetLeft: (number)?,
    OffsetRight: (number)?,
    OffsetTop: (number)?,
    OffsetBottom: (number)?,
    AnchorLeft: (number)?,
    AnchorRight: (number)?,
    AnchorTop: (number)?,
    AnchorBottom: (number)?,
    GrowHorizontal: (number)?,
    GrowVertical: (number)?,
    FocusMode: (number)?,
    LayoutMode: (number)?,
    ClipContents: (boolean)?,
    ModulateRGBA: (NativeColor4)?,
    SelfModulateRGBA: (NativeColor4)?,
    Theme: (NativeTheme?)?,
    TooltipText: (string)?,
}
export type NativeRayCast2DProperties = {
    Name: (string)?,
    Position: (NativeVector2)?,
    RotationDegrees: (number)?,
    Scale: (NativeVector2)?,
    Visible: (boolean)?,
    Modulate: (NativeColor3)?,
    GlobalPosition: (NativeVector2)?,
    GlobalRotation: (number)?,
    ZIndex: (number)?,
    YSortEnabled: (boolean)?,
    ModulateRGBA: (NativeColor4)?,
    SelfModulateRGBA: (NativeColor4)?,
    Enabled: (boolean)?,
    ExcludeParent: (boolean)?,
    HitFromInside: (boolean)?,
    CollideWithAreas: (boolean)?,
    CollideWithBodies: (boolean)?,
    CollisionMask: (number)?,
    TargetPosition: (NativeVector2)?,
}
export type NativeRayCast3DProperties = {
    Name: (string)?,
    Position: (NativeVector3)?,
    RotationDegrees: (NativeVector3)?,
    Scale: (NativeVector3)?,
    Visible: (boolean)?,
    Enabled: (boolean)?,
    ExcludeParent: (boolean)?,
    HitFromInside: (boolean)?,
    CollideWithAreas: (boolean)?,
    CollideWithBodies: (boolean)?,
    CollisionMask: (number)?,
    TargetPosition: (NativeVector3)?,
}
export type NativeRectangleShape2DProperties = {
    Size: (NativeVector2)?,
}
export type NativeRefCountedProperties = {
}
export type NativeResourceProperties = {
}
export type NativeRichTextLabelProperties = {
    Name: (string)?,
    Visible: (boolean)?,
    Position: (NativeVector2)?,
    Size: (NativeVector2)?,
    MinSize: (NativeVector2)?,
    MouseFilter: (number)?,
    Modulate: (NativeColor3)?,
    FontSize: (number)?,
    FullRect: (boolean)?,
    Font: (NativeFont?)?,
    OffsetLeft: (number)?,
    OffsetRight: (number)?,
    OffsetTop: (number)?,
    OffsetBottom: (number)?,
    AnchorLeft: (number)?,
    AnchorRight: (number)?,
    AnchorTop: (number)?,
    AnchorBottom: (number)?,
    GrowHorizontal: (number)?,
    GrowVertical: (number)?,
    FocusMode: (number)?,
    LayoutMode: (number)?,
    ClipContents: (boolean)?,
    ModulateRGBA: (NativeColor4)?,
    SelfModulateRGBA: (NativeColor4)?,
    Theme: (NativeTheme?)?,
    TooltipText: (string)?,
    Text: (string)?,
    BbcodeEnabled: (boolean)?,
    FitContent: (boolean)?,
    ScrollActive: (boolean)?,
}
export type NativeRigidBody2DProperties = {
    Name: (string)?,
    Position: (NativeVector2)?,
    RotationDegrees: (number)?,
    Scale: (NativeVector2)?,
    Visible: (boolean)?,
    Modulate: (NativeColor3)?,
    GlobalPosition: (NativeVector2)?,
    GlobalRotation: (number)?,
    ZIndex: (number)?,
    YSortEnabled: (boolean)?,
    ModulateRGBA: (NativeColor4)?,
    SelfModulateRGBA: (NativeColor4)?,
    CollisionLayer: (number)?,
    CollisionMask: (number)?,
    InputPickable: (boolean)?,
    Mass: (number)?,
    PhysicsMaterialOverride: (NativePhysicsMaterial?)?,
    GravityScale: (number)?,
    LinearVelocity: (NativeVector2)?,
    AngularVelocity: (number)?,
    LinearDamp: (number)?,
    AngularDamp: (number)?,
    LockRotation: (boolean)?,
    Freeze: (boolean)?,
    ContactMonitor: (boolean)?,
    MaxContactsReported: (number)?,
    Sleeping: (boolean)?,
}
export type NativeRigidBody3DProperties = {
    Name: (string)?,
    Position: (NativeVector3)?,
    RotationDegrees: (NativeVector3)?,
    Scale: (NativeVector3)?,
    Visible: (boolean)?,
    CollisionLayer: (number)?,
    CollisionMask: (number)?,
    Mass: (number)?,
    GravityScale: (number)?,
    Freeze: (boolean)?,
}
export type NativeScrollContainerProperties = {
    Name: (string)?,
    Visible: (boolean)?,
    Position: (NativeVector2)?,
    Size: (NativeVector2)?,
    MinSize: (NativeVector2)?,
    MouseFilter: (number)?,
    Modulate: (NativeColor3)?,
    FontSize: (number)?,
    FullRect: (boolean)?,
    Font: (NativeFont?)?,
    OffsetLeft: (number)?,
    OffsetRight: (number)?,
    OffsetTop: (number)?,
    OffsetBottom: (number)?,
    AnchorLeft: (number)?,
    AnchorRight: (number)?,
    AnchorTop: (number)?,
    AnchorBottom: (number)?,
    GrowHorizontal: (number)?,
    GrowVertical: (number)?,
    FocusMode: (number)?,
    LayoutMode: (number)?,
    ClipContents: (boolean)?,
    ModulateRGBA: (NativeColor4)?,
    SelfModulateRGBA: (NativeColor4)?,
    Theme: (NativeTheme?)?,
    TooltipText: (string)?,
}
export type NativeSegmentShape2DProperties = {
    A: (NativeVector2)?,
    B: (NativeVector2)?,
}
export type NativeSeparatorProperties = {
    Name: (string)?,
    Visible: (boolean)?,
    Position: (NativeVector2)?,
    Size: (NativeVector2)?,
    MinSize: (NativeVector2)?,
    MouseFilter: (number)?,
    Modulate: (NativeColor3)?,
    FontSize: (number)?,
    FullRect: (boolean)?,
    Font: (NativeFont?)?,
    OffsetLeft: (number)?,
    OffsetRight: (number)?,
    OffsetTop: (number)?,
    OffsetBottom: (number)?,
    AnchorLeft: (number)?,
    AnchorRight: (number)?,
    AnchorTop: (number)?,
    AnchorBottom: (number)?,
    GrowHorizontal: (number)?,
    GrowVertical: (number)?,
    FocusMode: (number)?,
    LayoutMode: (number)?,
    ClipContents: (boolean)?,
    ModulateRGBA: (NativeColor4)?,
    SelfModulateRGBA: (NativeColor4)?,
    Theme: (NativeTheme?)?,
    TooltipText: (string)?,
}
export type NativeShaderProperties = {
}
export type NativeShaderMaterialProperties = {
    Shader: (NativeShader?)?,
}
export type NativeShape2DProperties = {
}
export type NativeShape3DProperties = {
}
export type NativeSkeleton3DProperties = {
    Name: (string)?,
    Position: (NativeVector3)?,
    RotationDegrees: (NativeVector3)?,
    Scale: (NativeVector3)?,
    Visible: (boolean)?,
}
export type NativeSliderProperties = {
    Name: (string)?,
    Visible: (boolean)?,
    Position: (NativeVector2)?,
    Size: (NativeVector2)?,
    MinSize: (NativeVector2)?,
    MouseFilter: (number)?,
    Modulate: (NativeColor3)?,
    FontSize: (number)?,
    FullRect: (boolean)?,
    Font: (NativeFont?)?,
    MinValue: (number)?,
    MaxValue: (number)?,
    Value: (number)?,
    Step: (number)?,
    OffsetLeft: (number)?,
    OffsetRight: (number)?,
    OffsetTop: (number)?,
    OffsetBottom: (number)?,
    AnchorLeft: (number)?,
    AnchorRight: (number)?,
    AnchorTop: (number)?,
    AnchorBottom: (number)?,
    GrowHorizontal: (number)?,
    GrowVertical: (number)?,
    FocusMode: (number)?,
    LayoutMode: (number)?,
    ClipContents: (boolean)?,
    ModulateRGBA: (NativeColor4)?,
    SelfModulateRGBA: (NativeColor4)?,
    Theme: (NativeTheme?)?,
    TooltipText: (string)?,
}
export type NativeSoftBody3DProperties = {
    Name: (string)?,
    Position: (NativeVector3)?,
    RotationDegrees: (NativeVector3)?,
    Scale: (NativeVector3)?,
    Visible: (boolean)?,
    Mesh: (NativeArrayMesh?)?,
    Material: (NativeMaterial?)?,
    CollisionLayer: (number)?,
    CollisionMask: (number)?,
    SimulationPrecision: (number)?,
    TotalMass: (number)?,
}
export type NativeSphereMeshProperties = {
    Radius: (number)?,
    Height: (number)?,
    RadialSegments: (number)?,
    Rings: (number)?,
}
export type NativeSphereShape3DProperties = {
    Radius: (number)?,
}
export type NativeSplitContainerProperties = {
    Name: (string)?,
    Visible: (boolean)?,
    Position: (NativeVector2)?,
    Size: (NativeVector2)?,
    MinSize: (NativeVector2)?,
    MouseFilter: (number)?,
    Modulate: (NativeColor3)?,
    FontSize: (number)?,
    FullRect: (boolean)?,
    Font: (NativeFont?)?,
    OffsetLeft: (number)?,
    OffsetRight: (number)?,
    OffsetTop: (number)?,
    OffsetBottom: (number)?,
    AnchorLeft: (number)?,
    AnchorRight: (number)?,
    AnchorTop: (number)?,
    AnchorBottom: (number)?,
    GrowHorizontal: (number)?,
    GrowVertical: (number)?,
    FocusMode: (number)?,
    LayoutMode: (number)?,
    ClipContents: (boolean)?,
    ModulateRGBA: (NativeColor4)?,
    SelfModulateRGBA: (NativeColor4)?,
    Theme: (NativeTheme?)?,
    TooltipText: (string)?,
}
export type NativeSpotLight3DProperties = {
    Name: (string)?,
    Position: (NativeVector3)?,
    RotationDegrees: (NativeVector3)?,
    Scale: (NativeVector3)?,
    Visible: (boolean)?,
    Color: (NativeColor3)?,
    Energy: (number)?,
    ShadowEnabled: (boolean)?,
    Range: (number)?,
}
export type NativeSprite2DProperties = {
    Name: (string)?,
    Texture: (NativeTexture2D?)?,
    Position: (NativeVector2)?,
    RotationDegrees: (number)?,
    Scale: (NativeVector2)?,
    Visible: (boolean)?,
    Modulate: (NativeColor3)?,
    GlobalPosition: (NativeVector2)?,
    GlobalRotation: (number)?,
    ZIndex: (number)?,
    YSortEnabled: (boolean)?,
    ModulateRGBA: (NativeColor4)?,
    SelfModulateRGBA: (NativeColor4)?,
    Centered: (boolean)?,
    Offset: (NativeVector2)?,
    FlipH: (boolean)?,
    FlipV: (boolean)?,
    Hframes: (number)?,
    Vframes: (number)?,
    FrameCoords: nil,
    RegionEnabled: (boolean)?,
    RegionRect: (NativeRect2)?,
    RegionFilterClipEnabled: (boolean)?,
}
export type NativeSprite3DProperties = {
    Name: (string)?,
    Position: (NativeVector3)?,
    RotationDegrees: (NativeVector3)?,
    Scale: (NativeVector3)?,
    Visible: (boolean)?,
    Material: (NativeMaterial?)?,
    Texture: (NativeTexture2D?)?,
    PixelSize: (number)?,
}
export type NativeSpriteBase3DProperties = {
    Name: (string)?,
    Position: (NativeVector3)?,
    RotationDegrees: (NativeVector3)?,
    Scale: (NativeVector3)?,
    Visible: (boolean)?,
    Material: (NativeMaterial?)?,
    PixelSize: (number)?,
}
export type NativeSpriteFramesProperties = {
}
export type NativeStandardMaterial3DProperties = {
    Color: (NativeColor3)?,
    Roughness: (number)?,
    EmissionEnabled: (boolean)?,
    Emission: (NativeColor3)?,
    AlbedoTexture: (NativeTexture2D?)?,
    Metallic: (number)?,
    Transparency: (number)?,
}
export type NativeStaticBody2DProperties = {
    Name: (string)?,
    Position: (NativeVector2)?,
    RotationDegrees: (number)?,
    Scale: (NativeVector2)?,
    Visible: (boolean)?,
    Modulate: (NativeColor3)?,
    GlobalPosition: (NativeVector2)?,
    GlobalRotation: (number)?,
    ZIndex: (number)?,
    YSortEnabled: (boolean)?,
    ModulateRGBA: (NativeColor4)?,
    SelfModulateRGBA: (NativeColor4)?,
    CollisionLayer: (number)?,
    CollisionMask: (number)?,
    InputPickable: (boolean)?,
    PhysicsMaterialOverride: (NativePhysicsMaterial?)?,
    ConstantLinearVelocity: (NativeVector2)?,
    ConstantAngularVelocity: (number)?,
}
export type NativeStaticBody3DProperties = {
    Name: (string)?,
    Position: (NativeVector3)?,
    RotationDegrees: (NativeVector3)?,
    Scale: (NativeVector3)?,
    Visible: (boolean)?,
    CollisionLayer: (number)?,
    CollisionMask: (number)?,
}
export type NativeStyleBoxProperties = {
    ContentMarginLeft: (number)?,
    ContentMarginTop: (number)?,
    ContentMarginRight: (number)?,
    ContentMarginBottom: (number)?,
}
export type NativeStyleBoxEmptyProperties = {
    ContentMarginLeft: (number)?,
    ContentMarginTop: (number)?,
    ContentMarginRight: (number)?,
    ContentMarginBottom: (number)?,
}
export type NativeStyleBoxFlatProperties = {
    BgColor: (NativeColor4)?,
    BorderColor: (NativeColor4)?,
    BorderWidthLeft: (number)?,
    BorderWidthTop: (number)?,
    BorderWidthRight: (number)?,
    BorderWidthBottom: (number)?,
    CornerRadiusTopLeft: (number)?,
    CornerRadiusTopRight: (number)?,
    CornerRadiusBottomLeft: (number)?,
    CornerRadiusBottomRight: (number)?,
    ContentMarginLeft: (number)?,
    ContentMarginTop: (number)?,
    ContentMarginRight: (number)?,
    ContentMarginBottom: (number)?,
}
export type NativeStyleBoxLineProperties = {
    Color: (NativeColor4)?,
    Thickness: (number)?,
    Vertical: (boolean)?,
    ContentMarginLeft: (number)?,
    ContentMarginTop: (number)?,
    ContentMarginRight: (number)?,
    ContentMarginBottom: (number)?,
}
export type NativeTabContainerProperties = {
    Name: (string)?,
    Visible: (boolean)?,
    Position: (NativeVector2)?,
    Size: (NativeVector2)?,
    MinSize: (NativeVector2)?,
    MouseFilter: (number)?,
    Modulate: (NativeColor3)?,
    FontSize: (number)?,
    FullRect: (boolean)?,
    Font: (NativeFont?)?,
    OffsetLeft: (number)?,
    OffsetRight: (number)?,
    OffsetTop: (number)?,
    OffsetBottom: (number)?,
    AnchorLeft: (number)?,
    AnchorRight: (number)?,
    AnchorTop: (number)?,
    AnchorBottom: (number)?,
    GrowHorizontal: (number)?,
    GrowVertical: (number)?,
    FocusMode: (number)?,
    LayoutMode: (number)?,
    ClipContents: (boolean)?,
    ModulateRGBA: (NativeColor4)?,
    SelfModulateRGBA: (NativeColor4)?,
    Theme: (NativeTheme?)?,
    TooltipText: (string)?,
    CurrentTab: nil,
    TabsVisible: (boolean)?,
}
export type NativeTextEditProperties = {
    Name: (string)?,
    Visible: (boolean)?,
    Position: (NativeVector2)?,
    Size: (NativeVector2)?,
    MinSize: (NativeVector2)?,
    MouseFilter: (number)?,
    Modulate: (NativeColor3)?,
    FontSize: (number)?,
    FullRect: (boolean)?,
    Font: (NativeFont?)?,
    OffsetLeft: (number)?,
    OffsetRight: (number)?,
    OffsetTop: (number)?,
    OffsetBottom: (number)?,
    AnchorLeft: (number)?,
    AnchorRight: (number)?,
    AnchorTop: (number)?,
    AnchorBottom: (number)?,
    GrowHorizontal: (number)?,
    GrowVertical: (number)?,
    FocusMode: (number)?,
    LayoutMode: (number)?,
    ClipContents: (boolean)?,
    ModulateRGBA: (NativeColor4)?,
    SelfModulateRGBA: (NativeColor4)?,
    Theme: (NativeTheme?)?,
    TooltipText: (string)?,
    Text: (string)?,
    Editable: (boolean)?,
    PlaceholderText: (string)?,
    WrapMode: (number)?,
}
export type NativeTextureProperties = {
}
export type NativeTexture2DProperties = {
}
export type NativeTextureProgressBarProperties = {
    Name: (string)?,
    Visible: (boolean)?,
    Position: (NativeVector2)?,
    Size: (NativeVector2)?,
    MinSize: (NativeVector2)?,
    MouseFilter: (number)?,
    Modulate: (NativeColor3)?,
    FontSize: (number)?,
    FullRect: (boolean)?,
    Font: (NativeFont?)?,
    MinValue: (number)?,
    MaxValue: (number)?,
    Value: (number)?,
    Step: (number)?,
    OffsetLeft: (number)?,
    OffsetRight: (number)?,
    OffsetTop: (number)?,
    OffsetBottom: (number)?,
    AnchorLeft: (number)?,
    AnchorRight: (number)?,
    AnchorTop: (number)?,
    AnchorBottom: (number)?,
    GrowHorizontal: (number)?,
    GrowVertical: (number)?,
    FocusMode: (number)?,
    LayoutMode: (number)?,
    ClipContents: (boolean)?,
    ModulateRGBA: (NativeColor4)?,
    SelfModulateRGBA: (NativeColor4)?,
    Theme: (NativeTheme?)?,
    TooltipText: (string)?,
    TextureUnder: (NativeTexture2D?)?,
    TextureOver: (NativeTexture2D?)?,
    TextureProgress: (NativeTexture2D?)?,
    FillMode: (number)?,
    TintUnder: (NativeColor4)?,
    TintOver: (NativeColor4)?,
    TintProgress: (NativeColor4)?,
}
export type NativeTextureRectProperties = {
    Name: (string)?,
    Visible: (boolean)?,
    Position: (NativeVector2)?,
    Size: (NativeVector2)?,
    MinSize: (NativeVector2)?,
    MouseFilter: (number)?,
    Modulate: (NativeColor3)?,
    FontSize: (number)?,
    FullRect: (boolean)?,
    Texture: (NativeTexture2D?)?,
    ExpandMode: (number)?,
    StretchMode: (number)?,
    Font: (NativeFont?)?,
    OffsetLeft: (number)?,
    OffsetRight: (number)?,
    OffsetTop: (number)?,
    OffsetBottom: (number)?,
    AnchorLeft: (number)?,
    AnchorRight: (number)?,
    AnchorTop: (number)?,
    AnchorBottom: (number)?,
    GrowHorizontal: (number)?,
    GrowVertical: (number)?,
    FocusMode: (number)?,
    LayoutMode: (number)?,
    ClipContents: (boolean)?,
    ModulateRGBA: (NativeColor4)?,
    SelfModulateRGBA: (NativeColor4)?,
    Theme: (NativeTheme?)?,
    TooltipText: (string)?,
}
export type NativeThemeProperties = {
}
export type NativeTimerProperties = {
    Name: (string)?,
    WaitTime: (number)?,
    OneShot: (boolean)?,
    Autostart: (boolean)?,
    Paused: (boolean)?,
    ProcessCallback: (number)?,
    TimeLeft: nil,
}
export type NativeVBoxContainerProperties = {
    Name: (string)?,
    Visible: (boolean)?,
    Position: (NativeVector2)?,
    Size: (NativeVector2)?,
    MinSize: (NativeVector2)?,
    MouseFilter: (number)?,
    Modulate: (NativeColor3)?,
    FontSize: (number)?,
    FullRect: (boolean)?,
    Separation: (number)?,
    Font: (NativeFont?)?,
    OffsetLeft: (number)?,
    OffsetRight: (number)?,
    OffsetTop: (number)?,
    OffsetBottom: (number)?,
    AnchorLeft: (number)?,
    AnchorRight: (number)?,
    AnchorTop: (number)?,
    AnchorBottom: (number)?,
    GrowHorizontal: (number)?,
    GrowVertical: (number)?,
    FocusMode: (number)?,
    LayoutMode: (number)?,
    ClipContents: (boolean)?,
    ModulateRGBA: (NativeColor4)?,
    SelfModulateRGBA: (NativeColor4)?,
    Theme: (NativeTheme?)?,
    TooltipText: (string)?,
}
export type NativeVSeparatorProperties = {
    Name: (string)?,
    Visible: (boolean)?,
    Position: (NativeVector2)?,
    Size: (NativeVector2)?,
    MinSize: (NativeVector2)?,
    MouseFilter: (number)?,
    Modulate: (NativeColor3)?,
    FontSize: (number)?,
    FullRect: (boolean)?,
    Font: (NativeFont?)?,
    OffsetLeft: (number)?,
    OffsetRight: (number)?,
    OffsetTop: (number)?,
    OffsetBottom: (number)?,
    AnchorLeft: (number)?,
    AnchorRight: (number)?,
    AnchorTop: (number)?,
    AnchorBottom: (number)?,
    GrowHorizontal: (number)?,
    GrowVertical: (number)?,
    FocusMode: (number)?,
    LayoutMode: (number)?,
    ClipContents: (boolean)?,
    ModulateRGBA: (NativeColor4)?,
    SelfModulateRGBA: (NativeColor4)?,
    Theme: (NativeTheme?)?,
    TooltipText: (string)?,
}
export type NativeVSliderProperties = {
    Name: (string)?,
    Visible: (boolean)?,
    Position: (NativeVector2)?,
    Size: (NativeVector2)?,
    MinSize: (NativeVector2)?,
    MouseFilter: (number)?,
    Modulate: (NativeColor3)?,
    FontSize: (number)?,
    FullRect: (boolean)?,
    Font: (NativeFont?)?,
    MinValue: (number)?,
    MaxValue: (number)?,
    Value: (number)?,
    Step: (number)?,
    OffsetLeft: (number)?,
    OffsetRight: (number)?,
    OffsetTop: (number)?,
    OffsetBottom: (number)?,
    AnchorLeft: (number)?,
    AnchorRight: (number)?,
    AnchorTop: (number)?,
    AnchorBottom: (number)?,
    GrowHorizontal: (number)?,
    GrowVertical: (number)?,
    FocusMode: (number)?,
    LayoutMode: (number)?,
    ClipContents: (boolean)?,
    ModulateRGBA: (NativeColor4)?,
    SelfModulateRGBA: (NativeColor4)?,
    Theme: (NativeTheme?)?,
    TooltipText: (string)?,
}
export type NativeVSplitContainerProperties = {
    Name: (string)?,
    Visible: (boolean)?,
    Position: (NativeVector2)?,
    Size: (NativeVector2)?,
    MinSize: (NativeVector2)?,
    MouseFilter: (number)?,
    Modulate: (NativeColor3)?,
    FontSize: (number)?,
    FullRect: (boolean)?,
    Font: (NativeFont?)?,
    OffsetLeft: (number)?,
    OffsetRight: (number)?,
    OffsetTop: (number)?,
    OffsetBottom: (number)?,
    AnchorLeft: (number)?,
    AnchorRight: (number)?,
    AnchorTop: (number)?,
    AnchorBottom: (number)?,
    GrowHorizontal: (number)?,
    GrowVertical: (number)?,
    FocusMode: (number)?,
    LayoutMode: (number)?,
    ClipContents: (boolean)?,
    ModulateRGBA: (NativeColor4)?,
    SelfModulateRGBA: (NativeColor4)?,
    Theme: (NativeTheme?)?,
    TooltipText: (string)?,
}
export type NativeVisualInstance3DProperties = {
    Name: (string)?,
    Position: (NativeVector3)?,
    RotationDegrees: (NativeVector3)?,
    Scale: (NativeVector3)?,
    Visible: (boolean)?,
}
export type NativeWorldEnvironmentProperties = {
    Name: (string)?,
    Environment: (NativeEnvironment?)?,
}
declare class NativeSceneScope extends NativeNode3D
    New: ((self: NativeSceneScope, Class: "AnimatedSprite2D", Properties: NativeAnimatedSprite2DProperties, Parent: NativeNode?) -> NativeAnimatedSprite2D) &
        ((self: NativeSceneScope, Class: "Animation", Properties: NativeAnimationProperties, Parent: NativeNode?) -> MutableNativeAnimation) &
        ((self: NativeSceneScope, Class: "AnimationLibrary", Properties: NativeAnimationLibraryProperties, Parent: NativeNode?) -> MutableNativeAnimationLibrary) &
        ((self: NativeSceneScope, Class: "AnimationPlayer", Properties: NativeAnimationPlayerProperties, Parent: NativeNode?) -> NativeAnimationPlayer) &
        ((self: NativeSceneScope, Class: "Area2D", Properties: NativeArea2DProperties, Parent: NativeNode?) -> NativeArea2D) &
        ((self: NativeSceneScope, Class: "AspectRatioContainer", Properties: NativeAspectRatioContainerProperties, Parent: NativeNode?) -> NativeAspectRatioContainer) &
        ((self: NativeSceneScope, Class: "AudioStreamPlayer", Properties: NativeAudioStreamPlayerProperties, Parent: NativeNode?) -> NativeAudioStreamPlayer) &
        ((self: NativeSceneScope, Class: "AudioStreamPlayer2D", Properties: NativeAudioStreamPlayer2DProperties, Parent: NativeNode?) -> NativeAudioStreamPlayer2D) &
        ((self: NativeSceneScope, Class: "AudioStreamPlayer3D", Properties: NativeAudioStreamPlayer3DProperties, Parent: NativeNode?) -> NativeAudioStreamPlayer3D) &
        ((self: NativeSceneScope, Class: "BoxMesh", Properties: NativeBoxMeshProperties, Parent: NativeNode?) -> MutableNativeBoxMesh) &
        ((self: NativeSceneScope, Class: "BoxShape3D", Properties: NativeBoxShape3DProperties, Parent: NativeNode?) -> MutableNativeBoxShape3D) &
        ((self: NativeSceneScope, Class: "Button", Properties: NativeButtonProperties, Parent: NativeNode?) -> NativeButton) &
        ((self: NativeSceneScope, Class: "Camera2D", Properties: NativeCamera2DProperties, Parent: NativeNode?) -> NativeCamera2D) &
        ((self: NativeSceneScope, Class: "Camera3D", Properties: NativeCamera3DProperties, Parent: NativeNode?) -> NativeCamera3D) &
        ((self: NativeSceneScope, Class: "CanvasLayer", Properties: NativeCanvasLayerProperties, Parent: NativeNode?) -> NativeCanvasLayer) &
        ((self: NativeSceneScope, Class: "CapsuleMesh", Properties: NativeCapsuleMeshProperties, Parent: NativeNode?) -> MutableNativeCapsuleMesh) &
        ((self: NativeSceneScope, Class: "CapsuleShape2D", Properties: NativeCapsuleShape2DProperties, Parent: NativeNode?) -> MutableNativeCapsuleShape2D) &
        ((self: NativeSceneScope, Class: "CapsuleShape3D", Properties: NativeCapsuleShape3DProperties, Parent: NativeNode?) -> MutableNativeCapsuleShape3D) &
        ((self: NativeSceneScope, Class: "CenterContainer", Properties: NativeCenterContainerProperties, Parent: NativeNode?) -> NativeCenterContainer) &
        ((self: NativeSceneScope, Class: "CharacterBody2D", Properties: NativeCharacterBody2DProperties, Parent: NativeNode?) -> NativeCharacterBody2D) &
        ((self: NativeSceneScope, Class: "CharacterBody3D", Properties: NativeCharacterBody3DProperties, Parent: NativeNode?) -> NativeCharacterBody3D) &
        ((self: NativeSceneScope, Class: "CheckBox", Properties: NativeCheckBoxProperties, Parent: NativeNode?) -> NativeCheckBox) &
        ((self: NativeSceneScope, Class: "CheckButton", Properties: NativeCheckButtonProperties, Parent: NativeNode?) -> NativeCheckButton) &
        ((self: NativeSceneScope, Class: "CircleShape2D", Properties: NativeCircleShape2DProperties, Parent: NativeNode?) -> MutableNativeCircleShape2D) &
        ((self: NativeSceneScope, Class: "CollisionShape2D", Properties: NativeCollisionShape2DProperties, Parent: NativeNode?) -> NativeCollisionShape2D) &
        ((self: NativeSceneScope, Class: "CollisionShape3D", Properties: NativeCollisionShape3DProperties, Parent: NativeNode?) -> NativeCollisionShape3D) &
        ((self: NativeSceneScope, Class: "ColorRect", Properties: NativeColorRectProperties, Parent: NativeNode?) -> NativeColorRect) &
        ((self: NativeSceneScope, Class: "Control", Properties: NativeControlProperties, Parent: NativeNode?) -> NativeControl) &
        ((self: NativeSceneScope, Class: "CylinderMesh", Properties: NativeCylinderMeshProperties, Parent: NativeNode?) -> MutableNativeCylinderMesh) &
        ((self: NativeSceneScope, Class: "CylinderShape3D", Properties: NativeCylinderShape3DProperties, Parent: NativeNode?) -> MutableNativeCylinderShape3D) &
        ((self: NativeSceneScope, Class: "DirectionalLight3D", Properties: NativeDirectionalLight3DProperties, Parent: NativeNode?) -> NativeDirectionalLight3D) &
        ((self: NativeSceneScope, Class: "Environment", Properties: NativeEnvironmentProperties, Parent: NativeNode?) -> MutableNativeEnvironment) &
        ((self: NativeSceneScope, Class: "Gradient", Properties: NativeGradientProperties, Parent: NativeNode?) -> MutableNativeGradient) &
        ((self: NativeSceneScope, Class: "GradientTexture1D", Properties: NativeGradientTexture1DProperties, Parent: NativeNode?) -> MutableNativeGradientTexture1D) &
        ((self: NativeSceneScope, Class: "GradientTexture2D", Properties: NativeGradientTexture2DProperties, Parent: NativeNode?) -> MutableNativeGradientTexture2D) &
        ((self: NativeSceneScope, Class: "GridContainer", Properties: NativeGridContainerProperties, Parent: NativeNode?) -> NativeGridContainer) &
        ((self: NativeSceneScope, Class: "HBoxContainer", Properties: NativeHBoxContainerProperties, Parent: NativeNode?) -> NativeHBoxContainer) &
        ((self: NativeSceneScope, Class: "HSeparator", Properties: NativeHSeparatorProperties, Parent: NativeNode?) -> NativeHSeparator) &
        ((self: NativeSceneScope, Class: "HSlider", Properties: NativeHSliderProperties, Parent: NativeNode?) -> NativeHSlider) &
        ((self: NativeSceneScope, Class: "HSplitContainer", Properties: NativeHSplitContainerProperties, Parent: NativeNode?) -> NativeHSplitContainer) &
        ((self: NativeSceneScope, Class: "ItemList", Properties: NativeItemListProperties, Parent: NativeNode?) -> NativeItemList) &
        ((self: NativeSceneScope, Class: "Label", Properties: NativeLabelProperties, Parent: NativeNode?) -> NativeLabel) &
        ((self: NativeSceneScope, Class: "Label3D", Properties: NativeLabel3DProperties, Parent: NativeNode?) -> NativeLabel3D) &
        ((self: NativeSceneScope, Class: "LineEdit", Properties: NativeLineEditProperties, Parent: NativeNode?) -> NativeLineEdit) &
        ((self: NativeSceneScope, Class: "MarginContainer", Properties: NativeMarginContainerProperties, Parent: NativeNode?) -> NativeMarginContainer) &
        ((self: NativeSceneScope, Class: "MeshInstance3D", Properties: NativeMeshInstance3DProperties, Parent: NativeNode?) -> NativeMeshInstance3D) &
        ((self: NativeSceneScope, Class: "MultiMesh", Properties: NativeMultiMeshProperties, Parent: NativeNode?) -> MutableNativeMultiMesh) &
        ((self: NativeSceneScope, Class: "MultiMeshInstance2D", Properties: NativeMultiMeshInstance2DProperties, Parent: NativeNode?) -> NativeMultiMeshInstance2D) &
        ((self: NativeSceneScope, Class: "MultiMeshInstance3D", Properties: NativeMultiMeshInstance3DProperties, Parent: NativeNode?) -> NativeMultiMeshInstance3D) &
        ((self: NativeSceneScope, Class: "NavigationAgent3D", Properties: NativeNavigationAgent3DProperties, Parent: NativeNode?) -> NativeNavigationAgent3D) &
        ((self: NativeSceneScope, Class: "NavigationRegion3D", Properties: NativeNavigationRegion3DProperties, Parent: NativeNode?) -> NativeNavigationRegion3D) &
        ((self: NativeSceneScope, Class: "Node", Properties: NativeNodeProperties, Parent: NativeNode?) -> NativeNode) &
        ((self: NativeSceneScope, Class: "Node2D", Properties: NativeNode2DProperties, Parent: NativeNode?) -> NativeNode2D) &
        ((self: NativeSceneScope, Class: "Node3D", Properties: NativeNode3DProperties, Parent: NativeNode?) -> NativeNode3D) &
        ((self: NativeSceneScope, Class: "OmniLight3D", Properties: NativeOmniLight3DProperties, Parent: NativeNode?) -> NativeOmniLight3D) &
        ((self: NativeSceneScope, Class: "Panel", Properties: NativePanelProperties, Parent: NativeNode?) -> NativePanel) &
        ((self: NativeSceneScope, Class: "PanelContainer", Properties: NativePanelContainerProperties, Parent: NativeNode?) -> NativePanelContainer) &
        ((self: NativeSceneScope, Class: "PhysicsMaterial", Properties: NativePhysicsMaterialProperties, Parent: NativeNode?) -> MutableNativePhysicsMaterial) &
        ((self: NativeSceneScope, Class: "PlaneMesh", Properties: NativePlaneMeshProperties, Parent: NativeNode?) -> MutableNativePlaneMesh) &
        ((self: NativeSceneScope, Class: "ProgressBar", Properties: NativeProgressBarProperties, Parent: NativeNode?) -> NativeProgressBar) &
        ((self: NativeSceneScope, Class: "QuadMesh", Properties: NativeQuadMeshProperties, Parent: NativeNode?) -> MutableNativeQuadMesh) &
        ((self: NativeSceneScope, Class: "RayCast2D", Properties: NativeRayCast2DProperties, Parent: NativeNode?) -> NativeRayCast2D) &
        ((self: NativeSceneScope, Class: "RayCast3D", Properties: NativeRayCast3DProperties, Parent: NativeNode?) -> NativeRayCast3D) &
        ((self: NativeSceneScope, Class: "RectangleShape2D", Properties: NativeRectangleShape2DProperties, Parent: NativeNode?) -> MutableNativeRectangleShape2D) &
        ((self: NativeSceneScope, Class: "RichTextLabel", Properties: NativeRichTextLabelProperties, Parent: NativeNode?) -> NativeRichTextLabel) &
        ((self: NativeSceneScope, Class: "RigidBody2D", Properties: NativeRigidBody2DProperties, Parent: NativeNode?) -> NativeRigidBody2D) &
        ((self: NativeSceneScope, Class: "RigidBody3D", Properties: NativeRigidBody3DProperties, Parent: NativeNode?) -> NativeRigidBody3D) &
        ((self: NativeSceneScope, Class: "ScrollContainer", Properties: NativeScrollContainerProperties, Parent: NativeNode?) -> NativeScrollContainer) &
        ((self: NativeSceneScope, Class: "SegmentShape2D", Properties: NativeSegmentShape2DProperties, Parent: NativeNode?) -> MutableNativeSegmentShape2D) &
        ((self: NativeSceneScope, Class: "ShaderMaterial", Properties: NativeShaderMaterialProperties, Parent: NativeNode?) -> MutableNativeShaderMaterial) &
        ((self: NativeSceneScope, Class: "Skeleton3D", Properties: NativeSkeleton3DProperties, Parent: NativeNode?) -> NativeSkeleton3D) &
        ((self: NativeSceneScope, Class: "SoftBody3D", Properties: NativeSoftBody3DProperties, Parent: NativeNode?) -> NativeSoftBody3D) &
        ((self: NativeSceneScope, Class: "SphereMesh", Properties: NativeSphereMeshProperties, Parent: NativeNode?) -> MutableNativeSphereMesh) &
        ((self: NativeSceneScope, Class: "SphereShape3D", Properties: NativeSphereShape3DProperties, Parent: NativeNode?) -> MutableNativeSphereShape3D) &
        ((self: NativeSceneScope, Class: "SpotLight3D", Properties: NativeSpotLight3DProperties, Parent: NativeNode?) -> NativeSpotLight3D) &
        ((self: NativeSceneScope, Class: "Sprite2D", Properties: NativeSprite2DProperties, Parent: NativeNode?) -> NativeSprite2D) &
        ((self: NativeSceneScope, Class: "Sprite3D", Properties: NativeSprite3DProperties, Parent: NativeNode?) -> NativeSprite3D) &
        ((self: NativeSceneScope, Class: "SpriteFrames", Properties: NativeSpriteFramesProperties, Parent: NativeNode?) -> MutableNativeSpriteFrames) &
        ((self: NativeSceneScope, Class: "StandardMaterial3D", Properties: NativeStandardMaterial3DProperties, Parent: NativeNode?) -> MutableNativeStandardMaterial3D) &
        ((self: NativeSceneScope, Class: "StaticBody2D", Properties: NativeStaticBody2DProperties, Parent: NativeNode?) -> NativeStaticBody2D) &
        ((self: NativeSceneScope, Class: "StaticBody3D", Properties: NativeStaticBody3DProperties, Parent: NativeNode?) -> NativeStaticBody3D) &
        ((self: NativeSceneScope, Class: "StyleBoxEmpty", Properties: NativeStyleBoxEmptyProperties, Parent: NativeNode?) -> MutableNativeStyleBoxEmpty) &
        ((self: NativeSceneScope, Class: "StyleBoxFlat", Properties: NativeStyleBoxFlatProperties, Parent: NativeNode?) -> MutableNativeStyleBoxFlat) &
        ((self: NativeSceneScope, Class: "StyleBoxLine", Properties: NativeStyleBoxLineProperties, Parent: NativeNode?) -> MutableNativeStyleBoxLine) &
        ((self: NativeSceneScope, Class: "TabContainer", Properties: NativeTabContainerProperties, Parent: NativeNode?) -> NativeTabContainer) &
        ((self: NativeSceneScope, Class: "TextEdit", Properties: NativeTextEditProperties, Parent: NativeNode?) -> NativeTextEdit) &
        ((self: NativeSceneScope, Class: "TextureProgressBar", Properties: NativeTextureProgressBarProperties, Parent: NativeNode?) -> NativeTextureProgressBar) &
        ((self: NativeSceneScope, Class: "TextureRect", Properties: NativeTextureRectProperties, Parent: NativeNode?) -> NativeTextureRect) &
        ((self: NativeSceneScope, Class: "Timer", Properties: NativeTimerProperties, Parent: NativeNode?) -> NativeTimer) &
        ((self: NativeSceneScope, Class: "VBoxContainer", Properties: NativeVBoxContainerProperties, Parent: NativeNode?) -> NativeVBoxContainer) &
        ((self: NativeSceneScope, Class: "VSeparator", Properties: NativeVSeparatorProperties, Parent: NativeNode?) -> NativeVSeparator) &
        ((self: NativeSceneScope, Class: "VSlider", Properties: NativeVSliderProperties, Parent: NativeNode?) -> NativeVSlider) &
        ((self: NativeSceneScope, Class: "VSplitContainer", Properties: NativeVSplitContainerProperties, Parent: NativeNode?) -> NativeVSplitContainer) &
        ((self: NativeSceneScope, Class: "WorldEnvironment", Properties: NativeWorldEnvironmentProperties, Parent: NativeNode?) -> NativeWorldEnvironment)
    Configure: ((self: NativeSceneScope, Target: NativeAnimatedSprite2D, Properties: NativeAnimatedSprite2DProperties) -> ()) &
        ((self: NativeSceneScope, Target: MutableNativeAnimation, Properties: NativeAnimationProperties) -> ()) &
        ((self: NativeSceneScope, Target: MutableNativeAnimationLibrary, Properties: NativeAnimationLibraryProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeAnimationPlayer, Properties: NativeAnimationPlayerProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeArea2D, Properties: NativeArea2DProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeAspectRatioContainer, Properties: NativeAspectRatioContainerProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeAudioStreamPlayer, Properties: NativeAudioStreamPlayerProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeAudioStreamPlayer2D, Properties: NativeAudioStreamPlayer2DProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeAudioStreamPlayer3D, Properties: NativeAudioStreamPlayer3DProperties) -> ()) &
        ((self: NativeSceneScope, Target: MutableNativeBoxMesh, Properties: NativeBoxMeshProperties) -> ()) &
        ((self: NativeSceneScope, Target: MutableNativeBoxShape3D, Properties: NativeBoxShape3DProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeButton, Properties: NativeButtonProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeCamera2D, Properties: NativeCamera2DProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeCamera3D, Properties: NativeCamera3DProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeCanvasLayer, Properties: NativeCanvasLayerProperties) -> ()) &
        ((self: NativeSceneScope, Target: MutableNativeCapsuleMesh, Properties: NativeCapsuleMeshProperties) -> ()) &
        ((self: NativeSceneScope, Target: MutableNativeCapsuleShape2D, Properties: NativeCapsuleShape2DProperties) -> ()) &
        ((self: NativeSceneScope, Target: MutableNativeCapsuleShape3D, Properties: NativeCapsuleShape3DProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeCenterContainer, Properties: NativeCenterContainerProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeCharacterBody2D, Properties: NativeCharacterBody2DProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeCharacterBody3D, Properties: NativeCharacterBody3DProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeCheckBox, Properties: NativeCheckBoxProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeCheckButton, Properties: NativeCheckButtonProperties) -> ()) &
        ((self: NativeSceneScope, Target: MutableNativeCircleShape2D, Properties: NativeCircleShape2DProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeCollisionShape2D, Properties: NativeCollisionShape2DProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeCollisionShape3D, Properties: NativeCollisionShape3DProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeColorRect, Properties: NativeColorRectProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeControl, Properties: NativeControlProperties) -> ()) &
        ((self: NativeSceneScope, Target: MutableNativeCylinderMesh, Properties: NativeCylinderMeshProperties) -> ()) &
        ((self: NativeSceneScope, Target: MutableNativeCylinderShape3D, Properties: NativeCylinderShape3DProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeDirectionalLight3D, Properties: NativeDirectionalLight3DProperties) -> ()) &
        ((self: NativeSceneScope, Target: MutableNativeEnvironment, Properties: NativeEnvironmentProperties) -> ()) &
        ((self: NativeSceneScope, Target: MutableNativeGradient, Properties: NativeGradientProperties) -> ()) &
        ((self: NativeSceneScope, Target: MutableNativeGradientTexture1D, Properties: NativeGradientTexture1DProperties) -> ()) &
        ((self: NativeSceneScope, Target: MutableNativeGradientTexture2D, Properties: NativeGradientTexture2DProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeGridContainer, Properties: NativeGridContainerProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeHBoxContainer, Properties: NativeHBoxContainerProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeHSeparator, Properties: NativeHSeparatorProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeHSlider, Properties: NativeHSliderProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeHSplitContainer, Properties: NativeHSplitContainerProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeItemList, Properties: NativeItemListProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeLabel, Properties: NativeLabelProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeLabel3D, Properties: NativeLabel3DProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeLineEdit, Properties: NativeLineEditProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeMarginContainer, Properties: NativeMarginContainerProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeMeshInstance3D, Properties: NativeMeshInstance3DProperties) -> ()) &
        ((self: NativeSceneScope, Target: MutableNativeMultiMesh, Properties: NativeMultiMeshProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeMultiMeshInstance2D, Properties: NativeMultiMeshInstance2DProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeMultiMeshInstance3D, Properties: NativeMultiMeshInstance3DProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeNavigationAgent3D, Properties: NativeNavigationAgent3DProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeNavigationRegion3D, Properties: NativeNavigationRegion3DProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeNode, Properties: NativeNodeProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeNode2D, Properties: NativeNode2DProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeNode3D, Properties: NativeNode3DProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeOmniLight3D, Properties: NativeOmniLight3DProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativePanel, Properties: NativePanelProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativePanelContainer, Properties: NativePanelContainerProperties) -> ()) &
        ((self: NativeSceneScope, Target: MutableNativePhysicsMaterial, Properties: NativePhysicsMaterialProperties) -> ()) &
        ((self: NativeSceneScope, Target: MutableNativePlaneMesh, Properties: NativePlaneMeshProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeProgressBar, Properties: NativeProgressBarProperties) -> ()) &
        ((self: NativeSceneScope, Target: MutableNativeQuadMesh, Properties: NativeQuadMeshProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeRayCast2D, Properties: NativeRayCast2DProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeRayCast3D, Properties: NativeRayCast3DProperties) -> ()) &
        ((self: NativeSceneScope, Target: MutableNativeRectangleShape2D, Properties: NativeRectangleShape2DProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeRichTextLabel, Properties: NativeRichTextLabelProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeRigidBody2D, Properties: NativeRigidBody2DProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeRigidBody3D, Properties: NativeRigidBody3DProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeScrollContainer, Properties: NativeScrollContainerProperties) -> ()) &
        ((self: NativeSceneScope, Target: MutableNativeSegmentShape2D, Properties: NativeSegmentShape2DProperties) -> ()) &
        ((self: NativeSceneScope, Target: MutableNativeShaderMaterial, Properties: NativeShaderMaterialProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeSkeleton3D, Properties: NativeSkeleton3DProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeSoftBody3D, Properties: NativeSoftBody3DProperties) -> ()) &
        ((self: NativeSceneScope, Target: MutableNativeSphereMesh, Properties: NativeSphereMeshProperties) -> ()) &
        ((self: NativeSceneScope, Target: MutableNativeSphereShape3D, Properties: NativeSphereShape3DProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeSpotLight3D, Properties: NativeSpotLight3DProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeSprite2D, Properties: NativeSprite2DProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeSprite3D, Properties: NativeSprite3DProperties) -> ()) &
        ((self: NativeSceneScope, Target: MutableNativeSpriteFrames, Properties: NativeSpriteFramesProperties) -> ()) &
        ((self: NativeSceneScope, Target: MutableNativeStandardMaterial3D, Properties: NativeStandardMaterial3DProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeStaticBody2D, Properties: NativeStaticBody2DProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeStaticBody3D, Properties: NativeStaticBody3DProperties) -> ()) &
        ((self: NativeSceneScope, Target: MutableNativeStyleBoxEmpty, Properties: NativeStyleBoxEmptyProperties) -> ()) &
        ((self: NativeSceneScope, Target: MutableNativeStyleBoxFlat, Properties: NativeStyleBoxFlatProperties) -> ()) &
        ((self: NativeSceneScope, Target: MutableNativeStyleBoxLine, Properties: NativeStyleBoxLineProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeTabContainer, Properties: NativeTabContainerProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeTextEdit, Properties: NativeTextEditProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeTextureProgressBar, Properties: NativeTextureProgressBarProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeTextureRect, Properties: NativeTextureRectProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeTimer, Properties: NativeTimerProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeVBoxContainer, Properties: NativeVBoxContainerProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeVSeparator, Properties: NativeVSeparatorProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeVSlider, Properties: NativeVSliderProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeVSplitContainer, Properties: NativeVSplitContainerProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeWorldEnvironment, Properties: NativeWorldEnvironmentProperties) -> ())
    Get: ((self: NativeSceneScope, Target: NativeNode, Property: "Name") -> string) &
        ((self: NativeSceneScope, Target: NativeNode3D, Property: "Position") -> NativeVector3) &
        ((self: NativeSceneScope, Target: NativeNode3D, Property: "RotationDegrees") -> NativeVector3) &
        ((self: NativeSceneScope, Target: NativeNode3D, Property: "Scale") -> NativeVector3) &
        ((self: NativeSceneScope, Target: NativeNode3D, Property: "Visible") -> boolean) &
        ((self: NativeSceneScope, Target: NativeMeshInstance3D, Property: "Mesh") -> NativeMesh?) &
        ((self: NativeSceneScope, Target: NativeGeometryInstance3D, Property: "Material") -> NativeMaterial?) &
        ((self: NativeSceneScope, Target: NativeCollisionObject3D, Property: "CollisionLayer") -> number) &
        ((self: NativeSceneScope, Target: NativeCollisionObject3D, Property: "CollisionMask") -> number) &
        ((self: NativeSceneScope, Target: NativeRigidBody3D, Property: "Mass") -> number) &
        ((self: NativeSceneScope, Target: NativeRigidBody3D, Property: "GravityScale") -> number) &
        ((self: NativeSceneScope, Target: NativeRigidBody3D, Property: "Freeze") -> boolean) &
        ((self: NativeSceneScope, Target: NativeCollisionShape3D, Property: "Shape") -> NativeShape3D?) &
        ((self: NativeSceneScope, Target: NativeCollisionShape3D, Property: "Disabled") -> boolean) &
        ((self: NativeSceneScope, Target: NativeLight3D, Property: "Color") -> NativeColor3) &
        ((self: NativeSceneScope, Target: NativeLight3D, Property: "Energy") -> number) &
        ((self: NativeSceneScope, Target: NativeLight3D, Property: "ShadowEnabled") -> boolean) &
        ((self: NativeSceneScope, Target: NativeOmniLight3D, Property: "Range") -> number) &
        ((self: NativeSceneScope, Target: NativeSpotLight3D, Property: "Range") -> number) &
        ((self: NativeSceneScope, Target: NativeCamera3D, Property: "Fov") -> number) &
        ((self: NativeSceneScope, Target: NativeCamera3D, Property: "Near") -> number) &
        ((self: NativeSceneScope, Target: NativeCamera3D, Property: "Far") -> number) &
        ((self: NativeSceneScope, Target: NativeWorldEnvironment, Property: "Environment") -> NativeEnvironment?) &
        ((self: NativeSceneScope, Target: NativeLabel3D, Property: "Text") -> string) &
        ((self: NativeSceneScope, Target: NativeLabel3D, Property: "Billboard") -> number) &
        ((self: NativeSceneScope, Target: NativeLabel3D, Property: "FontSize") -> number) &
        ((self: NativeSceneScope, Target: NativeCanvasLayer, Property: "Layer") -> number) &
        ((self: NativeSceneScope, Target: NativeControl, Property: "Visible") -> boolean) &
        ((self: NativeSceneScope, Target: NativeControl, Property: "Position") -> NativeVector2) &
        ((self: NativeSceneScope, Target: NativeControl, Property: "Size") -> NativeVector2) &
        ((self: NativeSceneScope, Target: NativeControl, Property: "MinSize") -> NativeVector2) &
        ((self: NativeSceneScope, Target: NativeControl, Property: "MouseFilter") -> number) &
        ((self: NativeSceneScope, Target: NativeControl, Property: "Modulate") -> NativeColor3) &
        ((self: NativeSceneScope, Target: NativeControl, Property: "FontSize") -> number) &
        ((self: NativeSceneScope, Target: NativeBoxContainer, Property: "Separation") -> number) &
        ((self: NativeSceneScope, Target: NativeColorRect, Property: "Color") -> NativeColor3) &
        ((self: NativeSceneScope, Target: NativeLabel, Property: "Text") -> string) &
        ((self: NativeSceneScope, Target: NativeButton, Property: "Text") -> string) &
        ((self: NativeSceneScope, Target: NativeLineEdit, Property: "Text") -> string) &
        ((self: NativeSceneScope, Target: NativeLineEdit, Property: "PlaceholderText") -> string) &
        ((self: NativeSceneScope, Target: NativeAudioStreamPlayer, Property: "Stream") -> NativeAudioStream?) &
        ((self: NativeSceneScope, Target: NativeAudioStreamPlayer, Property: "VolumeDb") -> number) &
        ((self: NativeSceneScope, Target: NativeAudioStreamPlayer, Property: "PitchScale") -> number) &
        ((self: NativeSceneScope, Target: NativeSoftBody3D, Property: "Mesh") -> NativeArrayMesh?) &
        ((self: NativeSceneScope, Target: NativeSoftBody3D, Property: "CollisionLayer") -> number) &
        ((self: NativeSceneScope, Target: NativeSoftBody3D, Property: "CollisionMask") -> number) &
        ((self: NativeSceneScope, Target: NativeSoftBody3D, Property: "SimulationPrecision") -> number) &
        ((self: NativeSceneScope, Target: NativeSoftBody3D, Property: "TotalMass") -> number) &
        ((self: NativeSceneScope, Target: NativeBoxMesh, Property: "Size") -> NativeVector3) &
        ((self: NativeSceneScope, Target: NativeSphereMesh, Property: "Radius") -> number) &
        ((self: NativeSceneScope, Target: NativeSphereMesh, Property: "Height") -> number) &
        ((self: NativeSceneScope, Target: NativeSphereMesh, Property: "RadialSegments") -> number) &
        ((self: NativeSceneScope, Target: NativeSphereMesh, Property: "Rings") -> number) &
        ((self: NativeSceneScope, Target: NativeBoxShape3D, Property: "Size") -> NativeVector3) &
        ((self: NativeSceneScope, Target: NativeSphereShape3D, Property: "Radius") -> number) &
        ((self: NativeSceneScope, Target: NativeStandardMaterial3D, Property: "Color") -> NativeColor3) &
        ((self: NativeSceneScope, Target: NativeStandardMaterial3D, Property: "Roughness") -> number) &
        ((self: NativeSceneScope, Target: NativeStandardMaterial3D, Property: "EmissionEnabled") -> boolean) &
        ((self: NativeSceneScope, Target: NativeStandardMaterial3D, Property: "Emission") -> NativeColor3) &
        ((self: NativeSceneScope, Target: NativeEnvironment, Property: "BackgroundMode") -> number) &
        ((self: NativeSceneScope, Target: NativeEnvironment, Property: "BackgroundColor") -> NativeColor3) &
        ((self: NativeSceneScope, Target: NativeEnvironment, Property: "AmbientLightSource") -> number) &
        ((self: NativeSceneScope, Target: NativeEnvironment, Property: "AmbientLightColor") -> NativeColor3) &
        ((self: NativeSceneScope, Target: NativeEnvironment, Property: "AmbientLightEnergy") -> number) &
        ((self: NativeSceneScope, Target: NativeTextureRect, Property: "Texture") -> NativeTexture2D?) &
        ((self: NativeSceneScope, Target: NativeSprite3D, Property: "Texture") -> NativeTexture2D?) &
        ((self: NativeSceneScope, Target: NativeSprite2D, Property: "Texture") -> NativeTexture2D?) &
        ((self: NativeSceneScope, Target: NativeTextureRect, Property: "ExpandMode") -> number) &
        ((self: NativeSceneScope, Target: NativeTextureRect, Property: "StretchMode") -> number) &
        ((self: NativeSceneScope, Target: NativeSpriteBase3D, Property: "PixelSize") -> number) &
        ((self: NativeSceneScope, Target: NativeNode2D, Property: "Position") -> NativeVector2) &
        ((self: NativeSceneScope, Target: NativeNode2D, Property: "RotationDegrees") -> number) &
        ((self: NativeSceneScope, Target: NativeNode2D, Property: "Scale") -> NativeVector2) &
        ((self: NativeSceneScope, Target: NativeCanvasItem, Property: "Visible") -> boolean) &
        ((self: NativeSceneScope, Target: NativeCanvasItem, Property: "Modulate") -> NativeColor3) &
        ((self: NativeSceneScope, Target: NativeBaseMaterial3D, Property: "AlbedoTexture") -> NativeTexture2D?) &
        ((self: NativeSceneScope, Target: NativeBaseMaterial3D, Property: "Metallic") -> number) &
        ((self: NativeSceneScope, Target: NativeBaseMaterial3D, Property: "Transparency") -> number) &
        ((self: NativeSceneScope, Target: NativeControl, Property: "Font") -> NativeFont?) &
        ((self: NativeSceneScope, Target: NativeLabel3D, Property: "Font") -> NativeFont?) &
        ((self: NativeSceneScope, Target: NativeButton, Property: "Icon") -> NativeTexture2D?) &
        ((self: NativeSceneScope, Target: NativePlaneMesh, Property: "Size") -> NativeVector2) &
        ((self: NativeSceneScope, Target: NativeQuadMesh, Property: "Size") -> NativeVector2) &
        ((self: NativeSceneScope, Target: NativeCapsuleMesh, Property: "Radius") -> number) &
        ((self: NativeSceneScope, Target: NativeCapsuleMesh, Property: "Height") -> number) &
        ((self: NativeSceneScope, Target: NativeCapsuleShape3D, Property: "Radius") -> number) &
        ((self: NativeSceneScope, Target: NativeCapsuleShape3D, Property: "Height") -> number) &
        ((self: NativeSceneScope, Target: NativeCylinderShape3D, Property: "Radius") -> number) &
        ((self: NativeSceneScope, Target: NativeCylinderShape3D, Property: "Height") -> number) &
        ((self: NativeSceneScope, Target: NativeCylinderMesh, Property: "TopRadius") -> number) &
        ((self: NativeSceneScope, Target: NativeCylinderMesh, Property: "BottomRadius") -> number) &
        ((self: NativeSceneScope, Target: NativeCylinderMesh, Property: "Height") -> number) &
        ((self: NativeSceneScope, Target: NativeCapsuleMesh, Property: "RadialSegments") -> number) &
        ((self: NativeSceneScope, Target: NativeCapsuleMesh, Property: "Rings") -> number) &
        ((self: NativeSceneScope, Target: NativeCylinderMesh, Property: "RadialSegments") -> number) &
        ((self: NativeSceneScope, Target: NativeCylinderMesh, Property: "Rings") -> number) &
        ((self: NativeSceneScope, Target: NativeBaseButton, Property: "Disabled") -> boolean) &
        ((self: NativeSceneScope, Target: NativeBaseButton, Property: "ToggleMode") -> boolean) &
        ((self: NativeSceneScope, Target: NativeBaseButton, Property: "ButtonPressed") -> boolean) &
        ((self: NativeSceneScope, Target: NativeGridContainer, Property: "Columns") -> number) &
        ((self: NativeSceneScope, Target: NativeRange, Property: "MinValue") -> number) &
        ((self: NativeSceneScope, Target: NativeRange, Property: "MaxValue") -> number) &
        ((self: NativeSceneScope, Target: NativeRange, Property: "Value") -> number) &
        ((self: NativeSceneScope, Target: NativeRange, Property: "Step") -> number) &
        ((self: NativeSceneScope, Target: NativeControl, Property: "OffsetLeft") -> number) &
        ((self: NativeSceneScope, Target: NativeControl, Property: "OffsetRight") -> number) &
        ((self: NativeSceneScope, Target: NativeControl, Property: "OffsetTop") -> number) &
        ((self: NativeSceneScope, Target: NativeControl, Property: "OffsetBottom") -> number) &
        ((self: NativeSceneScope, Target: NativeControl, Property: "AnchorLeft") -> number) &
        ((self: NativeSceneScope, Target: NativeControl, Property: "AnchorRight") -> number) &
        ((self: NativeSceneScope, Target: NativeControl, Property: "AnchorTop") -> number) &
        ((self: NativeSceneScope, Target: NativeControl, Property: "AnchorBottom") -> number) &
        ((self: NativeSceneScope, Target: NativeControl, Property: "GrowHorizontal") -> number) &
        ((self: NativeSceneScope, Target: NativeControl, Property: "GrowVertical") -> number) &
        ((self: NativeSceneScope, Target: NativeControl, Property: "FocusMode") -> number) &
        ((self: NativeSceneScope, Target: NativeControl, Property: "LayoutMode") -> number) &
        ((self: NativeSceneScope, Target: NativeControl, Property: "ClipContents") -> boolean) &
        ((self: NativeSceneScope, Target: NativeNode2D, Property: "GlobalPosition") -> NativeVector2) &
        ((self: NativeSceneScope, Target: NativeNode2D, Property: "GlobalRotation") -> number) &
        ((self: NativeSceneScope, Target: NativeNode2D, Property: "ZIndex") -> number) &
        ((self: NativeSceneScope, Target: NativeNode2D, Property: "YSortEnabled") -> boolean) &
        ((self: NativeSceneScope, Target: NativeCanvasItem, Property: "ModulateRGBA") -> NativeColor4) &
        ((self: NativeSceneScope, Target: NativeCanvasItem, Property: "SelfModulateRGBA") -> NativeColor4) &
        ((self: NativeSceneScope, Target: NativeControl, Property: "Theme") -> NativeTheme?) &
        ((self: NativeSceneScope, Target: NativeControl, Property: "TooltipText") -> string) &
        ((self: NativeSceneScope, Target: NativeTimer, Property: "WaitTime") -> number) &
        ((self: NativeSceneScope, Target: NativeTimer, Property: "OneShot") -> boolean) &
        ((self: NativeSceneScope, Target: NativeTimer, Property: "Autostart") -> boolean) &
        ((self: NativeSceneScope, Target: NativeTimer, Property: "Paused") -> boolean) &
        ((self: NativeSceneScope, Target: NativeTimer, Property: "ProcessCallback") -> number) &
        ((self: NativeSceneScope, Target: NativeTimer, Property: "TimeLeft") -> number) &
        ((self: NativeSceneScope, Target: NativeSprite2D, Property: "Centered") -> boolean) &
        ((self: NativeSceneScope, Target: NativeSprite2D, Property: "Offset") -> NativeVector2) &
        ((self: NativeSceneScope, Target: NativeSprite2D, Property: "FlipH") -> boolean) &
        ((self: NativeSceneScope, Target: NativeSprite2D, Property: "FlipV") -> boolean) &
        ((self: NativeSceneScope, Target: NativeSprite2D, Property: "Hframes") -> number) &
        ((self: NativeSceneScope, Target: NativeSprite2D, Property: "Vframes") -> number) &
        ((self: NativeSceneScope, Target: NativeSprite2D, Property: "FrameCoords") -> NativeVector2i) &
        ((self: NativeSceneScope, Target: NativeSprite2D, Property: "RegionEnabled") -> boolean) &
        ((self: NativeSceneScope, Target: NativeSprite2D, Property: "RegionRect") -> NativeRect2) &
        ((self: NativeSceneScope, Target: NativeSprite2D, Property: "RegionFilterClipEnabled") -> boolean) &
        ((self: NativeSceneScope, Target: NativeCollisionObject2D, Property: "CollisionLayer") -> number) &
        ((self: NativeSceneScope, Target: NativeCollisionObject2D, Property: "CollisionMask") -> number) &
        ((self: NativeSceneScope, Target: NativeCollisionObject2D, Property: "InputPickable") -> boolean) &
        ((self: NativeSceneScope, Target: NativeStaticBody2D, Property: "PhysicsMaterialOverride") -> NativePhysicsMaterial?) &
        ((self: NativeSceneScope, Target: NativeStaticBody2D, Property: "ConstantLinearVelocity") -> NativeVector2) &
        ((self: NativeSceneScope, Target: NativeStaticBody2D, Property: "ConstantAngularVelocity") -> number) &
        ((self: NativeSceneScope, Target: NativeRigidBody2D, Property: "Mass") -> number) &
        ((self: NativeSceneScope, Target: NativeRigidBody2D, Property: "PhysicsMaterialOverride") -> NativePhysicsMaterial?) &
        ((self: NativeSceneScope, Target: NativeRigidBody2D, Property: "GravityScale") -> number) &
        ((self: NativeSceneScope, Target: NativeRigidBody2D, Property: "LinearVelocity") -> NativeVector2) &
        ((self: NativeSceneScope, Target: NativeRigidBody2D, Property: "AngularVelocity") -> number) &
        ((self: NativeSceneScope, Target: NativeRigidBody2D, Property: "LinearDamp") -> number) &
        ((self: NativeSceneScope, Target: NativeRigidBody2D, Property: "AngularDamp") -> number) &
        ((self: NativeSceneScope, Target: NativeRigidBody2D, Property: "LockRotation") -> boolean) &
        ((self: NativeSceneScope, Target: NativeRigidBody2D, Property: "Freeze") -> boolean) &
        ((self: NativeSceneScope, Target: NativeRigidBody2D, Property: "ContactMonitor") -> boolean) &
        ((self: NativeSceneScope, Target: NativeRigidBody2D, Property: "MaxContactsReported") -> number) &
        ((self: NativeSceneScope, Target: NativeRigidBody2D, Property: "Sleeping") -> boolean) &
        ((self: NativeSceneScope, Target: NativeArea2D, Property: "Monitoring") -> boolean) &
        ((self: NativeSceneScope, Target: NativeArea2D, Property: "Monitorable") -> boolean) &
        ((self: NativeSceneScope, Target: NativeArea2D, Property: "Gravity") -> number) &
        ((self: NativeSceneScope, Target: NativeArea2D, Property: "GravityDirection") -> NativeVector2) &
        ((self: NativeSceneScope, Target: NativeCollisionShape2D, Property: "Shape") -> NativeShape2D?) &
        ((self: NativeSceneScope, Target: NativeCollisionShape2D, Property: "Disabled") -> boolean) &
        ((self: NativeSceneScope, Target: NativeCollisionShape2D, Property: "OneWayCollision") -> boolean) &
        ((self: NativeSceneScope, Target: NativeCamera2D, Property: "Enabled") -> boolean) &
        ((self: NativeSceneScope, Target: NativeCamera2D, Property: "Zoom") -> NativeVector2) &
        ((self: NativeSceneScope, Target: NativeCamera2D, Property: "Offset") -> NativeVector2) &
        ((self: NativeSceneScope, Target: NativeCamera2D, Property: "PositionSmoothingEnabled") -> boolean) &
        ((self: NativeSceneScope, Target: NativeCamera2D, Property: "PositionSmoothingSpeed") -> number) &
        ((self: NativeSceneScope, Target: NativeAnimatedSprite2D, Property: "SpriteFrames") -> NativeSpriteFrames?) &
        ((self: NativeSceneScope, Target: NativeAnimatedSprite2D, Property: "Animation") -> string) &
        ((self: NativeSceneScope, Target: NativeAnimatedSprite2D, Property: "SpeedScale") -> number) &
        ((self: NativeSceneScope, Target: NativeAnimatedSprite2D, Property: "Centered") -> boolean) &
        ((self: NativeSceneScope, Target: NativeAnimatedSprite2D, Property: "Offset") -> NativeVector2) &
        ((self: NativeSceneScope, Target: NativeAnimatedSprite2D, Property: "FlipH") -> boolean) &
        ((self: NativeSceneScope, Target: NativeAnimatedSprite2D, Property: "FlipV") -> boolean) &
        ((self: NativeSceneScope, Target: NativeAnimatedSprite2D, Property: "Frame") -> number) &
        ((self: NativeSceneScope, Target: NativeAnimatedSprite2D, Property: "FrameProgress") -> number) &
        ((self: NativeSceneScope, Target: NativeRectangleShape2D, Property: "Size") -> NativeVector2) &
        ((self: NativeSceneScope, Target: NativeCircleShape2D, Property: "Radius") -> number) &
        ((self: NativeSceneScope, Target: NativeCapsuleShape2D, Property: "Radius") -> number) &
        ((self: NativeSceneScope, Target: NativeCapsuleShape2D, Property: "Height") -> number) &
        ((self: NativeSceneScope, Target: NativeSegmentShape2D, Property: "A") -> NativeVector2) &
        ((self: NativeSceneScope, Target: NativeSegmentShape2D, Property: "B") -> NativeVector2) &
        ((self: NativeSceneScope, Target: NativePhysicsMaterial, Property: "Friction") -> number) &
        ((self: NativeSceneScope, Target: NativePhysicsMaterial, Property: "Rough") -> boolean) &
        ((self: NativeSceneScope, Target: NativePhysicsMaterial, Property: "Bounce") -> number) &
        ((self: NativeSceneScope, Target: NativePhysicsMaterial, Property: "Absorbent") -> boolean) &
        ((self: NativeSceneScope, Target: NativeRichTextLabel, Property: "Text") -> string) &
        ((self: NativeSceneScope, Target: NativeRichTextLabel, Property: "BbcodeEnabled") -> boolean) &
        ((self: NativeSceneScope, Target: NativeRichTextLabel, Property: "FitContent") -> boolean) &
        ((self: NativeSceneScope, Target: NativeRichTextLabel, Property: "ScrollActive") -> boolean) &
        ((self: NativeSceneScope, Target: NativeTextEdit, Property: "Text") -> string) &
        ((self: NativeSceneScope, Target: NativeTextEdit, Property: "Editable") -> boolean) &
        ((self: NativeSceneScope, Target: NativeTextEdit, Property: "PlaceholderText") -> string) &
        ((self: NativeSceneScope, Target: NativeTextEdit, Property: "WrapMode") -> number) &
        ((self: NativeSceneScope, Target: NativeItemList, Property: "SelectMode") -> number) &
        ((self: NativeSceneScope, Target: NativeItemList, Property: "AllowReselect") -> boolean) &
        ((self: NativeSceneScope, Target: NativeItemList, Property: "FixedColumnWidth") -> number) &
        ((self: NativeSceneScope, Target: NativeItemList, Property: "MaxColumns") -> number) &
        ((self: NativeSceneScope, Target: NativeItemList, Property: "IconMode") -> number) &
        ((self: NativeSceneScope, Target: NativeItemList, Property: "FixedIconSize") -> NativeVector2i) &
        ((self: NativeSceneScope, Target: NativeItemList, Property: "ItemCount") -> number) &
        ((self: NativeSceneScope, Target: NativeTabContainer, Property: "CurrentTab") -> number) &
        ((self: NativeSceneScope, Target: NativeTabContainer, Property: "TabsVisible") -> boolean) &
        ((self: NativeSceneScope, Target: NativeAspectRatioContainer, Property: "Ratio") -> number) &
        ((self: NativeSceneScope, Target: NativeAspectRatioContainer, Property: "StretchMode") -> number) &
        ((self: NativeSceneScope, Target: NativeTextureProgressBar, Property: "TextureUnder") -> NativeTexture2D?) &
        ((self: NativeSceneScope, Target: NativeTextureProgressBar, Property: "TextureOver") -> NativeTexture2D?) &
        ((self: NativeSceneScope, Target: NativeTextureProgressBar, Property: "TextureProgress") -> NativeTexture2D?) &
        ((self: NativeSceneScope, Target: NativeTextureProgressBar, Property: "FillMode") -> number) &
        ((self: NativeSceneScope, Target: NativeTextureProgressBar, Property: "TintUnder") -> NativeColor4) &
        ((self: NativeSceneScope, Target: NativeTextureProgressBar, Property: "TintOver") -> NativeColor4) &
        ((self: NativeSceneScope, Target: NativeTextureProgressBar, Property: "TintProgress") -> NativeColor4) &
        ((self: NativeSceneScope, Target: NativeGradientTexture1D, Property: "Gradient") -> NativeGradient?) &
        ((self: NativeSceneScope, Target: NativeGradientTexture1D, Property: "Width") -> number) &
        ((self: NativeSceneScope, Target: NativeGradientTexture2D, Property: "Gradient") -> NativeGradient?) &
        ((self: NativeSceneScope, Target: NativeGradientTexture2D, Property: "Width") -> number) &
        ((self: NativeSceneScope, Target: NativeGradientTexture2D, Property: "Height") -> number) &
        ((self: NativeSceneScope, Target: NativeGradientTexture2D, Property: "Fill") -> number) &
        ((self: NativeSceneScope, Target: NativeGradientTexture2D, Property: "FillFrom") -> NativeVector2) &
        ((self: NativeSceneScope, Target: NativeGradientTexture2D, Property: "FillTo") -> NativeVector2) &
        ((self: NativeSceneScope, Target: NativeShaderMaterial, Property: "Shader") -> NativeShader?) &
        ((self: NativeSceneScope, Target: NativeMultiMesh, Property: "TransformFormat") -> number) &
        ((self: NativeSceneScope, Target: NativeMultiMesh, Property: "UseColors") -> boolean) &
        ((self: NativeSceneScope, Target: NativeMultiMesh, Property: "InstanceCount") -> number) &
        ((self: NativeSceneScope, Target: NativeMultiMesh, Property: "VisibleInstanceCount") -> number) &
        ((self: NativeSceneScope, Target: NativeMultiMesh, Property: "Mesh") -> NativeMesh?) &
        ((self: NativeSceneScope, Target: NativeMultiMesh, Property: "CustomAabb") -> NativeAABB) &
        ((self: NativeSceneScope, Target: NativeMultiMeshInstance2D, Property: "Multimesh") -> NativeMultiMesh?) &
        ((self: NativeSceneScope, Target: NativeMultiMeshInstance3D, Property: "Multimesh") -> NativeMultiMesh?) &
        ((self: NativeSceneScope, Target: NativeStyleBoxFlat, Property: "BgColor") -> NativeColor4) &
        ((self: NativeSceneScope, Target: NativeStyleBoxFlat, Property: "BorderColor") -> NativeColor4) &
        ((self: NativeSceneScope, Target: NativeStyleBoxFlat, Property: "BorderWidthLeft") -> number) &
        ((self: NativeSceneScope, Target: NativeStyleBoxFlat, Property: "BorderWidthTop") -> number) &
        ((self: NativeSceneScope, Target: NativeStyleBoxFlat, Property: "BorderWidthRight") -> number) &
        ((self: NativeSceneScope, Target: NativeStyleBoxFlat, Property: "BorderWidthBottom") -> number) &
        ((self: NativeSceneScope, Target: NativeStyleBoxFlat, Property: "CornerRadiusTopLeft") -> number) &
        ((self: NativeSceneScope, Target: NativeStyleBoxFlat, Property: "CornerRadiusTopRight") -> number) &
        ((self: NativeSceneScope, Target: NativeStyleBoxFlat, Property: "CornerRadiusBottomLeft") -> number) &
        ((self: NativeSceneScope, Target: NativeStyleBoxFlat, Property: "CornerRadiusBottomRight") -> number) &
        ((self: NativeSceneScope, Target: NativeStyleBoxLine, Property: "Color") -> NativeColor4) &
        ((self: NativeSceneScope, Target: NativeStyleBoxLine, Property: "Thickness") -> number) &
        ((self: NativeSceneScope, Target: NativeStyleBoxLine, Property: "Vertical") -> boolean) &
        ((self: NativeSceneScope, Target: NativeStyleBox, Property: "ContentMarginLeft") -> number) &
        ((self: NativeSceneScope, Target: NativeStyleBox, Property: "ContentMarginTop") -> number) &
        ((self: NativeSceneScope, Target: NativeStyleBox, Property: "ContentMarginRight") -> number) &
        ((self: NativeSceneScope, Target: NativeStyleBox, Property: "ContentMarginBottom") -> number) &
        ((self: NativeSceneScope, Target: NativeAudioStreamPlayer2D, Property: "Stream") -> NativeAudioStream?) &
        ((self: NativeSceneScope, Target: NativeAudioStreamPlayer2D, Property: "VolumeDb") -> number) &
        ((self: NativeSceneScope, Target: NativeAudioStreamPlayer2D, Property: "PitchScale") -> number) &
        ((self: NativeSceneScope, Target: NativeAudioStreamPlayer2D, Property: "Autoplay") -> boolean) &
        ((self: NativeSceneScope, Target: NativeAudioStreamPlayer2D, Property: "StreamPaused") -> boolean) &
        ((self: NativeSceneScope, Target: NativeAudioStreamPlayer3D, Property: "Stream") -> NativeAudioStream?) &
        ((self: NativeSceneScope, Target: NativeAudioStreamPlayer3D, Property: "VolumeDb") -> number) &
        ((self: NativeSceneScope, Target: NativeAudioStreamPlayer3D, Property: "PitchScale") -> number) &
        ((self: NativeSceneScope, Target: NativeAudioStreamPlayer3D, Property: "Autoplay") -> boolean) &
        ((self: NativeSceneScope, Target: NativeAudioStreamPlayer3D, Property: "StreamPaused") -> boolean) &
        ((self: NativeSceneScope, Target: NativeRayCast2D, Property: "Enabled") -> boolean) &
        ((self: NativeSceneScope, Target: NativeRayCast2D, Property: "ExcludeParent") -> boolean) &
        ((self: NativeSceneScope, Target: NativeRayCast2D, Property: "HitFromInside") -> boolean) &
        ((self: NativeSceneScope, Target: NativeRayCast2D, Property: "CollideWithAreas") -> boolean) &
        ((self: NativeSceneScope, Target: NativeRayCast2D, Property: "CollideWithBodies") -> boolean) &
        ((self: NativeSceneScope, Target: NativeRayCast2D, Property: "CollisionMask") -> number) &
        ((self: NativeSceneScope, Target: NativeRayCast2D, Property: "TargetPosition") -> NativeVector2) &
        ((self: NativeSceneScope, Target: NativeRayCast3D, Property: "Enabled") -> boolean) &
        ((self: NativeSceneScope, Target: NativeRayCast3D, Property: "ExcludeParent") -> boolean) &
        ((self: NativeSceneScope, Target: NativeRayCast3D, Property: "HitFromInside") -> boolean) &
        ((self: NativeSceneScope, Target: NativeRayCast3D, Property: "CollideWithAreas") -> boolean) &
        ((self: NativeSceneScope, Target: NativeRayCast3D, Property: "CollideWithBodies") -> boolean) &
        ((self: NativeSceneScope, Target: NativeRayCast3D, Property: "CollisionMask") -> number) &
        ((self: NativeSceneScope, Target: NativeRayCast3D, Property: "TargetPosition") -> NativeVector3) &
        ((self: NativeSceneScope, Target: NativeCharacterBody2D, Property: "Velocity") -> NativeVector2) &
        ((self: NativeSceneScope, Target: NativeCharacterBody2D, Property: "UpDirection") -> NativeVector2) &
        ((self: NativeSceneScope, Target: NativeCharacterBody2D, Property: "MaxSlides") -> number) &
        ((self: NativeSceneScope, Target: NativeCharacterBody2D, Property: "FloorMaxAngle") -> number) &
        ((self: NativeSceneScope, Target: NativeCharacterBody2D, Property: "FloorSnapLength") -> number) &
        ((self: NativeSceneScope, Target: NativeCharacterBody2D, Property: "SafeMargin") -> number) &
        ((self: NativeSceneScope, Target: NativeCharacterBody2D, Property: "FloorStopOnSlope") -> boolean) &
        ((self: NativeSceneScope, Target: NativeCharacterBody2D, Property: "FloorConstantSpeed") -> boolean) &
        ((self: NativeSceneScope, Target: NativeCharacterBody2D, Property: "SlideOnCeiling") -> boolean) &
        ((self: NativeSceneScope, Target: NativeCharacterBody3D, Property: "Velocity") -> NativeVector3) &
        ((self: NativeSceneScope, Target: NativeCharacterBody3D, Property: "UpDirection") -> NativeVector3) &
        ((self: NativeSceneScope, Target: NativeCharacterBody3D, Property: "MaxSlides") -> number) &
        ((self: NativeSceneScope, Target: NativeCharacterBody3D, Property: "FloorMaxAngle") -> number) &
        ((self: NativeSceneScope, Target: NativeCharacterBody3D, Property: "FloorSnapLength") -> number) &
        ((self: NativeSceneScope, Target: NativeCharacterBody3D, Property: "SafeMargin") -> number) &
        ((self: NativeSceneScope, Target: NativeCharacterBody3D, Property: "FloorStopOnSlope") -> boolean) &
        ((self: NativeSceneScope, Target: NativeCharacterBody3D, Property: "FloorConstantSpeed") -> boolean) &
        ((self: NativeSceneScope, Target: NativeCharacterBody3D, Property: "SlideOnCeiling") -> boolean) &
        ((self: NativeSceneScope, Target: NativeNavigationRegion3D, Property: "NavigationMesh") -> NativeNavigationMesh?) &
        ((self: NativeSceneScope, Target: NativeNavigationRegion3D, Property: "Enabled") -> boolean) &
        ((self: NativeSceneScope, Target: NativeNavigationRegion3D, Property: "NavigationLayers") -> number) &
        ((self: NativeSceneScope, Target: NativeNavigationAgent3D, Property: "TargetPosition") -> NativeVector3) &
        ((self: NativeSceneScope, Target: NativeNavigationAgent3D, Property: "NavigationLayers") -> number) &
        ((self: NativeSceneScope, Target: NativeNavigationAgent3D, Property: "PathDesiredDistance") -> number) &
        ((self: NativeSceneScope, Target: NativeNavigationAgent3D, Property: "TargetDesiredDistance") -> number) &
        ((self: NativeSceneScope, Target: NativeNavigationAgent3D, Property: "PathMaxDistance") -> number) &
        ((self: NativeSceneScope, Target: NativeAnimation, Property: "Length") -> number) &
        ((self: NativeSceneScope, Target: NativeAnimation, Property: "LoopMode") -> number) &
        ((self: NativeSceneScope, Target: NativeAnimationPlayer, Property: "SpeedScale") -> number) &
        ((self: NativeSceneScope, Target: NativeAnimationPlayer, Property: "CurrentAnimationPosition") -> number) &
        ((self: NativeSceneScope, Target: NativeAnimationPlayer, Property: "CurrentAnimationLength") -> number)
    Call: ((self: NativeSceneScope, Target: NativeNode3D, Method: "GetGlobalPosition") -> NativeVector3) &
        ((self: NativeSceneScope, Target: NativeControl, Method: "GetGlobalPosition") -> NativeVector2) &
        ((self: NativeSceneScope, Target: NativeNode3D, Method: "ToLocal", global_point: NativeVector3) -> NativeVector3) &
        ((self: NativeSceneScope, Target: NativeNode3D, Method: "ToGlobal", local_point: NativeVector3) -> NativeVector3) &
        ((self: NativeSceneScope, Target: NativeCanvasItem, Method: "Show") -> ()) &
        ((self: NativeSceneScope, Target: NativeCanvasItem, Method: "Hide") -> ()) &
        ((self: NativeSceneScope, Target: NativeCanvasItem, Method: "IsVisible") -> boolean) &
        ((self: NativeSceneScope, Target: NativeControl, Method: "GrabFocus") -> ()) &
        ((self: NativeSceneScope, Target: NativeControl, Method: "ReleaseFocus") -> ()) &
        ((self: NativeSceneScope, Target: NativeControl, Method: "HasFocus") -> boolean) &
        ((self: NativeSceneScope, Target: NativeControl, Method: "GetMinimumSize") -> NativeVector2) &
        ((self: NativeSceneScope, Target: NativeBaseButton, Method: "SetPressedNoSignal", pressed: boolean) -> ()) &
        ((self: NativeSceneScope, Target: NativeBaseButton, Method: "IsPressed") -> boolean) &
        ((self: NativeSceneScope, Target: NativeLineEdit, Method: "Clear") -> ()) &
        ((self: NativeSceneScope, Target: NativeLineEdit, Method: "SelectAll") -> ()) &
        ((self: NativeSceneScope, Target: NativeLineEdit, Method: "Deselect") -> ()) &
        ((self: NativeSceneScope, Target: NativeRange, Method: "SetValueNoSignal", value: number) -> ()) &
        ((self: NativeSceneScope, Target: NativeAudioStreamPlayer, Method: "Play", from_position: number?) -> ()) &
        ((self: NativeSceneScope, Target: NativeAudioStreamPlayer, Method: "Stop") -> ()) &
        ((self: NativeSceneScope, Target: NativeAudioStreamPlayer, Method: "IsPlaying") -> boolean) &
        ((self: NativeSceneScope, Target: NativeAudioStreamPlayer, Method: "GetPlaybackPosition") -> number) &
        ((self: NativeSceneScope, Target: NativeAudioStreamPlayer, Method: "Seek", to_position: number) -> ()) &
        ((self: NativeSceneScope, Target: NativeTexture2D, Method: "GetWidth") -> number) &
        ((self: NativeSceneScope, Target: NativeTexture2D, Method: "GetHeight") -> number) &
        ((self: NativeSceneScope, Target: NativeMesh, Method: "GetSurfaceCount") -> number) &
        ((self: NativeSceneScope, Target: NativeNode, Method: "GetChildCount", include_internal: boolean?) -> number) &
        ((self: NativeSceneScope, Target: (MutableNativeStandardMaterial3D), Method: "SetRoughness", roughness: number) -> ()) &
        ((self: NativeSceneScope, Target: NativeAudioStreamPlayer2D, Method: "Play", from_position: number?) -> ()) &
        ((self: NativeSceneScope, Target: NativeAudioStreamPlayer2D, Method: "Stop") -> ()) &
        ((self: NativeSceneScope, Target: NativeAudioStreamPlayer2D, Method: "IsPlaying") -> boolean) &
        ((self: NativeSceneScope, Target: NativeAudioStreamPlayer3D, Method: "Play", from_position: number?) -> ()) &
        ((self: NativeSceneScope, Target: NativeAudioStreamPlayer3D, Method: "Stop") -> ()) &
        ((self: NativeSceneScope, Target: NativeAudioStreamPlayer3D, Method: "IsPlaying") -> boolean) &
        ((self: NativeSceneScope, Target: NativeTimer, Method: "Start", time_sec: number?) -> ()) &
        ((self: NativeSceneScope, Target: NativeTimer, Method: "Stop") -> ()) &
        ((self: NativeSceneScope, Target: NativeTimer, Method: "IsStopped") -> boolean) &
        ((self: NativeSceneScope, Target: NativeNode2D, Method: "ToLocal", global_point: NativeVector2) -> NativeVector2) &
        ((self: NativeSceneScope, Target: NativeNode2D, Method: "ToGlobal", local_point: NativeVector2) -> NativeVector2) &
        ((self: NativeSceneScope, Target: NativeSprite2D, Method: "GetRect") -> NativeRect2) &
        ((self: NativeSceneScope, Target: NativeRigidBody2D, Method: "ApplyCentralImpulse", impulse: NativeVector2?) -> ()) &
        ((self: NativeSceneScope, Target: NativeRigidBody2D, Method: "ApplyImpulse", impulse: NativeVector2, position: NativeVector2?) -> ()) &
        ((self: NativeSceneScope, Target: NativeRigidBody2D, Method: "ApplyCentralForce", force: NativeVector2) -> ()) &
        ((self: NativeSceneScope, Target: NativeRigidBody2D, Method: "ApplyForce", force: NativeVector2, position: NativeVector2?) -> ()) &
        ((self: NativeSceneScope, Target: NativeRigidBody2D, Method: "ApplyTorque", torque: number) -> ()) &
        ((self: NativeSceneScope, Target: NativeRigidBody2D, Method: "ApplyTorqueImpulse", torque: number) -> ()) &
        ((self: NativeSceneScope, Target: NativeRigidBody2D, Method: "GetContactCount") -> number) &
        ((self: NativeSceneScope, Target: NativeArea2D, Method: "HasOverlappingBodies") -> boolean) &
        ((self: NativeSceneScope, Target: NativeArea2D, Method: "HasOverlappingAreas") -> boolean) &
        ((self: NativeSceneScope, Target: NativeAnimatedSprite2D, Method: "IsPlaying") -> boolean) &
        ((self: NativeSceneScope, Target: NativeAnimatedSprite2D, Method: "GetPlayingSpeed") -> number) &
        ((self: NativeSceneScope, Target: NativeAnimatedSprite2D, Method: "Play", name: string?, custom_speed: number?, from_end: boolean?) -> ()) &
        ((self: NativeSceneScope, Target: NativeAnimatedSprite2D, Method: "PlayBackwards", name: string?) -> ()) &
        ((self: NativeSceneScope, Target: NativeAnimatedSprite2D, Method: "Pause") -> ()) &
        ((self: NativeSceneScope, Target: NativeAnimatedSprite2D, Method: "Stop") -> ()) &
        ((self: NativeSceneScope, Target: NativeSpriteFrames, Method: "HasAnimation", anim: string) -> boolean) &
        ((self: NativeSceneScope, Target: NativeSpriteFrames, Method: "GetAnimationNames") -> {string}) &
        ((self: NativeSceneScope, Target: (MutableNativeSpriteFrames), Method: "AddAnimation", anim: string) -> ()) &
        ((self: NativeSceneScope, Target: (MutableNativeSpriteFrames), Method: "SetAnimationSpeed", anim: string, fps: number) -> ()) &
        ((self: NativeSceneScope, Target: NativeSpriteFrames, Method: "GetAnimationSpeed", anim: string) -> number) &
        ((self: NativeSceneScope, Target: (MutableNativeSpriteFrames), Method: "SetAnimationLoop", anim: string, loop: boolean) -> ()) &
        ((self: NativeSceneScope, Target: NativeSpriteFrames, Method: "GetAnimationLoop", anim: string) -> boolean) &
        ((self: NativeSceneScope, Target: NativeSpriteFrames, Method: "GetFrameCount", anim: string) -> number) &
        ((self: NativeSceneScope, Target: NativeSpriteFrames, Method: "GetFrameTexture", anim: string, idx: number) -> NativeTexture2D?) &
        ((self: NativeSceneScope, Target: (MutableNativeSpriteFrames), Method: "RemoveFrame", anim: string, idx: number) -> ()) &
        ((self: NativeSceneScope, Target: (MutableNativeSpriteFrames), Method: "AddFrame", anim: string, texture: NativeTexture2D?, duration: number?, at_position: number?) -> ()) &
        ((self: NativeSceneScope, Target: NativeItemList, Method: "AddItem", text: string, icon: NativeTexture2D??, selectable: boolean?) -> number) &
        ((self: NativeSceneScope, Target: NativeItemList, Method: "GetItemCount") -> number) &
        ((self: NativeSceneScope, Target: NativeItemList, Method: "GetItemText", idx: number) -> string) &
        ((self: NativeSceneScope, Target: NativeItemList, Method: "SetItemText", idx: number, text: string) -> ()) &
        ((self: NativeSceneScope, Target: NativeItemList, Method: "GetItemIcon", idx: number) -> NativeTexture2D?) &
        ((self: NativeSceneScope, Target: NativeItemList, Method: "SetItemIcon", idx: number, icon: NativeTexture2D?) -> ()) &
        ((self: NativeSceneScope, Target: NativeItemList, Method: "IsSelected", idx: number) -> boolean) &
        ((self: NativeSceneScope, Target: NativeItemList, Method: "Select", idx: number, single: boolean?) -> ()) &
        ((self: NativeSceneScope, Target: NativeItemList, Method: "Deselect", idx: number) -> ()) &
        ((self: NativeSceneScope, Target: NativeItemList, Method: "DeselectAll") -> ()) &
        ((self: NativeSceneScope, Target: NativeItemList, Method: "RemoveItem", idx: number) -> ()) &
        ((self: NativeSceneScope, Target: NativeItemList, Method: "Clear") -> ()) &
        ((self: NativeSceneScope, Target: NativeItemList, Method: "GetSelectedItems") -> {number}) &
        ((self: NativeSceneScope, Target: NativeTextEdit, Method: "GetLineCount") -> number) &
        ((self: NativeSceneScope, Target: NativeTextEdit, Method: "GetSelectedText", caret_index: number?) -> string) &
        ((self: NativeSceneScope, Target: NativeTextEdit, Method: "HasSelection", caret_index: number?) -> boolean) &
        ((self: NativeSceneScope, Target: NativeTextEdit, Method: "Deselect", caret_index: number?) -> ()) &
        ((self: NativeSceneScope, Target: NativeRichTextLabel, Method: "Clear") -> ()) &
        ((self: NativeSceneScope, Target: NativeRichTextLabel, Method: "GetTotalCharacterCount") -> number) &
        ((self: NativeSceneScope, Target: (MutableNativeMultiMesh), Method: "SetInstanceTransform", instance: number, transform: NativeTransform3D) -> ()) &
        ((self: NativeSceneScope, Target: NativeMultiMesh, Method: "GetInstanceTransform", instance: number) -> NativeTransform3D) &
        ((self: NativeSceneScope, Target: (MutableNativeMultiMesh), Method: "SetInstanceTransform2d", instance: number, transform: NativeTransform2D) -> ()) &
        ((self: NativeSceneScope, Target: NativeMultiMesh, Method: "GetInstanceTransform2d", instance: number) -> NativeTransform2D) &
        ((self: NativeSceneScope, Target: (MutableNativeMultiMesh), Method: "SetInstanceColor", instance: number, color: NativeColor4) -> ()) &
        ((self: NativeSceneScope, Target: NativeMultiMesh, Method: "GetInstanceColor", instance: number) -> NativeColor4) &
        ((self: NativeSceneScope, Target: NativeMesh, Method: "GetAabb") -> NativeAABB) &
        ((self: NativeSceneScope, Target: (MutableNativeShaderMaterial), Method: "SetShaderParameter", param: string, value: NativeVariant) -> ()) &
        ((self: NativeSceneScope, Target: NativeShaderMaterial, Method: "GetShaderParameter", param: string) -> NativeVariant) &
        ((self: NativeSceneScope, Target: NativeGradient, Method: "GetPointCount") -> number) &
        ((self: NativeSceneScope, Target: (MutableNativeGradient), Method: "Sample", offset: number) -> NativeColor4) &
        ((self: NativeSceneScope, Target: (MutableNativeGradient), Method: "GetColor", point: number) -> NativeColor4) &
        ((self: NativeSceneScope, Target: (MutableNativeGradient), Method: "SetColor", point: number, color: NativeColor4) -> ()) &
        ((self: NativeSceneScope, Target: (MutableNativeGradient), Method: "GetOffset", point: number) -> number) &
        ((self: NativeSceneScope, Target: (MutableNativeGradient), Method: "SetOffset", point: number, offset: number) -> ()) &
        ((self: NativeSceneScope, Target: (MutableNativeGradient), Method: "AddPoint", offset: number, color: NativeColor4) -> ()) &
        ((self: NativeSceneScope, Target: (MutableNativeGradient), Method: "RemovePoint", point: number) -> ()) &
        ((self: NativeSceneScope, Target: NativeRayCast2D, Method: "IsColliding") -> boolean) &
        ((self: NativeSceneScope, Target: NativeRayCast2D, Method: "GetCollisionPoint") -> NativeVector2) &
        ((self: NativeSceneScope, Target: NativeRayCast2D, Method: "GetCollisionNormal") -> NativeVector2) &
        ((self: NativeSceneScope, Target: NativeRayCast2D, Method: "ForceRaycastUpdate") -> ()) &
        ((self: NativeSceneScope, Target: NativeRayCast2D, Method: "AddException", node: NativeCollisionObject2D?) -> ()) &
        ((self: NativeSceneScope, Target: NativeRayCast2D, Method: "ClearExceptions") -> ()) &
        ((self: NativeSceneScope, Target: NativeRayCast2D, Method: "GetCollider") -> NativeCollisionObject2D?) &
        ((self: NativeSceneScope, Target: NativeRayCast3D, Method: "IsColliding") -> boolean) &
        ((self: NativeSceneScope, Target: NativeRayCast3D, Method: "GetCollisionPoint") -> NativeVector3) &
        ((self: NativeSceneScope, Target: NativeRayCast3D, Method: "GetCollisionNormal") -> NativeVector3) &
        ((self: NativeSceneScope, Target: NativeRayCast3D, Method: "ForceRaycastUpdate") -> ()) &
        ((self: NativeSceneScope, Target: NativeRayCast3D, Method: "AddException", node: NativeCollisionObject3D?) -> ()) &
        ((self: NativeSceneScope, Target: NativeRayCast3D, Method: "ClearExceptions") -> ()) &
        ((self: NativeSceneScope, Target: NativeRayCast3D, Method: "GetCollider") -> NativeCollisionObject3D?) &
        ((self: NativeSceneScope, Target: NativeCharacterBody2D, Method: "MoveAndSlide") -> boolean) &
        ((self: NativeSceneScope, Target: NativeCharacterBody2D, Method: "IsOnFloor") -> boolean) &
        ((self: NativeSceneScope, Target: NativeCharacterBody2D, Method: "IsOnWall") -> boolean) &
        ((self: NativeSceneScope, Target: NativeCharacterBody2D, Method: "IsOnCeiling") -> boolean) &
        ((self: NativeSceneScope, Target: NativeCharacterBody2D, Method: "GetFloorNormal") -> NativeVector2) &
        ((self: NativeSceneScope, Target: NativeCharacterBody2D, Method: "GetSlideCollisionCount") -> number) &
        ((self: NativeSceneScope, Target: NativeCharacterBody3D, Method: "MoveAndSlide") -> boolean) &
        ((self: NativeSceneScope, Target: NativeCharacterBody3D, Method: "IsOnFloor") -> boolean) &
        ((self: NativeSceneScope, Target: NativeCharacterBody3D, Method: "IsOnWall") -> boolean) &
        ((self: NativeSceneScope, Target: NativeCharacterBody3D, Method: "IsOnCeiling") -> boolean) &
        ((self: NativeSceneScope, Target: NativeCharacterBody3D, Method: "GetFloorNormal") -> NativeVector3) &
        ((self: NativeSceneScope, Target: NativeCharacterBody3D, Method: "GetSlideCollisionCount") -> number) &
        ((self: NativeSceneScope, Target: NativeNavigationAgent3D, Method: "GetNextPathPosition") -> NativeVector3) &
        ((self: NativeSceneScope, Target: NativeNavigationAgent3D, Method: "GetCurrentNavigationPath") -> {NativeVector3}) &
        ((self: NativeSceneScope, Target: NativeNavigationAgent3D, Method: "GetFinalPosition") -> NativeVector3) &
        ((self: NativeSceneScope, Target: NativeNavigationAgent3D, Method: "IsNavigationFinished") -> boolean) &
        ((self: NativeSceneScope, Target: NativeNavigationAgent3D, Method: "IsTargetReached") -> boolean) &
        ((self: NativeSceneScope, Target: NativeNavigationAgent3D, Method: "IsTargetReachable") -> boolean) &
        ((self: NativeSceneScope, Target: NativeSkeleton3D, Method: "AddBone", name: string) -> number) &
        ((self: NativeSceneScope, Target: NativeSkeleton3D, Method: "FindBone", name: string) -> number) &
        ((self: NativeSceneScope, Target: NativeSkeleton3D, Method: "GetBoneCount") -> number) &
        ((self: NativeSceneScope, Target: NativeSkeleton3D, Method: "GetBoneName", bone_idx: number) -> string) &
        ((self: NativeSceneScope, Target: NativeSkeleton3D, Method: "GetBoneParent", bone_idx: number) -> number) &
        ((self: NativeSceneScope, Target: NativeSkeleton3D, Method: "GetBoneRest", bone_idx: number) -> NativeTransform3D) &
        ((self: NativeSceneScope, Target: NativeSkeleton3D, Method: "GetBoneGlobalRest", bone_idx: number) -> NativeTransform3D) &
        ((self: NativeSceneScope, Target: NativeSkeleton3D, Method: "GetBonePose", bone_idx: number) -> NativeTransform3D) &
        ((self: NativeSceneScope, Target: NativeSkeleton3D, Method: "GetBonePosePosition", bone_idx: number) -> NativeVector3) &
        ((self: NativeSceneScope, Target: NativeSkeleton3D, Method: "GetBonePoseRotation", bone_idx: number) -> NativeQuaternion) &
        ((self: NativeSceneScope, Target: NativeSkeleton3D, Method: "GetBonePoseScale", bone_idx: number) -> NativeVector3) &
        ((self: NativeSceneScope, Target: NativeSkeleton3D, Method: "SetBoneParent", bone_idx: number, parent_idx: number) -> ()) &
        ((self: NativeSceneScope, Target: NativeSkeleton3D, Method: "SetBoneRest", bone_idx: number, rest: NativeTransform3D) -> ()) &
        ((self: NativeSceneScope, Target: NativeSkeleton3D, Method: "SetBonePosePosition", bone_idx: number, position: NativeVector3) -> ()) &
        ((self: NativeSceneScope, Target: NativeSkeleton3D, Method: "SetBonePoseRotation", bone_idx: number, rotation: NativeQuaternion) -> ()) &
        ((self: NativeSceneScope, Target: NativeSkeleton3D, Method: "SetBonePoseScale", bone_idx: number, scale: NativeVector3) -> ()) &
        ((self: NativeSceneScope, Target: NativeSkeleton3D, Method: "ResetBonePose", bone_idx: number) -> ()) &
        ((self: NativeSceneScope, Target: (MutableNativeAnimation), Method: "AddTrack", type: number, at_position: number?) -> number) &
        ((self: NativeSceneScope, Target: NativeAnimation, Method: "GetTrackCount") -> number) &
        ((self: NativeSceneScope, Target: (MutableNativeAnimation), Method: "RemoveTrack", track_idx: number) -> ()) &
        ((self: NativeSceneScope, Target: (MutableNativeAnimation), Method: "TrackSetPath", track_idx: number, path: string) -> ()) &
        ((self: NativeSceneScope, Target: NativeAnimation, Method: "TrackGetPath", track_idx: number) -> string) &
        ((self: NativeSceneScope, Target: NativeAnimation, Method: "TrackGetKeyCount", track_idx: number) -> number) &
        ((self: NativeSceneScope, Target: (MutableNativeAnimation), Method: "TrackSetInterpolationType", track_idx: number, interpolation: number) -> ()) &
        ((self: NativeSceneScope, Target: (MutableNativeAnimation), Method: "TrackInsertKey", track_idx: number, time: number, key: NativeVariant, transition: number?) -> number) &
        ((self: NativeSceneScope, Target: (MutableNativeAnimationLibrary), Method: "AddAnimation", name: string, animation: NativeAnimation?) -> number) &
        ((self: NativeSceneScope, Target: NativeAnimationLibrary, Method: "GetAnimationList") -> {string}) &
        ((self: NativeSceneScope, Target: NativeAnimationLibrary, Method: "GetAnimation", name: string) -> NativeAnimation?) &
        ((self: NativeSceneScope, Target: NativeAnimationPlayer, Method: "AddAnimationLibrary", name: string, library: NativeAnimationLibrary?) -> number) &
        ((self: NativeSceneScope, Target: NativeAnimationPlayer, Method: "GetAnimationList") -> {string}) &
        ((self: NativeSceneScope, Target: NativeAnimationPlayer, Method: "Play", name: string?, custom_blend: number?, custom_speed: number?, from_end: boolean?) -> ()) &
        ((self: NativeSceneScope, Target: NativeAnimationPlayer, Method: "Stop", keep_state: boolean?) -> ()) &
        ((self: NativeSceneScope, Target: NativeAnimationPlayer, Method: "Pause") -> ()) &
        ((self: NativeSceneScope, Target: NativeAnimationPlayer, Method: "IsPlaying") -> boolean)
    Connect: ((self: NativeSceneScope, Source: NativeBaseButton, Signal: "Pressed", Callback: () -> ()) -> NativeConnection) &
        ((self: NativeSceneScope, Source: NativeBaseButton, Signal: "Toggled", Callback: (boolean) -> ()) -> NativeConnection) &
        ((self: NativeSceneScope, Source: NativeBaseButton, Signal: "ButtonDown", Callback: () -> ()) -> NativeConnection) &
        ((self: NativeSceneScope, Source: NativeBaseButton, Signal: "ButtonUp", Callback: () -> ()) -> NativeConnection) &
        ((self: NativeSceneScope, Source: NativeLineEdit, Signal: "TextSubmitted", Callback: (string) -> ()) -> NativeConnection) &
        ((self: NativeSceneScope, Source: NativeLineEdit, Signal: "TextChanged", Callback: (string) -> ()) -> NativeConnection) &
        ((self: NativeSceneScope, Source: NativeAudioStreamPlayer, Signal: "Finished", Callback: () -> ()) -> NativeConnection) &
        ((self: NativeSceneScope, Source: NativeControl, Signal: "Resized", Callback: () -> ()) -> NativeConnection) &
        ((self: NativeSceneScope, Source: NativeControl, Signal: "FocusEntered", Callback: () -> ()) -> NativeConnection) &
        ((self: NativeSceneScope, Source: NativeControl, Signal: "FocusExited", Callback: () -> ()) -> NativeConnection) &
        ((self: NativeSceneScope, Source: NativeCanvasItem, Signal: "VisibilityChanged", Callback: () -> ()) -> NativeConnection) &
        ((self: NativeSceneScope, Source: NativeRange, Signal: "ValueChanged", Callback: (number) -> ()) -> NativeConnection) &
        ((self: NativeSceneScope, Source: NativeAudioStreamPlayer2D, Signal: "Finished", Callback: () -> ()) -> NativeConnection) &
        ((self: NativeSceneScope, Source: NativeAudioStreamPlayer3D, Signal: "Finished", Callback: () -> ()) -> NativeConnection) &
        ((self: NativeSceneScope, Source: NativeTimer, Signal: "Timeout", Callback: () -> ()) -> NativeConnection) &
        ((self: NativeSceneScope, Source: NativeRigidBody2D, Signal: "BodyEntered", Callback: (NativeNode?) -> ()) -> NativeConnection) &
        ((self: NativeSceneScope, Source: NativeRigidBody2D, Signal: "BodyExited", Callback: (NativeNode?) -> ()) -> NativeConnection) &
        ((self: NativeSceneScope, Source: NativeArea2D, Signal: "BodyEntered", Callback: (NativeNode2D?) -> ()) -> NativeConnection) &
        ((self: NativeSceneScope, Source: NativeArea2D, Signal: "BodyExited", Callback: (NativeNode2D?) -> ()) -> NativeConnection) &
        ((self: NativeSceneScope, Source: NativeAnimatedSprite2D, Signal: "AnimationFinished", Callback: () -> ()) -> NativeConnection) &
        ((self: NativeSceneScope, Source: NativeAnimatedSprite2D, Signal: "AnimationLooped", Callback: () -> ()) -> NativeConnection) &
        ((self: NativeSceneScope, Source: NativeAnimatedSprite2D, Signal: "FrameChanged", Callback: () -> ()) -> NativeConnection) &
        ((self: NativeSceneScope, Source: NativeAnimatedSprite2D, Signal: "AnimationChanged", Callback: () -> ()) -> NativeConnection) &
        ((self: NativeSceneScope, Source: NativeItemList, Signal: "ItemSelected", Callback: (number) -> ()) -> NativeConnection) &
        ((self: NativeSceneScope, Source: NativeItemList, Signal: "MultiSelected", Callback: (number, boolean) -> ()) -> NativeConnection) &
        ((self: NativeSceneScope, Source: NativeItemList, Signal: "EmptyClicked", Callback: (NativeVector2, number) -> ()) -> NativeConnection) &
        ((self: NativeSceneScope, Source: NativeItemList, Signal: "ItemActivated", Callback: (number) -> ()) -> NativeConnection) &
        ((self: NativeSceneScope, Source: NativeTextEdit, Signal: "TextChanged", Callback: () -> ()) -> NativeConnection) &
        ((self: NativeSceneScope, Source: NativeNavigationAgent3D, Signal: "PathChanged", Callback: () -> ()) -> NativeConnection) &
        ((self: NativeSceneScope, Source: NativeNavigationAgent3D, Signal: "TargetReached", Callback: () -> ()) -> NativeConnection) &
        ((self: NativeSceneScope, Source: NativeNavigationAgent3D, Signal: "NavigationFinished", Callback: () -> ()) -> NativeConnection) &
        ((self: NativeSceneScope, Source: NativeSkeleton3D, Signal: "PoseUpdated", Callback: () -> ()) -> NativeConnection) &
        ((self: NativeSceneScope, Source: NativeAnimationPlayer, Signal: "AnimationFinished", Callback: (string) -> ()) -> NativeConnection)
    Load: ((self: NativeSceneScope, Type: "Texture2D", Path: string) -> NativeTexture2D) &
        ((self: NativeSceneScope, Type: "AudioStream", Path: string) -> NativeAudioStream) &
        ((self: NativeSceneScope, Type: "Mesh", Path: string) -> NativeMesh) &
        ((self: NativeSceneScope, Type: "Font", Path: string) -> NativeFont) &
        ((self: NativeSceneScope, Type: "PackedScene", Path: string) -> NativePackedScene) &
        ((self: NativeSceneScope, Type: "SpriteFrames", Path: string) -> NativeSpriteFrames) &
        ((self: NativeSceneScope, Type: "Shader", Path: string) -> NativeShader) &
        ((self: NativeSceneScope, Type: "Material", Path: string) -> NativeMaterial) &
        ((self: NativeSceneScope, Type: "Theme", Path: string) -> NativeTheme) &
        ((self: NativeSceneScope, Type: "StyleBox", Path: string) -> NativeStyleBox) &
        ((self: NativeSceneScope, Type: "Shape2D", Path: string) -> NativeShape2D) &
        ((self: NativeSceneScope, Type: "Shape3D", Path: string) -> NativeShape3D) &
        ((self: NativeSceneScope, Type: "Gradient", Path: string) -> NativeGradient) &
        ((self: NativeSceneScope, Type: "NavigationMesh", Path: string) -> NativeNavigationMesh) &
        ((self: NativeSceneScope, Type: "Animation", Path: string) -> NativeAnimation) &
        ((self: NativeSceneScope, Type: "AnimationLibrary", Path: string) -> NativeAnimationLibrary)
    Instantiate: (self: NativeSceneScope, Scene: NativePackedScene, Parent: NativeNode?) -> NativeNode
    Clone: (self: NativeSceneScope, Source: NativeNode, Parent: NativeNode?) -> NativeNode
    Reparent: (self: NativeSceneScope, Target: NativeNode, Parent: NativeNode, KeepGlobal: boolean?) -> ()
    Mesh: (self: NativeSceneScope, Primitive: NativePrimitiveMesh) -> NativeArrayMesh
    Pin: (self: NativeSceneScope, Body: NativeSoftBody3D, Vertex: number, Pinned: boolean) -> ()
    Tone: (self: NativeSceneScope, Frequency: number, Seconds: number) -> NativeAudioStream
    Play: (self: NativeSceneScope, Player: NativeAudioStreamPlayer) -> ()
    Stop: (self: NativeSceneScope, Player: NativeAudioStreamPlayer) -> ()
    Impulse: (self: NativeSceneScope, Body: NativeRigidBody3D, Impulse: NativeVector3) -> ()
end
declare Scene: { new: (Parent: NativeNode) -> NativeSceneScope, Classes: () -> {string}, Value: ((Type: "Vector3", Value: NativeVector3) -> NativeVector3) & ((Type: "Vector2", Value: NativeVector2) -> NativeVector2) & ((Type: "Vector2i", Value: NativeVector2i) -> NativeVector2i) & ((Type: "Vector3i", Value: NativeVector3i) -> NativeVector3i) & ((Type: "Vector4", Value: NativeVector4) -> NativeVector4) & ((Type: "Vector4i", Value: NativeVector4i) -> NativeVector4i) & ((Type: "Rect2", Value: NativeRect2) -> NativeRect2) & ((Type: "Rect2i", Value: NativeRect2i) -> NativeRect2i) & ((Type: "Quaternion", Value: NativeQuaternion) -> NativeQuaternion) & ((Type: "Basis", Value: NativeBasis) -> NativeBasis) & ((Type: "Transform2D", Value: NativeTransform2D) -> NativeTransform2D) & ((Type: "Transform3D", Value: NativeTransform3D) -> NativeTransform3D) & ((Type: "Plane", Value: NativePlane) -> NativePlane) & ((Type: "AABB", Value: NativeAABB) -> NativeAABB) & ((Type: "Array", Value: {NativeVariant}) -> {NativeVariant}) & ((Type: "Dictionary", Value: {[string]: NativeVariant}) -> {[string]: NativeVariant}) & ((Type: "NodePath", Value: string) -> string) & ((Type: "PackedByteArray", Value: {number}) -> {number}) & ((Type: "PackedInt32Array", Value: {number}) -> {number}) & ((Type: "PackedInt64Array", Value: {number}) -> {number}) & ((Type: "PackedFloat32Array", Value: {number}) -> {number}) & ((Type: "PackedFloat64Array", Value: {number}) -> {number}) & ((Type: "PackedStringArray", Value: {string}) -> {string}) & ((Type: "PackedVector2Array", Value: {NativeVector2}) -> {NativeVector2}) & ((Type: "PackedVector3Array", Value: {NativeVector3}) -> {NativeVector3}) & ((Type: "PackedColorArray", Value: {NativeColor4}) -> {NativeColor4}) & ((Type: "PackedVector4Array", Value: {NativeVector4}) -> {NativeVector4}) & ((Type: "Color", Value: NativeColor4) -> NativeColor4),
    PolicySHA256: string, ApiSHA256: string, Describe: (Class: string) -> { [string]: any }?, Enums: {Control: {MouseFilter: {MOUSE_FILTER_STOP: number, MOUSE_FILTER_PASS: number, MOUSE_FILTER_IGNORE: number}}, TextureRect: {ExpandMode: {EXPAND_KEEP_SIZE: number, EXPAND_IGNORE_SIZE: number, EXPAND_FIT_WIDTH: number, EXPAND_FIT_WIDTH_PROPORTIONAL: number, EXPAND_FIT_HEIGHT: number, EXPAND_FIT_HEIGHT_PROPORTIONAL: number}, StretchMode: {STRETCH_SCALE: number, STRETCH_TILE: number, STRETCH_KEEP: number, STRETCH_KEEP_CENTERED: number, STRETCH_KEEP_ASPECT: number, STRETCH_KEEP_ASPECT_CENTERED: number, STRETCH_KEEP_ASPECT_COVERED: number}}, BaseMaterial3D: {Transparency: {TRANSPARENCY_DISABLED: number, TRANSPARENCY_ALPHA: number, TRANSPARENCY_ALPHA_SCISSOR: number, TRANSPARENCY_ALPHA_HASH: number, TRANSPARENCY_ALPHA_DEPTH_PRE_PASS: number, TRANSPARENCY_MAX: number}}, Timer: {TimerProcessCallback: {TIMER_PROCESS_PHYSICS: number, TIMER_PROCESS_IDLE: number}}, RigidBody2D: {FreezeMode: {FREEZE_MODE_STATIC: number, FREEZE_MODE_KINEMATIC: number}}, Camera2D: {AnchorMode: {ANCHOR_MODE_FIXED_TOP_LEFT: number, ANCHOR_MODE_DRAG_CENTER: number}}, ItemList: {SelectMode: {SELECT_SINGLE: number, SELECT_MULTI: number}, IconMode: {ICON_MODE_TOP: number, ICON_MODE_LEFT: number}}, TextureProgressBar: {FillMode: {FILL_LEFT_TO_RIGHT: number, FILL_RIGHT_TO_LEFT: number, FILL_TOP_TO_BOTTOM: number, FILL_BOTTOM_TO_TOP: number, FILL_CLOCKWISE: number, FILL_COUNTER_CLOCKWISE: number, FILL_BILINEAR_LEFT_AND_RIGHT: number, FILL_BILINEAR_TOP_AND_BOTTOM: number, FILL_CLOCKWISE_AND_COUNTER_CLOCKWISE: number}}, MultiMesh: {TransformFormat: {TRANSFORM_2D: number, TRANSFORM_3D: number}}, Animation: {TrackType: {TYPE_VALUE: number}, InterpolationType: {INTERPOLATION_NEAREST: number, INTERPOLATION_LINEAR: number}, LoopMode: {LOOP_NONE: number, LOOP_LINEAR: number, LOOP_PINGPONG: number}}} }
