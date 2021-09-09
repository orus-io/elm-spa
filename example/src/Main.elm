module Main exposing (..)

import Browser exposing (Document)
import Element exposing (Element)
import Pages.Counter as Counter
import Pages.Home as Home
import Pages.SignIn as SignIn
import Pages.Time as Time
import Route
import Spa
import View exposing (View)


mappers =
    ( View.map, View.map )


main =
    Spa.initNoShared Route.toRoute View.defaultView
        |> Spa.addPage mappers Route.matchHome Home.page
        |> Spa.addPage mappers Route.matchSignIn SignIn.page
        |> Spa.addPage mappers Route.matchCounter Counter.page
        |> Spa.addPage mappers Route.matchTime Time.page
        |> Spa.application { toDocument = toDocument }
        |> Browser.application


toDocument : View msg -> Document msg
toDocument view =
    { title = view.title
    , body =
        [ Element.layout
            []
          <|
            Element.el
                [ Element.centerX, Element.centerY ]
                view.body
        ]
    }
