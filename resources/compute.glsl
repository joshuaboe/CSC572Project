#version 450 
#extension GL_ARB_shader_storage_buffer_object : require

#define NUMBALLS 20 // number of balls
#define NUMPEGS 100 // number of pegs

#define BALLRADIUS 0.20 // radius of the balls
#define PEGSEPARATION (BALLRADIUS * 3.0) // how far to distance pegs between one another

#define PEGSCALE 0.1 // how large the pegs are

#define BOARDBUFFER 2.0 // extra space at top and bottom of board

#define BOARDWIDTH ((2.0 * sqrt(NUMPEGS) + 1.0) * PEGSEPARATION)
#define BOARDLENGTH (((2.0 * sqrt(NUMPEGS) + 1.0) * PEGSEPARATION) + (2.0 * BOARDBUFFER))

#define CAMERAPOSITION (-1.0 * BOARDLENGTH * 1.7) // distance of camera from board
#define BOARDPOSITION 0.0 // z-ccordinate of the wall

#define LEFTSIDE (-1.0 * BOARDWIDTH / 2.0)
#define BOTTOMSIDE (-1.0 * BOARDLENGTH / 2.0)
#define BOTTOMPEG ((-1.0 * BOARDLENGTH / 2.0) + BOARDBUFFER)

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
    vec4 curr_pos = ballpos[index];

    int max_index = int(sqrt(NUMPEGS)) - 1;
    float min_board_height = pegpos[0][0].y - PEGSEPARATION;
    float max_board_height = pegpos[max_index][max_index].y + PEGSEPARATION;
    float max_board_width = pegpos[max_index][max_index].x + PEGSEPARATION;

    int row = int((curr_pos.y - (pegpos[0][0].y - PEGSEPARATION)) / (PEGSEPARATION * 2));
    int col = int((curr_pos.x - (pegpos[0][0].x - PEGSEPARATION) - ((row % 2) * PEGSEPARATION)) / (PEGSEPARATION * 2));
    //ballv[index].w = row*10 + col;

    if (row <= max_index && row >= 0 && col <= max_index && col >= 0) {
        float distance_to_collide = BALLRADIUS + PEGSCALE; //0.35; //(BALLRADIUS + PEGSCALE) / PEGSEPARATION * 2;
        vec2 diff = curr_pos.xy - pegpos[row][col].xy;
        //ballv[index].w = length(diff);
        if (length(diff) < distance_to_collide) {
            float dampening = 0.7;
            ballv[index].xy = normalize(diff) * length(ballv[index].xy) * dampening;
            ballpos[index].xy = pegpos[row][col].xy + normalize(diff) * distance_to_collide;
        }
    }
}
