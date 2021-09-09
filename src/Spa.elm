module Spa exposing (..)

import Browser exposing (Document, UrlRequest)
import Browser.Navigation as Nav
import Effect exposing (Effect)
import Html
import Url exposing (Url)
import Url.Parser exposing ((</>), Parser)


type PageMsg current previous
    = CurrentMsg current
    | PreviousMsg previous


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
    { init : flags -> ( model, Effect sharedMsg msg )
    , update : msg -> model -> ( model, Effect sharedMsg msg )
    , subscriptions : model -> Sub msg
    , view : model -> view
    }


type alias PageSetup flags shared sharedMsg view model msg =
    shared -> Page flags sharedMsg view model msg


type alias Model shared current previous =
    { key : Nav.Key
    , shared : shared
    , page : PageModel current previous
    }


modelPrevious : Model shared current (PageModel previous previous2) -> Model shared previous previous2
modelPrevious model =
    { key = model.key
    , shared = model.shared
    , page = previousPageModel model.page
    }


type alias NoPageModel shared =
    Model shared () ()


initModel : Nav.Key -> shared -> NoPageModel shared
initModel key shared =
    { key = key
    , shared = shared
    , page = NoPage
    }


type alias Builder flags route shared sharedMsg view current previous pageMsg =
    { init : flags -> Url -> Nav.Key -> ( Model shared current previous, Cmd (Msg sharedMsg pageMsg) )
    , view : Model shared current previous -> view
    , update : Msg sharedMsg pageMsg -> Model shared current previous -> ( Model shared current previous, Cmd (Msg sharedMsg pageMsg) )
    , subscriptions : Model shared current previous -> Sub (Msg sharedMsg pageMsg)
    , toRoute : Url -> route
    }


init :
    { init : flags -> ( shared, Cmd sharedMsg )
    , subscriptions : shared -> Sub sharedMsg
    , update : sharedMsg -> shared -> ( shared, Cmd sharedMsg )
    , defaultView : view
    , toRoute : Url -> route
    }
    -> Builder flags route shared sharedMsg view () () ()
init shared =
    { init = builderInit shared.init
    , subscriptions = always Sub.none
    , update = builderRootUpdate shared.update
    , view =
        always shared.defaultView
    , toRoute = shared.toRoute
    }


initNoShared : (Url -> route) -> view -> Builder () route () () view () () ()
initNoShared toRoute defaultView =
    init
        { init = always ( (), Cmd.none )
        , subscriptions = always Sub.none
        , update = \_ _ -> ( (), Cmd.none )
        , defaultView = defaultView
        , toRoute = toRoute
        }


builderInit :
    (flags -> ( shared, Cmd sharedMsg ))
    -> flags
    -> Url
    -> Nav.Key
    -> ( Model shared () (), Cmd (Msg sharedMsg ()) )
builderInit sharedInit flags url key =
    let
        ( shared, sharedCmd ) =
            sharedInit flags
    in
    ( initModel key shared, Cmd.map SharedMsg sharedCmd )


builderRootUpdate :
    (sharedMsg -> shared -> ( shared, Cmd sharedMsg ))
    -> Msg sharedMsg ()
    -> Model shared () ()
    -> ( Model shared () (), Cmd (Msg sharedMsg ()) )
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


addPage :
    ( (currentPageMsg -> Msg sharedMsg (PageMsg currentPageMsg previousPageMsg)) -> pageView -> view
    , (Msg sharedMsg previousPageMsg -> Msg sharedMsg (PageMsg currentPageMsg previousPageMsg)) -> previousView -> view
    )
    -> (route -> Maybe pageFlags)
    -> PageSetup pageFlags shared sharedMsg pageView currentPageModel currentPageMsg
    -> Builder flags route shared sharedMsg previousView prev prevprev previousPageMsg
    -> Builder flags route shared sharedMsg view currentPageModel (PageModel prev prevprev) (PageMsg currentPageMsg previousPageMsg)
addPage ( viewMap1, viewMap2 ) matchRoute page builder =
    { toRoute = builder.toRoute
    , init =
        \flags url key ->
            let
                ( model, previousCmd ) =
                    builder.init flags url key

                ( pageModel, cmd ) =
                    case model.page of
                        NoPage ->
                            case builder.toRoute url |> matchRoute of
                                Just pageFlags ->
                                    let
                                        ( currentPage, currentPageEffect ) =
                                            (page model.shared).init pageFlags
                                    in
                                    ( Current currentPage
                                    , currentPageEffect
                                        |> Effect.toCmd ( SharedMsg, CurrentMsg >> PageMsg )
                                    )

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
                Current current ->
                    (page model.shared).subscriptions current
                        |> Sub.map (CurrentMsg >> PageMsg)

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
                        Just pageModel ->
                            let
                                ( pageModelNew, pageEffect ) =
                                    (page model.shared).update pageMsg pageModel
                            in
                            ( { model
                                | page = Current pageModelNew
                              }
                            , Effect.toCmd ( SharedMsg, CurrentMsg >> PageMsg ) pageEffect
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
                    {- ( { key = modelPreviousNew.key
                         , shared = modelPreviousNew.shared
                         , page = Previous modelPreviousNew.page
                         }
                       , previousCmd |> Cmd.map PreviousMsg
                       )
                    -}
                    ( model, Cmd.none )

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
                                    case builder.toRoute url |> matchRoute of
                                        Just pageFlags ->
                                            let
                                                ( currentPage, currentPageEffect ) =
                                                    (page model.shared).init pageFlags
                                            in
                                            ( Current currentPage
                                            , currentPageEffect
                                                |> Effect.toCmd ( SharedMsg, CurrentMsg >> PageMsg )
                                            )

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
                Current pageModel ->
                    (page model.shared).view pageModel
                        |> viewMap1 (CurrentMsg >> PageMsg)

                _ ->
                    builder.view (modelPrevious model)
                        |> viewMap2 mapPreviousMsg
    }


application :
    { toDocument : view -> Document (Msg sharedMsg pageMsg) }
    -> Builder flags route shared sharedMsg view current previous pageMsg
    ->
        { init : flags -> Url -> Nav.Key -> ( Model shared current previous, Cmd (Msg sharedMsg pageMsg) )
        , view : Model shared current previous -> Document (Msg sharedMsg pageMsg)
        , update : Msg sharedMsg pageMsg -> Model shared current previous -> ( Model shared current previous, Cmd (Msg sharedMsg pageMsg) )
        , subscriptions : Model shared current previous -> Sub (Msg sharedMsg pageMsg)
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
