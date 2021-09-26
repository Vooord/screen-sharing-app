module Presenter exposing (..)

import Api exposing (buildApiPath, routes)
import Html exposing (..)
import Html.Attributes exposing (disabled)
import Html.Events exposing (onClick)
import Http
import Json.Decode as DecodeJson exposing (Decoder)
import Json.Encode as EncodeJson
import Stuff.Mocks exposing (mobileScreens, webRTCScreens)
import Stuff.Modal as M exposing (Modal, ModalTab(..))
import Stuff.Pause as Pause exposing (PauseToggle)
import Stuff.Priority as P exposing (Priority(..), PriorityMap, WithPriority)
import Stuff.Transmission as T exposing (Screen, Transmission)
import Stuff.Utils exposing (viewIf, viewIfElse, viewJust, viewListJust)



---- MODEL ----


type alias DesktopSharingData =
    { t : Transmission, m : Modal, p : PriorityMap }


type Model
    = LoadingConfig
    | ConfigFailed String
    | WaitingForStart (WithPriority { error : Maybe String })
    | LoadingStart PriorityMap
    | LoadingStop PriorityMap
    | LoadingScreens PriorityMap
    | MobileSharing { t : Transmission, p : PriorityMap }
    | DesktopSharing DesktopSharingData


init : ( Model, Cmd Msg )
init =
    ( LoadingConfig, requestSharingConfig )



---- UPDATE ----


type alias ScreenSelectedData =
    { screen : Screen, isWindow : Bool }


type Msg
    = GotSharingConfig (Result Http.Error (List String))
    | StartSharing
    | StopSharing
    | StopConfirmed (Result Http.Error ())
    | WebRTCConfirmed (Result Http.Error ())
    | VNCConfirmed (Result Http.Error Int)
    | GotScreens (Result Http.Error ScreensAndWindows)
    | ToggleModal (Maybe ModalTab)
    | ChangeModalTab ModalTab
    | ScreenSelected ScreenSelectedData
    | ScreenConfirmed (Result Http.Error ())
    | PauseToggle PauseToggle
    | PauseConfirmed PauseToggle


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case ( msg, model ) of
        ( GotSharingConfig (Ok sharingConfig), LoadingConfig ) ->
            handleGotSharingConfig sharingConfig

        ( GotSharingConfig (Err _), LoadingConfig ) ->
            ( ConfigFailed "Failed to load screen sharing config :(", Cmd.none )

        ( StartSharing, WaitingForStart { priority } ) ->
            ( LoadingStart { priority = priority }, startSharing priority )

        ( StopSharing, DesktopSharing { p } ) ->
            ( LoadingStop p, stopSharing )

        ( StopSharing, MobileSharing { p } ) ->
            ( LoadingStop p, stopSharing )

        ( StopConfirmed _, LoadingStop { priority } ) ->
            ( WaitingForStart { priority = priority, error = Nothing }, Cmd.none )

        ( WebRTCConfirmed (Ok _), LoadingStart p ) ->
            handleTransmissionInit ( T.init { mobile = False, screens = webRTCScreens, windows = Nothing }, p )

        ( WebRTCConfirmed (Err _), LoadingStart { priority } ) ->
            handleStartError priority

        ( VNCConfirmed (Ok mobileFlag), LoadingStart p ) ->
            handleVNCConfirmed ( mobileFlag, p )

        ( VNCConfirmed (Err _), LoadingStart { priority } ) ->
            handleStartError priority

        ( GotScreens (Ok { screens, windows }), LoadingScreens p ) ->
            handleTransmissionInit ( T.init { mobile = False, screens = screens, windows = Just windows }, p )

        ( GotScreens (Err _), LoadingScreens { priority } ) ->
            ( WaitingForStart { priority = priority, error = Just "Failed to get screens and windows." }, Cmd.none )

        ( ToggleModal tab, DesktopSharing sharing ) ->
            ( DesktopSharing { sharing | m = M.init tab }, Cmd.none )

        ( ChangeModalTab tab, DesktopSharing sharing ) ->
            ( DesktopSharing { sharing | m = M.changeTab sharing.m tab }, Cmd.none )

        ( ScreenSelected ssData, DesktopSharing dsData ) ->
            handleScreenSelected ssData dsData

        ( ScreenConfirmed _, DesktopSharing sharing ) ->
            ( DesktopSharing { sharing | t = T.confirmSharing sharing.t }, Cmd.none )

        ( PauseToggle toggle, DesktopSharing sharing ) ->
            ( DesktopSharing { sharing | t = T.waitForPause sharing.t toggle }, requestPause toggle )

        ( PauseConfirmed toggle, DesktopSharing sharing ) ->
            ( DesktopSharing { sharing | t = T.pauseSwitch sharing.t toggle }, Cmd.none )

        ( _, _ ) ->
            ( model, Cmd.none )



