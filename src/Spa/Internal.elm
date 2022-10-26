module Spa.Internal exposing (Page(..), PageDefinition)

import Effect exposing (Effect)


type alias PageDefinition flags sharedMsg view model msg =
    { init : flags -> ( model, Effect sharedMsg msg )
    , update : msg -> model -> ( model, Effect sharedMsg msg )
    , subscriptions : model -> Sub msg
    , view : model -> view
    , onNewFlags : Maybe (flags -> msg)
    }


type Page flags sharedMsg view model msg
    = Page (PageDefinition flags sharedMsg view model msg)
