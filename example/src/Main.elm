module Main exposing (..)

import Browser exposing (Document)
import Element exposing (Element)
import Pages.Counter as Counter
import Pages.Home as Home
import Pages.SignIn as SignIn
import Pages.Time as Time
import Route
import Shared exposing (Shared)
import Spa
import View exposing (View)


mappers =
    ( View.map, View.map )


toDocument : Shared -> View msg -> Document msg
toDocument _ view =
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


main =
    Spa.init
        { init = Shared.init
        , subscriptions = Shared.subscriptions
        , update = Shared.update
        , defaultView = View.defaultView
        , toRoute = Route.toRoute
        , extractIdentity = Shared.identity
        , protectPage = Route.toUrl >> Just >> Route.SignIn >> Route.toUrl
        }
        |> Spa.addPublicPage mappers Route.matchHome Home.page
        |> Spa.addPublicPage mappers Route.matchSignIn SignIn.page
        |> Spa.addProtectedPage mappers Route.matchCounter Counter.page
        |> Spa.addPublicPage mappers Route.matchTime Time.page
        |> Spa.application { toDocument = toDocument }
        |> Browser.application
