module Pages.SignIn exposing (..)

import Element exposing (Element)
import Spa.Page
import View exposing (View)


page _ =
    Spa.Page.static view


view : View ()
view =
    { title = "SignIn"
    , body =
        Element.column []
            [ Element.text "Here you can SignIn (soon)"
            , Element.link []
                { label = Element.text "Go home"
                , url = "/"
                }
            ]
    }
