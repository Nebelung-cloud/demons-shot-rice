#version 440
// пиксель-арт: порог по альфе, без полупрозрачных краёв (в концепте — alpha > 110)
// собрать: qsb --qt6 -o pixel.frag.qsb pixel.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 tint;      // цвет глифа: из текстуры берём только альфу (субпиксельное сглаживание даёт цветные края)
};
layout(binding = 1) uniform sampler2D source;

void main() {
    float a = texture(source, qt_TexCoord0).a;
    fragColor = tint * step(0.43, a) * qt_Opacity;
}
