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

// Renders text in the 3D world.

#version 330 core

in vec2 UV;
in vec3 fragmentColor;
in vec4 stupidVector;
out vec3 color;

uniform sampler2D textureSampler;

void main()
{
	vec3 textureColor = texture(textureSampler, UV).rgb; // Used as mask.

    // Generally, the higher this value is, the thinner the font is.
    float threshold = 0.8;

    if(textureColor.r < threshold &&
        textureColor.g < threshold &&
        textureColor.b < threshold)
    {
        discard; // Get rid of non-white pixels.
    }

    // Remove our stupidVector used in the vertex shader to trick GLSL.
    color = fragmentColor - stupidVector.xyz;
}
