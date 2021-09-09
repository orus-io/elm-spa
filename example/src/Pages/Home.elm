module Pages.Home exposing (..)

import Element exposing (Element)
import Html
import Shared exposing (Shared)
import Spa.Page
import View exposing (View)


page shared =
    Spa.Page.static (view shared)


view : Shared -> View ()
view shared =
    { title = "Home"
    , body =
        Element.column []
            [ case Shared.identity shared of
                Just identity ->
                    Element.text <| "Welcome Home " ++ identity ++ "!"

                Nothing ->
                    Element.text "Welcome Home!"
            , Element.link []
                { label = Element.text "Go sign-in"
                , url = "/sign-in"
                }
            , Element.link []
                { label = Element.text "See counter"
                , url = "/counter"
                }
            , Element.link []
                { label = Element.text "See time"
                , url = "/time"
                }
            ]
    }
