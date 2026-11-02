shader_type canvas_item;

// Palette swap for Riftwarden's dark blue armor and amber scarf.
uniform vec4 tunic_color : source_color = vec4(0.10, 0.29, 0.55, 1.0);
uniform vec4 plume_color : source_color = vec4(0.97, 0.51, 0.08, 1.0);

void fragment() {
    vec4 source = texture(TEXTURE, UV);
    vec3 output_color = source.rgb;
    float armor_mask = step(source.r * 1.22, source.b) * step(source.g * 1.12, source.b) * step(0.08, source.b) * step(source.b, 0.62);
    float scarf_mask = step(0.55, source.r) * step(0.16, source.g) * step(source.g, source.r * 0.82) * step(source.b, 0.36);
    float armor_shade = clamp(source.b / 0.52, 0.35, 1.0);
    float scarf_shade = clamp(source.r / 0.98, 0.45, 1.0);
    output_color = mix(output_color, tunic_color.rgb * armor_shade, armor_mask);
    output_color = mix(output_color, plume_color.rgb * scarf_shade, scarf_mask);
    COLOR = vec4(output_color, source.a) * COLOR;
}
