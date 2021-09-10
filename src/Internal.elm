module Internal exposing (Page(..), PageDefinition, pageDefinition)

import Effect exposing (Effect)


type alias PageDefinition flags sharedMsg view model msg =
    { init : flags -> ( model, Effect sharedMsg msg )
    , update : msg -> model -> ( model, Effect sharedMsg msg )
    , subscriptions : model -> Sub msg
    , view : model -> view
    }


type Page flags sharedMsg view model msg
    = Page (PageDefinition flags sharedMsg view model msg)


pageDefinition :
    Page flags sharedMsg view model msg
    -> PageDefinition flags sharedMsg view model msg
pageDefinition (Page def) =
    def
