module Main exposing (..)

import Browser
import Html exposing (..)
import Http
import Json.Decode as DecodeJson exposing (Decoder)



-- Role --


type SpeakerType
    = Speaker


type ParticipantType
    = Participant


type Role
    = SpeakerVariant SpeakerType
    | ParticipantVariant ParticipantType


determineRole : Int -> Maybe Role
determineRole roleBit =
    if roleBit == 1 then
        Just (SpeakerVariant Speaker)

    else if roleBit == 0 then
        Just (ParticipantVariant Participant)

    else
        Nothing


handleGotRole : ( Int, Model ) -> ( Model, Cmd Msg )
handleGotRole ( roleBit, _ ) =
    case determineRole roleBit of
        Just (SpeakerVariant s) ->
            ( LoadingSharingConfig s, requestSharingConfig )

        Just (ParticipantVariant p) ->
            ( WaitingForTranslation p, Cmd.none )

        Nothing ->
            ( InvalidRole, Cmd.none )



-- Sharing Config --


type WebRTCType
    = WebRTC


type VNCType
    = VNC


type alias WebRTCPriorData =
    { p1 : WebRTCType
    , p2 : VNCType
    }


type alias VNCPriorData =
    { p1 : VNCType
    , p2 : WebRTCType
    }


type Prior
    = WebRTCPrior WebRTCPriorData
    | VNCPrior VNCPriorData


determinePrior : List String -> Maybe Prior
determinePrior config =
    case config of
        [ "WebRTC", "VNC" ] ->
            Just <| WebRTCPrior <| WebRTCPriorData WebRTC VNC

        [ "VNC", "WebRTC" ] ->
            Just <| VNCPrior <| VNCPriorData VNC WebRTC

        _ ->
            Nothing


handleGotSharingConfig : ( List String, Model ) -> ( Model, Cmd Msg )
handleGotSharingConfig ( config, model ) =
    case model of
        LoadingSharingConfig roleData ->
            case determinePrior config of
                Just prior ->
                    ( WaitingForStartSharing roleData prior, Cmd.none )

                Nothing ->
                    ( SharingConfigFailed, Cmd.none )

        _ ->
            ( InvalidSharingConfig, Cmd.none )



---- MODEL ----


type Model
    = LoadingRole
    | RoleFailed
    | InvalidRole
    | LoadingSharingConfig SpeakerType
    | SharingConfigFailed
    | InvalidSharingConfig
    | WaitingForTranslation ParticipantType
    | WaitingForStartSharing SpeakerType Prior


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
            handleGotRole ( roleBit, model )

        GotRole (Err _) ->
            ( RoleFailed, Cmd.none )

        GotSharingConfig (Ok sharingConfig) ->
            handleGotSharingConfig ( sharingConfig, model )

        GotSharingConfig (Err _) ->
            ( SharingConfigFailed, Cmd.none )



---- VIEW ----


view : Model -> Html Msg
view model =
    case model of
        LoadingRole ->
            div [] [ text "Loading role..." ]

        RoleFailed ->
            div [] [ text "Failed to load role :(" ]

        InvalidRole ->
            div [] [ text "Can't determine the role received from server :(" ]

        LoadingSharingConfig _ ->
            div [] [ text "Loading sharing config..." ]

        SharingConfigFailed ->
            div [] [ text "Failed to load screen sharing config :(" ]

        InvalidSharingConfig ->
            div [] [ text "Can't determine the screen sharing config received from server :(" ]

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

        --    it might be better to use
        --    expect = Http.expectBytes GotRole DecodeBytes.unsignedInt8
        , expect = Http.expectJson GotRole DecodeJson.int
        }


requestSharingConfig : Cmd Msg
requestSharingConfig =
    Http.get
        { url = buildApiPath "sharing_config"
        , expect = Http.expectJson GotSharingConfig (DecodeJson.list DecodeJson.string)
        }



---- PROGRAM ----


main : Program () Model Msg
main =
    Browser.element
        { view = view
        , init = \_ -> init
        , update = update
        , subscriptions = always Sub.none
        }
