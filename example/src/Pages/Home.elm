module Pages.Home exposing (..)

import Element exposing (Element)
import Html
import Spa.Page


page _ =
    Spa.Page.static view


view : Element ()
view =
    Element.column []
        [ Element.text "Welcome Home !"
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