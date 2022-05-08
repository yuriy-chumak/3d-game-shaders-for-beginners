#!/usr/bin/env ol

; initialize OpenGL
(import (lib gl-2))
(gl:set-window-title "ssao+lighting.lisp")
(import (lib soil))

; gl global init
(glShadeModel GL_SMOOTH)
(glEnable GL_DEPTH_TEST)

(glEnable GL_CULL_FACE); GL_BACK

; scene
(import (scene))

; load (and create if no one) a models cache
(define models (prepare-models "cache.bin"))
(define geometry (compile-triangles models))

; load a scene
(import (file json))
(define scene (read-json-file "scene.json"))

; scene lights
(define Lights (vector->list (scene 'Lights)))
(print "Lights: " Lights)

; scene objects
(define Objects (vector->list (scene 'Objects)))
(print "Objects: " Objects)

; let's rotate ceilingFan
(attach-entity-handler "ceilingFan" (lambda (entity)
   (define-values (ss ms) (clock))
   (ff-replace entity {
      'rotation [0 0 (+ (mod (* ss 10) 360) (/ ms 100))]
   })))

;; render buffer
(import (OpenGL EXT framebuffer_object))

; найдем код текстуры дисплея
(import (lib x11))
(define computer-screen-texture (ref ((ref geometry 1) '|metal.024|) 3))
; сконфигурируем
(define dpy (XOpenDisplay #f))
(define root (XDefaultRootWindow dpy))
(define SCREENW 1920)
(define SCREENH 1080)

; texture buffer sizes
(define TEXW 1024)
(define TEXH 1024)

; depth texture2d
(define texture '(0))
(glGenTextures (length texture) texture)
(glBindTexture GL_TEXTURE_2D (car texture))
   (glTexParameteri GL_TEXTURE_2D GL_TEXTURE_WRAP_S GL_REPEAT)
   (glTexParameteri GL_TEXTURE_2D GL_TEXTURE_WRAP_T GL_REPEAT)
   (glTexParameteri GL_TEXTURE_2D GL_TEXTURE_MAG_FILTER GL_NEAREST)
   (glTexParameteri GL_TEXTURE_2D GL_TEXTURE_MIN_FILTER GL_NEAREST)
   (glTexImage2D GL_TEXTURE_2D 0 GL_DEPTH_COMPONENT 1024 1024 0 GL_DEPTH_COMPONENT GL_FLOAT 0)
(glBindTexture GL_TEXTURE_2D 0)

; depthbuffer
(import (OpenGL EXT geometry_shader4))

(define depthbuffer '(0))
(glGenFramebuffers (length depthbuffer) depthbuffer)
(print "depthbuffer: " depthbuffer)
(glBindFramebuffer GL_FRAMEBUFFER (car depthbuffer))
   (glFramebufferTexture GL_FRAMEBUFFER GL_DEPTH_ATTACHMENT (car texture) 0)

   (glDrawBuffer GL_NONE)
   (glReadBuffer GL_NONE)
(glBindFramebuffer GL_FRAMEBUFFER 0)

; depths producer
(define depths (gl:create-program
"#version 120 // OpenGL 2.1
   #define gl_ModelMatrix gl_TextureMatrix[7]   // Model matrix
   #define gl_ViewMatrix gl_ModelViewMatrix
   #define gl_ViewProjectionMatrix gl_ModelViewProjectionMatrix

   uniform float clip_end;

   varying float depth;
   void main() {
      gl_Position = gl_ViewProjectionMatrix * gl_ModelMatrix * gl_Vertex;
      depth = gl_Position.z / clip_end;
   }"
"#version 120 // OpenGL 2.1
   varying float depth;
   void main() {
      gl_FragDepth = depth;
   }"))

(define ssao+lighting (gl:create-program
"#version 120 // OpenGL 2.1
   #define gl_ModelMatrix gl_TextureMatrix[7]   // Model matrix
   #define gl_ViewMatrix gl_ModelViewMatrix
   #define gl_ViewProjectionMatrix gl_ModelViewProjectionMatrix

   uniform float clip_end;

   varying float depth;
   varying vec3 normal;
   varying vec3 position;

   varying vec4 vertexPosition;
   varying vec4 vertexNormal;

   void main() {
      gl_Position = gl_ViewProjectionMatrix * gl_ModelMatrix * gl_Vertex;
      gl_FrontColor = gl_Color;

      depth = gl_Position.z / clip_end;
      normal = mat3(gl_ModelMatrix) * gl_Normal; // или (gl_ViewMatrix * gl_ModelMatrix * vec4(gl_Normal, 0.0)).xyz ?
      position = (gl_ModelMatrix * gl_Vertex).xyz; // координата вертекса в мире

      vertexPosition = gl_ViewMatrix * gl_ModelMatrix * gl_Vertex; // vertex position in the modelview space (not just in world space)
      vertexNormal   = gl_ViewMatrix * gl_ModelMatrix * vec4(gl_Normal, 0.0);

      gl_TexCoord[0] = gl_MultiTexCoord0;
   }"
"#version 120 // OpenGL 2.1
   #define gl_ViewProjectionMatrix gl_ModelViewProjectionMatrix
   // https://habr.com/ru/post/421385/
   uniform sampler2D depthMap;

   uniform sampler2D kernelMap; // ядро выборки, у нас 16 векторов
   uniform sampler2D rotateMap; // рандомные повороты
   uniform vec2 screen;
   uniform float clip_end;

   uniform int lightsCount;
   uniform sampler2D tex;

   varying float depth;
   varying vec3 normal;
   varying vec3 position;

   varying vec4 vertexPosition;
   varying vec4 vertexNormal;

   float ssao() {
      // настройки
      float radius = 0.1; // переменные, контролирующие эффект
      float bias = 0.002;

      // текстурные координаты на пререндере глубины
      vec2 st = vec2(gl_FragCoord.x / screen.x, gl_FragCoord.y / screen.y);
      vec2 noiseScale = vec2(screen.x / 4, screen.y / 4); // 4x4 - размер текстуры поворота

      // 'рандомный' вектор плоскости отражения ядра выборки, использовать через reflect
      // можно и не использовать для начала, но сильно улучшает качество
      vec3 noise = normalize(texture2D(rotateMap, st * noiseScale).xyz * 2 - 1);

      float occlusion = 0.0;
      // мы будем отсекать примерно половину рандомных векторов (тех, которые разнонаправлены с нормалью)
      for (int i = 0; i < 64; i++) { // 64 is a kernel size
         vec3 kernel = texture2D(kernelMap, vec2(i/64.0, 0)).xyz * 2 - 1; // вектор на тестируемую точку

         // если рандомный вектор не противоположен нормали (не проваливает точку под поверхность)
         //if (dot(kernel, normal) >= 0) {
            vec3 sample = position + kernel * radius; // координаты тестируемой точки

            vec4 offset = vec4(sample, 1.0);
            offset      = gl_ViewProjectionMatrix * offset;
            offset.xy  /= offset.w;
            offset.xy   = offset.xy * 0.5 + 0.5;
            offset.z   /= clip_end;

            float sampleDepth = texture2D(depthMap, offset.xy).z;
            float rangeCheck = 0.1; //1.0 - smoothstep(0.0, 1.0, radius / abs(depth - sampleDepth));
            occlusion += (sampleDepth > offset.z - bias ? 1.0 : rangeCheck);
         //}
      }
      occlusion = (occlusion / 64); // 8 - половина от 16, так как приблизительно половину мы отсеем
      return occlusion;
   }

   void main() {
      float occlusion = ssao();

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

      gl_FragColor = (ambient + diffuse + specular) * occlusion / 1.3;
   }"))

(define rotate-array
   (SOIL_load_OGL_texture "media/rotate.tga" SOIL_LOAD_RGB SOIL_CREATE_NEW_ID 0))
(print "rotate-array: " rotate-array)
(glBindTexture GL_TEXTURE_2D rotate-array)
   (glTexParameteri GL_TEXTURE_2D GL_TEXTURE_MIN_FILTER GL_NEAREST)
   (glTexParameteri GL_TEXTURE_2D GL_TEXTURE_MAG_FILTER GL_NEAREST)
   (glTexParameteri GL_TEXTURE_2D GL_TEXTURE_WRAP_S GL_REPEAT)
   (glTexParameteri GL_TEXTURE_2D GL_TEXTURE_WRAP_T GL_REPEAT)
(glBindTexture GL_TEXTURE_2D 0)

(define kernel-array
   (SOIL_load_OGL_texture "media/kernel.tga" SOIL_LOAD_RGB SOIL_CREATE_NEW_ID 0))
   (glTexParameteri GL_TEXTURE_2D GL_TEXTURE_MIN_FILTER GL_NEAREST)
   (glTexParameteri GL_TEXTURE_2D GL_TEXTURE_MAG_FILTER GL_NEAREST)
   ;; (glTexParameteri GL_TEXTURE_2D GL_TEXTURE_WRAP_S GL_REPEAT)
   ;; (glTexParameteri GL_TEXTURE_2D GL_TEXTURE_WRAP_T GL_REPEAT)
(print "kernel-array: " kernel-array)

(import (lib math))
(import (owl math fp))

; ambient RGBA intensity of the entire scene
(glLightModelfv GL_LIGHT_MODEL_AMBIENT '(0.1 0.1 0.1 1))

; draw
(gl:set-renderer (lambda ()
   (glViewport 0 0 TEXW TEXH)
   (glBindFramebuffer GL_FRAMEBUFFER (car depthbuffer))

   (glClearColor 0 0 0 1)
   (glClear (vm:ior GL_COLOR_BUFFER_BIT GL_DEPTH_BUFFER_BIT))

   (glUseProgram depths)

   ; camera setup
   (begin
      (define Camera (ref (scene 'Cameras) 1))

      (glMatrixMode GL_PROJECTION)
      (glLoadIdentity)
      (gluPerspective
         (Camera 'angle)
         (/ (gl:get-window-width) (gl:get-window-height))
         (Camera 'clip_start) (Camera 'clip_end))

      (glUniform1f (glGetUniformLocation depths "clip_end") (Camera 'clip_end))

      (define target (vector->list (Camera 'target)))
      (define location (vector->list (Camera 'location)))
      (define up (vector->list [0 0 1]))

      (glMatrixMode GL_MODELVIEW)
      (glLoadIdentity)
      (apply gluLookAt (append location target up)))

   ; draw just a geometry
   (draw-geometry Objects geometry)

   ; -------------------------------------
   ; -- ssao+lighting --------------------
   ; --
   (glViewport 0 0 (gl:get-window-width) (gl:get-window-height))
   (glClearColor 0 0 0 1)

   (glBindFramebuffer GL_FRAMEBUFFER 0)
   (glClear (vm:ior GL_COLOR_BUFFER_BIT GL_DEPTH_BUFFER_BIT))

   (glUseProgram ssao+lighting)
   (glUniform2f (glGetUniformLocation ssao+lighting "screen") (gl:get-window-width)(gl:get-window-height))

   (glActiveTexture GL_TEXTURE2)
      (glUniform1i (glGetUniformLocation ssao+lighting "depthMap") 2)
      (glBindTexture GL_TEXTURE_2D (unbox texture))
   (glActiveTexture GL_TEXTURE3)
      (glUniform1i (glGetUniformLocation ssao+lighting "kernelMap") 3)
      (glBindTexture GL_TEXTURE_2D kernel-array)
   (glActiveTexture GL_TEXTURE4)
      (glUniform1i (glGetUniformLocation ssao+lighting "rotateMap") 4)
      (glBindTexture GL_TEXTURE_2D rotate-array)
   (glActiveTexture GL_TEXTURE0)

   ; camera setup
   (begin
      (define Camera (ref (scene 'Cameras) 1))

      (glMatrixMode GL_PROJECTION)
      (glLoadIdentity)
      (gluPerspective
         (Camera 'angle)
         (/ (gl:get-window-width) (gl:get-window-height))
         (Camera 'clip_start) (Camera 'clip_end))

      (glUniform1f (glGetUniformLocation ssao+lighting "clip_end") (Camera 'clip_end))

      (define target (vector->list (Camera 'target)))
      (define location (vector->list (Camera 'location)))
      (define up (vector->list [0 0 1]))

      (glMatrixMode GL_MODELVIEW)
      (glLoadIdentity)
      (apply gluLookAt (append location target up)))

   ; let's add dynamic light (i want to see dynamic changes of lighting)
   (define-values (ss ms) (clock))
   (define ticks (/ (+ ss (/ ms 1000)) 0.1))

   (define lights (append Lights (list
      {
         'type "POINT"
         'color [1 0 0]
         'position [
            (* 5 (sin (/ ticks 20)))
            (* 5 (cos (/ ticks 20)))
            4
            1]
      })))
   (glUniform1i (glGetUniformLocation ssao+lighting "lightsCount") (length lights))
   (glUniform1i (glGetUniformLocation ssao+lighting "tex") 0)

   ; define light positions
   ;(glEnable GL_LIGHTING)
   (for-each (lambda (light i)
         (glEnable i)
         ; GL_AMBIENT источника света не учавствует в освещении сцены
         (glLightfv i GL_DIFFUSE  (light 'color))
         (glLightfv i GL_SPECULAR (light 'color))
      ; GL_EMISSION
      ; GL_SHININESS
         (glLightfv i GL_POSITION (light 'position)))
      lights
      (iota (length lights) GL_LIGHT0))

   ; display texture
   (define image (XGetImage dpy root SCREENW 0 SCREENW SCREENH (XAllPlanes) ZPixmap))
   (define data (bytevector->void* (vptr->bytevector image 100) 16))

   (glBindTexture GL_TEXTURE_2D computer-screen-texture)
   (glTexImage2D GL_TEXTURE_2D 0 GL_RGB SCREENW SCREENH 0 GL_BGRA GL_UNSIGNED_BYTE data)
   (XDestroyImage image)

   ; draw just a geometry
   (render-scene Objects geometry)

   ; Draw a light bulbs
   (draw-lightbulbs lights)

))
