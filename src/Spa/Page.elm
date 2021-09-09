module Spa.Page exposing (..)

import Effect exposing (Effect)
import Spa exposing (Page)


static : view -> Page flags sharedMsg view () ()
static pageView =
    { init = \_ -> ( (), Effect.none )
    , update = \_ _ -> ( (), Effect.none )
    , subscriptions = always Sub.none
    , view = always pageView
    }


sandbox :
    { init : flags -> model
    , update : msg -> model -> model
    , view : model -> view
    }
    -> Page flags sharedMsg view model msg
sandbox { init, update, view } =
    { init = init >> Effect.withNone
    , update = \msg model -> update msg model |> Effect.withNone
    , subscriptions = always Sub.none
    , view = view
    }


element :
    { init : flags -> ( model, Effect sharedMsg msg )
    , update : msg -> model -> ( model, Effect sharedMsg msg )
    , view : model -> view
    , subscriptions : model -> Sub msg
    }
    -> Page flags sharedMsg view model msg
element { init, update, view, subscriptions } =
    { init = init
    , update = update
    , subscriptions = subscriptions
    , view = view
    }
