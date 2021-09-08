module Spa.Page exposing (..)

import Effect exposing (Effect)
import Element exposing (Element)
import Spa exposing (Page)


static : Element () -> Page sharedMsg () ()
static pageView =
    { init = ( (), Effect.none )
    , update = \_ _ -> ( (), Effect.none )
    , subscriptions = always Sub.none
    , view = always pageView
    }


sandbox :
    { init : model
    , update : msg -> model -> model
    , view : model -> Element msg
    }
    -> Page sharedMsg model msg
sandbox { init, update, view } =
    { init = init |> Effect.withNone
    , update = \msg model -> update msg model |> Effect.withNone
    , subscriptions = always Sub.none
    , view = view
    }


element :
    { init : ( model, Effect sharedMsg msg )
    , update : msg -> model -> ( model, Effect sharedMsg msg )
    , view : model -> Element msg
    , subscriptions : model -> Sub msg
    }
    -> Page sharedMsg model msg
element { init, update, view, subscriptions } =
    { init = init
    , update = update
    , subscriptions = subscriptions
    , view = view
    }
