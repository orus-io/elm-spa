module Spa.Page exposing (..)

import Effect
import Element exposing (Element)
import Spa exposing (Page)


static : Element () -> Page shared sharedMsg () ()
static pageView _ =
    { init = ( (), Effect.none )
    , update = \_ _ -> ( (), Effect.none )
    , view = always pageView
    }
