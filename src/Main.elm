module Main exposing (..)

import Browser
import Html exposing (..)
import Http
import Bytes.Decode as DecodeBytes


---- MODEL ----


type Role =
    Speaker |
    Participant

type Model =
    LoadingRole |
    RoleDone { role: Role } |
    RoleFailed


init : ( Model, Cmd Msg )
init =
    ( LoadingRole, requestRole )



---- UPDATE ----


type Msg
    = GotRole (Result Http.Error Int)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotRole (Ok role) -> (RoleDone { role = if role == 1 then Speaker else Participant }, Cmd.none)
        GotRole (Err _) -> (RoleFailed, Cmd.none)



---- VIEW ----


view : Model -> Html Msg
view model =
    case model of
        LoadingRole ->
            div [] [ text "Loading role..." ]
        RoleDone { role } ->
            div [] [ text ("Great! You're " ++ if role == Speaker then "participant" else "speaker") ]
        RoleFailed ->
            div [] [ text "Failed to load role :(" ]



---- PROGRAM ----


main : Program () Model Msg
main =
    Browser.element
        { view = view
        , init = \_ -> init
        , update = update
        , subscriptions = always Sub.none
        }


-- API --

apiHost: String
apiHost =
    "https://vord-elm.free.beeceptor.com"


requestRole: Cmd Msg
requestRole =
    Http.get {
    url = apiHost ++ "/current_role",
    expect = Http.expectBytes GotRole DecodeBytes.unsignedInt8
    }

