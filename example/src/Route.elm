module Route exposing (..)

import Url exposing (Url)
import Url.Parser as Parser exposing (..)


type Route
    = Home
    | SignIn
    | Counter
    | Time
    | NotFound Url


route : Parser (Route -> a) a
route =
    oneOf
        [ map Home top
        , map SignIn <| s "sign-in"
        , map Counter <| s "counter"
        , map Time <| s "time"
        ]


toRoute : Url -> Route
toRoute url =
    parse route url
        |> Maybe.withDefault (NotFound url)


matchAny : Route -> Route -> Maybe ()
matchAny any r =
    if any == r then
        Just ()

    else
        Nothing


matchHome : Route -> Maybe ()
matchHome =
    matchAny Home


matchSignIn : Route -> Maybe ()
matchSignIn =
    matchAny SignIn


matchCounter : Route -> Maybe ()
matchCounter =
    matchAny Counter


matchTime : Route -> Maybe ()
matchTime =
    matchAny Time
