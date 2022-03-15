module Spa exposing
    ( init, initNoShared
    , addPublicPage, addProtectedPage
    , application, mapSharedMsg
    , Builder, Model, Msg
    , Page, PageModel, PageMsg
    )

{-|


# Create the application

@docs init, initNoShared


# Add pages

@docs addPublicPage, addProtectedPage


# Finalize

Once all the pages are added to the application, we can change it into a record
suitable for the `Browser.application` function.

@docs application, mapSharedMsg


# Types

@docs Builder, Model, Msg
@docs Page, PageModel, PageMsg

-}

import Browser exposing (Document, UrlRequest)
import Browser.Navigation as Nav
import Effect
import Internal exposing (PageDefinition)
import Url exposing (Url)


{-| A message type that carries page messages
-}
type PageMsg current previous
    = CurrentMsg current
    | PreviousMsg previous


{-| A model for storing the active page model
-}
type PageModel current previous
    = NoPage
    | Current current
    | Previous previous


previousPageModel :
    PageModel current (PageModel previous previous2)
    -> PageModel previous previous2
previousPageModel page =
    case page of
        Previous previous ->
            previous

        Current _ ->
            NoPage

        NoPage ->
            NoPage


currentPageModel : PageModel current previous -> Maybe current
currentPageModel page =
    case page of
        Current model ->
            Just model

        _ ->
            Nothing


{-| The top-level application message type
-}
type Msg sharedMsg pageMsg
    = SharedMsg sharedMsg
    | PageMsg pageMsg
    | UrlRequest UrlRequest
    | UrlChange Url


mapPreviousMsg : Msg sharedMsg previous -> Msg sharedMsg (PageMsg current previous)
mapPreviousMsg msg =
    case msg of
        SharedMsg sharedMsg ->
            SharedMsg sharedMsg

        PageMsg previousMsg ->
            PageMsg <| PreviousMsg previousMsg

        UrlRequest request ->
            UrlRequest request

        UrlChange url ->
            UrlChange url


{-| map a shared message to top-level application message

Useful to put shared msg events in the 'toDocument' function

-}
mapSharedMsg : sharedMsg -> Msg sharedMsg pageMsg
mapSharedMsg =
    SharedMsg


{-| A page definition

See package Spa.Page for constructors

-}
type alias Page flags sharedMsg view model msg =
    Internal.Page flags sharedMsg view model msg


type PageSetup flags identity shared sharedMsg view model msg
    = PublicPage (shared -> Page flags sharedMsg view model msg)
    | ProtectedPage (shared -> identity -> Page flags sharedMsg view model msg)


type alias CoreModel route shared =
    { key : Nav.Key
    , currentRoute : route
    , shared : shared
    }


{-| The application model
-}
type Model route shared current previous
    = Model ( CoreModel route shared, PageModel current previous )


type alias NoPageModel route shared =
    Model route shared () ()


modelPrevious : Model route shared current (PageModel previous previous2) -> Model route shared previous previous2
modelPrevious (Model ( core, page )) =
    Model ( core, previousPageModel page )


modelShared : Model route shared current previous -> shared
modelShared (Model ( core, _ )) =
    core.shared


initModel : route -> Nav.Key -> shared -> NoPageModel route shared
initModel route key shared =
    Model
        ( { key = key
          , currentRoute = route
          , shared = shared
          }
        , NoPage
        )


{-| Intermediate type for building an application
-}
type Builder flags route identity shared sharedMsg view current previous pageMsg
    = Builder
        { init : flags -> Url -> Nav.Key -> ( Model route shared current previous, Cmd (Msg sharedMsg pageMsg) )
        , view : Model route shared current previous -> view
        , update : Msg sharedMsg pageMsg -> Model route shared current previous -> ( Model route shared current previous, Cmd (Msg sharedMsg pageMsg) )
        , subscriptions : Model route shared current previous -> Sub (Msg sharedMsg pageMsg)
        , toRoute : Url -> route
        , extractIdentity : shared -> Maybe identity
        , protectPage : route -> String
        }


