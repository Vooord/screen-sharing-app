module Participant exposing (..)

---- MODEL ----

import Api exposing (onScreensReceived)
import Html exposing (..)
import Stuff.Transmission exposing (Screen)


type Model
    = WaitingForTransmission
    | Transmission (List Screen)


init : ( Model, Cmd Msg )
init =
    ( WaitingForTransmission, Cmd.none )



---- UPDATE ----


type Msg
    = StorageChange (List Screen)


update : Msg -> Model -> ( Model, Cmd Msg )
update (StorageChange s) _ =
    ( Transmission s, Cmd.none )



---- SUBSCRIPTIONS ----


subscriptions : Model -> Sub Msg
subscriptions _ =
    onScreensReceived StorageChange



---- VIEW ----


view : Model -> Html Msg
view model =
    case model of
        WaitingForTransmission ->
            div [] [ text "Waiting for transmission..." ]

        Transmission screens ->
            div [] (List.map (\s -> div [] [ text s.title, canvas [] [ text "Here should be screen sharing..." ] ]) screens)
