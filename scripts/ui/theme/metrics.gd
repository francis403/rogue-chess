class_name Metrics
extends RefCounted
## The spacing scale (base unit 4) and the few layout sizes screens share.
## Use these instead of literal pixel values.

const XS := 4
const S := 8
const M := 12
const L := 16
const XL := 24
const XXL := 32
const XXXL := 48

## Height of the base canvas; taller windows (16:10) get the extra as margin (Ui.centre_tall).
const BASE_HEIGHT := 720
## Outer margins of a full screen (canvas is 1280x720 and grows with aspect "expand").
const SCREEN_X := 48
const SCREEN_Y := 32
## Fixed side columns of the match and roster screens.
const SIDE_COLUMN := 272
const BUTTON_HEIGHT := 40
const BUTTON_HEIGHT_LARGE := 48

## Screen transition slide distance (its duration is "screen_transition" in config/ux.json).
const TRANSITION_SLIDE := 14.0

## Settings panel: one of its two columns, the choice buttons (speed, window),
## slider rows and the key buttons of the Controls list.
const SETTINGS_COLUMN := 460
const SPEED_BUTTON := 84
const SETTINGS_LABEL := 80
const SETTINGS_SLIDER := 240
const SETTINGS_KEY := 96

## Menu content sizes: reward cards (1.3x the hand card), set tiles, artifact tiles
## and their emblems, the run-end piece row.
const REWARD_CARD := Vector2(195, 273)
const SET_TILE_WIDTH := 440
const SET_TOKEN := 58
## Artifact tiles are one wide row each (a list of up to ARTIFACT_LIST_MAX).
const ARTIFACT_TILE := Vector2(760, 96)
const ARTIFACT_LIST_MAX := 4
## The right-hand column of an artifact tile, kept free for its CHOSEN chip and key cap.
const CHIP_COLUMN := 128
const EMBLEM := 64
const KEY_CAP := 22
## Narrowest the deck / collection overlay gets (it hugs its content beyond that).
const OVERLAY_MIN_WIDTH := 560
## The piece token on a coaching offer (cards show at CardView.SIZE).
const COACH_TOKEN := 80
