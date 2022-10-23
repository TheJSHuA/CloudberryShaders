/*
    Melon Shaders
    By Ash (ashie404)
    https://ashiecorner.xyz
*/

#include "/lib/settings.glsl"
#include "/lib/util.glsl"

// FRAGMENT SHADER //

#ifdef FSH

/* RENDERTARGETS: 0,1 */
out vec4 albedoOut;
out vec4 dataOut;

// Inputs from vertex shader
in vec2 texcoord;
in vec2 lmcoord;
in vec3 normal;
in vec4 glcolor;

// Uniforms
uniform sampler2D texture;

uniform mat4 gbufferModelViewInverse;

void main() {
    // get albedo
    vec4 albedo = texture2D(texture, texcoord) * glcolor;

    if (albedo.a < 0.1) discard;

    albedo.rgb = toLinear(albedo.rgb);

    // output everything
	albedoOut = albedo;
    dataOut = vec4(
        encodeLightmaps(clamp01(lmcoord-0.03125)), // lightmap
        encodeLightmaps(vec2(0.6, albedo.a)), // material mask and albedo alpha
        0.0, // specular green channel
        1.0 // specular red channel
    );
}

#endif

// VERTEX SHADER //

#ifdef VSH

// Outputs to fragment shader
out vec2 texcoord;
out vec2 lmcoord;
out vec3 normal;
out vec4 glcolor;

// Uniforms
uniform float viewWidth;
uniform float viewHeight;

uniform int frameCounter;

// Includes
#include "/lib/util/taaJitter.glsl"

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;

    normal = normalize(gl_NormalMatrix * gl_Normal);

    glcolor = gl_Color;

    gl_Position = ftransform();

    #ifdef TAA
    gl_Position.xy += jitter(2.0)*gl_Position.w;
    #endif
}

#endif