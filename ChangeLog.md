Changes for 0.5.0

# Fixes
- Removed improper variable assignement and signaling that was causing import errors to default to code 0,
  even when the tool had enough information to present an actual error code
- Implemented potential crash fix (TBD)

# New Update System
- Implemented an update system that is opt-in in the settings (Enable Network Features)
  when toggled on, it will check the github repo for the latest updates, present a button to download, install the update, and restart the application
  Note: This will be used for most minor updates and fixes going forward, however, any updates that affect the new launcher will get their own release and wont utilize the update system

# Error system
- added additional blueprint checks in the format handler to ensure only compatable blueprints can be handled
- added new error messages
- clarified certain error messages to be more explicit

# Debug System
- Temporarily disabled until a more seamless method is implemented

# Misc

# Code:
Threading/Memory: (Hopefully these changes continue to help with compatability)
- Finished removing left over ThreadPool code, tool now runs on a single worker thread entirely

Other:
- Removed left over testing code for the error system that should not have been present in the last version
- Moved ConfigManager to Autoload

# Renderer:
- Disabled the fancy lighting and added a reflection probe in its place

# UI:
- Implemented Minecraft-like splash message system
- Removed Tab saving from the tool entirely
- Modified Checkbox Styling
