module Shared exposing
    ( Identity
    , Msg(..)
    , Shared
    , identity
    , init
    , pushRoute
    , replaceRoute
    , setIdentity
    , subscriptions
    , update
    )

import Browser.Navigation as Nav
import Route exposing (Route)
import Time


type alias Identity =
    String


type alias Shared =
    { key : Nav.Key
    , identity : Maybe Identity
    , currentRoute : Route
    , timezone : Time.Zone
    , appStartedAt : Time.Posix
    }


type Msg
    = SetIdentity Identity (Maybe String)
    | ResetIdentity
    | PushRoute Route
    | ReplaceRoute Route
    | RouteChange Route


identity : Shared -> Maybe Identity
identity =
    .identity


init : Route -> Nav.Key -> Time.Zone -> Time.Posix -> ( Shared, Cmd Msg )
init route key here now =
    ( { key = key
      , identity = Nothing
      , currentRoute = route
      , timezone = here
      , appStartedAt = now
      }
    , Cmd.none
    )


update : Msg -> Shared -> ( Shared, Cmd Msg )
update msg shared =
    case msg of
        SetIdentity newIdentity redirect ->
            ( { shared | identity = Just newIdentity }
            , redirect
                |> Maybe.map (Nav.replaceUrl shared.key)
                |> Maybe.withDefault Cmd.none
            )

        ResetIdentity ->
            ( { shared | identity = Nothing }, Cmd.none )

        PushRoute route ->
            ( shared, Nav.pushUrl shared.key <| Route.toUrl route )

        ReplaceRoute route ->
            ( shared, Nav.replaceUrl shared.key <| Route.toUrl route )

        RouteChange route ->
            ( { shared
                | currentRoute = route
              }
            , Cmd.none
            )


subscriptions : Shared -> Sub Msg
subscriptions =
    always Sub.none


setIdentity : String -> Maybe String -> Msg
setIdentity =
    SetIdentity


replaceRoute : Route -> Msg
replaceRoute =
    ReplaceRoute


pushRoute : Route -> Msg
pushRoute =
    ReplaceRoute
