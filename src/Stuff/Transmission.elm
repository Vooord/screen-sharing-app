module Stuff.Transmission exposing
    ( Screen
    , Transmission
    , confirmSharing
    , getCurrentScreen
    , getScreens
    , getWindows
    , hasActiveScreen
    , hasScreens
    , hasWindows
    , init
    , isMobile
    , isPauseWaiting
    , isPaused
    , isScreenRequesting
    , isVNC
    , pauseSwitch
    , startScreenSharing
    , startWindowSharing
    , waitForPause
    )

import Stuff.Pause as P exposing (Pause(..), PauseToggle(..))
import Stuff.Utils exposing (nothingToBool)


type alias Screen =
    { title : String, id : String }


type VNCCurrent
    = SharingScreen Screen
    | SharingWindow Screen
    | RequestingScreen Screen
    | RequestingWindow Screen


type Transmission
    = WebRTC { pause : Pause, current : Maybe Screen, screens : List Screen }
    | VNC { pause : Pause, current : Maybe VNCCurrent, screens : List Screen, windows : List Screen }
    | Mobile { pause : Pause, current : Screen }


startSharing : Transmission -> ( Screen, Bool ) -> Transmission
startSharing transmission ( s, isWindow ) =
    case transmission of
        VNC t ->
            VNC
                { t
                    | current =
                        if isWindow then
                            Just <| RequestingWindow s

                        else
                            Just <| RequestingScreen s
                }

        WebRTC t ->
            WebRTC { t | current = Just s }

        Mobile _ ->
            transmission


startScreenSharing : Transmission -> Screen -> Transmission
startScreenSharing t s =
    startSharing t ( s, False )


startWindowSharing : Transmission -> Screen -> Transmission
startWindowSharing t s =
    startSharing t ( s, True )


confirmVNC : Maybe VNCCurrent -> Maybe VNCCurrent
confirmVNC c =
    case c of
        Just (RequestingScreen s) ->
            Just (SharingScreen s)

        Just (RequestingWindow s) ->
            Just (SharingWindow s)

        Just (SharingScreen _) ->
            c

        Just (SharingWindow _) ->
            c

        Nothing ->
            c


getVNCScreen : Maybe VNCCurrent -> Maybe Screen
getVNCScreen c =
    case c of
        Just (RequestingScreen s) ->
            Just s

        Just (RequestingWindow s) ->
            Just s

        Just (SharingScreen s) ->
            Just s

        Just (SharingWindow s) ->
            Just s

        Nothing ->
            Nothing


getCurrentScreen : Transmission -> Maybe Screen
getCurrentScreen transmission =
    case transmission of
        WebRTC t ->
            t.current

        VNC t ->
            getVNCScreen t.current

        Mobile t ->
            Just t.current


hasActiveScreen : Transmission -> Bool
hasActiveScreen transmission =
    case transmission of
        WebRTC t ->
            nothingToBool t.current

        VNC t ->
            nothingToBool t.current

        Mobile _ ->
            True


confirmSharing : Transmission -> Transmission
confirmSharing transmission =
    case transmission of
        VNC t ->
            VNC { t | current = confirmVNC t.current }

        WebRTC _ ->
            transmission

        Mobile _ ->
            transmission


isScreenRequesting : Transmission -> Bool
isScreenRequesting transmission =
    case transmission of
        VNC t ->
            case t.current of
                Just (RequestingScreen _) ->
                    True

                Just (RequestingWindow _) ->
                    True

                -- didn't use "_ -> False" for all the rest deliberately. IMHO, it works more safe this way
                Just (SharingScreen _) ->
                    False

                Just (SharingWindow _) ->
                    False

                Nothing ->
                    False

        WebRTC _ ->
            False

        Mobile _ ->
            False


isPauseWaiting : Transmission -> Bool
isPauseWaiting transmission =
    case transmission of
        WebRTC t ->
            P.isRequesting t.pause

        VNC t ->
            P.isRequesting t.pause

        Mobile t ->
            P.isRequesting t.pause


