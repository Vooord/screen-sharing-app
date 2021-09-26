port module Api exposing (buildApiPath, onScreensReceived, routes)

import Stuff.Transmission exposing (Screen)


port onScreensReceived : (List Screen -> msg) -> Sub msg


apiHost : String
apiHost =
    "https://vord1-elm.free.beeceptor.com"


buildApiPath : String -> String
buildApiPath path =
    apiHost ++ "/" ++ path


routes =
    { currentRole = "current_role"
    , sharingCondig = "sharing_config"
    , sharingStart = "start_sharing"
    , sharingStop = "stop_sharing"
    , getScreens = "screens"
    , sharingConfirm = "sharing_confirm"
    , pause = "pause"
    }
