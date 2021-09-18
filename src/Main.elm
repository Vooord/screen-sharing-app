module Main exposing (..)

import Browser
import Html exposing (..)
import Http
import Json.Decode as DecodeJson exposing (Decoder)



---- MODEL ----


type SpeakerRole
    = Speaker


type ParticipantRole
    = Participant


type Role
    = SpeakerRole
    | ParticipantRole


type alias ParticipantRoleData =
    { role : ParticipantRole }


type alias SpeakerRoleData =
    { role : SpeakerRole }


type Model
    = LoadingRole
    | RoleFailed
    | LoadingSharingConfig SpeakerRoleData
    | WaitingForTranslation ParticipantRoleData
    | WaitingForStartSharing SpeakerRoleData (List String)


init : ( Model, Cmd Msg )
init =
    ( LoadingRole, requestRole )



---- UPDATE ----


type Msg
    = GotRole (Result Http.Error Int)
    | GotSharingConfig (Result Http.Error (List String))


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotRole (Ok roleBit) ->
            handleGotRole roleBit

        GotRole (Err _) ->
            ( RoleFailed, Cmd.none )

        GotSharingConfig (Ok sharingConfig) ->
            case model of
                LoadingSharingConfig roleData ->
                    ( WaitingForStartSharing roleData sharingConfig, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        GotSharingConfig (Err _) ->
            ( model, Cmd.none )


handleGotRole : Int -> ( Model, Cmd Msg )
handleGotRole roleBit =
    let
        isSpeaker =
            determineRole roleBit == SpeakerRole
    in
    ( if isSpeaker then
        LoadingSharingConfig { role = Speaker }

      else
        WaitingForTranslation { role = Participant }
    , if isSpeaker then
        requestSharingConfig

      else
        Cmd.none
    )



---- VIEW ----


view : Model -> Html Msg
view model =
    case model of
        LoadingRole ->
            div [] [ text "Loading role..." ]

        RoleFailed ->
            div [] [ text "Failed to load role :(" ]

        LoadingSharingConfig _ ->
            div [] [ text "Loading sharing config..." ]

        WaitingForTranslation _ ->
            -- TODO: make canvas
            div [] [ text "Waiting for translation..." ]

        WaitingForStartSharing _ _ ->
            div [] [ button [] [ text "Start" ] ]



-- API --


apiHost : String
apiHost =
    "https://vord1-elm.free.beeceptor.com"


buildApiPath : String -> String
buildApiPath path =
    apiHost ++ "/" ++ path


requestRole : Cmd Msg
requestRole =
    Http.get
        { url = buildApiPath "current_role"

        --    it's might be better to use
        --    expect = Http.expectBytes GotRole DecodeBytes.unsignedInt8
        , expect = Http.expectJson GotRole DecodeJson.int
        }


requestSharingConfig : Cmd Msg
requestSharingConfig =
    Http.get
        { url = buildApiPath "sharing_config"
        , expect = Http.expectJson GotSharingConfig (DecodeJson.list DecodeJson.string)
        }



-- utils --


determineRole : Int -> Role
determineRole roleBit =
    if roleBit == 1 then
        SpeakerRole

    else
        ParticipantRole



---- PROGRAM ----


main : Program () Model Msg
main =
    Browser.element
        { view = view
        , init = \_ -> init
        , update = update
        , subscriptions = always Sub.none
        }
