module Spa.Page exposing (..)

import Effect exposing (Effect)
import Element exposing (Element)
import Spa exposing (Page)


static : Element () -> Page sharedMsg () ()
static pageView =
    { init = ( (), Effect.none )
    , update = \_ _ -> ( (), Effect.none )
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
    , view = view
    }
