# Sprocket-Conversion-Tool

# Installation:
- extract .zip file where ever you'd like. Although I recommend making a folder named "Sprocket Conversion Tool", and placing its contents into the folder.
- It will contain the .exe, 2 folders (default Blueprint and Object folders), a config file where filepaths are saved, and a copy of this readme


# How To Use:
- Simply save the part you'd like to modify as a plate structure, open tool, navigate to "Blueprint to OBJ" and select your file.
  If you set a custom filepath in the settings, it will auto-fill the output path and set the OBJ name to the blueprints name.
- Same instructions when going from OBJ to Blueprint, with the exception of the limits toggle that will let you know if you're importing a high-poly model that might affect performance.
- The Previewer can load both .obj and .blueprint files and display them prior to actual import/export. 
  A toggle to auto-preview loaded models is located in the settings.

Caveats:
- It doesnt retain armor values when exporting to .obj
- Make sure you're only exporting/importing Plate Structure blueprints. it wont work with anything else.
- Ensure that when exporting from blender, the objects rotation is the same as it was when it was initially loaded into blender.
- Generally speaking, the more complex the model, the higher chance Sprocket will lag and/or freeze.
  The limit toggle has the max vert/face values I've personally tested without lag or unexpected performance issues,
  your mileage may vary depending on PC setup.
- .obj exporter has no such limit, just keep performance expectation's in mind when importing and loading it into Sprocket

- If you decide to set custom filepaths for Blueprints and Objects, you can safely delete the default folders.
- If you wipe the custom filepaths from the config, it will regenerate the default folders in whatever directory you place the executable.
- If you decide to move the executable and dont move the config with it, it will regenerate the config with default values and you will need to resave your filepaths again
  and it will regenerate the default folders
