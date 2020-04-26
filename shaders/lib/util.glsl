
/*
const int colortex0Format = RGBA16F;
const int colortex1Format = RGBA16F;
*/

#define clamp01(p) (clamp(p, 0.0, 1.0))
#define log10(x) log(x) / log(10.0)

const float PI = 3.1415926535897;

void calcLightingColor(in float angle, out vec3 ambient, out vec3 light) {

    float sunrise  = ((clamp(angle, 0.96, 1.00)-0.96) / 0.04 + 1-(clamp(angle, 0.02, 0.15)-0.02) / 0.13);
    float noon     = ((clamp(angle, 0.02, 0.15)-0.02) / 0.13   - (clamp(angle, 0.35, 0.48)-0.35) / 0.13);
    float sunset   = ((clamp(angle, 0.35, 0.48)-0.35) / 0.13   - (clamp(angle, 0.50, 0.53)-0.50) / 0.03);
    float night    = ((clamp(angle, 0.50, 0.53)-0.50) / 0.03   - (clamp(angle, 0.96, 1.00)-0.96) / 0.03);

    vec3 sunriseAmbColor = vec3(0.44, 0.22, 0.03)*0.15;
    vec3 noonAmbColor    = vec3(0.37, 0.39, 0.48)*0.5;
    vec3 sunsetAmbColor  = vec3(0.44, 0.22, 0.03)*0.15;
    vec3 nightAmbColor   = vec3(0.19, 0.21, 0.29)*0.05;

    vec3 sunriseLightColor = vec3(0.9, 0.72, 0.5)*1.5;
    vec3 noonLightColor    = vec3(0.9, 0.88, 0.86)*2.0;
    vec3 sunsetLightColor  = vec3(0.9, 0.72, 0.5)*1.5;
    vec3 nightLightColor   = vec3(0.35, 0.33, 0.32)*0.5;

    ambient = (sunrise * sunriseAmbColor) + (noon * noonAmbColor) + (sunset * sunsetAmbColor) + (night * nightAmbColor);
    light = (sunrise * sunriseLightColor) + (noon * noonLightColor) + (sunset * sunsetLightColor) + (night * nightLightColor);
}