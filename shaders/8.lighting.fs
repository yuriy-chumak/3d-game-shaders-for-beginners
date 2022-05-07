#version 120 // OpenGL 2.1

uniform int lightsCount;
uniform sampler2D tex;

varying vec4 vertexPosition;
varying vec4 vertexNormal;

void main() {
	vec3 vertex = vertexPosition.xyz;
	vec3 normal = normalize(vertexNormal.xyz);

	vec3 eyeDirection = normalize(-vertex); // in the modelview space eye direction is just inverse of position

	vec4 diffuseTex = gl_Color * texture2D(tex, gl_TexCoord[0].st);
	vec4 specularTex = diffuseTex; // надо бы брать из материала
	vec4 diffuse  = vec4(0.0, 0.0, 0.0, diffuseTex.a);
	vec4 specular = vec4(0.0, 0.0, 0.0, diffuseTex.a);

	// Общее фоновое освещение сцены
	vec4 ambient = gl_Color * gl_LightModel.ambient;

	for (int i = 0; i < lightsCount; i++) {
		vec4 lightPosition = /*gl_ModelViewMatrixInverse **/gl_LightSource[i].position; // gl_LightSource already multiplied by gl_ModelViewMatrix
		vec3 lightDirection = lightPosition.xyz - vertex * lightPosition.w;

		vec3 unitLightDirection = normalize(lightDirection);
		vec3 reflectedDirection = normalize(reflect(-unitLightDirection, normal));

		// Рассеянное (diffuse) освещение, имитирует воздействие на объект направленного источника света.
		float diffuseIntensity = dot(normal, unitLightDirection);

		if (diffuseIntensity > 0.0) {
			vec3 diffuseTemp = diffuseTex.rgb
				* gl_LightSource[i].diffuse.rgb * diffuseIntensity;

			diffuseTemp = clamp(diffuseTemp, vec3(0), diffuseTex.rgb);
		
			if (lightPosition.w != 0) // ослабление яркости с расстоянием
				diffuseTemp /= length(lightDirection);
			
			diffuse += vec4(diffuseTemp, diffuseTex.a);
		}

		// Освещение имитирует яркое пятно света, которое появляется на объектах.
		// По цвету блики часто ближе к цвету источника света, чем к цвету объекта.
		float specularIntensity = max(dot(reflectedDirection, eyeDirection), 0);

		vec3 specularTemp = specularTex.rgb
			* gl_LightSource[i].specular.rgb * pow(specularIntensity, 96);

		specularTemp = clamp(specularTemp, vec3(0), specularTex.rgb); // or vec3(1) ?

		if (lightPosition.w != 0)
			specularTemp /= length(lightDirection);
			
		specular += vec4(specularTemp, diffuseTex.a);
	}


	gl_FragColor = (ambient + diffuse + specular) / 1.3;
}
