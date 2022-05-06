#version 120 // OpenGL 2.1

uniform int lightsCount;

varying vec4 vertexPosition;
varying vec4 vertexNormal;

void main() {
	vec3 vertex = vertexPosition.xyz;
	vec3 normal = normalize(vertexNormal.xyz);

	vec3 eyeDirection = normalize(-vertex); // in the modelview space eye direction is just inverse of position

	vec4 diffuseTex = gl_Color; // цвет поверхности модели, надо бы брать из материала (или даже из текстуры)
	vec4 diffuse  = vec4(0.0, 0.0, 0.0, diffuseTex.a);
	vec4 specular = vec4(0.0, 0.0, 0.0, diffuseTex.a);

	// Фоновое освещение (для солнца, для лампочки, для всех источников света)
	vec4 ambient = gl_Color * gl_LightModel.ambient * vec4(1.0, 1.0, 1.0, 1); // todo: light color

	// 1 - POINT
	// 2 - SUN
	for (int i = 0; i < lightsCount; i++) {
		vec4 lightPosition = /*gl_ModelViewMatrixInverse **/gl_LightSource[i].position; // gl_LightSource already multiplied by gl_ModelViewMatrix
		vec3 lightDirection = lightPosition.xyz - vertex * lightPosition.w;

		vec3 unitLightDirection = normalize(lightDirection);
		vec3 reflectedDirection = normalize(reflect(-unitLightDirection, normal));

		// Диффузное освещение, имитирует воздействие на объект направленного источника света.
		float diffuseIntensity = dot(normal, unitLightDirection);

		if (diffuseIntensity > 0.0) {
			vec3 diffuseTemp =
				diffuseTex.rgb * vec3(1,1,1) * diffuseIntensity; // gl_LightSource[i].diffuse.rgb

			diffuseTemp = clamp(diffuseTemp, vec3(0), diffuseTex.rgb);
		
			if (lightPosition.w != 0.0)
				diffuseTemp /= length(lightDirection);
			
			diffuse += vec4(diffuseTemp, diffuseTex.a); // alpha is a question
		}

		// Освещение имитирует яркое пятно света, которое появляется на объектах.
		// По цвету блики часто ближе к цвету источника света, чем к цвету объекта.
		float specularIntensity = max(dot(reflectedDirection, eyeDirection), 0);

		vec3 specularTemp = 
			vec3(0.5, 0.5, 0.5) * // material specular
			vec3(1.0, 1.0, 1.0) * //gl_LightSource[i].specular (?)
			pow(specularIntensity, 96); // material shininess

		specularTemp = clamp(specularTemp, vec3(0), vec3(1));

		if (lightPosition.w != 0.0)
			specularTemp /= length(lightDirection);
			
		specular += vec4(specularTemp, diffuseTex.a); // alpha is a question
	}


	gl_FragColor = ambient + diffuse + specular;
}
