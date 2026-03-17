#include <metal_stdlib>
using namespace metal;

// ── BlendParams (Inverse Mode 지원) ─────────────────────────────
struct BlendParams {
    float isInverse;   // 0.0=일반, 1.0=반전 (피사체↔배경 교환)
};

// ── 1. Color Pop 합성 커널 ──────────────────────────────────────
// Final = mix(color, gray, mask)
// mask=1 → 흑백, mask=0 → 컬러 (isInverse=1이면 반전)
kernel void colorPopBlend(
    texture2d<float, access::read>  colorTex [[texture(0)]],
    texture2d<float, access::read>  grayTex  [[texture(1)]],
    texture2d<float, access::read>  maskTex  [[texture(2)]],
    texture2d<float, access::write> outTex   [[texture(3)]],
    constant BlendParams& p [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= outTex.get_width() || gid.y >= outTex.get_height()) return;

    float4 color = colorTex.read(gid);
    float4 gray  = grayTex.read(gid);
    float  mask  = maskTex.read(gid).r;

    if (p.isInverse > 0.5f) mask = 1.0f - mask;

    float4 result = mix(color, gray, mask);
    outTex.write(float4(result.rgb, 1.0f), gid);
}

// ── 2. 브러시 페인팅 커널 ──────────────────────────────────────
struct BrushParams {
    float2 center;
    float  radius;
    float  softness;
    float  opacity;
    float  targetValue;
};

kernel void paintBrush(
    texture2d<float, access::read_write> maskTex [[texture(0)]],
    constant BrushParams &params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= maskTex.get_width() || gid.y >= maskTex.get_height()) return;

    float2 pos = float2(gid.x, gid.y);
    float dist = length(pos - params.center);

    if (dist > params.radius) return;

    float normalizedDist = dist / max(params.radius, 0.001f);
    float hardEdge = max(1.0f - params.softness, 0.001f);
    float alpha = smoothstep(1.0f, hardEdge * 0.5f, normalizedDist) * params.opacity;

    float currentMask = maskTex.read(gid).r;
    float newMask = clamp(mix(currentMask, params.targetValue, alpha), 0.0f, 1.0f);
    maskTex.write(float4(newMask, 0.0f, 0.0f, 1.0f), gid);
}

// ── 3. 마스크 초기화 커널 ──────────────────────────────────────
kernel void fillMask(
    texture2d<float, access::write> maskTex [[texture(0)]],
    constant float &value [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= maskTex.get_width() || gid.y >= maskTex.get_height()) return;
    maskTex.write(float4(value, 0.0f, 0.0f, 1.0f), gid);
}

// ── 공통: RGB → HSL ────────────────────────────────────────────
static float3 rgbToHSL(float r, float g, float b)
{
    float maxC = max(r, max(g, b));
    float minC = min(r, min(g, b));
    float l    = (maxC + minC) * 0.5f;
    if (maxC == minC) return float3(0.0f, 0.0f, l);

    float d = maxC - minC;
    float s = l > 0.5f ? d / (2.0f - maxC - minC) : d / (maxC + minC);
    float h;
    if      (maxC == r) h = (g - b) / d + (g < b ? 6.0f : 0.0f);
    else if (maxC == g) h = (b - r) / d + 2.0f;
    else                h = (r - g) / d + 4.0f;
    h /= 6.0f;
    return float3(h, s, l);
}

// ── 4. 단일 색상 선택 마스크 커널 ─────────────────────────────
struct ColorSelectParams {
    float targetH;
    float targetS;
    float hueTol;
    float satMin;
};

kernel void colorSelectMask(
    texture2d<float, access::read>  colorTex [[texture(0)]],
    texture2d<float, access::write> maskTex  [[texture(1)]],
    constant ColorSelectParams& p [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= colorTex.get_width() || gid.y >= colorTex.get_height()) return;

    float4 raw = colorTex.read(gid);
    float3 hsl = rgbToHSL(raw.b, raw.g, raw.r); // BGRA8 swizzle

    float h = hsl.x, s = hsl.y;
    if (s < p.satMin) { maskTex.write(float4(1.0f, 0, 0, 1), gid); return; }

    float diff = abs(h - p.targetH);
    if (diff > 0.5f) diff = 1.0f - diff;
    maskTex.write(float4((diff <= p.hueTol) ? 0.0f : 1.0f, 0, 0, 1), gid);
}

// ── 5. 그라디언트 범위 색상 선택 마스크 커널 (B-6) ────────────
struct ColorRangeParams {
    float hFrom;
    float hTo;
    float hueTol;
    float satMin;
};

