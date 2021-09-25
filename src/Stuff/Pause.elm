module Stuff.Pause exposing (..)


type PauseToggle
    = SwitchOn
    | SwitchOff


type Pause
    = PauseOff
    | RequestingPause PauseToggle
    | PauseOn


isOn : Pause -> Bool
isOn p =
    case p of
        PauseOff ->
            False

        RequestingPause _ ->
            False

        PauseOn ->
            True


isRequesting : Pause -> Bool
isRequesting p =
    case p of
        PauseOff ->
            False

        RequestingPause _ ->
            True

        PauseOn ->
            False


getToggle : Bool -> PauseToggle
getToggle isPaused =
    if isPaused then
        SwitchOff

    else
        SwitchOn


getText : Bool -> String
getText isPaused =
    if isPaused then
        "Resume"

    else
        "Pause"


toggleToString : PauseToggle -> String
toggleToString t =
    case t of
        SwitchOn ->
            "switch_on"

        SwitchOff ->
            "switch_off"
