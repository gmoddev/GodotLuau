-- Generated approved native definitions. Load as a definitions file, never require it.
-- Policy SHA256: 115d4506bef5b4285bedc8a209952fb615b28eedee3a1c339cb8d65696601020
type NativeVector2 = { X: number, Y: number }
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
type NativeConnection = { Disconnect: (self: NativeConnection) -> (), Connected: boolean }
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
declare class NativeAudioStreamPlayer extends NativeNode
    Stream: NativeAudioStream?
    VolumeDb: number
    PitchScale: number
end
declare class NativeCanvasItem extends NativeNode
    Visible: boolean
    Modulate: NativeColor3
end
declare class NativeCanvasLayer extends NativeNode
    Layer: number
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
declare class NativeWorldEnvironment extends NativeNode
    Environment: NativeEnvironment?
end
declare class NativeAudioStream extends NativeResource
end
declare class MutableNativeAudioStream extends NativeAudioStream
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
    Visible: boolean
    Position: NativeVector2
    Size: NativeVector2
    MinSize: NativeVector2
    MouseFilter: number
    Modulate: NativeColor3
    FontSize: number
    Font: NativeFont?
end
declare class NativeEnvironment extends NativeResource
end
declare class MutableNativeEnvironment extends NativeEnvironment
end
declare class NativeFont extends NativeResource
end
declare class MutableNativeFont extends NativeFont
end
declare class NativeMaterial extends NativeResource
end
declare class MutableNativeMaterial extends NativeMaterial
end
declare class NativeMesh extends NativeResource
end
declare class MutableNativeMesh extends NativeMesh
end
declare class NativeNode2D extends NativeCanvasItem
    Position: NativeVector2
    RotationDegrees: number
    Scale: NativeVector2
end
declare class NativePackedScene extends NativeResource
end
declare class MutableNativePackedScene extends NativePackedScene
end
declare class NativeShape3D extends NativeResource
end
declare class MutableNativeShape3D extends NativeShape3D
end
declare class NativeTexture extends NativeResource
end
declare class MutableNativeTexture extends NativeTexture
end
declare class NativeVisualInstance3D extends NativeNode3D
end
declare class NativeArrayMesh extends NativeMesh
end
declare class MutableNativeArrayMesh extends NativeArrayMesh
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
declare class NativeCapsuleShape3D extends NativeShape3D
end
declare class MutableNativeCapsuleShape3D extends NativeCapsuleShape3D
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
declare class NativeSphereShape3D extends NativeShape3D
end
declare class MutableNativeSphereShape3D extends NativeSphereShape3D
end
declare class NativeSprite2D extends NativeNode2D
    Texture: NativeTexture2D?
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
declare class NativeCylinderMesh extends NativePrimitiveMesh
end
declare class MutableNativeCylinderMesh extends NativeCylinderMesh
end
declare class NativeDirectionalLight3D extends NativeLight3D
end
declare class NativeGridContainer extends NativeContainer
    Columns: number
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
declare class NativeOmniLight3D extends NativeLight3D
    Range: number
