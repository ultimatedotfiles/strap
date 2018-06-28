#!/usr/bin/env bats

load util

setup() {
  strap::lib::import fonts
}

@test "fonts: import" {
  strap::lib::import fonts
  [ "$?" -eq 0 ]
}

@test "fonts: black" {
  [ -n "$FONT_BLACK" ]
}

@test "fonts: maroon" {
  [ -n "$FONT_MAROON" ]
}

@test "fonts: green" {
  [ -n "$FONT_GREEN" ]
}

@test "fonts: olive" {
  [ -n "$FONT_OLIVE" ]
}

@test "fonts: navy" {
  [ -n "$FONT_NAVY" ]
}

@test "fonts: purple" {
  [ -n "$FONT_PURPLE" ]
}

@test "fonts: teal" {
  [ -n "$FONT_TEAL" ]
}

@test "fonts: silver" {
  [ -n "$FONT_SILVER" ]
}

@test "fonts: gray" {
  [ -n "$FONT_GRAY" ]
}

@test "fonts: red" {
  [ -n "$FONT_RED" ]
}

@test "fonts: lime" {
  [ -n "$FONT_LIME" ]
}

@test "fonts: yellow" {
  [ -n "$FONT_YELLOW" ]
}

@test "fonts: blue" {
  [ -n "$FONT_BLUE" ]
}

@test "fonts: fushia" {
  [ -n "$FONT_FUSHIA" ]
}

@test "fonts: aqua" {
  [ -n "$FONT_AQUA" ]
}

@test "fonts: white" {
  [ -n "$FONT_WHITE" ]
}

@test "fonts: dark blue" {
  [ -n "$FONT_DARK_BLUE" ]
}

@test "fonts: dodger blue 3" {
  [ -n "$FONT_DODGER_BLUE_3" ]
}

@test "fonts: blue violet" {
  [ -n "$FONT_BLUE_VIOLET" ]
}

@test "fonts: medium purple 4" {
  [ -n "$FONT_MEDIUM_PURPLE_4" ]
}

@test "fonts: slate blue 3" {
  [ -n "$FONT_SLATE_BLUE_3" ]
}

@test "fonts: cornflower blue" {
  [ -n "$FONT_CORNFLOWER_BLUE" ]
}

@test "fonts: skyblue 2" {
  [ -n "$FONT_SKYBLUE_2" ]
}

@test "fonts: light skyblue 1" {
  [ -n "$FONT_LIGHT_SKYBLUE_1" ]
}

@test "fonts: deep pink 3" {
  [ -n "$FONT_DEEP_PINK_3" ]
}

@test "fonts: gold 3" {
  [ -n "$FONT_GOLD_3" ]
}

@test "fonts: light steel blue 1" {
  [ -n "$FONT_LIGHT_STEEL_BLUE_1" ]
}

@test "fonts: dark sea green" {
  [ -n "$FONT_DARK_SEA_GREEN" ]
}

@test "fonts: red 1" {
  [ -n "$FONT_RED_1" ]
}

@test "fonts: orange red 1" {
  [ -n "$FONT_ORANGE_RED_1" ]
}

@test "fonts: orange 1" {
  [ -n "$FONT_ORANGE_1" ]
}

@test "fonts: gold 1" {
  [ -n "$FONT_GOLD_1" ]
}

@test "fonts: light goldenrod 2" {
  [ -n "$FONT_LIGHT_GOLDENROD_2" ]
}

@test "fonts: light goldenrod 1" {
  [ -n "$FONT_LIGHT_GOLDENROD_1" ]
}

@test "fonts: khaki 1" {
  [ -n "$FONT_KHAKI_1" ]
}

@test "fonts: wheat 1" {
  [ -n "$FONT_WHEAT_1" ]
}

@test "fonts: cornsilk 1" {
  [ -n "$FONT_CORNSILK_1" ]
}

@test "fonts: gray 93" {
  [ -n "$FONT_GRAY_93" ]
}

@test "fonts: bold" {
  [ -n "$FONT_BOLD" ]
}

@test "fonts: uline" {
  [ -n "$FONT_ULINE" ]
}

@test "fonts: unuline" {
  [ -n "$FONT_UNULINE" ]
}

@test "fonts: invert" {
  [ -n "$FONT_INVERT" ]
}

@test "fonts: clear" {
  [ -n "$FONT_CLEAR" ]
}

@test "fonts: checkmark" {
  [ -n "$FONT_CHECKMARK" ]
}

@test "fonts: errcross" {
  [ -n "$FONT_ERRCROSS" ]
}