{-| Bootstrap a Spa application

    Spa.init
        { init = Shared.init
        , subscriptions = Shared.subscriptions
        , update = Shared.update
        , defaultView = View.defaultView
        , toRoute = Route.toRoute
        , extractIdentity = Shared.identity
        , protectPage = Route.toUrl >> Just >> Route.SignIn >> Route.toUrl
        }

-}
init :
    { init : flags -> Nav.Key -> ( shared, Cmd sharedMsg )
    , subscriptions : shared -> Sub sharedMsg
    , update : sharedMsg -> shared -> ( shared, Cmd sharedMsg )
    , defaultView : view
    , toRoute : Url -> route
    , extractIdentity : shared -> Maybe identity
    , protectPage : route -> String
    }
    -> Builder flags route identity shared sharedMsg view () () ()
init shared =
    Builder
        { init = builderInit shared.toRoute shared.init
        , subscriptions = \(Model ( core, _ )) -> shared.subscriptions core.shared |> Sub.map SharedMsg
        , update = builderRootUpdate shared.toRoute shared.update
        , view =
            always shared.defaultView
        , toRoute = shared.toRoute
        , extractIdentity = shared.extractIdentity
        , protectPage = shared.protectPage
        }


{-| Bootstrap a Spa application that has no Shared state
-}
initNoShared : (Url -> route) -> view -> Builder () route () () () view () () ()
initNoShared toRoute defaultView =
    init
        { init = \_ _ -> ( (), Cmd.none )
        , subscriptions = always Sub.none
        , update = \_ _ -> ( (), Cmd.none )
        , defaultView = defaultView
        , toRoute = toRoute
        , extractIdentity = always Nothing
        , protectPage = always "/"
        }


builderInit :
    (Url -> route)
    -> (flags -> Nav.Key -> ( shared, Cmd sharedMsg ))
    -> flags
    -> Url
    -> Nav.Key
    -> ( Model route shared () (), Cmd (Msg sharedMsg ()) )
builderInit toRoute sharedInit flags url key =
    let
        ( shared, sharedCmd ) =
            sharedInit flags key
    in
    ( initModel (toRoute url) key shared, Cmd.map SharedMsg sharedCmd )


builderRootUpdate :
    (Url -> route)
    -> (sharedMsg -> shared -> ( shared, Cmd sharedMsg ))
    -> Msg sharedMsg ()
    -> Model route shared () ()
    -> ( Model route shared () (), Cmd (Msg sharedMsg ()) )
builderRootUpdate toRoute sharedUpdate msg (Model ( core, page )) =
    case msg of
        SharedMsg sharedMsg ->
            let
                ( sharedNew, sharedCmd ) =
                    sharedUpdate sharedMsg core.shared
            in
            ( Model ( { core | shared = sharedNew }, page ), Cmd.map SharedMsg sharedCmd )

        UrlChange url ->
            ( Model ( { core | currentRoute = toRoute url }, NoPage ), Cmd.none )

        _ ->
            -- XXX: This is an unexpected situation. We may want to report this
            -- somehow
            ( Model ( core, page ), Cmd.none )


setupPage :
    (shared -> Maybe identity)
    -> shared
    -> PageSetup pageFlags identity shared sharedMsg pageView currentPageModel currentPageMsg
    -> Maybe (PageDefinition pageFlags sharedMsg pageView currentPageModel currentPageMsg)
setupPage extractIdentity shared page =
    case page of
        PublicPage setup ->
            Just <| Internal.pageDefinition <| setup shared

        ProtectedPage setup ->
            extractIdentity shared
                |> Maybe.map (setup shared >> Internal.pageDefinition)


{-| Add a public page to the application
-}
addPublicPage :
    ( (currentPageMsg -> Msg sharedMsg (PageMsg currentPageMsg previousPageMsg)) -> pageView -> view
    , (Msg sharedMsg previousPageMsg -> Msg sharedMsg (PageMsg currentPageMsg previousPageMsg)) -> previousView -> view
    )
    -> (route -> Maybe pageFlags)
    -> (shared -> Page pageFlags sharedMsg pageView currentPageModel currentPageMsg)
    -> Builder flags route identity shared sharedMsg previousView prev prevprev previousPageMsg
    -> Builder flags route identity shared sharedMsg view currentPageModel (PageModel prev prevprev) (PageMsg currentPageMsg previousPageMsg)
addPublicPage mappers matchRoute page =
    addPage mappers matchRoute (PublicPage page)


