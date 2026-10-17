#version 440
// рваный блэклеттер: fractal noise → displacement, как svg-фильтр #rot в концепте
// собрать: qsb --qt6 -o glitch.frag.qsb glitch.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;      // размер в px, чтобы частоты были в пикселях
    vec2 freq;      // базовая частота шума по x/y (концепт: .022 .09)
    float amount;   // сила сдвига в px (концепт: 26)
    float seed;     // меняется — рвётся заново
};
layout(binding = 1) uniform sampler2D source;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7)) + seed * 17.13) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
               mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
    float v = 0.0, a = 0.5;
    for (int o = 0; o < 3; o++) { v += a * noise(p); p *= 2.0; a *= 0.5; }
    return v;
}

void main() {
    vec2 px = qt_TexCoord0 * size;
    vec2 d = vec2(fbm(px * freq), fbm(px * freq + 31.7)) - 0.5;
    fragColor = texture(source, qt_TexCoord0 + d * amount / size) * qt_Opacity;
}
