#version 450 
#extension GL_ARB_shader_storage_buffer_object : require

#define NUMBALLS 1
#define NUMPEGS 25

layout(local_size_x = NUMBALLS, local_size_y = 1) in;	

//local group of shaders
layout (std430, binding=0) volatile buffer shader_data
{ 
	vec4 ballpos[NUMBALLS]; // x, y, z, w = radius
	vec4 ballv[NUMBALLS];	// x, y, z, w = collision
	vec4 pegpos[NUMPEGS][NUMPEGS];
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
    float rSquared = ballpos[s1].w + ballpos[s2].w;
    rSquared *= rSquared;
    return distanceSquared(vec3(ballpos[s1]), vec3(ballpos[s2])) < rSquared;
}

void performCollision(uint s1, uint s2) {
    vec3 nv1; // new velocity for sphere 1
    vec3 nv2; // new velocity for sphere 2
    // this can probably be optimised a bit, but it basically swaps the velocity amounts
    // that are perpendicular to the surface of the collistion.
    // If the spheres had different masses, then u would need to scale the amounts of
    // velocities exchanged inversely proportional to their masses.
    nv1 = vec3(ballv[s1]);
    nv1 += projectUonV(vec3(ballv[s2]), minus(vec3(ballpos[s2]), vec3(ballpos[s1])));
    nv1 -= projectUonV(vec3(ballv[s1]), minus(vec3(ballpos[s1]), vec3(ballpos[s2])));
    nv2 = vec3(ballv[s2]);
    nv2 += projectUonV(vec3(ballv[s1]), minus(vec3(ballpos[s2]), vec3(ballpos[s1])));
    nv2 -= projectUonV(vec3(ballv[s2]), minus(vec3(ballpos[s1]), vec3(ballpos[s2])));

    ballv[s1].x = nv1.x;
    ballv[s1].y = nv1.y;
    ballv[s1].z = nv1.z;

    ballv[s2].x = nv2.x;
    ballv[s2].y = nv2.y;
    ballv[s2].z = nv2.z;
}


void main() 
{
	uint index = gl_LocalInvocationID.x;
    uint a = 0;

}