{-| Add a protected page to the application
-}
addProtectedPage :
    ( (currentPageMsg -> Msg sharedMsg (PageMsg currentPageMsg previousPageMsg)) -> pageView -> view
    , (Msg sharedMsg previousPageMsg -> Msg sharedMsg (PageMsg currentPageMsg previousPageMsg)) -> previousView -> view
    )
    -> (route -> Maybe pageFlags)
    -> (shared -> identity -> Page pageFlags sharedMsg pageView currentPageModel currentPageMsg)
    -> Builder flags route identity shared sharedMsg previousView prev prevprev previousPageMsg
    -> Builder flags route identity shared sharedMsg view currentPageModel (PageModel prev prevprev) (PageMsg currentPageMsg previousPageMsg)
addProtectedPage mappers matchRoute page =
    addPage mappers matchRoute (ProtectedPage page)


addPage :
    ( (currentPageMsg -> Msg sharedMsg (PageMsg currentPageMsg previousPageMsg)) -> pageView -> view
    , (Msg sharedMsg previousPageMsg -> Msg sharedMsg (PageMsg currentPageMsg previousPageMsg)) -> previousView -> view
    )
    -> (route -> Maybe pageFlags)
    -> PageSetup pageFlags identity shared sharedMsg pageView currentPageModel currentPageMsg
    -> Builder flags route identity shared sharedMsg previousView prev prevprev previousPageMsg
    -> Builder flags route identity shared sharedMsg view currentPageModel (PageModel prev prevprev) (PageMsg currentPageMsg previousPageMsg)
