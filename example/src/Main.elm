module Main exposing (..)

import Browser exposing (Document)
import Element
import Element.Input as Input
import Pages.Counter as Counter
import Pages.Home as Home
import Pages.SignIn as SignIn
import Pages.Time as Time
import Route
import Shared exposing (Shared)
import Spa
import View exposing (View)


mappers : ( (a -> b) -> View a -> View b, (c -> d) -> View c -> View d )
mappers =
    ( View.map, View.map )


toDocument :
    Shared
    -> View (Spa.Msg Shared.Msg pageMsg)
    -> Document (Spa.Msg Shared.Msg pageMsg)
toDocument shared view =
    { title = view.title
    , body =
        [ Element.layout
            []
          <|
            Element.column
                [ Element.width Element.fill
                , Element.height Element.fill
                ]
                [ Element.row
                    [ Element.alignRight
                    , Element.padding 20
                    , Element.spacing 20
                    ]
                  <|
                    case shared.identity of
                        Just username ->
                            [ Element.text username
                            , Input.button []
                                { label = Element.text "logout"
                                , onPress = Just (Spa.mapSharedMsg Shared.ResetIdentity)
                                }
                            ]

                        Nothing ->
                            [ Element.link []
                                { label = Element.text "Sign-in"
                                , url = "/sign-in"
                                }
                            ]
                , Element.el
                    [ Element.centerX, Element.centerY ]
                    view.body
                ]
        ]
    }


main =
    Spa.init
        { defaultView = View.defaultView
        , extractIdentity = Shared.identity
        }
        |> Spa.addPublicPage mappers Route.matchHome Home.page
        |> Spa.addPublicPage mappers Route.matchSignIn SignIn.page
        |> Spa.addProtectedPage mappers Route.matchCounter Counter.page
        |> Spa.addPublicPage mappers Route.matchTime Time.page
        |> Spa.application View.map
            { init = Shared.init
            , subscriptions = Shared.subscriptions
            , update = Shared.update
            , toRoute = Route.toRoute
            , toDocument = toDocument
            , protectPage = Route.toUrl >> Just >> Route.SignIn >> Route.toUrl
            }
        |> Browser.application