---- VIEW ----


view : Model -> Html Msg
view model =
    case model of
        LoadingConfig ->
            div [] [ text "Loading sharing config..." ]

        ConfigFailed e ->
            div [] [ text e ]

        WaitingForStart { priority, error } ->
            div []
                [ button [ onClick StartSharing ] [ text "Start" ]
                , viewJust error (\e -> div [] [ text <| e ++ " Please, try again." ])
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

        LoadingStop _ ->
            div []
                [ button [ disabled True ] [ text "Stop" ]
                , div [] [ text "Requesting stop sharing confirmation..." ]
                ]

        DesktopSharing { t, m, p } ->
            let
                waitingForConfirmation =
                    T.isScreenRequesting t

                hasScreens =
                    T.hasScreens t

                hasWindows =
                    T.hasWindows t

                selectScreenDisabled =
                    not hasScreens || waitingForConfirmation

                selectWindowDisabled =
                    not hasWindows || waitingForConfirmation
            in
            div []
                [ button [ onClick StopSharing ] [ text "Stop" ]
                , button [ disabled selectScreenDisabled, onClick <| ToggleModal (Just ScreensTab) ] [ text "Select Screen" ]
                , viewIf (T.isVNC t) <| button [ disabled selectWindowDisabled, onClick <| ToggleModal (Just WindowsTab) ] [ text "Select Window" ]

                -- Modal
                , viewIf (M.isOpen m) <|
                    div []
                        [ viewIf hasScreens (div [ onClick (ChangeModalTab ScreensTab) ] [ text "Screens" ])
                        , viewIf hasWindows (div [ onClick (ChangeModalTab WindowsTab) ] [ text "Windows" ])
                        , viewJust (M.getTab m) (\activeTab -> div [] (renderScreens t activeTab))
                        ]

                -- Sharing
                , viewIf (T.hasActiveScreen t) <|
                    viewIfElse waitingForConfirmation (div [] [ text "Waiting for sharing confirmation..." ]) (renderSharing t)
                ]

        MobileSharing { t } ->
            renderSharing t


renderSharing : Transmission -> Html Msg
renderSharing t =
    let
        isPaused =
            T.isPaused t
    in
    viewJust
        (T.getCurrentScreen t)
        (\c ->
            div []
                [ button
                    [ disabled (T.isPauseWaiting t), onClick <| PauseToggle (Pause.getToggle isPaused) ]
                    [ text <| Pause.getText isPaused ]
                , div [] [ text c.title, canvas [] [ text "Here should be screen sharing..." ] ]
                ]
        )


renderScreen : ScreenSelectedData -> Html Msg
renderScreen s =
    div [ onClick <| ScreenSelected s ] [ text <| s.screen.title ++ " #" ++ s.screen.id ]


renderScreens : Transmission -> ModalTab -> List (Html Msg)
renderScreens t activeTab =
    case activeTab of
        ScreensTab ->
            List.map (\screen -> renderScreen { screen = screen, isWindow = False }) (T.getScreens t)

        WindowsTab ->
            viewListJust
                (T.getWindows t)
                (\windows -> List.map (\window -> renderScreen { screen = window, isWindow = True }) windows)



-- Get Sharing Config --


requestSharingConfig : Cmd Msg
requestSharingConfig =
    Http.get
        { url = buildApiPath routes.sharingCondig
        , expect = Http.expectJson GotSharingConfig (DecodeJson.list DecodeJson.string)
        }


handleGotSharingConfig : List String -> ( Model, Cmd Msg )
handleGotSharingConfig rawConfig =
    case P.determine rawConfig of
        Just p ->
            ( WaitingForStart { priority = p, error = Nothing }, Cmd.none )

        Nothing ->
            ( ConfigFailed "Can't determine the screen sharing config received from server :(", Cmd.none )



-- Start Sharing --


startSharing : Priority -> Cmd Msg
startSharing priority =
    Http.post
        { url = buildApiPath routes.sharingStart
        , body = Http.jsonBody <| EncodeJson.string <| P.toString priority
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



-- Sharing --


type alias ScreensAndWindows =
    { screens : List Screen, windows : List Screen }


handleVNCConfirmed : ( Int, PriorityMap ) -> ( Model, Cmd Msg )
handleVNCConfirmed ( mobileFlag, p ) =
    case mobileFlag of
        0 ->
            ( LoadingScreens p, requestScreens )

        1 ->
            handleTransmissionInit ( T.init { mobile = True, screens = mobileScreens, windows = Nothing }, p )

        _ ->
            ( WaitingForStart { priority = p.priority, error = Just "Can't determine the VNC platform." }, Cmd.none )


handleTransmissionInit : ( Maybe Transmission, PriorityMap ) -> ( Model, Cmd Msg )
handleTransmissionInit ( transmission, p ) =
    case transmission of
        Just t ->
            ( if T.isMobile t then
                MobileSharing { t = t, p = p }

              else
                DesktopSharing { t = t, m = M.init Nothing, p = p }
            , Cmd.none
            )

        Nothing ->
            ( WaitingForStart { priority = p.priority, error = Just "Failed to init the Transmission." }, Cmd.none )


handleScreenSelected : ScreenSelectedData -> DesktopSharingData -> ( Model, Cmd Msg )
handleScreenSelected { screen, isWindow } { t, m, p } =
    ( DesktopSharing
        { t =
            if isWindow then
                T.startScreenSharing t screen

            else
                T.startWindowSharing t screen
        , m = M.close m
        , p = p
        }
    , if T.isVNC t then
        requestSharingConfirm screen

      else
        Cmd.none
    )


stopSharing : Cmd Msg
stopSharing =
    Http.post
        { url = buildApiPath routes.sharingStop
        , body = Http.jsonBody (EncodeJson.object []) -- here should be userId / sessionId param
        , expect = Http.expectWhatever StopConfirmed -- "assume it never fails"
        }


requestScreens : Cmd Msg
requestScreens =
    -- here should be userId / sessionId param
    Http.get
        { url = buildApiPath routes.getScreens
        , expect = Http.expectJson GotScreens decodeScreens
        }


requestSharingConfirm : Screen -> Cmd Msg
requestSharingConfirm s =
    Http.post
        { url = buildApiPath routes.sharingConfirm
        , body = Http.jsonBody <| encodeScreen s
        , expect = Http.expectWhatever ScreenConfirmed -- "assume that it also never fails"
        }


requestPause : PauseToggle -> Cmd Msg
requestPause p =
    Http.post
        { url = buildApiPath routes.pause
        , body = Http.jsonBody (EncodeJson.string <| Pause.toggleToString p)
        , expect = Http.expectWhatever (\_ -> PauseConfirmed p) -- "assume that this command never fails as well"
        }


encodeScreen : Screen -> EncodeJson.Value
encodeScreen s =
    EncodeJson.object
        [ ( "id", EncodeJson.string s.id )
        , ( "title", EncodeJson.string s.title )
        ]


decodeScreens : Decoder ScreensAndWindows
decodeScreens =
    DecodeJson.map2 ScreensAndWindows
        (DecodeJson.field "screens" <| DecodeJson.list decodeScreen)
        (DecodeJson.field "windows" <| DecodeJson.list decodeScreen)


decodeScreen : Decoder Screen
decodeScreen =
    DecodeJson.map2 Screen (DecodeJson.field "title" DecodeJson.string) (DecodeJson.field "id" DecodeJson.string)
