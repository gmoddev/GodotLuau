shader_type spatial;
render_mode unshaded;
uniform vec4 Tint : source_color = vec4(0.15,0.9,0.8,1.0);
uniform float Pulse = 0.8;
void fragment() { ALBEDO = Tint.rgb * Pulse; ALPHA = Tint.a; }
