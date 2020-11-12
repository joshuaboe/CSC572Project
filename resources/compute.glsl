#version 450 
#extension GL_ARB_shader_storage_buffer_object : require

#define NUMBALLS 100

layout(local_size_x = NUMBALLS, local_size_y = 1) in;	

//local group of shaders
layout (std430, binding=0) volatile buffer shader_data
{ 
  vec4 pos[NUMBALLS];
  vec4 v[NUMBALLS];
  uint collisions[NUMBALLS];
};

vec3 minus(vec3 v1, vec3 v2) {
    vec3 r;
    r.x = v1.x - v2.x;
    r.y = v1.y - v2.y;
    r.z = v1.z - v2.z;
    return r;
}

float dotProduct(vec3 v1, vec3 v2) {
    return v1.x * v2.x + v1.y * v2.y + v1.z * v2.z;
}

vec3 scale(vec3 v, float a) {
    vec3 r;
    r.x = v.x * a;
    r.y = v.y * a;
    r.z = v.z * a;
    return r;
}

vec3 projectUonV(vec3 u, vec3 v) {
    vec3 r;
    r = scale(v, dotProduct(u, v) / dotProduct(v, v));
    return r;
}

float distanceSquared(vec3 v1, vec3 v2) {
    vec3 delta = minus(v2, v1);
    return dotProduct(delta, delta);
}

bool doesItCollide(uint s1, uint s2) {
    float rSquared = pos[s1].w + pos[s2].w;
    rSquared *= rSquared;
    return distanceSquared(vec3(pos[s1]), vec3(pos[s2])) < rSquared;
}

void performCollision(uint s1, uint s2) {
    vec3 nv1; // new velocity for sphere 1
    vec3 nv2; // new velocity for sphere 2
    // this can probably be optimised a bit, but it basically swaps the velocity amounts
    // that are perpendicular to the surface of the collistion.
    // If the spheres had different masses, then u would need to scale the amounts of
    // velocities exchanged inversely proportional to their masses.
    nv1 = vec3(v[s1]);
    nv1 += projectUonV(vec3(v[s2]), minus(vec3(pos[s2]), vec3(pos[s1])));
    nv1 -= projectUonV(vec3(v[s1]), minus(vec3(pos[s1]), vec3(pos[s2])));
    nv2 = vec3(v[s2]);
    nv2 += projectUonV(vec3(v[s1]), minus(vec3(pos[s2]), vec3(pos[s1])));
    nv2 -= projectUonV(vec3(v[s2]), minus(vec3(pos[s1]), vec3(pos[s2])));

    v[s1].x = nv1.x;
    v[s1].y = nv1.y;
    v[s1].z = nv1.z;

    v[s2].x = nv2.x;
    v[s2].y = nv2.y;
    v[s2].z = nv2.z;
}


void main() 
{
	uint index = gl_LocalInvocationID.x;
    uint a = 0;

    for (uint i = index + 1; i < NUMBALLS; i++) {
        if (doesItCollide(index, i)) {
            atomicAdd(collisions[index], 1);
            atomicAdd(collisions[i], 1);
            if (collisions[index] < 2 && collisions[i] < 2) {
                performCollision(index, i);
            }
        }
    }
}
