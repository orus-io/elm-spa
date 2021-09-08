module Pages.SignIn exposing (..)

import Element exposing (Element)
import Html
import Spa.Page


page _ =
    Spa.Page.static view


view : Element ()
view =
    Element.column []
        [ Element.text "Here you can SignIn (soon)"
        , Element.link []
            { label = Element.text "Go home"
            , url = "/"
            }
        ]
