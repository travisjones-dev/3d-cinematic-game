shader_type spatial;

uniform vec3 albedo_color : source_color = vec3(0.3, 0.36, 0.42);
uniform float roughness_value : hint_range(0.0, 1.0) = 0.15;
uniform float metallic_value : hint_range(0.0, 1.0) = 0.3;
uniform float wave_speed = 0.15;
uniform float wave_height = 0.05;
uniform float wave_scale = 0.6;

void vertex() {
	float wave = sin(VERTEX.x * wave_scale + TIME * wave_speed) * cos(VERTEX.z * wave_scale * 0.7 + TIME * wave_speed * 0.8);
	VERTEX.y += wave * wave_height;
}

void fragment() {
	ALBEDO = albedo_color;
	ROUGHNESS = roughness_value;
	METALLIC = metallic_value;

	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	EMISSION = vec3(0.5, 0.55, 0.62) * fresnel * 0.25;

	float micro = sin(VERTEX.x * 4.0 + TIME * 0.6) * sin(VERTEX.z * 4.0 - TIME * 0.5);
	SPECULAR = clamp(0.5 + micro * 0.1, 0.0, 1.0);
}
