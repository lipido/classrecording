#!/bin/bash
# author lipido
#
# Requirements:
# - libav-tools
#
# avconv pipeline:
# - camera video is resized to the same as desktop
# - camera is positioned on the left side
# - the final video is resized to a user-defined scale


#Parameters
if [ "$#" -ne 1 ]; then
	PROJECT_NAME="teaching"
else
	PROJECT_NAME=$1
fi
########### CONFIGURATION ##############
OUTPUT_VIDEO=${PROJECT_NAME}.mkv
WEBCAM=/dev/video0
OUTPUT_SCALE="0.5" # a positive decimal number (<1.0 reduces)
STACK="HORIZONTAL" # HORIZONTAL or VERTICAL
VIDEO_DELAY="00:00:01.0" #HH:MM:SS
########################################


#detect desktop resolution to scale webcam to the same size
CURRENT_RESOLUTION=$(xrandr -q | awk -F'current' -F',' 'NR==1 \
{gsub("( |current)","");print $2}' | tr 'x' ':')

STACK_HORIZONTAL="[1:v:0]scale=${CURRENT_RESOLUTION}[camera];\
[2:v:0]pad=iw*2:ih[bg];[bg][camera]overlay=w"
STACK_VERTICAL="[1:v:0]scale=${CURRENT_RESOLUTION}[camera];\
[2:v:0]pad=iw:ih*2[bg];[bg][camera]overlay=0:h"


CURRENT_WIDTH=$(echo $CURRENT_RESOLUTION | cut -d ":" -f 1)
CURRENT_HEIGHT=$(echo $CURRENT_RESOLUTION | cut -d ":" -f 2)
if [ "$STACK" == "HORIZONTAL" ]; then
  STACK_FILTER=$STACK_HORIZONTAL
  FINAL_WIDTH=$(echo "$CURRENT_WIDTH * 2 * $OUTPUT_SCALE" | bc)
  FINAL_HEIGHT=$(echo "$CURRENT_HEIGHT * $OUTPUT_SCALE" | bc)  
elif [ "$STACK" == "VERTICAL" ]; then
  STACK_FILTER=$STACK_VERTICAL
  FINAL_WIDTH=$(echo "$CURRENT_WIDTH * $OUTPUT_SCALE" | bc)
  FINAL_HEIGHT=$(echo "$CURRENT_HEIGHT * 2 * $OUTPUT_SCALE" | bc)  
else
  echo "STACK not recognized";
  exit 1
fi
OUTPUT_RES="${FINAL_WIDTH%.*}:${FINAL_HEIGHT%.*}"

FINAL_FILTER="${STACK_FILTER}[merged];[merged]scale=${OUTPUT_RES}"

avconv -y -f pulse -i default -itsoffset $VIDEO_DELAY \
-f video4linux2 -i $WEBCAM -itsoffset $VIDEO_DELAY -f x11grab -s $CURRENT_RESOLUTION -show_region 1 -i :0.0 \
-filter_complex "$FINAL_FILTER" \
-vcodec libx264 -preset ultrafast -r 20 ${OUTPUT_VIDEO}
