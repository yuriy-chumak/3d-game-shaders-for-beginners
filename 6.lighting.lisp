#!/usr/bin/env ol
(import (lib gl-2))
(gl:set-window-title "5. GLSL")

; global GL init
(glShadeModel GL_SMOOTH)
(glClearColor 0.11 0.11 0.11 1)
(glEnable GL_DEPTH_TEST)

(glEnable GL_BLEND)
(glBlendFunc GL_SRC_ALPHA GL_ONE_MINUS_SRC_ALPHA)
(glEnable GL_TEXTURE_2D)

; scene
(import (file glTF))
(define scene (read-glTF-file "scene.gltf"))

; helper functions
(import (scene))

; lighting setup
(import (owl math fp))
(glLightModelfv GL_LIGHT_MODEL_AMBIENT '(0.1 0.1 0.1 1))

; shader program
(define lighting (gl:create-program
"#version 110 // OpenGL 2.0
   varying vec4 vertexPosition;
   varying vec4 vertexNormal;
   void main() {
   	// Подготовительные вектора
   	vertexPosition = gl_ModelViewMatrix * gl_Vertex; // vertex position in the modelview space
      vertexNormal   = gl_ModelViewMatrix * vec4(gl_Normal, 0.0);

      gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
      gl_TexCoord[0] = gl_MultiTexCoord0;
      gl_FrontColor = vec4(1,1,1, 1);
      gl_BackColor  = vec4(0,0,0, 1);
   }"
"#version 110 // OpenGL 2.0
   uniform int lightsCount;
   uniform sampler2D tex;

   varying vec4 vertexPosition;
   varying vec4 vertexNormal;

   void main() {
      vec3 vertex = vertexPosition.xyz;
      vec3 normal = normalize(vertexNormal.xyz);

      vec3 eyeDirection = normalize(-vertex); // in the modelview space eye direction is just inverse of position

      // Общее фоновое освещение сцены
      vec3 ambient = gl_Color.rgb * gl_LightModel.ambient.rgb;

      // Рассеянная и Зеркальная компоненты
      vec4 diffuseTex = texture2D(tex, gl_TexCoord[0].st);
      vec4 specularTex = diffuseTex; // надо бы брать из материала
      vec3 diffuse  = vec3(0.0, 0.0, 0.0);
      vec3 specular = vec3(0.0, 0.0, 0.0);

      for (int i = 0; i < lightsCount; i++) {
         vec4 lightPosition = /*gl_ModelViewMatrixInverse **/gl_LightSource[i].position; // gl_LightSource already multiplied by gl_ModelViewMatrix
         vec3 lightDirection = lightPosition.xyz - vertex * lightPosition.w;

         vec3 unitLightDirection = normalize(lightDirection);
         vec3 reflectedDirection = normalize(reflect(-unitLightDirection, normal));

         // Рассеянное (diffuse) освещение, имитирует воздействие на объект направленного источника света.
         float diffuseIntensity = dot(normal, unitLightDirection);

         // todo: для стекол если diffuseIntensity < 0, то сделать его >0, но уменьшить
         if (diffuseIntensity > 0.0) {
            vec3 diffuseTemp = diffuseTex.rgb
               * gl_LightSource[i].diffuse.rgb * diffuseIntensity;

            diffuseTemp = clamp(diffuseTemp, vec3(0), diffuseTex.rgb);
         
            if (lightPosition.w != 0.0) // ослабление яркости с расстоянием
               diffuseTemp /= length(lightDirection);
            
            diffuse += diffuseTemp;
         }

         // Освещение имитирует яркое пятно света, которое появляется на объектах.
         // По цвету блики часто ближе к цвету источника света, чем к цвету объекта.
         float specularIntensity = max(dot(reflectedDirection, eyeDirection), 0.0);

         vec3 specularTemp = specularTex.rgb
            * gl_LightSource[i].specular.rgb * pow(specularIntensity, 96.0);

         specularTemp = clamp(specularTemp, vec3(0), specularTex.rgb); // or vec3(1) ?

         if (lightPosition.w != 0.0)
            specularTemp /= length(lightDirection);
            
         specular += specularTemp;

      }

   	gl_FragColor = vec4((ambient + diffuse + specular), 1) * diffuseTex; //(ambient + diffuse + specular) / 1.3;
   }"))

; draw
(import (lib GLU))
(glPolygonMode GL_FRONT_AND_BACK GL_FILL)
(define quadric (gluNewQuadric))


(gl:set-renderer (lambda ()
   (glClear GL_COLOR_BUFFER_BIT)
   (glClear GL_DEPTH_BUFFER_BIT)
   (glEnable GL_BLEND)

   ; camera setup
   (glMatrixMode GL_PROJECTION)
   (glLoadIdentity)
   (gluPerspective
      45.0
      (/ (gl:get-window-width) (gl:get-window-height))
      0.1 1000) ; near - far

   (define target '(0 0 0))
   (define location '(0 6 30))
   (define up '(0 4 0))

   (glMatrixMode GL_MODELVIEW)
   (glLoadIdentity)
   (apply gluLookAt (append location target up))

   ; dynamic lights
   (define ticks (/ (mod (time-ms) 628318) #i1000))
   (define radius 8)
   (define Lights (list
      {
         'type "POINT"
         'color [1 1 1]
         'position [
            (* radius (fsin ticks))
            4
            (* radius (fcos ticks))
            1]
      }
      {
         'type "POINT"
         'color [0 1 0]
         'position [
            (* (- radius) (fsin ticks))
            4
            (* (- radius) (fcos ticks))
            1]
      }
   ))

   ; передадим характеристики нашего света в шейдеры
   (for-each (lambda (light i)
         (glEnable i)
         ; GL_AMBIENT источника света не учавствует в освещении сцены
         (glLightfv i GL_DIFFUSE  (light 'color))
         (glLightfv i GL_SPECULAR (light 'color))
         (glLightfv i GL_POSITION (light 'position)))
      Lights
      (iota (length Lights) GL_LIGHT0))

   ; draw the OPAQUE geometry details
   (glUseProgram lighting)
   (glUniform1i (glGetUniformLocation lighting "lightsCount") (length Lights))
   (render-scene scene (lambda (material)
      (eq? (material 'alphaMode 'OPAQUE) 'OPAQUE)))
   ; additionally, draw MASKed elements
   (glUseProgram lighting)
   (glUniform1i (glGetUniformLocation lighting "lightsCount") (length Lights))
   (render-scene scene (lambda (material)
      (eq? (material 'alphaMode #f) 'MASK)))

   ; and now - transparent things
   (glUseProgram lighting)
   (glUniform1i (glGetUniformLocation lighting "lightsCount") (length Lights))
   (render-scene scene (lambda (material)
      (eq? (material 'alphaMode #f) 'BLEND)))

   ;; todo: стекла надо освещать с обеих сторон (стекла же!)

   ;; покажем где были наши лампочки
   (glUseProgram 0)
   (glDisable GL_BLEND)
   (glMatrixMode GL_MODELVIEW)
   (for-each (lambda (light i)
         ; рисуем только "точечные" источники света:
         (when (eq? (ref (light 'position) 4) 1)
            (glColor3fv (light 'color))
            (glPushMatrix)
            (glTranslatef (ref (light 'position) 1)
                          (ref (light 'position) 2)
                          (ref (light 'position) 3))
            (gluSphere quadric 0.2 32 10)
            (glPopMatrix)))
      Lights
      (iota (length Lights)))
   (glEnable GL_BLEND)

   (render-scene scene) ))
