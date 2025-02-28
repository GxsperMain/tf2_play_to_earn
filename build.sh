#!/bin/sh

currentDir=$(pwd)

# Copying the file from sourcemod to the git folder
cp -r ./play_to_earn_db.sp ./tf/addons/sourcemod/scripting

# Compiling
cd ./tf/addons/sourcemod/scripting
./compile.sh play_to_earn_db.sp

echo "Output: ./tf/addons/sourcemod/scripting/compiled/play_to_earn_db.smx"

cd "$currentDir"
# Copying the file from sourcemod to the git folder
cp -r ./play_to_earn_json.sp ./tf/addons/sourcemod/scripting

# Compiling
cd ./tf/addons/sourcemod/scripting
./compile.sh play_to_earn_json.sp

echo "Output: ./tf/addons/sourcemod/scripting/compiled/play_to_earn_json.smx"