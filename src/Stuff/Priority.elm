module Stuff.Priority exposing (..)


type Priority
    = WebRTC
    | VNC
      -- Bool == current fallback status
    | WebRTC_VNC Bool
    | VNC_WebRTC Bool


type alias ExtendablePriority extends =
    { extends | priority : Priority }


determinePriority : List String -> Maybe Priority
determinePriority config =
    let
        webRtc =
            priorityToString WebRTC

        vnc =
            priorityToString VNC
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


priorityToString : Priority -> String
priorityToString p =
    case p of
        WebRTC ->
            "WebRTC"

        WebRTC_VNC _ ->
            "WebRTC"

        VNC ->
            "VNC"

        VNC_WebRTC _ ->
            "VNC"
