[shader("compute")]
[numthreads(8, 8, 1)]
void compute_main(uint2 tid : SV_DispatchThreadID,
                  uniform float2 center,
                  uniform float radius,
                  uniform float3 color,
                  RWTexture2D<float4> image) {
    uint width, height;
    image.GetDimensions(width, height);
    if (tid.x >= width || tid.y >= height) {
        return;
    }

    image[tid] = float4(1.0);
    

    //get pixel position
    float2 pixel = float2(tid.x, tid.y);

    float dist = distance(pixel, center);

        //check if pixel is in circle
        if (dist <= radius) {
        image[tid] = float4(color, 1.0);
        }
        else {
            image[tid] = float4(1.0, 1.0, 1.0, 1.0);
        }


}
