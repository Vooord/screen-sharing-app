module Stuff.Priority exposing (..)


type Priority
    = WebRTC
    | VNC
      -- Bool == current fallback status
    | WebRTC_VNC Bool
    | VNC_WebRTC Bool


type alias WithPriority extends =
    { extends | priority : Priority }


type alias PriorityMap =
    WithPriority {}


determine : List String -> Maybe Priority
determine config =
    let
        webRtc =
            toString WebRTC

        vnc =
            toString VNC
    in
    case config of
        [ p1, p2 ] ->
            if p1 == webRtc && p2 == vnc then
                Just <| WebRTC_VNC False

            else if p1 == vnc && p2 == webRtc then
                Just <| VNC_WebRTC False

            else
                Nothing

        [ p1 ] ->
            if p1 == webRtc then
                Just WebRTC

            else if p1 == vnc then
                Just VNC

            else
                Nothing

        _ ->
            Nothing


toString : Priority -> String
toString p =
    case p of
        WebRTC ->
            "WebRTC"

        WebRTC_VNC _ ->
            "WebRTC"

        VNC ->
            "VNC"

        VNC_WebRTC _ ->
            "VNC"
