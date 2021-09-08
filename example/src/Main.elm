module Main exposing (..)

import Browser exposing (Document)
import Element exposing (Element)
import Pages.Counter as Counter
import Pages.Home as Home
import Pages.SignIn as SignIn
import Spa


main =
    Spa.initNoShared
        |> Spa.addStaticPathPage [] Home.page
        |> Spa.addStaticPathPage [ "sign-in" ] SignIn.page
        |> Spa.addStaticPathPage [ "counter" ] Counter.page
        |> Spa.application { toDocument = toDocument }
        |> Browser.application


toDocument : Element msg -> Document msg
toDocument el =
    { title = "hi"
    , body =
        [ Element.layout
            []
            el
        ]
    }
