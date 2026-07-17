The Launcher contains the actual autoloads for this project, the autoload scripts in the Scripts directory are essentailly mirrored copies of the launchers with the exception of the FormatRegistry.gd script.
Inside of the Launcher project/directory is a modified version that loads the formats from the .pck file at runtime rather than being hardcoded into the Launcher executable.

This allows me to modify the formats with needing to update the launcher

All of the Autoloads in the main Conversion Tool Project exist for standalone testing without needing to export to .pck for every change or needing to update the executable
