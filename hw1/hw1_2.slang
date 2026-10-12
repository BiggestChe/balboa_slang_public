import hw1_common;

// ---------------------------------------------------------------------------
// Helper: is point p inside the closed polygon?
//
// Non-zero rule: shoot a ray from p to the right. Each edge the ray crosses
// adds +1 if the edge goes upward (y increasing) and -1 if it goes downward.
// The total is the "winding number": how many times the outline wraps around
// p. If it is anything other than 0, p is inside.
// ---------------------------------------------------------------------------
bool is_inside(float2 p, StructuredBuffer<float2> points, int n) {
    int winding = 0;

    for (int i = 0; i < n; i++) {
        float2 a = points[i];
        float2 b = points[(i + 1) % n];   // wrap around: last point connects to first

        // Skip edges that don't reach p's height (one end must be above, one below).
        if ((a.y > p.y) == (b.y > p.y)) {
            continue;
        }

        // Find the x where the edge crosses the horizontal line y = p.y.
        // t is how far along the edge (0 = at a, 1 = at b) that crossing is.
        float t = (p.y - a.y) / (b.y - a.y);
        float x_cross = a.x + t * (b.x - a.x);

        // Only count crossings to the right of p (that's where the ray goes).
        if (x_cross > p.x) {
            // Upward edge adds one, downward edge subtracts one.
            winding += (b.y > a.y) ? 1 : -1;
        }
    }

    return winding != 0;
}

// ---------------------------------------------------------------------------
// Main shader: one thread per pixel.
// ---------------------------------------------------------------------------
[shader("compute")]
[numthreads(8, 8, 1)]
void compute_main(uint2 tid : SV_DispatchThreadID,
                  StructuredBuffer<float2> polyline,
                  uniform int num_polyline,
                  uniform bool is_closed,
                  uniform bool use_fill_color,
                  uniform float3 fill_color,
                  uniform bool use_stroke_color,
                  uniform float3 stroke_color,
                  uniform float stroke_width,
                  RWTexture2D<float4> image) {
    // Skip threads that fall outside the image.
    uint width, height;
    image.GetDimensions(width, height);
    if (tid.x >= width || tid.y >= height) {
        return;
    }

    // Use the center of the pixel, not its corner.
    // The input points use y-up (origin at the bottom-left), but image rows
    // go top to bottom, so flip y to put p in the same space as the points.
    float2 p = float2(tid.x + 0.5, height - (tid.y + 0.5));

    // Start with a white background.
    float3 color = float3(1.0);

    // Fill: color the pixel if it's inside the polygon.
    if (use_fill_color && is_inside(p, polyline, num_polyline)) {
        color = fill_color;
    }

    // Stroke: color the pixel if it's close enough to any edge.
    // Done after the fill so the outline is drawn on top.
    if (use_stroke_color) {
        // An open polyline has one fewer edge (no segment from last back to first).
        int num_edges = is_closed ? num_polyline : num_polyline - 1;

        for (int i = 0; i < num_edges; i++) {
            float2 a = polyline[i];
            float2 b = polyline[(i + 1) % num_polyline];

            // Find the point on segment a-b closest to p.
            // Points on the segment are a + h * (b - a) with h in [0, 1]:
            // project p onto the edge, then clamp h so we stay between a and b.
            float2 ab = b - a;
            float len_sq = max(dot(ab, ab), 1e-8);   // avoid divide-by-zero if a == b
            float h = clamp(dot(p - a, ab) / len_sq, 0.0, 1.0);
            float2 closest = a + h * ab;

            // stroke_width is the full thickness, so half goes on each side.
            if (distance(p, closest) <= stroke_width / 2.0) {
                color = stroke_color;
                break;              // close to one edge is enough
            }
        }
    }

    image[tid] = float4(color, 1.0);
}