kernel void colorRangeMask(
    texture2d<float, access::read>  colorTex [[texture(0)]],
    texture2d<float, access::write> maskTex  [[texture(1)]],
    constant ColorRangeParams& p [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= colorTex.get_width() || gid.y >= colorTex.get_height()) return;

    float4 raw = colorTex.read(gid);
    float3 hsl = rgbToHSL(raw.b, raw.g, raw.r);
    float h = hsl.x, s = hsl.y;

    if (s < p.satMin) { maskTex.write(float4(1.0f, 0, 0, 1), gid); return; }

    float lo = p.hFrom - p.hueTol;
    float hi = p.hTo   + p.hueTol;
    float maskVal;
    if (p.hFrom <= p.hTo) {
        maskVal = (h >= lo && h <= hi) ? 0.0f : 1.0f;
    } else {
        maskVal = (h >= lo || h <= hi) ? 0.0f : 1.0f;
    }
    maskTex.write(float4(maskVal, 0, 0, 1), gid);
}

// ── Phase 5: 이펙트 공통 파라미터 ──────────────────────────────
struct EffectParams {
    float intensity;    // 0.0~1.0
    float frameCount;   // 필름 그레인 노이즈 시드
};

// ── 6. 네온 글로우 (컬러 영역만) ───────────────────────────────
kernel void neonGlowEffect(
    texture2d<float, access::read>  inTex   [[texture(0)]],
    texture2d<float, access::read>  maskTex [[texture(1)]],
    texture2d<float, access::write> outTex  [[texture(2)]],
    constant EffectParams& p [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= outTex.get_width() || gid.y >= outTex.get_height()) return;
    float4 c = inTex.read(gid);
    float mask = maskTex.read(gid).r;

    if (mask < 0.5f) {
        // 컬러 영역: 밝기 부스트 + 채도 높은 채널 글로우
        float3 boosted = c.rgb * (1.0f + p.intensity * 0.8f);
        float3 glow = max(c.rgb - 0.4f, 0.0f) * p.intensity * 1.5f;
        outTex.write(float4(clamp(boosted + glow, 0.0f, 1.0f), 1.0f), gid);
    } else {
        outTex.write(c, gid);
    }
}

// ── 7. 색수차 (Chromatic Aberration, 컬러 영역만) ──────────────
kernel void chromaticEffect(
    texture2d<float, access::read>  inTex   [[texture(0)]],
    texture2d<float, access::read>  maskTex [[texture(1)]],
    texture2d<float, access::write> outTex  [[texture(2)]],
    constant EffectParams& p [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= outTex.get_width() || gid.y >= outTex.get_height()) return;
    float4 c = inTex.read(gid);
    float mask = maskTex.read(gid).r;

    if (mask < 0.5f) {
        int shift = max(1, int(p.intensity * 7.0f));
        int W = int(inTex.get_width()), H = int(inTex.get_height());
        uint2 rPos = uint2(clamp(int(gid.x) + shift, 0, W - 1), gid.y);
        uint2 bPos = uint2(clamp(int(gid.x) - shift, 0, W - 1), gid.y);
        float r = inTex.read(rPos).r;
        float b = inTex.read(bPos).b;
        outTex.write(float4(r, c.g, b, 1.0f), gid);
    } else {
        outTex.write(c, gid);
    }
}

// ── 8. 필름 그레인 (전체 이미지) ───────────────────────────────
static float hashNoise(uint2 gid, float seed) {
    float2 pf = float2(float(gid.x), float(gid.y));
    float h = dot(pf, float2(127.1f, 311.7f)) + seed;
    return fract(sin(h) * 43758.5453f);
}

kernel void filmGrainEffect(
    texture2d<float, access::read>  inTex   [[texture(0)]],
    texture2d<float, access::read>  maskTex [[texture(1)]],  // 미사용 (인터페이스 통일)
    texture2d<float, access::write> outTex  [[texture(2)]],
    constant EffectParams& p [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= outTex.get_width() || gid.y >= outTex.get_height()) return;
    float4 c = inTex.read(gid);
    float noise = hashNoise(gid, p.frameCount) - 0.5f;
    float3 result = clamp(c.rgb + noise * p.intensity * 0.35f, 0.0f, 1.0f);
    outTex.write(float4(result, 1.0f), gid);
}

