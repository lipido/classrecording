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
OUTPUT_SCALE="0.5" # A positive decimal number (<1.0 reduces)
STACK="HORIZONTAL" # HORIZONTAL or VERTICAL
VIDEO_DELAY="00:00:01.0" # Delay with respect to sound in HH:MM:SS
X264_PRESET="ultrafast" # Encoding speed (less compression):  \ 
WEBCAM_DESKTOP_RATIO="0.5" # Webcam/destkop size, between 0.0 and 1.0
# ultrafast, superfast, veryfast, faster, fast, medium, \
# slow, slower, veryslow, placebo. 
########################################

echo "Output video: ${OUTPUT_VIDEO}"
echo "Webcam: $WEBCAM"
echo "Stack: $STACK"
echo "Video delay: $VIDEO_DELAY"
echo "X264 preset: $X264_PRESET"

#detect desktop resolution to scale webcam to the same size
CURRENT_RESOLUTION=$(xrandr -q | awk -F'current' -F',' 'NR==1 \
{gsub("( |current)","");print $2}' | tr 'x' ':')

CURRENT_WIDTH=$(echo $CURRENT_RESOLUTION | cut -d ":" -f 1)
CURRENT_HEIGHT=$(echo $CURRENT_RESOLUTION | cut -d ":" -f 2)
WEBCAM_WIDTH=$(echo "$CURRENT_WIDTH * $WEBCAM_DESKTOP_RATIO" | bc)
WEBCAM_WIDTH=${WEBCAM_WIDTH%.*}
WEBCAM_WIDTH=$(echo "${WEBCAM_WIDTH} + (${WEBCAM_WIDTH} % 2)" | bc)
WEBCAM_HEIGHT=$(echo "$CURRENT_HEIGHT * $WEBCAM_DESKTOP_RATIO" | bc)
WEBCAM_HEIGHT=${WEBCAM_HEIGHT%.*}
WEBCAM_HEIGHT=$(echo "${WEBCAM_HEIGHT} + (${WEBCAM_HEIGHT} % 2)" | bc)

echo "Webcam size: ${WEBCAM_WIDTH}:${WEBCAM_HEIGHT}"
STACK_HORIZONTAL="[1:v:0]scale=${WEBCAM_WIDTH}:${WEBCAM_HEIGHT}[camera];\
[2:v:0]pad=iw+${WEBCAM_WIDTH}:ih[bg];[bg][camera]overlay=W-${WEBCAM_WIDTH}"
STACK_VERTICAL="[1:v:0]scale=${WEBCAM_WIDTH}:${WEBCAM_HEIGHT}[camera];\
[2:v:0]pad=iw:ih+${WEBCAM_HEIGHT}[bg];[bg][camera]overlay=0:H-${WEBCAM_HEIGHT}"


if [ "$STACK" == "HORIZONTAL" ]; then
  STACK_FILTER=$STACK_HORIZONTAL
  FINAL_WIDTH=$(echo "($CURRENT_WIDTH + $WEBCAM_WIDTH) * $OUTPUT_SCALE" | bc)
  FINAL_HEIGHT=$(echo "$CURRENT_HEIGHT * $OUTPUT_SCALE" | bc)  
elif [ "$STACK" == "VERTICAL" ]; then
  STACK_FILTER=$STACK_VERTICAL
  FINAL_WIDTH=$(echo "$CURRENT_WIDTH * $OUTPUT_SCALE" | bc)
  FINAL_HEIGHT=$(echo "($CURRENT_HEIGHT + $WEBCAM_HEIGHT) * $OUTPUT_SCALE" | bc)

else
  echo "STACK not recognized";
  exit 1
fi
FINAL_WIDTH=$(echo "$FINAL_WIDTH + ($FINAL_WIDTH % 2)" | bc)
FINAL_HEIGHT=$(echo "$FINAL_HEIGHT + ($FINAL_HEIGHT % 2)" | bc)
OUTPUT_RES="${FINAL_WIDTH%.*}:${FINAL_HEIGHT%.*}"

echo "Output res: $OUTPUT_RES, scale: $OUTPUT_SCALE"

FINAL_FILTER="${STACK_FILTER}[merged];[merged]scale=${OUTPUT_RES}"

avconv -y -f pulse -i default -itsoffset $VIDEO_DELAY \
-f video4linux2 -i $WEBCAM -itsoffset $VIDEO_DELAY -f x11grab -s $CURRENT_RESOLUTION -show_region 1 -i :0.0 \
-filter_complex "$FINAL_FILTER" \
-vcodec libx264 -preset ${X264_PRESET} -r 20 ${OUTPUT_VIDEO}
