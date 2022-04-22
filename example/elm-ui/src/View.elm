module View exposing (View, defaultView, map)

import Element exposing (Element)


type alias View msg =
    { title : String
    , body : Element msg
    }


map : (msg1 -> msg) -> View msg1 -> View msg
map tomsg view =
    { title = view.title
    , body = Element.map tomsg view.body
    }


defaultView : View msg
defaultView =
    { title = "No page"
    , body =
        Element.text
            "You should not see this page unless you forgot to add pages to your application"
    }
