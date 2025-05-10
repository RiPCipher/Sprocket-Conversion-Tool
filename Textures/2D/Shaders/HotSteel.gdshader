shader_type canvas_item;

// Glow properties
uniform float glow_intensity : hint_range(0.0, 2.0) = 0.6; // Controls glow strength
uniform float heat_level : hint_range(0.0, 1.0) = 0.7; // Controls temp appearance
uniform float pulse_speed : hint_range(0.0, 3.0) = 1.0; // Pulse Speed lol
uniform float pulse_amplitude : hint_range(0.0, 0.5) = 0.18; // How much glow varies during pulse

// Hot steel color palette
const vec4 white_hot = vec4(1.0, 0.98, 0.94, 1.0);      // Almost white
const vec4 yellow_hot = vec4(1.0, 0.9, 0.4, 1.0);       // Yellow-white
const vec4 orange_hot = vec4(1.0, 0.55, 0.0, 1.0);      // Bright orange
const vec4 red_hot = vec4(1.0, 0.22, 0.0, 1.0);         // Bright red
const vec4 dark_red = vec4(0.6, 0.1, 0.0, 1.0);         // Dark red
const vec4 cool_steel = vec4(0.3, 0.3, 0.4, 1.0);       // Cool blueish-gray

void fragment() {
    // Get the original texture color
    vec4 original = texture(TEXTURE, UV);

    // Create pulse effect over time
    float pulse = sin(TIME * pulse_speed) * pulse_amplitude + (1.0 - pulse_amplitude);
    float adjusted_heat = heat_level * pulse;

    // Create the glow based on the alpha channel and edges
    float alpha_glow = original.a * glow_intensity * pulse;

    // Sample the texture with slightly modified UVs to create a soft blur effect
    vec4 glow = vec4(0.0);
    float blur_size = 0.01;

    // Add samples from surrounding pixels for the blur
    for(float x = -2.0; x <= 2.0; x++) {
        for(float y = -2.0; y <= 2.0; y++) {
            vec2 offset = vec2(x, y) * blur_size;
            glow += texture(TEXTURE, UV + offset);
        }
    }

    // Normalize the glow
    glow /= 25.0;
    glow *= alpha_glow;

    // Create a heat gradient based on the adjusted heat level
    vec4 heat_color;

    if (adjusted_heat > 0.9) {
        // White hot
        heat_color = mix(yellow_hot, white_hot, (adjusted_heat - 0.9) * 10.0);
    } else if (adjusted_heat > 0.7) {
        // Yellow hot
        heat_color = mix(orange_hot, yellow_hot, (adjusted_heat - 0.7) * 5.0);
    } else if (adjusted_heat > 0.5) {
        // Orange hot
        heat_color = mix(red_hot, orange_hot, (adjusted_heat - 0.5) * 5.0);
    } else if (adjusted_heat > 0.3) {
        // Red hot
        heat_color = mix(dark_red, red_hot, (adjusted_heat - 0.3) * 5.0);
    } else {
        // Dark red to cool steel
        heat_color = mix(cool_steel, dark_red, adjusted_heat * 3.33);
    }

    // Add internal glow based on the distance from center
    float dist_from_center = length(UV - vec2(0.5, 0.5)) * 2.0;
    float internal_glow = (1.0 - dist_from_center) * adjusted_heat;

    // Combine original texture with glow effect
    vec4 final_color = original;
    final_color.rgb = mix(final_color.rgb, heat_color.rgb, glow.a * glow_intensity);

    // Add the internal glow
    final_color.rgb = mix(final_color.rgb, heat_color.rgb, internal_glow * original.a * 0.5);

    // Keep the original alpha to preserve the shape
    COLOR = final_color;
}

//void light() {
	//
//}
