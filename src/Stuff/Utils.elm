module Stuff.Utils exposing (..)

import Html exposing (Html)


empty : Html msg
empty =
    Html.text ""


viewJust : Maybe a -> (a -> Html msg) -> Html msg
viewJust maybe fn =
    Maybe.map fn maybe |> Maybe.withDefault empty


viewListJust : Maybe a -> (a -> List (Html msg)) -> List (Html msg)
viewListJust maybe fn =
    Maybe.map fn maybe |> Maybe.withDefault [ empty ]


viewIf : Bool -> Html msg -> Html msg
viewIf shouldDisplay view =
    if shouldDisplay then
        view

    else
        empty


viewIfElse : Bool -> Html msg -> Html msg -> Html msg
viewIfElse shouldDisplay trueView falseView =
    if shouldDisplay then
        trueView

    else
        falseView


nothingToBool : Maybe smt -> Bool
nothingToBool smt =
    case smt of
        Just s ->
            True

        Nothing ->
            False
