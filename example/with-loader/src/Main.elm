module Main exposing (main)

import Browser exposing (Document)
import Element
import Element.Input as Input
import Loader
import Pages.Counter as Counter
import Pages.Home as Home
import Pages.SignIn as SignIn
import Pages.Time as Time
import Route
import Shared exposing (Shared)
import Spa
import Time
import View exposing (View)


mappers : ( (a -> b) -> View a -> View b, (c -> d) -> View c -> View d )
mappers =
    ( View.map, View.map )


toDocument :
    Shared
    -> View (Spa.Msg Loader.Msg Shared.Msg pageMsg)
    -> Document (Spa.Msg Loader.Msg Shared.Msg pageMsg)
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
                    [ Element.padding 20
                    , Element.spacing 20
                    , Element.width Element.fill
                    ]
                  <|
                    case shared.identity of
                        Just username ->
                            [ Element.el [ Element.alignRight ] <| Element.text username
                            , Input.button [ Element.alignRight ]
                                { label = Element.text "logout"
                                , onPress = Just (Spa.mapSharedMsg Shared.ResetIdentity)
                                }
                            ]

                        Nothing ->
                            [ Element.link [ Element.alignRight ]
                                { label = Element.text "Sign-in"
                                , url = "/sign-in"
                                }
                            ]
                , Element.el
                    [ Element.centerX, Element.centerY ]
                    view.body
                , Element.el
                    [ Element.alignBottom
                    ]
                  <|
                    Element.text
                        ("Started at "
                            ++ (String.fromInt <| Time.toHour shared.timezone shared.appStartedAt)
                            ++ ":"
                            ++ (String.fromInt <| Time.toMinute shared.timezone shared.appStartedAt)
                            ++ ":"
                            ++ (String.fromInt <| Time.toSecond shared.timezone shared.appStartedAt)
                            ++ ", Current route: "
                            ++ Route.toUrl shared.currentRoute
                        )
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
        |> Spa.beforeRouteChange Shared.RouteChange
        |> Spa.applicationWithLoader View.map
            Loader.loader
            { subscriptions = Shared.subscriptions
            , update = Shared.update
            , toRoute = Route.toRoute
            , toDocument = toDocument
            , protectPage = Route.toUrl >> Just >> Route.SignIn >> Route.toUrl
            }
        |> Browser.application
