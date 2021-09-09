module Pages.Counter exposing (page)

import Element exposing (Element)
import Element.Background as Background
import Element.Input as Input
import Spa.Page
import View exposing (View)


page _ identity =
    Spa.Page.sandbox
        { init = always initialModel
        , update = update
        , view = counterElements
        }


type Msg
    = Increment
    | Decrement


type alias Model =
    { amount : Int }


initialModel : Model
initialModel =
    Model 0


update : Msg -> Model -> Model
update msg model =
    case msg of
        Increment ->
            { model | amount = model.amount + 1 }

        Decrement ->
            { model | amount = model.amount - 1 }


blue =
    Element.rgb255 238 238 238


myButton : String -> Msg -> Element Msg
myButton label msg =
    Input.button
        [ Background.color blue
        ]
        { onPress = Just msg
        , label = Element.text label
        }


counterElements : Model -> View Msg
counterElements model =
    { title = "Counter"
    , body =
        Element.column []
            [ Element.row [ Element.spacing 30, Element.padding 10 ]
                [ myButton "Increment" Increment
                , Element.text <| String.fromInt model.amount
                , myButton "Decrement" Decrement
                ]
            , Element.link []
                { label = Element.text "Go Home"
                , url = "/"
                }
            ]
    }
