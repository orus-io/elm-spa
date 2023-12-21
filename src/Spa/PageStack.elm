module Spa.PageStack exposing
    ( Stack, setup, add
    , Msg, Model, empty, getError, routeChange
    , PageSetup, RouteMatcher, CurrentViewMap, PreviousViewMap
    )

{-| This module provides the tools to combine multiple pages into a single TEA
component.

It can be used separately from Spa, in case it doesn't handle the complexity of
your application (and if it's the case I am interested to know about it!).

Another use case is to progressively port a hand-written application to Spa, by
embedding a PageStack in the existing application, then port pages to it one by
one. Once all the pages are in the stack, the main application can be ported to
Spa.

@docs Stack, setup, add

@docs Msg, Model, empty, getError, routeChange

@docs PageSetup, RouteMatcher, CurrentViewMap, PreviousViewMap

-}

import Effect exposing (Effect)
import Spa.Internal as Internal
import Spa.Page exposing (Page)


{-| The Stack model
-}
type Model setupError current previous
    = NoPage
    | Current current
    | Previous previous
    | SetupError setupError


getPrevious : Model setupError current (Model setupError prev ante) -> Model setupError prev ante
getPrevious model =
    case model of
        NoPage ->
            NoPage

        Current _ ->
            NoPage

        SetupError err ->
            SetupError err

        Previous previous ->
            previous


{-| The Stack Msg type
-}
type Msg route current previous
    = CurrentMsg current
    | PreviousMsg previous
    | RouteChange route


{-| Build a message that signal a route change to the page stack
-}
routeChange : route -> Msg route current previous
routeChange =
    RouteChange


{-| A Stack combines pages into a single TEA component
-}
type alias Stack setupError shared sharedMsg route view current previous currentMsg previousMsg =
    { init : shared -> route -> ( Model setupError current previous, Effect sharedMsg (Msg route currentMsg previousMsg) )
    , update : shared -> Msg route currentMsg previousMsg -> Model setupError current previous -> ( Model setupError current previous, Effect sharedMsg (Msg route currentMsg previousMsg) )
    , subscriptions : shared -> Model setupError current previous -> Sub (Msg route currentMsg previousMsg)
    , view : shared -> Model setupError current previous -> view
    }


{-| A page setup returns the page definition given the share current state

It can fail with a custom error

-}
type alias PageSetup setupError flags shared sharedMsg view model msg =
    shared -> Result setupError (Page flags sharedMsg view model msg)


{-| A route matcher is provided for each page. If it matches the route of its
page, it returns the flags that will be passed to the page 'init' function
-}
type alias RouteMatcher route flags =
    route -> Maybe flags


{-| An empty model for initialising a stack state
-}
empty : Model setupError a b
empty =
    NoPage


{-| returns the current setup error if any
-}
getError : Model setupError current previous -> Maybe setupError
getError model =
    case model of
        SetupError err ->
            Just err

        _ ->
            Nothing


mapPrevious : Model setupError pa pb -> Model setupError a (Model setupError pa pb)
mapPrevious m =
    case m of
        NoPage ->
            NoPage

        SetupError err ->
            SetupError err

        _ ->
            Previous m


{-| Setup a new stack

The defaultView is used when no other view can be applied, which should never
happen if the application is properly defined.

-}
setup :
    { defaultView : shared -> view }
    -> Stack setupError shared sharedMsg route view () () () ()
setup { defaultView } =
    { init = \_ _ -> ( NoPage, Effect.none )
    , update = \_ _ _ -> ( NoPage, Effect.none )
    , view = \shared _ -> defaultView shared
    , subscriptions = \_ _ -> Sub.none
    }


{-| A view mapper, for example Html.map or Element.map depending on your actual
view type.
-}
type alias CurrentViewMap route currentMsg previousMsg pageView view =
    (currentMsg -> Msg route currentMsg previousMsg) -> pageView -> view


{-| A view mapper, for example Html.map or Element.map depending on your actual
view type.
-}
type alias PreviousViewMap route currentMsg previousMsg previousView view =
    (previousMsg -> Msg route currentMsg previousMsg) -> previousView -> view


{-| Add a page to a Stack
-}
add :
    ( CurrentViewMap route currentMsg previousMsg pageView view
    , PreviousViewMap route currentMsg previousMsg previousView view
    )
    -> RouteMatcher route flags
    -> PageSetup setupError flags shared sharedMsg pageView pageModel pageMsg
    -> Stack setupError shared sharedMsg route previousView previousCurrent previousPrevious previousCurrentMsg previousPreviousMsg
    -> Stack setupError shared sharedMsg route view pageModel (Model setupError previousCurrent previousPrevious) pageMsg (Msg route previousCurrentMsg previousPreviousMsg)
add ( mapPageView, mapPreviousView ) match pagesetup previousStack =
    { init =
        \shared route ->
            case match route of
                Just flags ->
                    case pagesetup shared of
                        Ok (Internal.Page page) ->
                            let
                                ( pageModel, pageEffect ) =
                                    page.init flags
                            in
                            ( Current pageModel
                            , Effect.map CurrentMsg pageEffect
                            )

                        Err err ->
                            ( SetupError err, Effect.none )

                Nothing ->
                    let
                        ( prevModel, prevEffect ) =
                            previousStack.init shared route
                    in
                    ( mapPrevious prevModel
                    , Effect.map PreviousMsg prevEffect
                    )
    , update =
        \shared msg model ->
            case ( msg, model ) of
                ( RouteChange route, _ ) ->
                    case match route of
                        Just flags ->
                            case pagesetup shared of
                                Ok (Internal.Page page) ->
                                    case ( page.onNewFlags, model ) of
                                        ( Just tomsg, Current pageModel ) ->
                                            -- we already are on the right page, and it has
                                            -- a 'onNewFlags' message
                                            let
                                                ( newPageModel, pageEffect ) =
                                                    page.update (tomsg flags) pageModel
                                            in
                                            ( Current newPageModel
                                            , Effect.map CurrentMsg pageEffect
                                            )

                                        _ ->
                                            let
                                                ( pageModel, pageEffect ) =
                                                    page.init flags
                                            in
                                            ( Current pageModel
                                            , Effect.map CurrentMsg pageEffect
                                            )

                                Err err ->
                                    ( SetupError err, Effect.none )

                        Nothing ->
                            -- current page doesn't match, let lower layers find the new one
                            let
                                ( newPreviousModel, previousEffect ) =
                                    previousStack.update shared (RouteChange route) (getPrevious model)
                            in
                            ( mapPrevious newPreviousModel, Effect.map PreviousMsg previousEffect )

                ( CurrentMsg pageMsg, Current pageModel ) ->
                    case pagesetup shared of
                        Ok (Internal.Page page) ->
                            let
                                ( newPageModel, newPageEffect ) =
                                    page.update pageMsg pageModel
                            in
                            ( Current newPageModel, Effect.map CurrentMsg newPageEffect )

                        Err err ->
                            ( SetupError err, Effect.none )

                ( PreviousMsg previousMsg, Previous previousModel ) ->
                    let
                        ( newPreviousModel, previousEffect ) =
                            previousStack.update shared previousMsg previousModel
                    in
                    ( mapPrevious newPreviousModel, Effect.map PreviousMsg previousEffect )

                ( _, NoPage ) ->
                    ( model, Effect.none )

                ( CurrentMsg _, _ ) ->
                    ( model, Effect.none )

                ( PreviousMsg _, _ ) ->
                    ( model, Effect.none )
    , subscriptions =
        \shared model ->
            case model of
                NoPage ->
                    Sub.none

                SetupError _ ->
                    Sub.none

                Current pageModel ->
                    case pagesetup shared of
                        Ok (Internal.Page page) ->
                            page.subscriptions pageModel
                                |> Sub.map CurrentMsg

                        Err _ ->
                            Sub.none

                Previous prevModel ->
                    previousStack.subscriptions shared prevModel
                        |> Sub.map PreviousMsg
    , view =
        \shared model ->
            case model of
                Current pageModel ->
                    case pagesetup shared of
                        Ok (Internal.Page page) ->
                            page.view pageModel
                                |> mapPageView CurrentMsg

                        Err _ ->
                            previousStack.view shared NoPage
                                |> mapPreviousView PreviousMsg

                Previous previousModel ->
                    previousStack.view shared previousModel
                        |> mapPreviousView PreviousMsg

                NoPage ->
                    previousStack.view shared NoPage
                        |> mapPreviousView PreviousMsg

                SetupError _ ->
                    previousStack.view shared NoPage
                        |> mapPreviousView PreviousMsg
    }
