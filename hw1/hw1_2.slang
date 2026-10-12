import hw1_common;

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
    uint width, height;
    image.GetDimensions(width, height);
    if (tid.x >= width || tid.y >= height) {
        return;
    }

    image[tid] = float4(1.0);


    //origin of a point
    float2 pixel = float2(tid.x, tid.y);

    float2 ray_direct = float2(1.0, 0.0);

    if (use_fill_color) {
        int crossings = 0;

        for (int i = 0; i < num_polyline; i++) {
            float2 a = polyline[i];
            float2 b = polyline[(i + 1) % num_polyline];

            // Question 1: does this edge reach the pixel's height?
            // One endpoint must be above p.y and the other below it.
            bool spans_y = (a.y > pixel.y) != (b.y > pixel.y);

            if (spans_y) {
                // Question 2: how far from a to b do we go to reach y = p.y?
                // (a number between 0 and 1)
                //float t = /* TODO */;

                // the x of the edge at that height
                float x_cross; /* TODO: use a.x, b.x, and t */

                // Question 3: is the crossing to the right of p?
                if (x_cross > pixel.x) {
                    crossings++;
                }
            }
        }

        if (crossings % 2 == 1) {
            image[tid] = float4(fill_color, 1.0);
        }
    }
}
