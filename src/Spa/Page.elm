module Spa.Page exposing
    ( Page, static, sandbox, element
    , onNewFlags
    )

{-| Provides `Page` builders

@docs Page, static, sandbox, element
@docs onNewFlags

-}

import Effect exposing (Effect)
import Internal


{-| A Page is a TEA component
-}
type alias Page flags sharedMsg view model msg =
    Internal.Page flags sharedMsg view model msg


{-| Create a static page that has no state, only a view
-}
static : view -> Page flags sharedMsg view () ()
static pageView =
    Internal.Page
        { init = \_ -> ( (), Effect.none )
        , update = \_ _ -> ( (), Effect.none )
        , subscriptions = always Sub.none
        , view = always pageView
        , onNewFlags = Nothing
        }


{-| Create a "sandboxed" page that cannot communicate with the outside world.

It is the page equivalent of a [sanboxed program](/packages/elm/browser/latest/Browser#sandbox)

-}
sandbox :
    { init : flags -> model
    , update : msg -> model -> model
    , view : model -> view
    }
    -> Page flags sharedMsg view model msg
sandbox { init, update, view } =
    Internal.Page
        { init = init >> Effect.withNone
        , update = \msg model -> update msg model |> Effect.withNone
        , subscriptions = always Sub.none
        , view = view
        , onNewFlags = Nothing
        }


{-| Create a page that can communicate with the outside world.

It is the page equivalent of a [element program](/packages/elm/browser/latest/Browser#element)

-}
element :
    { init : flags -> ( model, Effect sharedMsg msg )
    , update : msg -> model -> ( model, Effect sharedMsg msg )
    , view : model -> view
    , subscriptions : model -> Sub msg
    }
    -> Page flags sharedMsg view model msg
element { init, update, view, subscriptions } =
    Internal.Page
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        , onNewFlags = Nothing
        }


{-| Set the message to pass when the flags changed. If not set, the 'init'
function is called, resulting in a complete reinitialisation of the page model.
-}
onNewFlags :
    (flags -> msg)
    -> Page flags sharedMsg view model msg
    -> Page flags sharedMsg view model msg
onNewFlags tomsg (Internal.Page def) =
    Internal.Page
        { def
            | onNewFlags = Just tomsg
        }
