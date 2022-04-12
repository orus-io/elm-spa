module View exposing (..)

import Html exposing (Html)


type alias View msg =
    { title : String
    , body : Html msg
    }


map : (msg1 -> msg) -> View msg1 -> View msg
map tomsg view =
    { title = view.title
    , body = Html.map tomsg view.body
    }


defaultView : View msg
defaultView =
    { title = "No page"
    , body =
        Html.text
            "You should not see this page unless you forgot to add pages to your application"
    }
