shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.7, 0.75, 0.8, 1.0);
uniform float alpha_scale : hint_range(0.0, 1.0) = 0.4;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0],
		INV_VIEW_MATRIX[1],
		INV_VIEW_MATRIX[2],
		MODEL_MATRIX[3]
	);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	float d = distance(UV, vec2(0.5));
	float soft = smoothstep(0.5, 0.0, d);
	ALBEDO = tint.rgb;
	ALPHA = soft * tint.a * alpha_scale;
}
