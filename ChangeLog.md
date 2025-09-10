Changes for 0.4.5

# Fixes
- Fixed Issue where OBJ files imported from Blender would have duplicate/disconnected Vertices

# Code:
- Minor UI Updates

Threading/Memory: (Hopefully these changes continue to help with compatability)
- Removed ThreadPool Entirely
- Reworked ConversionWorker to operate with a single thread
- Updated Main.gd to work with the simplified thread system

Rendering:
- Removed View types from Renderer, now located in a seperate "Views" folder to provide a more focused development

# Renderer:
- Made Progress implementing the Internals/Armor View 
(Still some issues to iron out)
