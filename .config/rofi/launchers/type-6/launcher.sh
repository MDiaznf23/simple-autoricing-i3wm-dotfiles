#!/usr/bin/env bash

## Author : Aditya Shakya (adi1090x)
## Github : @adi1090x
#

dir="$HOME/.config/rofi/launchers/type-6"
theme='style-6'

## Run
rofi \
    -show drun \
    -theme ${dir}/${theme}.rasi
