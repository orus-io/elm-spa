module Pages.Counter exposing (page)

import Effect exposing (Effect)
import Html exposing (Html, a, button, div, text)
import Html.Attributes exposing (href, style)
import Html.Events exposing (onClick)
import Route
import Shared
import Spa.Page
import View exposing (View)


page _ identity =
    Spa.Page.element
        { init = init
        , update = update
        , subscriptions = always Sub.none
        , view = counterElements
        }
        |> Spa.Page.onNewFlags SetValue


type Msg
    = Increment
    | Decrement
    | SetValue Int


type alias Model =
    { amount : Int
    , directSetValue : Bool
    }


init : Int -> ( Model, Effect Shared.Msg Msg )
init value =
    Model value False |> Effect.withNone


setvalue : Int -> Model -> ( Model, Effect Shared.Msg Msg )
setvalue value model =
    { model | amount = value }
        |> Effect.withShared (Shared.replaceRoute <| Route.Counter value)


update : Msg -> Model -> ( Model, Effect Shared.Msg Msg )
update msg model =
    case msg of
        Increment ->
            setvalue (model.amount + 1) { model | directSetValue = False }

        Decrement ->
            setvalue (model.amount - 1) { model | directSetValue = False }

        SetValue value ->
            if value /= model.amount then
                setvalue value { model | directSetValue = True }

            else
                model |> Effect.withNone


myButton : String -> Msg -> Html Msg
myButton label msg =
    button
        [ onClick msg
        , style "margin" "10px"
        ]
        [ text label ]


counterElements : Model -> View Msg
counterElements model =
    { title = "Counter"
    , body =
        div [] <|
            [ div
                [ style "padding" "10px"
                ]
                [ myButton "Increment" Increment
                , text <| String.fromInt model.amount
                , myButton "Decrement" Decrement
                ]
            , div [] [ a [ href "?value=0" ] [ text "Reset" ] ]
            , div [] [ a [ href "/" ] [ text "Go Home" ] ]
            ]
                ++ (if model.directSetValue then
                        [ text "Just avoided a 'init' call" ]

                    else
                        []
                   )
    }
