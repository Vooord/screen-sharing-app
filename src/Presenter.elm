module Presenter exposing (..)

import Api exposing (buildApiPath, routes)
import Html exposing (..)
import Html.Attributes exposing (disabled)
import Html.Events exposing (onClick)
import Http
import Json.Decode as DecodeJson exposing (Decoder)
import Json.Encode as EncodeJson
import Stuff.Priority exposing (Priority(..), PriorityAlias, determinePriority, priorityToString)



---- MODEL ----


type Model
    = LoadingConfig
    | LoadingConfigFailed
    | InvalidConfig
    | WaitingForStart WaitingForStartData
    | LoadingStart LoadingStartData
    | LoadingScreens (PriorityAlias {})
    | MobileSharing MobileSharingData
    | WaitingForScreenSelect


init : ( Model, Cmd Msg )
init =
    ( LoadingConfig, requestSharingConfig )



---- UPDATE ----


type Msg
    = GotSharingConfig (Result Http.Error (List String))
    | StartSharing
    | WebRTCConfirmed (Result Http.Error ())
    | VNCConfirmed (Result Http.Error Int)
    | GotScreens (Result Http.Error ScreensAndWindows)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case ( msg, model ) of
        ( GotSharingConfig (Ok sharingConfig), LoadingConfig ) ->
            handleGotSharingConfig sharingConfig

        ( GotSharingConfig (Err _), LoadingConfig ) ->
            ( LoadingConfigFailed, Cmd.none )

        ( StartSharing, WaitingForStart { priority } ) ->
            ( LoadingStart { priority = priority }, startSharing priority )

        ( WebRTCConfirmed (Ok _), LoadingStart { priority } ) ->
            -- TODO
            ( WaitingForScreenSelect, Cmd.none )

        ( VNCConfirmed (Ok mobileFlag), LoadingStart { priority } ) ->
            case mobileFlag of
                -- TODO
                0 ->
                    ( LoadingScreens { priority = priority }, Cmd.none )

                -- TODO
                1 ->
                    ( MobileSharing <| { priority = priority, platform = Mobile, current = { title = "Mobile display", id = "0" }, paused = False }, Cmd.none )

                _ ->
                    ( WaitingForStart <| { priority = priority, error = Just "Can't determine the platform." }, Cmd.none )

        ( WebRTCConfirmed (Err _), LoadingStart { priority } ) ->
            handleStartError priority

        ( VNCConfirmed (Err _), LoadingStart { priority } ) ->
            handleStartError priority

        ( GotScreens (Ok screens), LoadingScreens _ ) ->
            -- TODO
            ( WaitingForScreenSelect, Cmd.none )

        ( GotScreens (Err _), LoadingScreens { priority } ) ->
            ( WaitingForStart <| { priority = priority, error = Just "Failed to get screens and windows." }, Cmd.none )

        ( _, _ ) ->
            ( model, Cmd.none )



---- VIEW ----


view : Model -> Html Msg
view model =
    case model of
        LoadingConfig ->
            div [] [ text "Loading sharing config..." ]

        LoadingConfigFailed ->
            div [] [ text "Failed to load screen sharing config :(" ]

        InvalidConfig ->
            div [] [ text "Can't determine the screen sharing config received from server :(" ]

        WaitingForStart { priority, error } ->
            div []
                [ button [ onClick <| StartSharing ] [ text "Start" ]
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



-- Get Sharing Config --


requestSharingConfig : Cmd Msg
requestSharingConfig =
    Http.get
        { url = buildApiPath routes.sharingCondig
        , expect = Http.expectJson GotSharingConfig (DecodeJson.list DecodeJson.string)
        }


handleGotSharingConfig : List String -> ( Model, Cmd Msg )
handleGotSharingConfig rawConfig =
    case determinePriority rawConfig of
        Just p ->
            ( WaitingForStart <| { priority = p, error = Nothing }, Cmd.none )

        Nothing ->
            ( InvalidConfig, Cmd.none )



-- Start Sharing --


type alias WaitingForStartData =
    PriorityAlias { error : Maybe String }


type alias LoadingStartData =
    PriorityAlias {}


type MobileType
    = Mobile


type DesktopType
    = Desktop


type Platform
    = MobileVariant MobileType
    | DesktopVariant DesktopType


startSharing : Priority -> Cmd Msg
startSharing priority =
    Http.post
        { url = buildApiPath routes.sharingStart
        , body = Http.jsonBody <| EncodeJson.string <| priorityToString priority
        , expect = getStartSharingExpect priority
        }


getStartSharingExpect : Priority -> Http.Expect Msg
getStartSharingExpect p =
    let
        webRtcExpect =
            Http.expectWhatever WebRTCConfirmed

        vncExpect =
            Http.expectJson VNCConfirmed DecodeJson.int
    in
    case p of
        WebRTC ->
            webRtcExpect

        WebRTC_VNC _ ->
            webRtcExpect

        VNC ->
            vncExpect

        VNC_WebRTC _ ->
            vncExpect


handleStartError : Priority -> ( Model, Cmd Msg )
handleStartError priority =
    case priority of
        WebRTC_VNC False ->
            ( LoadingStart { priority = WebRTC_VNC True }, startSharing <| WebRTC_VNC True )

        VNC_WebRTC False ->
            ( LoadingStart { priority = VNC_WebRTC True }, startSharing <| VNC_WebRTC True )

        _ ->
            ( WaitingForStart { priority = priority, error = Just "Failed to confirm sharing start." }, Cmd.none )



-- Waiting for Sharing --


type alias Screen =
    { title : String, id : String }


type alias MobileSharingData =
    PriorityAlias { platform : MobileType, current : Screen, paused : Bool }


type alias ScreensAndWindows =
    { screens : List Screen, windows : List Screen }



-- API --


requestScreens : Cmd Msg
requestScreens =
    -- here should be userId param
    Http.get
        { url = buildApiPath routes.getScreens
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
