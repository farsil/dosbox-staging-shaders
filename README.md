# DOSBox Staging Shaders

A collection of shaders to be used with DOSBox staging.

## How to use

Download the source code of the release that matches your DOSBox staging version,
extract the content of the archive so that the glsl files land in the `shaders` folder
(`glshaders` for DOSBox Staging 0.82).

Then you have to change the `glshader` setting in your configuration file to the exact
filename of the shader, eg:

```conf
[render]
glshader = zfast-composite
```

## Credits

All credits go to their respective authors, I merely updated the shader code for
compatibility.
