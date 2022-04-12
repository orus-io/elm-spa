module Pages.Home exposing (..)

import Html exposing (a, div, text)
import Html.Attributes exposing (href)
import Shared exposing (Shared)
import Spa.Page
import View exposing (View)


page shared =
    Spa.Page.static (view shared)


view : Shared -> View ()
view shared =
    { title = "Home"
    , body =
        div []
            [ case Shared.identity shared of
                Just identity ->
                    text <| "Welcome Home " ++ identity ++ "!"

                Nothing ->
                    text "Welcome Home!"
            , a [ href "/counter" ] [ text "See counter" ]
            , a [ href "/time" ] [ text "See time" ]
            ]
    }
