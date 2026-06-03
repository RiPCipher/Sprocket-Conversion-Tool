Changes for 0.6.0
Compatable Launcher(s): v2.0

## Code
- Reworked UI code to utilize unique names instead of paths. Ensures UI edits do not break the program and makes the scripts more readable
- Refactored main.gd to slim it from being 1000+ to around 300 lines. Moved functionalities to various controller scripts (UpdateController, PreviewController, ConversionController, BrowserController)
- Created and added an Editor Plugin that allows me to dump the editor error/warning logs on demand and all at once
- Removed ConfigManager from the launcher and tool autoloads. Now loads along with the other managers. This change enables me to make edits without needing to update the launcher.
- Small change to update manager to ensure it only attempts to grab .pck files named "Sprocket_Conversion_Tool.pck"
- Removed unused hardcoded keybinds from the project 
- Added ability to load a custom Splash Screen by adding a .png to the data folder and renaming it to "SplashScreen.png"

## UI
- Added a custom Splash Screen to the project
- Anchored some UI elements so they stay aligned when the screen size changes
- Added a Use Native Windows button for the file browser that replaces the custom window with a native one
- Minor Margin Adjustments to the Main Panel
- Reworked Theme Textures. Some now have normal maps.
- Added 2D Lighting
- Adjusted various elements of the UI to improve look/usability/uniformity
- Hid splash text
- Temporarily hid the Tools Tab/Gear Calculator as it is currently outdated

## Engine Update
- Updated Engine to Godot 4.6.stable to keep tool in line with my other projects. Re-download of tool required

## Graphical Settings
- Adjusted SSAA from FXAA to SMAA
