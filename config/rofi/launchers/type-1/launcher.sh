#!/usr/bin/env bash
## Author : Aditya Shakya (adi1090x)
## Github : @adi1090x
#
## Rofi   : Launcher (Modi Drun, Run, File Browser, Window)
#
## Available Styles
#
## style-1     style-2     style-3     style-4     style-5
## style-6     style-7     style-8     style-9     style-10
## style-11    style-12    style-13    style-14    style-15
dir="$HOME/.config/rofi/launchers/type-1"
theme='style-2'
## Vim motions on Alt, same as kitty.conf's alt+hjkl arrows (bare j/k
## would be eaten by the search box). None of these collide with
## rofi's default bindings.
##   Alt+j/k  row down/up    Alt+h/l  cursor left/right
##   Alt+d/u  page down/up
## Run
rofi \
    -show drun \
    -theme ${dir}/${theme}.rasi \
    -kb-row-down "Down,Control+n,Alt+j" \
    -kb-row-up "Up,Control+p,Alt+k" \
    -kb-move-char-back "Left,Control+b,Alt+h" \
    -kb-move-char-forward "Right,Control+f,Alt+l" \
    -kb-page-next "Page_Down,Alt+d" \
    -kb-page-prev "Page_Up,Alt+u"
