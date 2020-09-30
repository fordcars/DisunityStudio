//// Copyright 2016 Carl Hewett
////
//// This file is part of SDL3D.
////
//// SDL3D is free software: you can redistribute it and/or modify
//// it under the terms of the GNU General Public License as published by
//// the Free Software Foundation, either version 3 of the License, or
//// (at your option) any later version.
////
//// SDL3D is distributed in the hope that it will be useful,
//// but WITHOUT ANY WARRANTY; without even the implied warranty of
//// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//// GNU General Public License for more details.
////
//// You should have received a copy of the GNU General Public License
//// along with SDL3D. If not, see <http://www.gnu.org/licenses/>.
///////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////

// This file is heavily based off http://www.opengl-tutorial.org/, see SpecialThanks.txt

// Renders text directly on the screen.
// Uses the model matrix for x and y coords. z coord is discarded.

#version 330 core

// Input vertex data, different for all executions
layout(location = 0) in vec3 vertexPosition_modelspace;
layout(location = 1) in vec2 vertexUV;
layout(location = 2) in vec3 vertexColor;

// SDL3D forces us to use all uniforms :(
uniform mat4 MVP;
uniform mat4 modelMatrix;
uniform mat4 viewMatrix;
uniform mat4 projectionMatrix;
uniform mat4 normalMatrix;

out vec2 UV;
out vec3 fragmentColor;
out vec4 stupidVector;

void main()
{
    float clipSpaceZ = 0; // This is simply -w!

    // We keep x and y coords only
	vec4 worldSpaceVertex = modelMatrix * vec4(vertexPosition_modelspace, 1);
    gl_Position = vec4(worldSpaceVertex.xy, clipSpaceZ, 1);

    // We must trick GLSL that we are using all of the matrices.
    // Keep in mind these remain the same for all vertices, so it won't
    // be a problem to use stupidVector in the fragment vector aswell.
    stupidVector = MVP * viewMatrix * projectionMatrix * normalMatrix * vec4(1.0, 1.0, 1.0, 1.0);

	UV = vertexUV;
    fragmentColor = vertexColor + stupidVector.xyz; // Relax! We'll remove it in the fragment shader.
}
