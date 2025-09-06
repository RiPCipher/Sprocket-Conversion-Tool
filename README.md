# Sprocket-Conversion-Tool

# Installation:
- extract .zip file where ever you'd like. Although I recommend making a folder named "Sprocket Conversion Tool", and placing its contents into the folder.
- It will contain the .exe, a config file where filepaths are saved, an Output folder, and a copy of this readme


# How To Use:
- Simply save the part you'd like to modify as a plate structure, open tool, navigate to the "Conversion" tab and select your file.
- The Previewer can load both .obj and .blueprint files and display them prior to actual import/export. 
  A toggle to auto-preview loaded models is located in the settings, 
  if turned on it will swap to the preview tab everytime you load a file in the converison tab and load the model

Caveats:
- It doesnt retain armor values when exporting to .obj
- Make sure you're only exporting/importing Plate Structure blueprints. it wont work with anything else.
- Ensure that when exporting from blender, the objects rotation is the same as it was when it was initially loaded into blender.
- keep performance expectation's in mind when importing and loading it into Sprocket
- If you to set a custom Output filepath , you can safely delete the "Output" folder.
- If you wipe the custom filepaths from the config, it will regenerate the default folders in whatever directory you place the executable.
- If you decide to move the executable and dont move the config with it, it will regenerate the config with default values and you will need to resave your filepaths again

# Debugging
- There is a seperate debugger.pck file you can download.
  add the .pck to the .exe directory or make a folder named "debug" and place it there to turn on debug logging