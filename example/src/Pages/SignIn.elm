module Pages.SignIn exposing (..)

import Effect exposing (Effect)
import Html exposing (Attribute, a, button, div, text)
import Html.Attributes exposing (href, style)
import Html.Events exposing (onClick)
import Shared
import Spa.Page
import View exposing (View)


page _ =
    Spa.Page.element
        { init = init
        , update = update
        , view = view
        , subscriptions = always Sub.none
        }


type Msg
    = Login String


type alias Model =
    { redirect : Maybe String }


init : Maybe String -> ( Model, Effect Shared.Msg Msg )
init =
    Model
        >> Effect.withNone


update : Msg -> Model -> ( Model, Effect Shared.Msg Msg )
update msg model =
    case msg of
        Login login ->
            model
                |> Effect.withShared
                    (Shared.setIdentity login
                        (model.redirect
                            |> Maybe.withDefault "/"
                            |> Just
                        )
                    )


view : Model -> View Msg
view model =
    { title = "SignIn"
    , body =
        div []
            [ text "Choose who you are:"
            , div []
                [ button (onClick (Login "Jeannine") :: buttonClass) [ text "I am Jeannine" ]
                , button (onClick (Login "Bernard") :: buttonClass) [ text "I am Bernard" ]
                , button (onClick (Login "Marie") :: buttonClass) [ text "I am Marie" ]
                , button (onClick (Login "René") :: buttonClass) [ text "I am René" ]
                ]
            , div [] [ text <| "you will be redirected to " ++ Maybe.withDefault "/" model.redirect ++ " after login" ]
            , div [] [ a [ href "/" ] [ text "Go home" ] ]
            ]
    }


buttonClass : List (Attribute msg)
buttonClass =
    [ style "border" "1px solid black", style "padding" "20px 10px", style "margin" "20px", style "font-size" "20px" ]
