module Main exposing (..)

import Browser exposing (Document)
import Element exposing (Element)
import Pages.Counter as Counter
import Pages.Home as Home
import Pages.SignIn as SignIn
import Pages.Time as Time
import Spa
import View exposing (View)


mappers =
    ( View.map, View.map )


main =
    Spa.initNoShared View.defaultView
        |> Spa.addStaticPathPage mappers [] Home.page
        |> Spa.addStaticPathPage mappers [ "sign-in" ] SignIn.page
        |> Spa.addStaticPathPage mappers [ "counter" ] Counter.page
        |> Spa.addStaticPathPage mappers [ "time" ] Time.page
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
