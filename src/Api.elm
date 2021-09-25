module Api exposing (buildApiPath, routes)


apiHost : String
apiHost =
    "https://vord-elm1.free.beeceptor.com"


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
