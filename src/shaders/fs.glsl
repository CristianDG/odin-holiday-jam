#version 300 es

out mediump vec4 frag_color;
in mediump vec4 vertex_color;

void main()
{
  frag_color = vertex_color;
}

