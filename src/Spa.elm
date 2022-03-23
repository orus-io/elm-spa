module Spa exposing
    ( init, initNoShared
    , addPublicPage, addProtectedPage
    , application, mapSharedMsg
    , Builder, Model, Msg, SetupError
    )

{-| A typical SPA application is defined in a few simple steps:

  - boostrap the application with [init](#init) or [initNoShared](#initNoShared)

  - add pages with [addPublicPage](#addPublicPage) and [addProtectedPage](#addProtectedPage)

  - finalize the application with [application](#application) (with possible the help of [mapSharedMsg](#mapSharedMsg)

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
                    { toRoute = Route.toRoute
                    , init = Shared.init
                    , update = Shared.update
                    , subscriptions = Shared.subscriptions
                    , toDocument = toDocument
                    , protectPage = Route.toUrl >> Just >> Route.SignIn >> Route.toUrl
                    }
                |> Browser.application


# Create the application

@docs init, initNoShared


# Add pages

@docs addPublicPage, addProtectedPage


# Finalize

Once all the pages are added to the application, we can change it into a record
suitable for the `Browser.application` function.

@docs application, mapSharedMsg


# Types

@docs Builder, Model, Msg, SetupError

-}

import Browser exposing (Document, UrlRequest)
import Browser.Navigation as Nav
import Effect
import Spa.Page exposing (Page)
import Spa.PageStack as PageStack
import Url exposing (Url)


{-| The Application Msg type
-}
type Msg sharedMsg pageMsg
    = SharedMsg sharedMsg
    | PageMsg pageMsg
    | UrlRequest UrlRequest
    | UrlChange Url


{-| maps a sharedMsg into a Msg. Useful in the 'toDocument' function, to add
global actions that trigger shared messages
-}
mapSharedMsg : sharedMsg -> Msg sharedMsg pageMsg
mapSharedMsg =
    SharedMsg


{-| A custom setup error for the underlying PageStack.Stack
-}
type SetupError
    = ProtectedPageError


{-| The Application Model
-}
type alias Model route shared current previous =
    { key : Nav.Key
    , currentRoute : route
    , shared : shared
    , page : PageStack.Model SetupError current previous
    }


modelShared : Model route shared current previous -> shared
modelShared { shared } =
    shared


{-| The intermediate type for building an application.
-}
type alias Builder route identity shared sharedMsg view current previous currentMsg previousMsg =
    { extractIdentity : shared -> Maybe identity
    , pageStack : PageStack.Stack SetupError shared sharedMsg route view current previous currentMsg previousMsg
    }


{-| Bootstrap a Spa application

    Spa.init
        { defaultView = View.defaultView
        , extractIdentity = Shared.identity
        }

  - `defaultView` is the default view that will be used when no other page could
    be viewed, which should be _never_ once your app is properly setup (more on
    that a little further).

  - `extractIdentity` is a function that returns a `Maybe identity` from a
    `Shared` record. The actual `identity` type can be anything you want.

-}
init :
    { defaultView : view
    , extractIdentity : shared -> Maybe identity
    }
    -> Builder route identity shared sharedMsg view () () () ()
init shared =
    { extractIdentity = shared.extractIdentity
    , pageStack = PageStack.setup { defaultView = shared.defaultView }
    }


{-| Bootstrap a Spa application that has no Shared state
-}
initNoShared :
    { defaultView : view
    }
    -> Builder route () () () view () () () ()
initNoShared { defaultView } =
    init
        { defaultView = defaultView
        , extractIdentity = always Nothing
        }


{-| Add a public page to the application

    |> Spa.addPublicPage (View.map, View.map) matchHome Pages.Home.page

  - `mappers` is a Tuple of view mappers. For example, if the application view is
    a `Html msg`, the mappers will be: `( Html.map, Html.map )`. The duplication
    is for technical reasons (see the `addPage` function implementation).

  - `match` is a function that takes a route and returns the page flags if and
    only if the route matches the page. This is the place were information can
    be extracted from the route to be given to the page `init` function.

    A simple match function can be:

        matchHome : Route -> Maybe ()
        matchHome route =
            case route of
                Home ->
                    Just ()

                _ ->
                    Nothing

    A match function that extract information:

        matchSignIn : Route -> Maybe (Maybe String)
        matchSignIn route =
            case route of
                SignIn redirect ->
                    Just redirect

                _ ->
                    Nothing

  - `page` is a page constructor. A public page constructor is a function that
    takes the shared state:

        page : shared -> Page

-}
addPublicPage :
    ( PageStack.CurrentViewMap route currentPageMsg previousStackMsg pageView view
    , PageStack.PreviousViewMap route currentPageMsg previousStackMsg previousView view
    )
    -> (route -> Maybe pageFlags)
    -> (shared -> Page pageFlags sharedMsg pageView currentPageModel currentPageMsg)
    -> Builder route identity shared sharedMsg previousView previousCurrent previousPrevious previousStackCurrentMsg previousStackPreviousMsg
    -> Builder route identity shared sharedMsg view currentPageModel (PageStack.Model SetupError previousCurrent previousPrevious) currentPageMsg (PageStack.Msg route previousStackCurrentMsg previousStackPreviousMsg)
addPublicPage mappers matchRoute page =
    addPage mappers matchRoute (page >> Ok)


{-| Add a protected page to the application

    |> Spa.addProtectedPage (View.map, View.map) matchProfile Pages.Profile.page

The parameters are the same as addPublicPage, except that the page constructor
takes the current identity in addition to the shared state:

    page : shared -> identity -> Page

-}
addProtectedPage :
    ( PageStack.CurrentViewMap route currentPageMsg previousStackMsg pageView view
    , PageStack.PreviousViewMap route currentPageMsg previousStackMsg previousView view
    )
    -> (route -> Maybe pageFlags)
    -> (shared -> identity -> Page pageFlags sharedMsg pageView currentPageModel currentPageMsg)
    -> Builder route identity shared sharedMsg previousView previousCurrent previousPrevious previousStackCurrentMsg previousStackPreviousMsg
    -> Builder route identity shared sharedMsg view currentPageModel (PageStack.Model SetupError previousCurrent previousPrevious) currentPageMsg (PageStack.Msg route previousStackCurrentMsg previousStackPreviousMsg)
addProtectedPage mappers matchRoute page builder =
    addPage mappers
        matchRoute
        (\shared ->
            case builder.extractIdentity shared of
                Just identity ->
                    Ok <| page shared identity

                Nothing ->
                    Err ProtectedPageError
        )
        builder


addPage :
    ( PageStack.CurrentViewMap route currentPageMsg previousStackMsg pageView view
    , PageStack.PreviousViewMap route currentPageMsg previousStackMsg previousView view
    )
    -> (route -> Maybe pageFlags)
    -> PageStack.PageSetup SetupError pageFlags shared sharedMsg pageView currentPageModel currentPageMsg
    -> Builder route identity shared sharedMsg previousView previousCurrent previousPrevious previousStackCurrentMsg previousStackPreviousMsg
    -> Builder route identity shared sharedMsg view currentPageModel (PageStack.Model SetupError previousCurrent previousPrevious) currentPageMsg (PageStack.Msg route previousStackCurrentMsg previousStackPreviousMsg)
addPage mappers matchRoute page builder =
    let
        pageStack : PageStack.Stack SetupError shared sharedMsg route view currentPageModel (PageStack.Model SetupError previousCurrent previousPrevious) currentPageMsg (PageStack.Msg route previousStackCurrentMsg previousStackPreviousMsg)
        pageStack =
            builder.pageStack
                |> PageStack.add mappers matchRoute page
    in
    { extractIdentity = builder.extractIdentity
    , pageStack = pageStack
    }


{-| Finalize the Spa application into a record suitable for the `Browser.application`

    appWithPages
        |> Spa.application View.map
            { toRoute = Route.toRoute
            , protectPage = Route.toUrl >> Just >> Route.SignIn >> Route.toUrl
            , init = Shared.init
            , update = Shared.update
            , subscriptions = Shared.subscriptions
            , toDocument = toDocument
            }
        |> Browser.application

It takes a view mapper, then:

  - `toRoute` changes a Url.Url into a (custom) route
  - `protectPage` produces a redirection url when a protected route is accessed
    without being identified
  - `init` is the init function of the shared module
  - `update` is the update function of the shared module
  - `subscriptions` is the subscriptions function of the shared module
  - `toDocument` is a function that convert a view to a `Browser.Document`

-}
application :
    ((PageStack.Msg route stackCurrentMsg stackPreviousMsg -> Msg sharedMsg (PageStack.Msg route stackCurrentMsg stackPreviousMsg)) -> pageView -> view)
    ->
        { toRoute : Url -> route
        , init : flags -> Nav.Key -> ( shared, Cmd sharedMsg )
        , subscriptions : shared -> Sub sharedMsg
        , update : sharedMsg -> shared -> ( shared, Cmd sharedMsg )
        , protectPage : route -> String
        , toDocument : shared -> view -> Document (Msg sharedMsg (PageStack.Msg route stackCurrentMsg stackPreviousMsg))
        }
    -> Builder route identity shared sharedMsg pageView current previous stackCurrentMsg stackPreviousMsg
    ->
        { init : flags -> Url -> Nav.Key -> ( Model route shared current previous, Cmd (Msg sharedMsg (PageStack.Msg route stackCurrentMsg stackPreviousMsg)) )
        , view : Model route shared current previous -> Document (Msg sharedMsg (PageStack.Msg route stackCurrentMsg stackPreviousMsg))
        , update : Msg sharedMsg (PageStack.Msg route stackCurrentMsg stackPreviousMsg) -> Model route shared current previous -> ( Model route shared current previous, Cmd (Msg sharedMsg (PageStack.Msg route stackCurrentMsg stackPreviousMsg)) )
        , subscriptions : Model route shared current previous -> Sub (Msg sharedMsg (PageStack.Msg route stackCurrentMsg stackPreviousMsg))
        , onUrlRequest : UrlRequest -> Msg sharedMsg (PageStack.Msg route stackCurrentMsg stackPreviousMsg)
        , onUrlChange : Url -> Msg sharedMsg (PageStack.Msg route stackCurrentMsg stackPreviousMsg)
        }
application viewMap app builder =
    let
        initPage : route -> Nav.Key -> shared -> ( PageStack.Model SetupError current previous, Cmd (Msg sharedMsg (PageStack.Msg route stackCurrentMsg stackPreviousMsg)) )
        initPage route key shared =
            let
                ( page, effect ) =
                    builder.pageStack.init shared route
            in
            case PageStack.getError page of
                Just _ ->
                    ( PageStack.empty, Nav.replaceUrl key <| app.protectPage route )

                Nothing ->
                    ( page, Effect.toCmd ( SharedMsg, PageMsg ) effect )
    in
    { init =
        \flags url key ->
            let
                route : route
                route =
                    app.toRoute url

                ( shared, sharedCmd ) =
                    app.init flags key

                ( page, pageCmd ) =
                    initPage route key shared
            in
            ( { key = key
              , currentRoute = route
              , shared = shared
              , page = page
              }
            , Cmd.batch
                [ Cmd.map SharedMsg sharedCmd
                , pageCmd
                ]
            )
    , view =
        \model ->
            builder.pageStack.view model.shared model.page
                |> viewMap PageMsg
                |> app.toDocument (modelShared model)
    , update =
        \msg model ->
            case msg of
                SharedMsg sharedMsg ->
                    let
                        ( newShared, sharedCmd ) =
                            app.update sharedMsg model.shared

                        identityChanged =
                            builder.extractIdentity newShared
                                /= builder.extractIdentity model.shared
                    in
                    if identityChanged then
                        let
                            ( page, pageEffect ) =
                                builder.pageStack.update newShared (PageStack.routeChange model.currentRoute) model.page
                        in
                        case PageStack.getError page of
                            Just _ ->
                                ( { model
                                    | shared = newShared
                                    , page = page
                                  }
                                , Cmd.batch
                                    [ Cmd.map SharedMsg sharedCmd
                                    , Nav.replaceUrl model.key <| app.protectPage model.currentRoute
                                    ]
                                )

                            Nothing ->
                                ( { model
                                    | shared = newShared
                                    , page = page
                                  }
                                , Cmd.batch
                                    [ Cmd.map SharedMsg sharedCmd
                                    , Effect.toCmd ( SharedMsg, PageMsg ) pageEffect
                                    ]
                                )

                    else
                        ( { model | shared = newShared }
                        , Cmd.map SharedMsg sharedCmd
                        )

                PageMsg pageMsg ->
                    let
                        ( newPage, pageEffect ) =
                            builder.pageStack.update model.shared pageMsg model.page
                    in
                    ( { model | page = newPage }
                    , Effect.toCmd ( SharedMsg, PageMsg ) pageEffect
                    )

                UrlRequest urlRequest ->
                    case urlRequest of
                        Browser.Internal url ->
                            ( model
                            , Nav.pushUrl model.key (Url.toString url)
                            )

                        Browser.External url ->
                            ( model
                            , Nav.load url
                            )

                UrlChange url ->
                    let
                        route : route
                        route =
                            app.toRoute url

                        ( page, pageEffect ) =
                            builder.pageStack.update model.shared (PageStack.routeChange route) model.page
                    in
                    case PageStack.getError page of
                        Just _ ->
                            ( { model
                                | currentRoute = route
                                , page = page
                              }
                            , Nav.replaceUrl model.key <| app.protectPage route
                            )

                        Nothing ->
                            ( { model
                                | currentRoute = route
                                , page = page
                              }
                            , Effect.toCmd ( SharedMsg, PageMsg ) pageEffect
                            )
    , subscriptions =
        \model ->
            Sub.batch
                [ app.subscriptions model.shared |> Sub.map SharedMsg
                , builder.pageStack.subscriptions model.shared model.page |> Sub.map PageMsg
                ]
    , onUrlRequest = UrlRequest
    , onUrlChange = UrlChange
    }