addPage ( viewMap1, viewMap2 ) matchRoute page (Builder builder) =
    let
        setupCurrentPage :
            ( Model route shared current previous, Cmd (Msg sharedMsg previousPageMsg) )
            ->
                ( Model route shared currentPageModel (PageModel current previous)
                , Cmd (Msg sharedMsg (PageMsg currentPageMsg previousPageMsg))
                )
        setupCurrentPage ( Model ( core, currentPage ), previousCmd ) =
            let
                ( pageModel, cmd ) =
                    case currentPage of
                        NoPage ->
                            case core.currentRoute |> matchRoute of
                                Just pageFlags ->
                                    case setupPage builder.extractIdentity core.shared page of
                                        Just setup ->
                                            let
                                                ( newCurrentPage, newCurrentPageEffect ) =
                                                    setup.init pageFlags
                                            in
                                            ( Current newCurrentPage
                                            , newCurrentPageEffect
                                                |> Effect.toCmd ( SharedMsg, CurrentMsg >> PageMsg )
                                            )

                                        Nothing ->
                                            ( NoPage, Nav.replaceUrl core.key (builder.protectPage core.currentRoute) )

                                Nothing ->
                                    ( NoPage, Cmd.none )

                        prevPage ->
                            ( Previous prevPage, Cmd.none )
            in
            ( Model ( core, pageModel )
            , Cmd.batch
                [ previousCmd
                    |> Cmd.map mapPreviousMsg
                , cmd
                ]
            )
    in
    Builder
        { toRoute = builder.toRoute
        , extractIdentity = builder.extractIdentity
        , protectPage = builder.protectPage
        , init =
            \flags url key ->
                builder.init flags url key
                    |> setupCurrentPage
        , subscriptions =
            \(Model ( core, currentPage )) ->
                Sub.batch
                    [ case currentPage of
                        Current current ->
                            case setupPage builder.extractIdentity core.shared page of
                                Just setup ->
                                    setup.subscriptions current
                                        |> Sub.map (CurrentMsg >> PageMsg)

                                Nothing ->
                                    Sub.none

                        _ ->
                            Sub.none
                    , builder.subscriptions (modelPrevious (Model ( core, currentPage )))
                        |> Sub.map mapPreviousMsg
                    ]
        , update =
            \msg (Model ( core, currentPage )) ->
                case msg of
                    PageMsg (CurrentMsg pageMsg) ->
                        case currentPageModel currentPage of
                            Just pageModel ->
                                case setupPage builder.extractIdentity core.shared page of
                                    Just setup ->
                                        let
                                            ( pageModelNew, pageEffect ) =
                                                setup.update pageMsg pageModel
                                        in
                                        ( Model ( core, Current pageModelNew )
                                        , Effect.toCmd ( SharedMsg, CurrentMsg >> PageMsg ) pageEffect
                                        )

                                    Nothing ->
                                        ( Model ( core, NoPage )
                                        , Nav.replaceUrl core.key
                                            (builder.protectPage core.currentRoute)
                                        )

                            Nothing ->
                                ( Model ( core, currentPage ), Cmd.none )

                    PageMsg (PreviousMsg pageMsg) ->
                        let
                            ( Model ( _, previousPage ), previousCmd ) =
                                builder.update (PageMsg pageMsg) (modelPrevious (Model ( core, currentPage )))
                        in
                        ( Model ( core, Previous previousPage )
                        , previousCmd |> Cmd.map mapPreviousMsg
                        )

                    SharedMsg sharedMsg ->
                        let
                            ( Model ( previousCore, previousPage ), previousCmd ) =
                                builder.update (SharedMsg sharedMsg) (modelPrevious (Model ( core, currentPage )))

                            ( newPage, newPageEffect ) =
                                case ( previousPage, currentPage ) of
                                    ( NoPage, Current _ ) ->
                                        case setupPage builder.extractIdentity previousCore.shared page of
                                            Just _ ->
                                                -- the page is still accessible
                                                ( currentPage, Cmd.none )

                                            Nothing ->
                                                ( NoPage, Nav.replaceUrl core.key (builder.protectPage core.currentRoute) )

                                    ( NoPage, _ ) ->
                                        ( NoPage, Cmd.none )

                                    ( previous, _ ) ->
                                        ( Previous previous, Cmd.none )
                        in
                        ( Model
                            ( { previousCore
                                | currentRoute = core.currentRoute
                              }
                            , newPage
                            )
                        , Cmd.batch
                            [ previousCmd |> Cmd.map mapPreviousMsg
                            , newPageEffect |> Cmd.map (CurrentMsg >> PageMsg)
                            ]
                        )

                    UrlRequest urlRequest ->
                        case urlRequest of
                            Browser.Internal url ->
                                ( Model ( core, currentPage )
                                , Nav.pushUrl core.key (Url.toString url)
                                )

                            Browser.External url ->
                                ( Model ( core, currentPage )
                                , Nav.load url
                                )

                    UrlChange url ->
                        builder.update (UrlChange url) (modelPrevious (Model ( core, currentPage )))
                            |> setupCurrentPage
        , view =
            \(Model ( core, currentPage )) ->
                case currentPage of
                    Current pageModel ->
                        case setupPage builder.extractIdentity core.shared page of
                            Just setup ->
                                setup.view pageModel
                                    |> viewMap1 (CurrentMsg >> PageMsg)

                            Nothing ->
                                builder.view (modelPrevious (Model ( core, currentPage )))
                                    |> viewMap2 mapPreviousMsg

                    _ ->
                        builder.view (modelPrevious (Model ( core, currentPage )))
                            |> viewMap2 mapPreviousMsg
        }


{-| Finalize the Spa application into a record suitable for the `Browser.application`

`toDocument` is a function that convert a view to a `Browser.Document`

    appWithPages
        |> Spa.application { toDocument = View.toDocument }
        |> Browser.application

-}
application :
    { toDocument : shared -> view -> Document (Msg sharedMsg pageMsg) }
    -> Builder flags route identity shared sharedMsg view current previous pageMsg
    ->
        { init : flags -> Url -> Nav.Key -> ( Model route shared current previous, Cmd (Msg sharedMsg pageMsg) )
        , view : Model route shared current previous -> Document (Msg sharedMsg pageMsg)
        , update : Msg sharedMsg pageMsg -> Model route shared current previous -> ( Model route shared current previous, Cmd (Msg sharedMsg pageMsg) )
        , subscriptions : Model route shared current previous -> Sub (Msg sharedMsg pageMsg)
        , onUrlRequest : UrlRequest -> Msg sharedMsg pageMsg
        , onUrlChange : Url -> Msg sharedMsg pageMsg
        }
application { toDocument } (Builder builder) =
    { init = builder.init
    , view = \model -> builder.view model |> toDocument (modelShared model)
    , update = builder.update
    , subscriptions = builder.subscriptions
    , onUrlRequest = UrlRequest
    , onUrlChange = UrlChange
    }
