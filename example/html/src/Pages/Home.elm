module Pages.Home exposing (page)

import Html exposing (a, div, text)
import Html.Attributes exposing (href)
import Shared exposing (Shared)
import Spa.Page
import View exposing (View)


page : Shared -> Spa.Page.Page () Shared.Msg (View ()) () ()
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
            , div [] [ a [ href "/counter" ] [ text "See counter" ] ]
            , div [] [ a [ href "/time" ] [ text "See time" ] ]
            ]
    }
