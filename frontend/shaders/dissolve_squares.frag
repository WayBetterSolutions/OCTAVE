#version 440

layout(location=0) in vec2 qt_TexCoord0;
layout(location=0) out vec4 fragColor;

layout(std140, binding=0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
    float gridSize;
    float smoothness;
} ubuf;

layout(binding=1) uniform sampler2D source;

float rand(vec2 co) {
    return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
    vec2 uv = qt_TexCoord0;
    float r = rand(floor(vec2(ubuf.gridSize) * uv));
    float reveal = smoothstep(r - ubuf.smoothness, r + ubuf.smoothness, ubuf.progress);
    vec4 texColor = texture(source, uv);
    fragColor = vec4(texColor.rgb, texColor.a * reveal) * ubuf.qt_Opacity;
}
