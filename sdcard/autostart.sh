#!/bin/bash

v4l2-ctl --set-fmt-video=width=640,height=480,pixelformat=UYVY
export DISPLAY=:0.0
xrandr --output DP-1 --mode 800x600
xset s off -dpms

echo setting up ethernet gadget...
modprobe g_ether
ifup usb0
