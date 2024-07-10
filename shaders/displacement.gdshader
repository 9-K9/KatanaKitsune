shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture; // Define SCREEN_TEXTURE with hint
uniform float zoom = 300;
uniform bool pDir = false;
uniform bool noWrap = true;
uniform float displacementStrength = 0.1; // Uniform for displacement strength
uniform sampler2D displacementTexture; // Uniform for displacement texture

void fragment() {
    vec2 uv = SCREEN_UV;
    vec2 fPixel = SCREEN_PIXEL_SIZE;

    // Calculate the displacement factor
    float fB = 1.0 - zoom * (pDir ? fPixel.x : fPixel.y);
    float fC = max(pDir ? 0.05 : 0.02, 1.0 + (fB - 1.0) * 4.0 * pow((pDir ? uv.y : uv.x) - 0.5, 2.0));
    vec2 posTex = uv * (pDir ? vec2(fC, 1.0) : vec2(1.0, fC)) + (pDir ? vec2((1.0 - fC) / 2.0, 0.0) : vec2(0.0, (1.0 - fC) / 2.0));

    // Apply the displacement
    vec4 displacement = texture(displacementTexture, posTex);
    vec2 displacedPos = posTex + (displacement.rg - 0.5) * displacementStrength;

    // Sample and set the final color
    if (noWrap == false || (displacedPos.x >= 0.0 && displacedPos.x <= 1.0 && displacedPos.y >= 0.0 && displacedPos.y <= 1.0)) {
        COLOR.rgb = textureLod(SCREEN_TEXTURE, displacedPos, 0.0).rgb;
    }
}
