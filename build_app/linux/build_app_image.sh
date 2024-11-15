#!/bin/bash
cd "$(dirname "$0")"

# Variables
FLUTTER_BUILD_DIR="../../build/linux/x64/release/bundle"
APP_DIR="../../build/linux/x64/release/AppDir"
ICON_NAME="icon.png" # Replace with your icon file name
DESKTOP_FILE_NAME="path_pilot.desktop" # Replace with your desktop file name
VERSION="1.0.0"

# Step 1: Build Flutter app for Linux
echo "Building Flutter app for Linux..."
flutter build linux --release


# Step 2: Prepare AppDir structure
echo "Preparing AppDir structure..."
mkdir -p $APP_DIR/usr/bin
mkdir -p $APP_DIR/usr/lib

# Copy the built Flutter app
cp -r $FLUTTER_BUILD_DIR/* $APP_DIR/usr/bin

# Step 3: Create AppRun file
echo "Copying AppRun file..."
cp AppRun $APP_DIR/
chmod +x $APP_DIR/AppRun

# Step 4: Create .desktop file
echo "Copying .desktop file..."
cp $DESKTOP_FILE_NAME $APP_DIR/

# Step 5: Add icon
echo "Adding icon..."
cp ../$ICON_NAME $APP_DIR/ # Replace with the path to your icon

# Step 6: Install necessary tools
echo "Installing necessary tools..."
if ! command -v appimagetool &> /dev/null
then
    wget "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"
    chmod +x appimagetool-x86_64.AppImage
    sudo mv appimagetool-x86_64.AppImage /usr/local/bin/appimagetool
fi

# Step 7: Create the AppImage
echo "Creating AppImage..."
ARCH=x86_64 appimagetool $APP_DIR/ $APP_DIR/../RobiLineDrawer_Linux_V$VERSION.AppImage

echo "AppImage created successfully."

echo "Removing AppDir"
rm -r $APP_DIR/
