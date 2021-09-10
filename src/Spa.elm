module Spa exposing
    ( init
    , addPublicPage
    , application
    , addProtectedPage
    )

{-|


# Create the application

@docs init


# Add pages

@docs addPublicPage, addProtectedPage`


# Finalize

Once all the pages are added to the application, we can change it into a record
suitable for the `Browser.application` function.

@docs application

-}

import Browser exposing (Document, UrlRequest)
import Browser.Navigation as Nav
import Effect exposing (Effect)
import Html
import Internal exposing (PageDefinition)
import Url exposing (Url)
import Url.Parser exposing ((</>), Parser)


type PageMsg current previous
    = CurrentMsg current
    | PreviousMsg previous


type PageModel route current previous
    = NoPage
    | Current route current
    | Previous previous


previousPageModel :
    PageModel route current (PageModel route previous previous2)
    -> PageModel route previous previous2
previousPageModel page =
    case page of
        Previous previous ->
            previous

        Current _ _ ->
            NoPage

        NoPage ->
            NoPage


currentPageModel : PageModel route current previous -> Maybe ( route, current )
currentPageModel page =
    case page of
        Current route model ->
            Just ( route, model )

        _ ->
            Nothing


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


type alias Page flags sharedMsg view model msg =
    Internal.Page flags sharedMsg view model msg


type PageSetup flags identity shared sharedMsg view model msg
    = PublicPage (shared -> Page flags sharedMsg view model msg)
    | ProtectedPage (shared -> identity -> Page flags sharedMsg view model msg)


type alias Model route shared current previous =
    { key : Nav.Key
    , shared : shared
    , page : PageModel route current previous
    }


modelPrevious : Model route shared current (PageModel route previous previous2) -> Model route shared previous previous2
modelPrevious model =
    { key = model.key
    , shared = model.shared
    , page = previousPageModel model.page
    }


type alias NoPageModel route shared =
    Model route shared () ()


initModel : Nav.Key -> shared -> NoPageModel route shared
initModel key shared =
    { key = key
    , shared = shared
    , page = NoPage
    }


type alias Builder flags route identity shared sharedMsg view current previous pageMsg =
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
    { init : Nav.Key -> flags -> ( shared, Cmd sharedMsg )
    , subscriptions : shared -> Sub sharedMsg
    , update : sharedMsg -> shared -> ( shared, Cmd sharedMsg )
    , defaultView : view
    , toRoute : Url -> route
    , extractIdentity : shared -> Maybe identity
    , protectPage : route -> String
    }
    -> Builder flags route identity shared sharedMsg view () () ()
init shared =
    { init = builderInit shared.init
    , subscriptions = always Sub.none
    , update = builderRootUpdate shared.update
    , view =
        always shared.defaultView
    , toRoute = shared.toRoute
    , extractIdentity = shared.extractIdentity
    , protectPage = shared.protectPage
    }


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
    (Nav.Key -> flags -> ( shared, Cmd sharedMsg ))
    -> flags
    -> Url
    -> Nav.Key
    -> ( Model route shared () (), Cmd (Msg sharedMsg ()) )
builderInit sharedInit flags url key =
    let
        ( shared, sharedCmd ) =
            sharedInit key flags
    in
    ( initModel key shared, Cmd.map SharedMsg sharedCmd )


builderRootUpdate :
    (sharedMsg -> shared -> ( shared, Cmd sharedMsg ))
    -> Msg sharedMsg ()
    -> Model route shared () ()
    -> ( Model route shared () (), Cmd (Msg sharedMsg ()) )
builderRootUpdate sharedUpdate msg model =
    case msg of
        SharedMsg sharedMsg ->
            let
                ( sharedNew, sharedCmd ) =
                    sharedUpdate sharedMsg model.shared
            in
            ( { model | shared = sharedNew }, Cmd.map SharedMsg sharedCmd )

        UrlChange url ->
            ( { model | page = NoPage }, Cmd.none )

        _ ->
            -- XXX: This is an unexpected situation. We may want to report this
            -- somehow
            ( model, Cmd.none )


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
    -> Builder flags route identity shared sharedMsg view currentPageModel (PageModel route prev prevprev) (PageMsg currentPageMsg previousPageMsg)
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
    -> Builder flags route identity shared sharedMsg view currentPageModel (PageModel route prev prevprev) (PageMsg currentPageMsg previousPageMsg)
addProtectedPage mappers matchRoute page =
    addPage mappers matchRoute (ProtectedPage page)


addPage :
    ( (currentPageMsg -> Msg sharedMsg (PageMsg currentPageMsg previousPageMsg)) -> pageView -> view
    , (Msg sharedMsg previousPageMsg -> Msg sharedMsg (PageMsg currentPageMsg previousPageMsg)) -> previousView -> view
    )
    -> (route -> Maybe pageFlags)
    -> PageSetup pageFlags identity shared sharedMsg pageView currentPageModel currentPageMsg
    -> Builder flags route identity shared sharedMsg previousView prev prevprev previousPageMsg
    -> Builder flags route identity shared sharedMsg view currentPageModel (PageModel route prev prevprev) (PageMsg currentPageMsg previousPageMsg)
addPage ( viewMap1, viewMap2 ) matchRoute page builder =
    { toRoute = builder.toRoute
    , extractIdentity = builder.extractIdentity
    , protectPage = builder.protectPage
    , init =
        \flags url key ->
            let
                ( model, previousCmd ) =
                    builder.init flags url key

                ( pageModel, cmd ) =
                    case model.page of
                        NoPage ->
                            let
                                route =
                                    builder.toRoute url
                            in
                            case route |> matchRoute of
                                Just pageFlags ->
                                    case setupPage builder.extractIdentity model.shared page of
                                        Just setup ->
                                            let
                                                ( currentPage, currentPageEffect ) =
                                                    setup.init pageFlags
                                            in
                                            ( Current route currentPage
                                            , currentPageEffect
                                                |> Effect.toCmd ( SharedMsg, CurrentMsg >> PageMsg )
                                            )

                                        Nothing ->
                                            ( NoPage, Nav.replaceUrl key (builder.protectPage route) )

                                Nothing ->
                                    ( NoPage, Cmd.none )

                        prevPage ->
                            ( Previous prevPage, Cmd.none )
            in
            ( { key = model.key
              , shared = model.shared
              , page = pageModel
              }
            , Cmd.batch
                [ previousCmd
                    |> Cmd.map mapPreviousMsg
                , cmd
                ]
            )
    , subscriptions =
        \model ->
            case model.page of
                Current _ current ->
                    case setupPage builder.extractIdentity model.shared page of
                        Just setup ->
                            setup.subscriptions current
                                |> Sub.map (CurrentMsg >> PageMsg)

                        Nothing ->
                            Sub.none

                Previous previous ->
                    builder.subscriptions (modelPrevious model)
                        |> Sub.map mapPreviousMsg

                NoPage ->
                    Sub.none
    , update =
        \msg model ->
            case msg of
                PageMsg (CurrentMsg pageMsg) ->
                    case currentPageModel model.page of
                        Just ( pageRoute, pageModel ) ->
                            case setupPage builder.extractIdentity model.shared page of
                                Just setup ->
                                    let
                                        ( pageModelNew, pageEffect ) =
                                            setup.update pageMsg pageModel
                                    in
                                    ( { model
                                        | page = Current pageRoute pageModelNew
                                      }
                                    , Effect.toCmd ( SharedMsg, CurrentMsg >> PageMsg ) pageEffect
                                    )

                                Nothing ->
                                    ( { model | page = NoPage }
                                    , Nav.replaceUrl model.key (builder.protectPage pageRoute)
                                    )

                        Nothing ->
                            ( model, Cmd.none )

                PageMsg (PreviousMsg pageMsg) ->
                    let
                        ( previousModel, previousCmd ) =
                            builder.update (PageMsg pageMsg) (modelPrevious model)
                    in
                    ( { model
                        | page = Previous previousModel.page
                      }
                    , previousCmd |> Cmd.map mapPreviousMsg
                    )

                SharedMsg sharedMsg ->
                    let
                        ( modelPreviousNew, previousCmd ) =
                            builder.update (SharedMsg sharedMsg) (modelPrevious model)
                    in
                    ( { key = modelPreviousNew.key
                      , shared = modelPreviousNew.shared
                      , page = Previous modelPreviousNew.page
                      }
                    , previousCmd |> Cmd.map mapPreviousMsg
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
                        ( previousModel, previousCmd ) =
                            builder.update (UrlChange url) (modelPrevious model)

                        ( pageModel, cmd ) =
                            case previousModel.page of
                                NoPage ->
                                    let
                                        route =
                                            builder.toRoute url
                                    in
                                    case route |> matchRoute of
                                        Just pageFlags ->
                                            case setupPage builder.extractIdentity model.shared page of
                                                Just setup ->
                                                    let
                                                        ( currentPage, currentPageEffect ) =
                                                            setup.init pageFlags
                                                    in
                                                    ( Current route currentPage
                                                    , currentPageEffect
                                                        |> Effect.toCmd ( SharedMsg, CurrentMsg >> PageMsg )
                                                    )

                                                Nothing ->
                                                    ( NoPage, Nav.replaceUrl model.key <| builder.protectPage route )

                                        Nothing ->
                                            ( NoPage, Cmd.none )

                                prevPage ->
                                    ( Previous prevPage
                                    , Cmd.none
                                    )
                    in
                    ( { key = model.key
                      , shared = model.shared
                      , page = pageModel
                      }
                    , Cmd.batch
                        [ previousCmd |> Cmd.map mapPreviousMsg
                        , cmd
                        ]
                    )
    , view =
        \model ->
            case model.page of
                Current route pageModel ->
                    case setupPage builder.extractIdentity model.shared page of
                        Just setup ->
                            setup.view pageModel
                                |> viewMap1 (CurrentMsg >> PageMsg)

                        Nothing ->
                            builder.view (modelPrevious model)
                                |> viewMap2 mapPreviousMsg

                _ ->
                    builder.view (modelPrevious model)
                        |> viewMap2 mapPreviousMsg
    }


{-| Finalize the Spa application into a record suitable for the `Browser.application`

`toDocument` is a function that convert a view to a `Browser.Document`

    appWithPages
        |> Spa.application { toDocument = View.toDocument }
        |> Browser.application

-}
application :
    { toDocument : view -> Document (Msg sharedMsg pageMsg) }
    -> Builder flags route identity shared sharedMsg view current previous pageMsg
    ->
        { init : flags -> Url -> Nav.Key -> ( Model route shared current previous, Cmd (Msg sharedMsg pageMsg) )
        , view : Model route shared current previous -> Document (Msg sharedMsg pageMsg)
        , update : Msg sharedMsg pageMsg -> Model route shared current previous -> ( Model route shared current previous, Cmd (Msg sharedMsg pageMsg) )
        , subscriptions : Model route shared current previous -> Sub (Msg sharedMsg pageMsg)
        , onUrlRequest : UrlRequest -> Msg sharedMsg pageMsg
        , onUrlChange : Url -> Msg sharedMsg pageMsg
        }
application { toDocument } builder =
    { init = builder.init
    , view = builder.view >> toDocument
    , update = builder.update
    , subscriptions = builder.subscriptions
    , onUrlRequest = UrlRequest
    , onUrlChange = UrlChange
    }
