shader_type spatial;
render_mode diffuse_lambert_wrap, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.72, 0.64, 0.89, 1.0);
uniform float gloss : hint_range(0.0, 1.0) = 0.4;
uniform float rim_amount : hint_range(0.0, 1.0) = 0.3;
uniform float floor_darken : hint_range(0.0, 0.8) = 0.3;
uniform float darken_height = 1.0;

varying float world_y;

void vertex() {
    world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
    float ao = mix(1.0 - floor_darken, 1.0, clamp(world_y / darken_height, 0.0, 1.0));
    ALBEDO = base_color.rgb * ao;
    ROUGHNESS = gloss;
    SPECULAR = 0.6;
    RIM = rim_amount;
    RIM_TINT = 0.5;
}