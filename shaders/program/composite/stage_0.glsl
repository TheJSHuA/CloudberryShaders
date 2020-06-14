/* 
    Melon Shaders by June
    https://j0sh.cf
*/

#include "/lib/settings.glsl"
#include "/lib/util.glsl"

// FRAGMENT SHADER //

#ifdef FRAG

/* DRAWBUFFERS:0 */
layout (location = 0) out vec4 colorOut;

/*
const float eyeBrightnessSmoothHalflife = 4.0;
*/

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex5;

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;

uniform sampler2D noisetex;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

uniform float viewWidth;
uniform float viewHeight;
uniform float far;
uniform float near;
uniform float sunAngle;
uniform float frameTimeCounter;
uniform int isEyeInWater;
uniform float rainStrength;
uniform float centerDepthSmooth;
uniform ivec2 eyeBrightnessSmooth;

uniform vec3 shadowLightPosition;
uniform vec3 sunPosition;
uniform vec3 moonPosition;

in vec2 texcoord;
in vec3 ambientColor;
in vec3 lightColor;

#define linear(x) (2.0 * near * far / (far + near - (2.0 * x - 1.0) * (far - near)))

#include "/lib/distort.glsl"
#include "/lib/fragmentUtil.glsl"
#include "/lib/noise.glsl"
#include "/lib/labpbr.glsl"
#include "/lib/poisson.glsl"
#include "/lib/shading.glsl"
#include "/lib/atmosphere.glsl"

#include "/lib/dither.glsl"
#include "/lib/raytrace.glsl"
#include "/lib/reflection.glsl"

const vec3 attenuationCoefficient = vec3(1.0, 0.2, 0.1);
void main() {
    vec3 color = texture2D(colortex0, texcoord).rgb;

    float depth0 = texture2D(depthtex0, texcoord).r;

    vec4 screenPos = vec4(vec3(texcoord, depth0) * 2.0 - 1.0, 1.0);
    vec4 viewPos = gbufferProjectionInverse * screenPos;
    viewPos /= viewPos.w;
    vec4 worldPos = gbufferModelViewInverse * viewPos;
    
    // if not sky check for translucents
    if (depth0 != 1.0) {
        Fragment frag = getFragment(texcoord);
        PBRData pbr = getPBRData(frag.specular);

        // 2 is translucents tag
        if (frag.matMask == 2) {
            vec4 pos = shadowModelView * worldPos;
            pos = shadowProjection * pos;
            pos /= pos.w;
            vec3 shadowPos = distort(pos.xyz) * 0.5 + 0.5;
            color = calculateShading(frag, pbr, normalize(viewPos.xyz), shadowPos);
        } else if (frag.matMask == 3) {
            // render water fog
            float depth0 = linear(depth0);
            float depth1 = linear(texture2D(depthtex1, texcoord).r);

            float depthcomp = (depth1-depth0);
            // set color to color without water in it
            vec3 oldcolor = color;
            color = texture2D(colortex5, texcoord).rgb;
            // if eye is not in water, render above-water fog and render sky reflection
            if (isEyeInWater == 0) {
                // calculate transmittance
                vec3 transmittance = exp(-attenuationCoefficient * depthcomp);
                color = color * transmittance;
                // colorize water fog based on biome color
                color *= oldcolor;
                vec3 reflectedPos = reflect(viewPos.xyz, frag.normal);
                vec3 reflectedPosWorld = (gbufferModelViewInverse * vec4(reflectedPos, 1.0)).xyz;
                vec3 skyReflection = getSkyColor(reflectedPosWorld, normalize(reflectedPosWorld), mat3(gbufferModelViewInverse) * normalize(sunPosition), mat3(gbufferModelViewInverse) * normalize(moonPosition), sunAngle, false);
                #ifdef SSR
                vec4 reflectionColor = reflection(viewPos.xyz, frag.normal, bayer64(gl_FragCoord.xy), colortex5);
                color += mix(vec3(0.0), mix(mix(vec3(0.0), skyReflection, 0.25), reflectionColor.rgb, reflectionColor.a), 0.35);
                #else
                color += mix(vec3(0.0), skyReflection, 0.05);
                #endif
                // water foam
                #ifdef WAVE_FOAM
                if (depthcomp <= 0.15) {
		    	    color += vec3(0.75) * ambientColor;
		        } 
                #endif
            }
        }
        #ifdef SSR
        #ifdef SPECULAR
        // specular reflections
        else {
            float roughness = pow(1.0 - pbr.smoothness, 2.0);
            if (roughness <= 0.125 && frag.matMask != 4.0) {
                vec4 reflectionColor = roughReflection(viewPos.xyz, frag.normal, bayer64(gl_FragCoord.xy), roughness*8, colortex5);
                color *= mix(vec3(1.0), mix(vec3(1.0), reflectionColor.rgb, reflectionColor.a), clamp01((1.0-roughness*8)-(1.0-SPECULAR_REFLECTION_STRENGTH)));
            }
        }
        #endif
        #endif
    }

    float depth = length(viewPos.xyz);
    if (isEyeInWater == 1) {
        // render underwater fog
        color *= exp(-attenuationCoefficient * depth);
    } else if (isEyeInWater == 2) {
        // render lava fog
        color *= exp(-vec3(0.1, 0.2, 1.0) * (depth*4));
        color += vec3(0.2, 0.05, 0.0)*0.25;
    } 
    #ifdef FOG
    else {
        // render regular fog
        if (depth0 != 1.0) {
            if (eyeBrightnessSmooth.y <= 64 && eyeBrightnessSmooth.y > 8) {
                vec3 atmosColor = getSkyColor(worldPos.xyz, normalize(worldPos.xyz), mat3(gbufferModelViewInverse) * normalize(sunPosition), mat3(gbufferModelViewInverse) * normalize(moonPosition), sunAngle, true);
                float fade = clamp01((eyeBrightnessSmooth.y-9)/55.0);
                color = mix(color, mix(vec3(0.05), atmosColor, fade), clamp01((depth/256.0)*FOG_DENSITY*mix(8.0, 1.0, fade)));
            } else if (eyeBrightnessSmooth.y <= 8) {
                color = mix(color, vec3(0.05), clamp01((depth/256.0)*FOG_DENSITY*8.0));
            } else {
                vec3 atmosColor = getSkyColor(worldPos.xyz, normalize(worldPos.xyz), mat3(gbufferModelViewInverse) * normalize(sunPosition), mat3(gbufferModelViewInverse) * normalize(moonPosition), sunAngle, true);
                color = mix(color, atmosColor, clamp01((depth/256.0)*FOG_DENSITY));
            }
        }
    }
    #endif

    colorOut = vec4(color, 1.0);
}

#endif

// VERTEX SHADER //

#ifdef VERT

out vec2 texcoord;
out vec3 ambientColor;
out vec3 lightColor;

uniform float sunAngle;
uniform float rainStrength;

uniform vec3 sunPosition;
uniform vec3 shadowLightPosition;

void main() {
	gl_Position = ftransform();
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    calcLightingColor(sunAngle, rainStrength, sunPosition, shadowLightPosition, ambientColor, lightColor);
}

#endif