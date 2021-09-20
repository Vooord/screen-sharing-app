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
                Just p ->
                    ( WaitingForStart <| { role = roleData, priority = p, error = Nothing }, Cmd.none )

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



-- StartSharing --


type alias SpeakerWithPriority extends =
    { extends | role : SpeakerType, priority : Priority }


type alias WaitingForStartData =
    SpeakerWithPriority { error : Maybe String }


type alias LoadingStartData =
    SpeakerWithPriority { fallback : Bool }


type MobileType
    = Mobile


type DesktopType
    = Desktop


type Platform
    = MobileVariant MobileType
    | DesktopVariant DesktopType


handleStartError : Model -> ( Model, Cmd Msg )
handleStartError model =
    case model of
        LoadingStart { role, priority, fallback } ->
            if fallback then
                ( WaitingForStart <| { role = role, priority = priority, error = Just "Failed to confirm sharing start." }, Cmd.none )

            else
                ( LoadingStart <| { role = role, priority = priority, fallback = True }, startSharing ( priority, True ) )

        _ ->
            ( model, Cmd.none )



-- Waiting for Sharing --


type alias Screen =
    { title : String, id : String }


type alias MobileSharingData =
    SpeakerWithPriority { platform : MobileType, current : Screen, paused : Bool }


type alias ScreensAndWindows =
    { screens : List Screen, windows : List Screen }



---- MODEL ----


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
    | LoadingScreens (SpeakerWithPriority {})
    | MobileSharing MobileSharingData
    | WaitingForScreenSelect


init : ( Model, Cmd Msg )
init =
    ( LoadingRole, requestRole )



---- UPDATE ----


type Msg
    = GotRole (Result Http.Error Int)
    | GotSharingConfig (Result Http.Error (List String))
    | StartSharing SpeakerType Priority
    | WebRTCConfirmed (Result Http.Error ())
    | VNCConfirmed (Result Http.Error Int)
    | GotScreens (Result Http.Error ScreensAndWindows)


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
            ( LoadingStart <| { role = s, priority = p, fallback = fallback }, startSharing ( p, fallback ) )

        WebRTCConfirmed (Ok _) ->
            case model of
                LoadingStart { role, priority } ->
                    -- TODO
                    ( WaitingForScreenSelect, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        VNCConfirmed (Ok mobileFlag) ->
            case model of
                LoadingStart { role, priority } ->
                    case mobileFlag of
                        -- TODO
                        0 ->
                            ( LoadingScreens { role = role, priority = priority }, Cmd.none )

                        -- TODO
                        1 ->
                            ( MobileSharing <| { role = role, priority = priority, platform = Mobile, current = { title = "Mobile display", id = "0" }, paused = False }, Cmd.none )

                        _ ->
                            ( WaitingForStart <| { role = role, priority = priority, error = Just "Can't determine the platform." }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        WebRTCConfirmed (Err _) ->
            handleStartError model

        VNCConfirmed (Err _) ->
            handleStartError model

        GotScreens (Ok screens) ->
            case model of
                -- TODO
                LoadingScreens _ ->
                    ( WaitingForScreenSelect, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        GotScreens (Err _) ->
            case model of
                LoadingScreens { role, priority } ->
                    ( WaitingForStart <| { role = role, priority = priority, error = Just "Failed to get screens and windows." }, Cmd.none )

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
                , case error of
                    Just e ->
                        div [] [ text <| e ++ " Please, try again." ]

                    Nothing ->
                        div [] []
                ]

        LoadingStart _ ->
            div []
                [ button [ disabled True ] [ text "Start" ]
                , div [] [ text "Requesting confirmation from server..." ]
                ]

        LoadingScreens _ ->
            div []
                [ button [ disabled True ] [ text "Start" ]
                , div [] [ text "Loading screens and windows..." ]
                ]

        -- TODO
        MobileSharing data ->
            div [] [ text "Mobile screen sharing:" ]

        -- TODO
        WaitingForScreenSelect ->
            div []
                [ button [] [ text "Stop" ]
                , text "Select screen / Select window"
                ]



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
    let
        url =
            buildApiPath "start_sharing"
    in
    case priority of
        WebRTCPriorityVariant p ->
            Http.post
                { url = url
                , body = getStartSharingBody ( WebRTCPriorityVariant p, fallback )
                , expect = Http.expectWhatever WebRTCConfirmed
                }

        VNCPriorityVariant p ->
            Http.post
                { url = url
                , body = getStartSharingBody ( VNCPriorityVariant p, fallback )
                , expect = Http.expectJson VNCConfirmed DecodeJson.int
                }


getStartSharingBody : ( Priority, Bool ) -> Http.Body
getStartSharingBody ( p, f ) =
    Http.jsonBody <|
        EncodeJson.string <|
            configToString <|
                getConfig ( p, f )


requestScreens : Cmd Msg
requestScreens =
    -- here should be userId param
    Http.get
        { url = buildApiPath "screens"
        , expect = Http.expectJson GotScreens decodeScreens
        }


decodeScreens : Decoder ScreensAndWindows
decodeScreens =
    DecodeJson.map2 ScreensAndWindows
        (DecodeJson.field "screens" <| DecodeJson.list decodeScreen)
        (DecodeJson.field "windows" <| DecodeJson.list decodeScreen)


decodeScreen : Decoder Screen
decodeScreen =
    DecodeJson.map2 Screen (DecodeJson.field "title" DecodeJson.string) (DecodeJson.field "id" DecodeJson.string)



---- PROGRAM ----


main : Program () Model Msg
main =
    Browser.element
        { view = view
        , init = \_ -> init
        , update = update
        , subscriptions = always Sub.none
        }
