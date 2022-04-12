module Pages.Time exposing (..)

import Effect exposing (Effect)
import Element exposing (Element)
import Spa.Page
import Task
import Time exposing (Posix, Zone)
import View exposing (View)


page _ =
    Spa.Page.element
        { init = always init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }


type alias Model =
    Maybe
        { time : Posix
        , here : Zone
        }


type Msg
    = Tick Posix
    | Init ( Posix, Zone )


init : ( Model, Effect sharedMsg Msg )
init =
    Nothing
        |> Effect.withPerform Init
            (Task.map2 Tuple.pair Time.now Time.here)


update : Msg -> Model -> ( Model, Effect sharedMsg Msg )
update msg model =
    case msg of
        Init ( time, here ) ->
            Just { time = time, here = here }
                |> Effect.withNone

        Tick time ->
            model
                |> Maybe.map
                    (\m ->
                        { m | time = time }
                    )
                |> Effect.withNone


subscriptions : Model -> Sub Msg
subscriptions model =
    case model of
        Just _ ->
            Time.every 1000.0 Tick

        Nothing ->
            Sub.none


view : Model -> View Msg
view model =
    { title = "What time is it?"
    , body =
        Element.column []
            [ case model of
                Just { time, here } ->
                    (Time.toHour here time
                        |> String.fromInt
                    )
                        ++ ":"
                        ++ (Time.toMinute here time
                                |> String.fromInt
                           )
                        ++ ":"
                        ++ (Time.toSecond here time
                                |> String.fromInt
                           )
                        |> Element.text

                Nothing ->
                    Element.text "..."
            , Element.link []
                { label = Element.text "Go home"
                , url = "/"
                }
            ]
    }
