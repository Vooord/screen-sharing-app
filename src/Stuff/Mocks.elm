module Stuff.Mocks exposing (..)

import Stuff.Transmission exposing (Screen)


mobileScreens : List Screen
mobileScreens =
    [ { title = "Mobile display", id = "0" } ]


webRTCScreens : List Screen
webRTCScreens =
    [ { title = "mock_screen1", id = "1" }, { title = "mock_screen2", id = "2" } ]
