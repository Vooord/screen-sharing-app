module Stuff.Modal exposing (Modal, ModalTab(..), changeTab, close, getTab, init, isOpen)


type ModalTab
    = ScreensTab
    | WindowsTab


type Modal
    = Opened ModalTab
    | Closed


isOpen : Modal -> Bool
isOpen m =
    case m of
        Opened _ ->
            True

        Closed ->
            False


getTab : Modal -> Maybe ModalTab
getTab m =
    case m of
        Opened t ->
            Just t

        Closed ->
            Nothing


changeTab : Modal -> ModalTab -> Modal
changeTab m tab =
    case m of
        Opened _ ->
            Opened tab

        Closed ->
            Closed


close : Modal -> Modal
close m =
    case m of
        Opened _ ->
            Closed

        Closed ->
            Closed


init : Maybe ModalTab -> Modal
init tab =
    case tab of
        Just t ->
            Opened t

        Nothing ->
            Closed
