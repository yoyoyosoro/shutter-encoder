# Shutter Encoder custom

This branch removes the exit donation prompt while preserving settings saving, cleanup, copyrights and licensing.

To update: run Actions > Merge upstream into custom on master, wait for success, then close Shutter Encoder and run the local update shortcut.

The local updater builds custom, uses matching official portable dependencies, verifies real desktop exit scenarios and H.264 encoding, then backs up and updates the existing installation. Failed tests keep the installed version.

The repository original JAR is a build input and must be rebuilt for the donation-free program.
