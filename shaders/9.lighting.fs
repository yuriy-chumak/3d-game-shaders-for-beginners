#version 120 // OpenGL 2.1

varying vec4 vertexPosition;
varying vec4 vertexPosition2;
varying vec4 vertexNormal;

uniform float far_plane;
uniform samplerCube depthMap;

void main() {
	vec3 vertex = vertexPosition.xyz;
	vec3 normal = normalize(vertexNormal.xyz);

	vec3 eyeDirection = normalize(-vertex); // in the modelview space eye direction is just inverse of position

	vec4 diffuseTex = gl_Color; // цвет поверхности модели, надо бы брать из материала (или даже из текстуры)
	vec4 diffuse  = vec4(0.0, 0.0, 0.0, diffuseTex.a);
	vec4 specular = vec4(0.0, 0.0, 0.0, diffuseTex.a);

	// Фоновое освещение (для солнца, для лампочки, для всех источников света)
	vec4 ambient = gl_Color * gl_LightModel.ambient * vec4(1.0, 1.0, 1.0, 1); // todo: light color

	float shadow = 0;

	// 1 - POINT
	// 2 - SUN
	for (int i = 0; i < 1; i++) {
		// странно, а сейчас gl_LightSource[i].position вроде как не затронут modelview матрицей O_O ???
		vec4 lightPosition = gl_LightSource[i].position; // gl_LightSource already multiplied by gl_ModelViewMatrix
		// если мы делаем (glLightfv .. GL_POSITION) после (glMatrixMode GL_MODELVIEW), то надо умножить на обратную матрицу
		vec4 lightPosition2 = gl_ModelViewMatrixInverse * lightPosition; // gl_LightSource in the world, not in the view
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

		// shadow
		// lightDirection нам нужен в абсолютных мировых координатах, а не в координатах камеры
		vec3 fragToLight = vertexPosition2.xyz - lightPosition2.xyz;
		float closestDepth = textureCube(depthMap, fragToLight).r;
		float currentDepth = length(lightDirection) / far_plane;

		float bias = 0.005;
		shadow = (currentDepth - bias) > closestDepth ? 1.0 : 0.4;
	}

	gl_FragColor = 5 * (ambient + (diffuse + specular) * (1.0 - shadow)); //ambient + diffuse + specular;
}
