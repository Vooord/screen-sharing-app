module Main exposing (..)

import Api exposing (buildApiPath, routes)
import Browser
import Html exposing (..)
import Http
import Json.Decode as DecodeJson exposing (Decoder)
import Participant
import Presenter



---- MODEL ----


type Model
    = LoadingRole
    | RoleFailed String
    | PresenterModel Presenter.Model
    | ParticipantModel Participant.Model


init : ( Model, Cmd Msg )
init =
    ( LoadingRole, requestRole )



---- UPDATE ----


type Msg
    = GotRole (Result Http.Error Int)
    | GotPresenterMsg Presenter.Msg
    | GotParticipantMsg Participant.Msg


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case ( msg, model ) of
        ( GotRole (Ok roleBit), LoadingRole ) ->
            case roleBit of
                1 ->
                    Tuple.mapBoth PresenterModel (Cmd.map GotPresenterMsg) Presenter.init

                0 ->
                    Tuple.mapBoth ParticipantModel (Cmd.map GotParticipantMsg) Participant.init

                _ ->
                    ( RoleFailed "Can't determine the role received from server :(", Cmd.none )

        ( GotRole (Err _), LoadingRole ) ->
            ( RoleFailed "Failed to load the role :(", Cmd.none )

        ( GotPresenterMsg subMsg, PresenterModel subModel ) ->
            Tuple.mapBoth PresenterModel (Cmd.map GotPresenterMsg) <| Presenter.update subMsg subModel

        ( _, _ ) ->
            ( model, Cmd.none )



---- VIEW ----


view : Model -> Html Msg
view model =
    case model of
        LoadingRole ->
            div [] [ text "Loading role..." ]

        RoleFailed error ->
            div [] [ text error ]

        PresenterModel subModel ->
            Html.map GotPresenterMsg <| Presenter.view subModel

        ParticipantModel subModel ->
            Html.map GotParticipantMsg <| Participant.view subModel



-- API --


requestRole : Cmd Msg
requestRole =
    Http.get
        { url = buildApiPath routes.currentRole

        --    it might be better to use
        --    expect = Http.expectBytes GotRole DecodeBytes.unsignedInt8
        , expect = Http.expectJson GotRole DecodeJson.int
        }



---- PROGRAM ----


main : Program () Model Msg
main =
    Browser.element
        { view = view
        , init = \_ -> init
        , update = update
        , subscriptions = always Sub.none
        }
