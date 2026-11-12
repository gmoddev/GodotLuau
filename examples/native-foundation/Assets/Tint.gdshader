shader_type spatial;
uniform vec4 Tint : source_color = vec4(0.2,0.7,0.95,1.0);
void fragment() {
    ALBEDO = Tint.rgb;
    ROUGHNESS = 0.65;
}
