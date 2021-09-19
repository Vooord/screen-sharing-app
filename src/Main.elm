module Main exposing (..)

import Browser
import Html exposing (..)
import Html.Attributes exposing (disabled)
import Html.Events exposing (onClick)
import Http
import Json.Decode as DecodeJson exposing (Decoder)
import Json.Encode as EncodeJson



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


type SharingConfigType
    = WebRTCVariant WebRTCType
    | VNCVariant VNCType


type alias WebRTCPriorityData =
    { p1 : WebRTCType
    , p2 : VNCType
    }


type alias VNCPriorityData =
    { p1 : VNCType
    , p2 : WebRTCType
    }


type Priority
    = WebRTCPriorityVariant WebRTCPriorityData
    | VNCPriorityVariant VNCPriorityData


determinePriority : List String -> Maybe Priority
determinePriority config =
    case config of
        [ "WebRTC", "VNC" ] ->
            Just <| WebRTCPriorityVariant <| WebRTCPriorityData WebRTC VNC

        [ "VNC", "WebRTC" ] ->
            Just <| VNCPriorityVariant <| VNCPriorityData VNC WebRTC

        _ ->
            Nothing


handleGotSharingConfig : ( List String, Model ) -> ( Model, Cmd Msg )
handleGotSharingConfig ( config, model ) =
    case model of
        LoadingSharingConfig roleData ->
            case determinePriority config of
                Just priority ->
                    ( WaitingForStart <| WaitingForStartData roleData priority False, Cmd.none )

                Nothing ->
                    ( SharingConfigFailed, Cmd.none )

        _ ->
            ( InvalidSharingConfig, Cmd.none )


configToString : SharingConfigType -> String
configToString ct =
    case ct of
        WebRTCVariant _ ->
            "WebRTC"

        VNCVariant _ ->
            "VNC"


getConfig : ( Priority, Bool ) -> SharingConfigType
getConfig ( p, fallback ) =
    case p of
        WebRTCPriorityVariant { p1, p2 } ->
            if fallback then
                VNCVariant p2

            else
                WebRTCVariant p1

        VNCPriorityVariant { p1, p2 } ->
            if fallback then
                WebRTCVariant p2

            else
                VNCVariant p1



---- MODEL ----


type alias WaitingForStartData =
    { role : SpeakerType, priority : Priority, error : Bool }


type alias LoadingStartData =
    { role : SpeakerType, priority : Priority, fallback : Bool }


type alias StartSharingDoneData =
    { role : SpeakerType, priority : Priority, platform : String }


type Model
    = LoadingRole
    | RoleFailed
    | InvalidRole
    | LoadingSharingConfig SpeakerType
    | SharingConfigFailed
    | InvalidSharingConfig
    | WaitingForTranslation ParticipantType
    | WaitingForStart WaitingForStartData
    | LoadingStart LoadingStartData
    | StartSharingDone StartSharingDoneData


init : ( Model, Cmd Msg )
init =
    ( LoadingRole, requestRole )



---- UPDATE ----


type Msg
    = GotRole (Result Http.Error Int)
    | GotSharingConfig (Result Http.Error (List String))
    | StartSharing SpeakerType Priority
    | StartConfirmed (Result Http.Error String)


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

        StartSharing s p ->
            let
                fallback =
                    False
            in
            ( LoadingStart <| LoadingStartData s p fallback, startSharing ( p, fallback ) )

        StartConfirmed (Ok mobileFlag) ->
            case model of
                LoadingStart { role, priority } ->
                    ( StartSharingDone <| StartSharingDoneData role priority mobileFlag, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        StartConfirmed (Err _) ->
            case model of
                LoadingStart { role, priority, fallback } ->
                    if fallback then
                        ( WaitingForStart <| WaitingForStartData role priority True, Cmd.none )

                    else
                        ( LoadingStart <| LoadingStartData role priority True, startSharing ( priority, True ) )

                _ ->
                    ( model, Cmd.none )



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

        WaitingForStart { role, priority, error } ->
            div []
                [ button [ onClick <| StartSharing role priority ] [ text "Start" ]
                , if error then
                    div [] [ text "Failed to confirm sharing start. Please, try again." ]

                  else
                    div [] []
                ]

        LoadingStart _ ->
            div []
                [ button [ disabled True ] [ text "Start" ]
                , div [] [ text "Requesting confirmation from server..." ]
                ]

        StartSharingDone _ ->
            div [] [ text "Start Sharing Done!" ]



-- API --


apiHost : String
apiHost =
    "https://vord-elm1.free.beeceptor.com"


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


startSharing : ( Priority, Bool ) -> Cmd Msg
startSharing ( priority, fallback ) =
    case priority of
        WebRTCPriorityVariant p ->
            Http.post
                { url = buildApiPath "start_sharing"
                , body =
                    Http.jsonBody <|
                        EncodeJson.string <|
                            configToString <|
                                getConfig ( WebRTCPriorityVariant p, fallback )
                , expect = Http.expectJson StartConfirmed DecodeJson.string
                }

        VNCPriorityVariant p ->
            Http.post
                { url = buildApiPath "start_sharing"
                , body =
                    Http.jsonBody <|
                        EncodeJson.string <|
                            configToString <|
                                getConfig ( VNCPriorityVariant p, fallback )
                , expect = Http.expectJson StartConfirmed DecodeJson.string
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
