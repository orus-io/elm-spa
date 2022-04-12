module Pages.SignIn exposing (..)

import Effect exposing (Effect)
import Element exposing (Element)
import Element.Border as Border
import Element.Input as Input
import Shared
import Spa.Page
import View exposing (View)


page _ =
    Spa.Page.element
        { init = init
        , update = update
        , view = view
        , subscriptions = always Sub.none
        }


type Msg
    = Login String


type alias Model =
    { redirect : Maybe String }


init : Maybe String -> ( Model, Effect Shared.Msg Msg )
init =
    Model
        >> Effect.withNone


update : Msg -> Model -> ( Model, Effect Shared.Msg Msg )
update msg model =
    case msg of
        Login login ->
            model
                |> Effect.withShared
                    (Shared.setIdentity login
                        (model.redirect
                            |> Maybe.withDefault "/"
                            |> Just
                        )
                    )


view : Model -> View Msg
view model =
    { title = "SignIn"
    , body =
        Element.column [ Element.spacing 20 ]
            [ Element.text "Choose who you are:"
            , Element.row [ Element.spacing 20 ]
                [ Input.button [ Border.width 1, Element.paddingXY 20 10 ]
                    { label = Element.text "I am Jeannine"
                    , onPress = Just (Login "Jeannine")
                    }
                , Input.button [ Border.width 1, Element.paddingXY 20 10 ]
                    { label = Element.text "I am Bernard"
                    , onPress = Just (Login "Bernard")
                    }
                , Input.button [ Border.width 1, Element.paddingXY 20 10 ]
                    { label = Element.text "I am Marie"
                    , onPress = Just (Login "Marie")
                    }
                , Input.button [ Border.width 1, Element.paddingXY 20 10 ]
                    { label = Element.text "I am René"
                    , onPress = Just (Login "René")
                    }
                ]
            , Element.text <| "you will be redirected to " ++ Maybe.withDefault "/" model.redirect ++ " after login"
            , Element.link []
                { label = Element.text "Go home"
                , url = "/"
                }
            ]
    }
