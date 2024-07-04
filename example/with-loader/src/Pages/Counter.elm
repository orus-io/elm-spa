module Pages.Counter exposing (Model, Msg, page)

import Effect exposing (Effect)
import Element exposing (Element)
import Element.Background as Background
import Element.Input as Input
import Route
import Shared exposing (Identity, Shared)
import Spa.Page
import View exposing (View)


page : Shared -> Identity -> Spa.Page.Page Int Shared.Msg (View Msg) Model Msg
page shared identity =
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


btnColor : Element.Color
btnColor =
    Element.rgb255 238 238 238


myButton : String -> Msg -> Element Msg
myButton label msg =
    Input.button
        [ Background.color btnColor
        ]
        { onPress = Just msg
        , label = Element.text label
        }


counterElements : Model -> View Msg
counterElements model =
    { title = "Counter"
    , body =
        Element.column [] <|
            [ Element.row
                [ Element.spacing 30
                , Element.padding 10
                ]
                [ myButton "Increment" Increment
                , Element.text <| String.fromInt model.amount
                , myButton "Decrement" Decrement
                ]
            , Element.link []
                { label = Element.text "Reset"
                , url = "?value=0"
                }
            , Element.link []
                { label = Element.text "Go Home"
                , url = "/"
                }
            ]
                ++ (if model.directSetValue then
                        [ Element.text "Just avoided a 'init' call" ]

                    else
                        []
                   )
    }
