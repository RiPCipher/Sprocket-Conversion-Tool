shader_type spatial;
render_mode blend_mix, depth_draw_always;

//uniform vec4 albedo : source_color = vec4(1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.4;
uniform int cull_mode : hint_range(0, 2) = 0; // 0:CULL_BACK, 1:CULL_FRONT, 2:CULL_DISABLED

void fragment() {
    // For transparency
    //ALBEDO = albedo.rgb;
    ALPHA = opacity;

    // Access the cull_mode uniform here to make the shader compiler include it
    // We actually set culling at the material level in GDScript
    if (cull_mode < 0) { discard; } // Will never execute, just prevents optimization
}