end
declare class NativePanelContainer extends NativeContainer
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
declare class NativeCheckBox extends NativeButton
end
declare class NativeCheckButton extends NativeButton
end
declare class NativeHBoxContainer extends NativeBoxContainer
end
declare class NativeHSlider extends NativeSlider
end
declare class NativeQuadMesh extends NativePlaneMesh
end
declare class MutableNativeQuadMesh extends NativeQuadMesh
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
declare class NativeVBoxContainer extends NativeBoxContainer
end
declare class NativeVSlider extends NativeSlider
end
type NativeArrayMeshProperties = {
}
type NativeAudioStreamProperties = {
}
type NativeAudioStreamPlayerProperties = {
    Name: (string)?,
    Stream: (NativeAudioStream?)?,
    VolumeDb: (number)?,
    PitchScale: (number)?,
}
type NativeBaseButtonProperties = {
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
}
type NativeBaseMaterial3DProperties = {
    AlbedoTexture: (NativeTexture2D?)?,
    Metallic: (number)?,
    Transparency: (number)?,
}
type NativeBoxContainerProperties = {
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
}
type NativeBoxMeshProperties = {
    Size: (NativeVector3)?,
}
type NativeBoxShape3DProperties = {
    Size: (NativeVector3)?,
}
type NativeButtonProperties = {
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
}
type NativeCamera3DProperties = {
    Name: (string)?,
    Position: (NativeVector3)?,
    RotationDegrees: (NativeVector3)?,
    Scale: (NativeVector3)?,
    Visible: (boolean)?,
    Fov: (number)?,
    Near: (number)?,
    Far: (number)?,
}
type NativeCanvasItemProperties = {
    Name: (string)?,
    Visible: (boolean)?,
    Modulate: (NativeColor3)?,
}
type NativeCanvasLayerProperties = {
    Name: (string)?,
    Layer: (number)?,
}
type NativeCapsuleMeshProperties = {
    Radius: (number)?,
    Height: (number)?,
    RadialSegments: (number)?,
    Rings: (number)?,
}
type NativeCapsuleShape3DProperties = {
    Radius: (number)?,
    Height: (number)?,
}
type NativeCenterContainerProperties = {
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
}
type NativeCheckBoxProperties = {
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
}
type NativeCheckButtonProperties = {
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
}
type NativeCollisionObject3DProperties = {
    Name: (string)?,
    Position: (NativeVector3)?,
    RotationDegrees: (NativeVector3)?,
    Scale: (NativeVector3)?,
    Visible: (boolean)?,
    CollisionLayer: (number)?,
    CollisionMask: (number)?,
}
type NativeCollisionShape3DProperties = {
    Name: (string)?,
    Position: (NativeVector3)?,
    RotationDegrees: (NativeVector3)?,
    Scale: (NativeVector3)?,
    Visible: (boolean)?,
    Shape: (NativeShape3D?)?,
    Disabled: (boolean)?,
}
type NativeColorRectProperties = {
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
}
type NativeContainerProperties = {
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
}
type NativeControlProperties = {
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
}
type NativeCylinderMeshProperties = {
    TopRadius: (number)?,
    BottomRadius: (number)?,
    Height: (number)?,
    RadialSegments: (number)?,
    Rings: (number)?,
}
type NativeCylinderShape3DProperties = {
    Radius: (number)?,
    Height: (number)?,
}
type NativeDirectionalLight3DProperties = {
    Name: (string)?,
    Position: (NativeVector3)?,
    RotationDegrees: (NativeVector3)?,
    Scale: (NativeVector3)?,
    Visible: (boolean)?,
    Color: (NativeColor3)?,
    Energy: (number)?,
    ShadowEnabled: (boolean)?,
}
type NativeEnvironmentProperties = {
    BackgroundMode: (number)?,
    BackgroundColor: (NativeColor3)?,
    AmbientLightSource: (number)?,
    AmbientLightColor: (NativeColor3)?,
    AmbientLightEnergy: (number)?,
}
type NativeFontProperties = {
}
type NativeGeometryInstance3DProperties = {
    Name: (string)?,
    Position: (NativeVector3)?,
    RotationDegrees: (NativeVector3)?,
    Scale: (NativeVector3)?,
    Visible: (boolean)?,
    Material: (NativeMaterial?)?,
}
type NativeGridContainerProperties = {
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
}
type NativeHBoxContainerProperties = {
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
}
type NativeHSliderProperties = {
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
}
type NativeLabelProperties = {
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
}
type NativeLabel3DProperties = {
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
type NativeLight3DProperties = {
    Name: (string)?,
    Position: (NativeVector3)?,
    RotationDegrees: (NativeVector3)?,
    Scale: (NativeVector3)?,
    Visible: (boolean)?,
    Color: (NativeColor3)?,
    Energy: (number)?,
    ShadowEnabled: (boolean)?,
}
type NativeLineEditProperties = {
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
}
type NativeMarginContainerProperties = {
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
}
type NativeMaterialProperties = {
}
type NativeMeshProperties = {
}
type NativeMeshInstance3DProperties = {
    Name: (string)?,
    Position: (NativeVector3)?,
    RotationDegrees: (NativeVector3)?,
    Scale: (NativeVector3)?,
    Visible: (boolean)?,
    Mesh: (NativeMesh?)?,
    Material: (NativeMaterial?)?,
}
type NativeNodeProperties = {
    Name: (string)?,
}
type NativeNode2DProperties = {
    Name: (string)?,
    Position: (NativeVector2)?,
    RotationDegrees: (number)?,
    Scale: (NativeVector2)?,
    Visible: (boolean)?,
    Modulate: (NativeColor3)?,
}
type NativeNode3DProperties = {
    Name: (string)?,
    Position: (NativeVector3)?,
    RotationDegrees: (NativeVector3)?,
    Scale: (NativeVector3)?,
    Visible: (boolean)?,
}
type NativeObjectProperties = {
}
type NativeOmniLight3DProperties = {
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
type NativePackedSceneProperties = {
}
type NativePanelContainerProperties = {
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
}
type NativePhysicsBody3DProperties = {
    Name: (string)?,
    Position: (NativeVector3)?,
    RotationDegrees: (NativeVector3)?,
    Scale: (NativeVector3)?,
    Visible: (boolean)?,
    CollisionLayer: (number)?,
    CollisionMask: (number)?,
}
type NativePlaneMeshProperties = {
    Size: (NativeVector2)?,
}
type NativePrimitiveMeshProperties = {
}
type NativeProgressBarProperties = {
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
}
type NativeQuadMeshProperties = {
    Size: (NativeVector2)?,
}
type NativeRangeProperties = {
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
}
type NativeRefCountedProperties = {
}
type NativeResourceProperties = {
}
type NativeRigidBody3DProperties = {
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
type NativeScrollContainerProperties = {
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
}
type NativeShape3DProperties = {
}
type NativeSliderProperties = {
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
}
type NativeSoftBody3DProperties = {
    Name: (string)?,
    Position: (NativeVector3)?,
    RotationDegrees: (NativeVector3)?,
    Scale: (NativeVector3)?,
    Visible: (boolean)?,
    Mesh: (NativeMesh?)?,
    Material: (NativeMaterial?)?,
    CollisionLayer: (number)?,
    CollisionMask: (number)?,
    SimulationPrecision: (number)?,
    TotalMass: (number)?,
}
type NativeSphereMeshProperties = {
    Radius: (number)?,
    Height: (number)?,
    RadialSegments: (number)?,
    Rings: (number)?,
}
type NativeSphereShape3DProperties = {
    Radius: (number)?,
}
type NativeSpotLight3DProperties = {
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
type NativeSprite2DProperties = {
    Name: (string)?,
    Texture: (NativeTexture2D?)?,
    Position: (NativeVector2)?,
    RotationDegrees: (number)?,
    Scale: (NativeVector2)?,
    Visible: (boolean)?,
    Modulate: (NativeColor3)?,
}
type NativeSprite3DProperties = {
    Name: (string)?,
    Position: (NativeVector3)?,
    RotationDegrees: (NativeVector3)?,
    Scale: (NativeVector3)?,
    Visible: (boolean)?,
    Material: (NativeMaterial?)?,
    Texture: (NativeTexture2D?)?,
    PixelSize: (number)?,
}
type NativeSpriteBase3DProperties = {
    Name: (string)?,
    Position: (NativeVector3)?,
    RotationDegrees: (NativeVector3)?,
    Scale: (NativeVector3)?,
    Visible: (boolean)?,
    Material: (NativeMaterial?)?,
    PixelSize: (number)?,
}
type NativeStandardMaterial3DProperties = {
    Color: (NativeColor3)?,
    Roughness: (number)?,
    EmissionEnabled: (boolean)?,
    Emission: (NativeColor3)?,
    AlbedoTexture: (NativeTexture2D?)?,
    Metallic: (number)?,
    Transparency: (number)?,
}
type NativeStaticBody3DProperties = {
    Name: (string)?,
    Position: (NativeVector3)?,
    RotationDegrees: (NativeVector3)?,
    Scale: (NativeVector3)?,
    Visible: (boolean)?,
    CollisionLayer: (number)?,
    CollisionMask: (number)?,
}
type NativeTextureProperties = {
}
type NativeTexture2DProperties = {
}
type NativeTextureRectProperties = {
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
}
type NativeVBoxContainerProperties = {
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
}
type NativeVSliderProperties = {
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
}
type NativeVisualInstance3DProperties = {
    Name: (string)?,
    Position: (NativeVector3)?,
    RotationDegrees: (NativeVector3)?,
    Scale: (NativeVector3)?,
    Visible: (boolean)?,
}
type NativeWorldEnvironmentProperties = {
    Name: (string)?,
    Environment: (NativeEnvironment?)?,
}
declare class NativeSceneScope extends NativeNode3D
    New: ((self: NativeSceneScope, Class: "AudioStreamPlayer", Properties: NativeAudioStreamPlayerProperties, Parent: NativeNode?) -> NativeAudioStreamPlayer) &
        ((self: NativeSceneScope, Class: "BoxMesh", Properties: NativeBoxMeshProperties, Parent: NativeNode?) -> MutableNativeBoxMesh) &
        ((self: NativeSceneScope, Class: "BoxShape3D", Properties: NativeBoxShape3DProperties, Parent: NativeNode?) -> MutableNativeBoxShape3D) &
        ((self: NativeSceneScope, Class: "Button", Properties: NativeButtonProperties, Parent: NativeNode?) -> NativeButton) &
        ((self: NativeSceneScope, Class: "Camera3D", Properties: NativeCamera3DProperties, Parent: NativeNode?) -> NativeCamera3D) &
        ((self: NativeSceneScope, Class: "CanvasLayer", Properties: NativeCanvasLayerProperties, Parent: NativeNode?) -> NativeCanvasLayer) &
        ((self: NativeSceneScope, Class: "CapsuleMesh", Properties: NativeCapsuleMeshProperties, Parent: NativeNode?) -> MutableNativeCapsuleMesh) &
        ((self: NativeSceneScope, Class: "CapsuleShape3D", Properties: NativeCapsuleShape3DProperties, Parent: NativeNode?) -> MutableNativeCapsuleShape3D) &
        ((self: NativeSceneScope, Class: "CenterContainer", Properties: NativeCenterContainerProperties, Parent: NativeNode?) -> NativeCenterContainer) &
        ((self: NativeSceneScope, Class: "CheckBox", Properties: NativeCheckBoxProperties, Parent: NativeNode?) -> NativeCheckBox) &
        ((self: NativeSceneScope, Class: "CheckButton", Properties: NativeCheckButtonProperties, Parent: NativeNode?) -> NativeCheckButton) &
        ((self: NativeSceneScope, Class: "CollisionShape3D", Properties: NativeCollisionShape3DProperties, Parent: NativeNode?) -> NativeCollisionShape3D) &
        ((self: NativeSceneScope, Class: "ColorRect", Properties: NativeColorRectProperties, Parent: NativeNode?) -> NativeColorRect) &
        ((self: NativeSceneScope, Class: "Control", Properties: NativeControlProperties, Parent: NativeNode?) -> NativeControl) &
        ((self: NativeSceneScope, Class: "CylinderMesh", Properties: NativeCylinderMeshProperties, Parent: NativeNode?) -> MutableNativeCylinderMesh) &
        ((self: NativeSceneScope, Class: "CylinderShape3D", Properties: NativeCylinderShape3DProperties, Parent: NativeNode?) -> MutableNativeCylinderShape3D) &
        ((self: NativeSceneScope, Class: "DirectionalLight3D", Properties: NativeDirectionalLight3DProperties, Parent: NativeNode?) -> NativeDirectionalLight3D) &
        ((self: NativeSceneScope, Class: "Environment", Properties: NativeEnvironmentProperties, Parent: NativeNode?) -> MutableNativeEnvironment) &
        ((self: NativeSceneScope, Class: "GridContainer", Properties: NativeGridContainerProperties, Parent: NativeNode?) -> NativeGridContainer) &
        ((self: NativeSceneScope, Class: "HBoxContainer", Properties: NativeHBoxContainerProperties, Parent: NativeNode?) -> NativeHBoxContainer) &
        ((self: NativeSceneScope, Class: "HSlider", Properties: NativeHSliderProperties, Parent: NativeNode?) -> NativeHSlider) &
        ((self: NativeSceneScope, Class: "Label", Properties: NativeLabelProperties, Parent: NativeNode?) -> NativeLabel) &
        ((self: NativeSceneScope, Class: "Label3D", Properties: NativeLabel3DProperties, Parent: NativeNode?) -> NativeLabel3D) &
        ((self: NativeSceneScope, Class: "LineEdit", Properties: NativeLineEditProperties, Parent: NativeNode?) -> NativeLineEdit) &
        ((self: NativeSceneScope, Class: "MarginContainer", Properties: NativeMarginContainerProperties, Parent: NativeNode?) -> NativeMarginContainer) &
        ((self: NativeSceneScope, Class: "MeshInstance3D", Properties: NativeMeshInstance3DProperties, Parent: NativeNode?) -> NativeMeshInstance3D) &
        ((self: NativeSceneScope, Class: "Node", Properties: NativeNodeProperties, Parent: NativeNode?) -> NativeNode) &
        ((self: NativeSceneScope, Class: "Node2D", Properties: NativeNode2DProperties, Parent: NativeNode?) -> NativeNode2D) &
        ((self: NativeSceneScope, Class: "Node3D", Properties: NativeNode3DProperties, Parent: NativeNode?) -> NativeNode3D) &
        ((self: NativeSceneScope, Class: "OmniLight3D", Properties: NativeOmniLight3DProperties, Parent: NativeNode?) -> NativeOmniLight3D) &
        ((self: NativeSceneScope, Class: "PanelContainer", Properties: NativePanelContainerProperties, Parent: NativeNode?) -> NativePanelContainer) &
        ((self: NativeSceneScope, Class: "PlaneMesh", Properties: NativePlaneMeshProperties, Parent: NativeNode?) -> MutableNativePlaneMesh) &
        ((self: NativeSceneScope, Class: "ProgressBar", Properties: NativeProgressBarProperties, Parent: NativeNode?) -> NativeProgressBar) &
        ((self: NativeSceneScope, Class: "QuadMesh", Properties: NativeQuadMeshProperties, Parent: NativeNode?) -> MutableNativeQuadMesh) &
        ((self: NativeSceneScope, Class: "RigidBody3D", Properties: NativeRigidBody3DProperties, Parent: NativeNode?) -> NativeRigidBody3D) &
        ((self: NativeSceneScope, Class: "ScrollContainer", Properties: NativeScrollContainerProperties, Parent: NativeNode?) -> NativeScrollContainer) &
        ((self: NativeSceneScope, Class: "SoftBody3D", Properties: NativeSoftBody3DProperties, Parent: NativeNode?) -> NativeSoftBody3D) &
        ((self: NativeSceneScope, Class: "SphereMesh", Properties: NativeSphereMeshProperties, Parent: NativeNode?) -> MutableNativeSphereMesh) &
        ((self: NativeSceneScope, Class: "SphereShape3D", Properties: NativeSphereShape3DProperties, Parent: NativeNode?) -> MutableNativeSphereShape3D) &
        ((self: NativeSceneScope, Class: "SpotLight3D", Properties: NativeSpotLight3DProperties, Parent: NativeNode?) -> NativeSpotLight3D) &
        ((self: NativeSceneScope, Class: "Sprite2D", Properties: NativeSprite2DProperties, Parent: NativeNode?) -> NativeSprite2D) &
        ((self: NativeSceneScope, Class: "Sprite3D", Properties: NativeSprite3DProperties, Parent: NativeNode?) -> NativeSprite3D) &
        ((self: NativeSceneScope, Class: "StandardMaterial3D", Properties: NativeStandardMaterial3DProperties, Parent: NativeNode?) -> MutableNativeStandardMaterial3D) &
        ((self: NativeSceneScope, Class: "StaticBody3D", Properties: NativeStaticBody3DProperties, Parent: NativeNode?) -> NativeStaticBody3D) &
        ((self: NativeSceneScope, Class: "TextureRect", Properties: NativeTextureRectProperties, Parent: NativeNode?) -> NativeTextureRect) &
        ((self: NativeSceneScope, Class: "VBoxContainer", Properties: NativeVBoxContainerProperties, Parent: NativeNode?) -> NativeVBoxContainer) &
        ((self: NativeSceneScope, Class: "VSlider", Properties: NativeVSliderProperties, Parent: NativeNode?) -> NativeVSlider) &
        ((self: NativeSceneScope, Class: "WorldEnvironment", Properties: NativeWorldEnvironmentProperties, Parent: NativeNode?) -> NativeWorldEnvironment)
    Configure: ((self: NativeSceneScope, Target: NativeAudioStreamPlayer, Properties: NativeAudioStreamPlayerProperties) -> ()) &
        ((self: NativeSceneScope, Target: MutableNativeBoxMesh, Properties: NativeBoxMeshProperties) -> ()) &
        ((self: NativeSceneScope, Target: MutableNativeBoxShape3D, Properties: NativeBoxShape3DProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeButton, Properties: NativeButtonProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeCamera3D, Properties: NativeCamera3DProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeCanvasLayer, Properties: NativeCanvasLayerProperties) -> ()) &
        ((self: NativeSceneScope, Target: MutableNativeCapsuleMesh, Properties: NativeCapsuleMeshProperties) -> ()) &
        ((self: NativeSceneScope, Target: MutableNativeCapsuleShape3D, Properties: NativeCapsuleShape3DProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeCenterContainer, Properties: NativeCenterContainerProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeCheckBox, Properties: NativeCheckBoxProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeCheckButton, Properties: NativeCheckButtonProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeCollisionShape3D, Properties: NativeCollisionShape3DProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeColorRect, Properties: NativeColorRectProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeControl, Properties: NativeControlProperties) -> ()) &
        ((self: NativeSceneScope, Target: MutableNativeCylinderMesh, Properties: NativeCylinderMeshProperties) -> ()) &
        ((self: NativeSceneScope, Target: MutableNativeCylinderShape3D, Properties: NativeCylinderShape3DProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeDirectionalLight3D, Properties: NativeDirectionalLight3DProperties) -> ()) &
        ((self: NativeSceneScope, Target: MutableNativeEnvironment, Properties: NativeEnvironmentProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeGridContainer, Properties: NativeGridContainerProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeHBoxContainer, Properties: NativeHBoxContainerProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeHSlider, Properties: NativeHSliderProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeLabel, Properties: NativeLabelProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeLabel3D, Properties: NativeLabel3DProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeLineEdit, Properties: NativeLineEditProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeMarginContainer, Properties: NativeMarginContainerProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeMeshInstance3D, Properties: NativeMeshInstance3DProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeNode, Properties: NativeNodeProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeNode2D, Properties: NativeNode2DProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeNode3D, Properties: NativeNode3DProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeOmniLight3D, Properties: NativeOmniLight3DProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativePanelContainer, Properties: NativePanelContainerProperties) -> ()) &
        ((self: NativeSceneScope, Target: MutableNativePlaneMesh, Properties: NativePlaneMeshProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeProgressBar, Properties: NativeProgressBarProperties) -> ()) &
        ((self: NativeSceneScope, Target: MutableNativeQuadMesh, Properties: NativeQuadMeshProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeRigidBody3D, Properties: NativeRigidBody3DProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeScrollContainer, Properties: NativeScrollContainerProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeSoftBody3D, Properties: NativeSoftBody3DProperties) -> ()) &
        ((self: NativeSceneScope, Target: MutableNativeSphereMesh, Properties: NativeSphereMeshProperties) -> ()) &
        ((self: NativeSceneScope, Target: MutableNativeSphereShape3D, Properties: NativeSphereShape3DProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeSpotLight3D, Properties: NativeSpotLight3DProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeSprite2D, Properties: NativeSprite2DProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeSprite3D, Properties: NativeSprite3DProperties) -> ()) &
        ((self: NativeSceneScope, Target: MutableNativeStandardMaterial3D, Properties: NativeStandardMaterial3DProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeStaticBody3D, Properties: NativeStaticBody3DProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeTextureRect, Properties: NativeTextureRectProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeVBoxContainer, Properties: NativeVBoxContainerProperties) -> ()) &
        ((self: NativeSceneScope, Target: NativeVSlider, Properties: NativeVSliderProperties) -> ()) &
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
        ((self: NativeSceneScope, Target: NativeRange, Property: "Step") -> number)
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
        ((self: NativeSceneScope, Target: NativeNode, Method: "GetChildCount", include_internal: boolean?) -> number)
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
        ((self: NativeSceneScope, Source: NativeRange, Signal: "ValueChanged", Callback: (number) -> ()) -> NativeConnection)
    Load: ((self: NativeSceneScope, Type: "Texture2D", Path: string) -> NativeTexture2D) &
        ((self: NativeSceneScope, Type: "AudioStream", Path: string) -> NativeAudioStream) &
        ((self: NativeSceneScope, Type: "Mesh", Path: string) -> NativeMesh) &
        ((self: NativeSceneScope, Type: "Font", Path: string) -> NativeFont) &
        ((self: NativeSceneScope, Type: "PackedScene", Path: string) -> NativePackedScene)
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
declare Scene: { new: (Parent: any) -> NativeSceneScope, Classes: () -> {string},
    Describe: (Class: string) -> { [string]: any }?, Enums: {Control: {MouseFilter: {MOUSE_FILTER_STOP: number, MOUSE_FILTER_PASS: number, MOUSE_FILTER_IGNORE: number}}, TextureRect: {ExpandMode: {EXPAND_KEEP_SIZE: number, EXPAND_IGNORE_SIZE: number, EXPAND_FIT_WIDTH: number, EXPAND_FIT_WIDTH_PROPORTIONAL: number, EXPAND_FIT_HEIGHT: number, EXPAND_FIT_HEIGHT_PROPORTIONAL: number}, StretchMode: {STRETCH_SCALE: number, STRETCH_TILE: number, STRETCH_KEEP: number, STRETCH_KEEP_CENTERED: number, STRETCH_KEEP_ASPECT: number, STRETCH_KEEP_ASPECT_CENTERED: number, STRETCH_KEEP_ASPECT_COVERED: number}}, BaseMaterial3D: {Transparency: {TRANSPARENCY_DISABLED: number, TRANSPARENCY_ALPHA: number, TRANSPARENCY_ALPHA_SCISSOR: number, TRANSPARENCY_ALPHA_HASH: number, TRANSPARENCY_ALPHA_DEPTH_PRE_PASS: number, TRANSPARENCY_MAX: number}}} }
