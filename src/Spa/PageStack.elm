module Spa.PageStack exposing
    ( Stack, setup, add
    , Msg, Model, empty, getError
    , PageSetup, RouteMatcher, CurrentViewMap, PreviousViewMap
    )

{-|

@docs Stack, setup, add

@docs Msg, Model, empty, getError

@docs PageSetup, RouteMatcher, CurrentViewMap, PreviousViewMap

-}

import Effect exposing (Effect)
import Internal
import Spa.Page exposing (Page)


{-| The Stack model
-}
type Model setupError current previous
    = NoPage
    | Current current
    | Previous previous
    | SetupError setupError


{-| The Stack Msg type
-}
type Msg current previous
    = CurrentMsg current
    | PreviousMsg previous


{-| A Stack combines pages into a single TEA component
-}
type alias Stack setupError shared sharedMsg route view current previous msg =
    { init : shared -> route -> ( Model setupError current previous, Effect sharedMsg msg )
    , update : shared -> msg -> Model setupError current previous -> ( Model setupError current previous, Effect sharedMsg msg )
    , subscriptions : shared -> Model setupError current previous -> Sub msg
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
    { defaultView : view }
    -> Stack setupError shared sharedMsg route view () () ()
setup { defaultView } =
    { init = \_ _ -> ( NoPage, Effect.none )
    , update = \_ _ _ -> ( NoPage, Effect.none )
    , view = \_ _ -> defaultView
    , subscriptions = \_ _ -> Sub.none
    }


{-| A view mapper, for example Html.map or Element.map depending on your actual
view type.
-}
type alias CurrentViewMap currentMsg previousMsg pageView view =
    (currentMsg -> Msg currentMsg previousMsg) -> pageView -> view


{-| A view mapper, for example Html.map or Element.map depending on your actual
view type.
-}
type alias PreviousViewMap currentMsg previousMsg previousView view =
    (previousMsg -> Msg currentMsg previousMsg) -> previousView -> view


{-| Add a page on a Stack
-}
add :
    ( CurrentViewMap currentMsg previousMsg pageView view
    , PreviousViewMap currentMsg previousMsg previousView view
    )
    -> RouteMatcher route flags
    -> PageSetup setupError flags shared sharedMsg pageView pageModel pageMsg
    -> Stack setupError shared sharedMsg route previousView previousCurrent previousPrevious previousMsg
    -> Stack setupError shared sharedMsg route view pageModel (Model setupError previousCurrent previousPrevious) (Msg pageMsg previousMsg)
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
