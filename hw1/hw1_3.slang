import hw1_common;

bool is_inside(float2 p, StructuredBuffer<float2> points,
               int begin, int n)
{
    int counter = 0;

    for (int i = 0; i < n; i++)
    {
        float2 a = points[begin + i];
        float2 b = points[begin + (i + 1) % n];

        if ((a.y > p.y) == (b.y > p.y))
            continue;

        float t = (p.y - a.y) / (b.y - a.y);
        float x_cross = a.x + t * (b.x - a.x);

        if (x_cross > p.x)
        {
            counter += (b.y > a.y) ? 1 : -1;
        }
    }

    return counter != 0;
}

[shader("compute")]
[numthreads(8, 8, 1)]
void compute_main(uint2 tid: SV_DispatchThreadID,
                  uniform float3 background,
                  uniform int /*samples_per_axis*/, // ignore for now
                  StructuredBuffer<Shape> shapes,
                  uniform int num_shapes,
                  StructuredBuffer<Circle> circles,
                  StructuredBuffer<Polyline> polylines,
                  StructuredBuffer<QuadraticBezier> S/*quadratic_beziers*/, // ignore for now
                  StructuredBuffer<float2> points,
                  RWTexture2D<float4> image)
{
    uint width, height;
    image.GetDimensions(width, height);
    if (tid.x >= width || tid.y >= height)
        return;

    // Pixel center, flipped so y points up like the scene coordinates.
    float2 p = float2(tid.x + 0.5, height - (tid.y + 0.5));

    // Background shows if no shape covers this pixel.
    float3 color = background;

    // Front to back: shapes[0] is the frontmost.
    for (int i = 0; i < num_shapes; i++)
    {
        Shape s = shapes[i];
        bool hit = false;

        if (s.type == ShapeType::Circle)
        {
            Circle c = circles[s.index];
            float d = distance(p, c.center);

            // Stroke: within half the width of the edge (inside or outside).
            if (s.use_stroke && abs(d - c.radius) <= s.stroke_width / 2.0)
            {
                color = s.stroke_rgba.rgb;
                hit = true;
            }
            // Fill
            else if (s.use_fill && d <= c.radius)
            {
                color = s.fill_rgba.rgb;
                hit = true;
            }
        }
        else if (s.type == ShapeType::Polyline)
        {
            Polyline pl = polylines[s.index];
            int begin = pl.pts_begin;
            int n = pl.pts_end - pl.pts_begin;

            // Stroke: is p within half the stroke width of any edge?
            if (s.use_stroke)
            {
                // An open polyline has no edge from the last point back to the first.
                int num_edges = pl.closed ? n : n - 1;

                for (int j = 0; j < num_edges; j++)
                {
                    float2 a = points[begin + j];
                    float2 b = points[begin + (j + 1) % n];

                    // Closest point on segment a-b to p, then measure the distance to it.
                    float2 ab = b - a;
                    float len_sq = max(dot(ab, ab), 1e-8);
                    float h = clamp(dot(p - a, ab) / len_sq, 0.0, 1.0);
                    float2 closest = a + h * ab;

                    if (distance(p, closest) <= s.stroke_width / 2.0)
                    {
                        color = s.stroke_rgba.rgb;
                        hit = true;
                        break;
                    }
                }
            }

            // Fill: only if the stroke didn't already cover this pixel.
            if (!hit && s.use_fill && is_inside(p, points, begin, n ))
            {
                color = s.fill_rgba.rgb;
                hit = true;
            }
        }

        // The frontmost shape covers everything behind it, so stop looking.
        if (hit)
            break;
    }
    image[tid] = float4(color, 1.0);
}