isPaused : Transmission -> Bool
isPaused transmission =
    case transmission of
        WebRTC t ->
            P.isOn t.pause

        VNC t ->
            P.isOn t.pause

        Mobile t ->
            P.isOn t.pause


waitForPause : Transmission -> PauseToggle -> Transmission
waitForPause transmission toggle =
    case transmission of
        WebRTC t ->
            case ( t.pause, toggle ) of
                ( PauseOff, SwitchOn ) ->
                    WebRTC { t | pause = RequestingPause toggle }

                ( PauseOn, SwitchOff ) ->
                    WebRTC { t | pause = RequestingPause toggle }

                _ ->
                    transmission

        VNC t ->
            case ( t.pause, toggle ) of
                ( PauseOff, SwitchOn ) ->
                    VNC { t | pause = RequestingPause toggle }

                ( PauseOn, SwitchOff ) ->
                    VNC { t | pause = RequestingPause toggle }

                _ ->
                    transmission

        Mobile t ->
            case ( t.pause, toggle ) of
                ( PauseOff, SwitchOn ) ->
                    Mobile { t | pause = RequestingPause toggle }

                ( PauseOn, SwitchOff ) ->
                    Mobile { t | pause = RequestingPause toggle }

                _ ->
                    transmission


pauseSwitch : Transmission -> PauseToggle -> Transmission
pauseSwitch transmission toggle =
    case transmission of
        WebRTC t ->
            case ( t.pause, toggle ) of
                ( RequestingPause SwitchOn, SwitchOn ) ->
                    WebRTC { t | pause = PauseOn }

                ( RequestingPause SwitchOff, SwitchOff ) ->
                    WebRTC { t | pause = PauseOff }

                _ ->
                    transmission

        VNC t ->
            case ( t.pause, toggle ) of
                ( RequestingPause SwitchOn, SwitchOn ) ->
                    VNC { t | pause = PauseOn }

                ( RequestingPause SwitchOff, SwitchOff ) ->
                    VNC { t | pause = PauseOff }

                _ ->
                    transmission

        Mobile t ->
            case ( t.pause, toggle ) of
                ( RequestingPause SwitchOn, SwitchOn ) ->
                    Mobile { t | pause = PauseOn }

                ( RequestingPause SwitchOff, SwitchOff ) ->
                    Mobile { t | pause = PauseOff }

                _ ->
                    transmission


isVNC : Transmission -> Bool
isVNC t =
    case t of
        WebRTC _ ->
            False

        VNC _ ->
            True

        Mobile _ ->
            True


isMobile : Transmission -> Bool
isMobile t =
    case t of
        WebRTC _ ->
            False

        VNC _ ->
            False

        Mobile _ ->
            True


getScreens : Transmission -> List Screen
getScreens transmission =
    case transmission of
        WebRTC t ->
            t.screens

        VNC t ->
            t.screens

        Mobile t ->
            [ t.current ]


hasScreens : Transmission -> Bool
hasScreens t =
    List.length (getScreens t) > 0


getWindows : Transmission -> Maybe (List Screen)
getWindows transmission =
    case transmission of
        WebRTC _ ->
            Nothing

        VNC t ->
            Just t.windows

        Mobile _ ->
            Nothing


hasWindows : Transmission -> Bool
hasWindows t =
    let
        windows =
            getWindows t
    in
    case windows of
        Just w ->
            List.length w > 0

        Nothing ->
            False


init : { mobile : Bool, screens : List Screen, windows : Maybe (List Screen) } -> Maybe Transmission
init { mobile, screens, windows } =
    let
        screen =
            List.head screens
    in
    case screen of
        -- any valid transmission should have at least one screen
        Just s ->
            if mobile then
                Just <| Mobile { pause = PauseOff, current = s }

            else
                case windows of
                    Just ws ->
                        Just <| VNC { pause = PauseOff, current = Nothing, screens = screens, windows = ws }

                    Nothing ->
                        Just <| WebRTC { pause = PauseOff, current = Nothing, screens = screens }

        Nothing ->
            Nothing
