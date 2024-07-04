module Loader exposing (Model, Msg, loader)

import Browser.Navigation as Nav
import Html
import Route exposing (Route)
import Shared
import Spa
import Task
import Time


type alias Model =
    { key : Nav.Key
    , currentRoute : Route
    }


type Msg
    = SetHereNow ( Time.Zone, Time.Posix )


loader =
    { init =
        \() route key ->
            Spa.Loading
                ( { key = key
                  , currentRoute = route
                  }
                , Task.map2 Tuple.pair Time.here Time.now
                    |> Task.perform SetHereNow
                )
    , subscriptions = always Sub.none
    , view =
        \model ->
            { title = "Loading"
            , body = [ Html.text "App is loading..." ]
            }
    , update =
        \msg model ->
            case msg of
                SetHereNow ( here, now ) ->
                    Spa.Loaded (Shared.init model.currentRoute model.key here now)
    }
