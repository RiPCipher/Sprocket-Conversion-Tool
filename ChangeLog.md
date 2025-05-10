Changes for 0.4.4:
- Previewer
	-Added Wireframe Mesh view with toggle
	-Added Wireframe Overlay that displays both Mesh and Wireframe
	-Added a WIP internals view
	-Added Camera panning
	-Added SDFGI / SSIL / SSAO to Previewer world space for better lighting
	-Adjusted Brightness Slider Min/Max Values
	-Lighting adjusts itself based on the size of the model,
	 resulting in more consistent lighting
	-Added a Freecam mode

- Keybinds:
	-Shift + Left Click Pans camera instead of rotating camera
	-R - recenter camera to the model
	-Q/E keys for Camera Zoom (Q = Zoom out E = Zoom in) / Scroll remains similar to 0.3
	-F toggles freecam / Shift for faster movement speed
	-WASD freecam movement / Q and E for vertical movement
	-Escape closes settings menu if opened. If closed, closes application
	- -/= for FOV (- decreases FOV and = Increases FOV) / 30 minimun, 120 maximum, 75 Default
	
- Utility:
	-Removed limits toggle
	-Added Drag and Drop functionality
	 drop the file anywhere in the app window and it will load the file.
	 if auto-preview is on, it will open the preview tab
	 if on previewer tab, it wont switch tabs but will still load the file

- Settings/Config:
	-Program should now save current settings when you exit the application
	 it now also saves the current window size, so you can resize it to how you want it
	-Added Color Options settings for both Wireframe and Mesh
	-Added themes drop list

- Code Stuff:
	-Completely restructured projects rendering, importing, data handling, and threading logic
	-Entirety of Mesh related functions are seperated from main codebase

- UI:
	-Merged individual conversion tabs into a single "Conversion" tab
	-Updated external menus to be detached from the application
	-Implemented proper theme resources, which will make future ui adjustments much more simple
	-Implemented custom file window
	-Added Advanced Settings Menu where keybinds/Settings can be modified

- Fixes:
	Fixed the Auto-Preview setting to correctly save in the config
