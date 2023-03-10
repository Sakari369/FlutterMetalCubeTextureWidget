//  SumoShaders.metal
//  Created by Sakari Lehtonen on 1.12.2022.

#include <metal_stdlib>

using namespace metal;

typedef enum VertexInputIndex {
    VertexInVertices = 0,
    VertexInUniforms = 1,
} VertexInputIndex;

typedef struct {
    vector_float3 position;
    vector_float4 color;
} Vertex;

struct Uniforms{
    float4x4 modelMatrix;
    float4x4 viewMatrix;
    float4x4 projectionMatrix;
};

struct RasterizerData {
    // The [[position]] attribute of this member indicates that this value is the clip space
    // position of the vertex when this structure is returned from the vertex function.
    float4 position [[position]];
    
    // Since this member does not have a special attribute, the rasterizer
    // interpolates its value with the values of the other triangle vertices
    // and then passes the interpolated value to the fragment shader for each
    // fragment in the triangle.
    float4 color;
};

vertex RasterizerData
vertexShader(
             uint vertexID                          [ [vertex_id] ],
             constant Vertex *vertices              [ [buffer(VertexInVertices)] ],
             constant Uniforms &uniforms            [ [buffer(VertexInUniforms)] ]
             )
{
    Vertex vertexIn = vertices[vertexID];
    float4x4 mvp = uniforms.viewMatrix * uniforms.projectionMatrix * uniforms.modelMatrix;
    
    RasterizerData out;
    out.position = mvp * float4(vertexIn.position, 1);
    out.color = vertexIn.color;
    
    return out;
}

// The stage_in attribute indicates that this argument is generated by the rasterizer.
fragment float4 fragmentShader(RasterizerData in [[stage_in]]) {
    // Return interpolated color.
    return in.color;
}

