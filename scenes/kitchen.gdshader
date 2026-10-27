shader_type spatial;

uniform vec4 color_a : source_color = vec4(0.98, 0.96, 0.93, 1.0);
uniform vec4 color_b : source_color = vec4(0.72, 0.64, 0.89, 1.0);
uniform vec2 tiles = vec2(16.0, 12.0);

void fragment() {
    vec2 p = floor(UV * tiles);
    float checker = mod(p.x + p.y, 2.0);
    ALBEDO = mix(color_a.rgb, color_b.rgb, checker);
    ROUGHNESS = 0.6;
     SPECULAR = 0.2;
}