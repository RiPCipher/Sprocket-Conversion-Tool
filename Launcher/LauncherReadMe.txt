This project that acts as a bootstrapper for the conversion tool. It owns all Singletons and when exported, is what contains the Godot Engines Binaries (Stripped of the editor and debugging tools). 
In the past, I bundled everything together as a single executable but that rules out minor updates as an option as changing 1 line of code required people to download a nearly 100mb file each time

this method allows for the updating of the actual Conversion Tools .pck file

Launch Flow: Sprocket Conversion Tool.exe -> executable loads the .pck that contains the actual Conversion Tool content -> Main Converter.tscn scene loads along with all other files