// ── 9. 배경 블러 (흑백 영역 박스 블러) ─────────────────────────
kernel void bgBlurEffect(
    texture2d<float, access::read>  inTex   [[texture(0)]],
    texture2d<float, access::read>  maskTex [[texture(1)]],
    texture2d<float, access::write> outTex  [[texture(2)]],
    constant EffectParams& p [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= outTex.get_width() || gid.y >= outTex.get_height()) return;
    float mask = maskTex.read(gid).r;
    float4 c = inTex.read(gid);

    if (mask > 0.5f) {
        int radius = max(1, int(p.intensity * 5.0f));
        float3 sum = float3(0.0f);
        float cnt = 0.0f;
        int W = int(inTex.get_width()), H = int(inTex.get_height());
        for (int dy = -radius; dy <= radius; dy++) {
            for (int dx = -radius; dx <= radius; dx++) {
                uint2 s = uint2(clamp(int(gid.x)+dx, 0, W-1),
                                clamp(int(gid.y)+dy, 0, H-1));
                sum += inTex.read(s).rgb;
                cnt += 1.0f;
            }
        }
        outTex.write(float4(sum / cnt, 1.0f), gid);
    } else {
        outTex.write(c, gid);
    }
}

// ── 11. 그레이스케일 변환 (카메라 실시간용, BGRA 입출력) ──────────
// BGRA 텍스처: .r=Blue, .g=Green, .b=Red 채널 순서
kernel void makeGrayscale(
    texture2d<float, access::read>  colorTex [[texture(0)]],
    texture2d<float, access::write> grayTex  [[texture(1)]],
    uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= grayTex.get_width() || gid.y >= grayTex.get_height()) return;
    float4 c = colorTex.read(gid);
    // BGRA 스와이즐: c.r=Blue, c.g=Green, c.b=Red → 실제 RGB 루미넌스
    float lum = 0.0722f * c.r + 0.7152f * c.g + 0.2126f * c.b;
    float boosted = clamp(lum * 1.1f + 0.03f, 0.0f, 1.0f);
    grayTex.write(float4(boosted, boosted, boosted, 1.0f), gid);
}

// ── 12. 시간적 스무딩 (Temporal Smoothing, EMA α=0.3) ────────────
// 이전 프레임 마스크와 현재 AI 마스크를 가중 평균하여 지터 방지
kernel void temporalSmooth(
    texture2d<float, access::read>  currentMask [[texture(0)]],
    texture2d<float, access::read>  prevMask    [[texture(1)]],
    texture2d<float, access::write> outMask     [[texture(2)]],
    constant float &alpha                        [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= outMask.get_width() || gid.y >= outMask.get_height()) return;
    float curr = currentMask.read(gid).r;
    float prev = prevMask.read(gid).r;
    // α=0.3: 새 프레임 30% + 이전 프레임 70% → 부드러운 전환
    outMask.write(float4(mix(prev, curr, alpha), 0.0f, 0.0f, 1.0f), gid);
}

// ── 13. 실시간 Color Splash 블렌드 (카메라 프리뷰용, BGRA I/O) ───
// colorTex(BGRA) + grayTex(BGRA) + maskTex(R32F) → outTex(BGRA)
kernel void realtimeColorSplash(
    texture2d<float, access::read>  colorTex  [[texture(0)]],
    texture2d<float, access::read>  grayTex   [[texture(1)]],
    texture2d<float, access::read>  maskTex   [[texture(2)]],
    texture2d<float, access::write> outTex    [[texture(3)]],
    constant float &isInverse                  [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= outTex.get_width() || gid.y >= outTex.get_height()) return;
    float4 color = colorTex.read(gid);
    float4 gray  = grayTex.read(gid);
    float  mask  = maskTex.read(gid).r;
    if (isInverse > 0.5f) mask = 1.0f - mask;
    outTex.write(float4(mix(color, gray, mask).rgb, 1.0f), gid);
}

// ── 10. 필름 누아르 (흑백 영역 고대비 + 비네팅) ─────────────────
kernel void filmNoirEffect(
    texture2d<float, access::read>  inTex   [[texture(0)]],
    texture2d<float, access::read>  maskTex [[texture(1)]],
    texture2d<float, access::write> outTex  [[texture(2)]],
    constant EffectParams& p [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= outTex.get_width() || gid.y >= outTex.get_height()) return;
    float4 c = inTex.read(gid);
    float mask = maskTex.read(gid).r;

    if (mask > 0.5f) {
        // 고대비 S커브
        float3 contrasted = (c.rgb - 0.5f) * (1.0f + p.intensity * 1.8f) + 0.5f;
        // 비네팅
        float cx = float(gid.x) / float(inTex.get_width())  - 0.5f;
        float cy = float(gid.y) / float(inTex.get_height()) - 0.5f;
        float dist = length(float2(cx, cy));
        float vignette = 1.0f - smoothstep(0.25f, 0.75f, dist * p.intensity * 2.5f);
        outTex.write(float4(clamp(contrasted * vignette, 0.0f, 1.0f), 1.0f), gid);
    } else {
        outTex.write(c, gid);
    }
}
