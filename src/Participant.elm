module Participant exposing (..)

---- MODEL ----

import Html exposing (..)


type Model
    = WaitingForTranslation


init : ( Model, Cmd Msg )
init =
    ( WaitingForTranslation, Cmd.none )



---- UPDATE ----


type alias Msg =
    {}



---- VIEW ----


view : Model -> Html Msg
view model =
    case model of
        WaitingForTranslation ->
            -- TODO: make canvas
            div [] [ text "Waiting for translation..." ]
