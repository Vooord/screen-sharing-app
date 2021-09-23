module Stuff.Transmission exposing (Screen, Transmission, init, isMobile, mobileScreens, webRTCScreens)


type alias Screen =
    { title : String, id : String }


type Transmission
    = WebRTC { paused : Bool, current : Maybe Screen, screens : List Screen }
    | VNC { paused : Bool, current : Maybe Screen, screens : List Screen, windows : List Screen }
    | Mobile { paused : Bool, current : Screen }


mobileScreens : List Screen
mobileScreens =
    [ { title = "Mobile display", id = "0" } ]


webRTCScreens : List Screen
webRTCScreens =
    [ { title = "mock_screen1", id = "1" }, { title = "mock_screen2", id = "2" } ]


hasActiveScreen : Transmission -> Bool
hasActiveScreen transmission =
    case transmission of
        WebRTC t ->
            case t.current of
                Just _ ->
                    True

                Nothing ->
                    False

        VNC t ->
            case t.current of
                Just _ ->
                    True

                Nothing ->
                    False

        Mobile _ ->
            True


isActive : Transmission -> Bool
isActive transmission =
    case transmission of
        WebRTC t ->
            hasActiveScreen transmission && not t.paused

        VNC t ->
            hasActiveScreen transmission && not t.paused

        Mobile t ->
            hasActiveScreen transmission && not t.paused


isMobile : Transmission -> Bool
isMobile t =
    case t of
        WebRTC _ ->
            False

        VNC _ ->
            False

        Mobile _ ->
            True


init : { mobile : Bool, screens : List Screen, windows : Maybe (List Screen) } -> Maybe Transmission
init { mobile, screens, windows } =
    let
        screen =
            List.head screens
    in
    case screen of
        Just s ->
            if mobile then
                Just <| Mobile { paused = False, current = s }

            else
                case windows of
                    Just ws ->
                        Just <| VNC { paused = False, current = Nothing, screens = screens, windows = ws }

                    Nothing ->
                        Just <| WebRTC { paused = False, current = Nothing, screens = screens }

        Nothing ->
            Nothing
