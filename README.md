# Orus.io Elm-Spa

This package provides tools to easily build Single Page Applications.

It provides the same features as [ryannhg/elm-spa](https://www.elm-spa.dev/)
but without any code generation.

The key idea to avoid code generation is taken from
[insurello/elm-ui-explorer](https://package.elm-lang.org/packages/insurello/elm-ui-explorer/latest/)
(see the aknowlegments).

## Quickstart

The easiest way to start using Elm-Spa is to copy the [example
application](https://github.com/orus-io/elm-spa/tree/master/example/src) files
and adapt them to your needs.

To better understand the example code, keep reading, we'll cover all the
concepts.

## Running your application

When developing, it is recommended to use ``elm-live`` to run the application:

```sh
elm-live --pushstate -- src/Main.elm
```

## In-depth

- [App construction](#app-construction)
- [Shared state](#shared-state)
- [Routing](#routing)
- [Identity management](#identity-management)
- [Pages](#pages)
  - [Adding pages](#adding-pages)
  - [Effect](#effect)
  - [Page constructor](#page-constructor)
    - [static page](#static-page)
    - [sandbox page](#sandbox-page)
    - [element page](#element-page)
- [Finalize](#finalize)

### App construction

Setting up the application consists in a pipeline that initialise the application,
then add pages to it, and finally build a record suitable for `Browser.application`

```elm
main =
    Spa.init
        { defaultView = View.defaultView
        , extractIdentity = Shared.identity
        }
        |> Spa.addPublicPage mappers Route.matchHome Home.page
        |> Spa.addPublicPage mappers Route.matchSignIn SignIn.page
        |> Spa.addProtectedPage mappers Route.matchCounter Counter.page
        |> Spa.addPublicPage mappers Route.matchTime Time.page
        |> Spa.application View.map
            { toRoute = Route.toRoute
            , init = Shared.init
            , update = Shared.update
            , subscriptions = Shared.subscriptions
            , toDocument = toDocument
            , protectPage = Route.toUrl >> Just >> Route.SignIn >> Route.toUrl
            }
        |> Browser.application
```

In the following sections we describe the different steps of this pipeline by
explaining the concepts.

### Routing

A hand-written Elm SPA application generally have a central `Route` type. The
urls are parsed into a `Route` (there is a good example of that in the
[documentation](https://package.elm-lang.org/packages/elm/url/latest/Url-Parser#parse)),
which is in turn used for deciding which page should be currently displayed.

Orus Elm-Spa allows to use such a type, and the first thing for that is to give
a `toRoute` function to `Spa.init`, so it is capable to parse an incoming URL
into your own custom `Route` type.

```elm
main =
    -- ...
        |> Spa.application View.map
            { toRoute = Route.toRoute
            -- ...
            }
```

Because it doesn't generate any code, Orus Elm-Spa is not able to do a
`case ... of` on the route, so you will need to provide a match function for
each page, more on that a bit further but don't worry: it is dead easy and
even provides a nice way to pass arguments of the route to your page.

### Shared state

The whole application will share a single TEA component that we generally call
`Shared`. It can be anything you want, as long as you provide `init`, and
`update` and `subscriptions` functions.

So, given a simple `Shared` module exposing the shared model and its
init/update/subscriptions functions, this is how you plug your shared state
in the application:

```elm
main =
    Spa.init
        { defaultView = View.defaultView
        -- ...
        }
        -- |> Spa.addXxxxPage
        |> Spa.application View.map
            { -- ...
            , init = Shared.init
            , update = Shared.update
            , subscriptions = Shared.subscriptions
            -- ...
            }
```

If your application doesn't need a shared state, Elm-Spa provides an alternative
constructor that will produce a no-op shared state for you (`Spa.noSharedInit`).

The `defaultView` property is the default view that will be used when no other
page could be viewed, which should be _never_ once your app is properly setup
(more on that a little further).


### Identity management

The pages of the application can be 'protected', which means they cannot be
accessed unless the user is authenticated.

For that, Orus Elm-Spa needs two things:

- a way to extract the current identity from the shared state:
  `extractIdentity`. It is a simple function that returns a `Maybe identity`
  from a `Shared` record. Note that the actual `identity` type can be anything
  you want.

- a fallback URL if the user attempt to access a protected page when
  unauthenticated: `protectPage`. Its role is to return a new URL (as a string),
  and is given the current route that the user attempted to access.
  It allows to build a URL that contains the original route in a 'redirect'
  query parameters, which is very useful.

```elm
main =
    Spa.init
        { -- ...
        , extractIdentity = Shared.identity
        }
        -- |> Spa.addXxxxPage
        |> Spa.application View.map
            { -- ...
            , protectPage = Route.toUrl >> Just >> Route.SignIn >> Route.toUrl
            }
```

### Pages

We now have a inialised application, and we can add pages to it.

A page is a small TEA app on its own, it has `Msg`, `Model`, `init`, `update`,
`subscriptions` and `view`.
It differs from a normal application in a few different ways:

- The page constructor is given the shared state, and optionnaly the identity if
  required.

- The `init` and `update` functions return `Effect Msg` instead of `Cmd Msg`.

- The `init` function takes a `flags` only argument that is the output of the
  page `match` function (see below).

- The `view` function returns a `View Msg`, which can be whatever you define.

#### Adding pages

Adding a page to an application is done by calling the `Spa.addPublicPage`
or the `Spa.addProtectedPage` function. It takes 3 arguments:

- `mappers` is a Tuple of view mappers. For example, if the application view is
  a `Html msg`, the mappers will be: `( Html.map, Html.map )`. The duplication
  is for technical reasons (see the `addPage` function implementation).

- `match` is a function that takes a route and returns the page flags if and
  only if the route matches the page. This is the place were information can
  be extracted from the route to be given to the page `init` function.

  A simple match function can be:

  ```elm
  matchHome : Route -> Maybe ()
  matchHome route =
      case route of
          Home ->
              Just ()
          _ ->
              Nothing
  ```

  A match function that extract information:

  ```elm
  matchSignIn : Route -> Maybe (Maybe String)
  matchSignIn route =
      case route of
          SignIn redirect ->
              Just redirect
          _ ->
              Nothing
  ```

- `page` is a page constructor. A public page constructor is a function that
  takes the shared state:

  ```elm
  page : shared -> Page
  ```

  A protected page constructor takes the current
  identity in addition to the shared state:

  ```elm
  page : shared -> identity -> Page
  ```

#### Effect

A [`Effect`](Effect#Effect) works the same as a `Cmd`, but can also carry
messages and commands of the `Shared` module when sent from a `Page`. It is the
only way for a page to interract with the shared state.

#### Page constructor

A public page constructor takes the shared state and returns init, update,
subscriptions and view functions.

A protected page constructor takes both the shared state and the current
identity and returns the same thing as a public page constructor.

For pages that requires less (static pages, message-less pages), helpers
provide simple ways to build pages.

##### Static page

A static page has no internal state, only a static view:

```elm
page shared =
    Spa.Page.static view
```

The view function could take 'shared' and its only argument:

```elm
page shared =
    Spa.Page.static (view shared)
```

##### Sandbox page

A sandbox page has an internal state but no effects:

```
-- this is a protected page constructor, it takes 'identity' as its second parameter
page shared identity =
    Spa.Page.sandbox
        { init = init
        , update = update
        , view = view
        }
```

##### Element page

A element page has a state, effects and subscriptions:

```
page shared =
    Spa.Page.element
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }
```

#### Page extra properties

##### Page onNewFlags

When a route change actually points to the same page as before, but with
different flags, the default behavior is to call the page 'init' function.

In some case it is sub-optimal. For example a page may use the query parameters
to store the current query: changing it should not reload the page completely.

For such situations, the page can be sent a custom message that will inform it
that the flags have changed.

```

type Flags
    = String  -- or anything the route can produce


type Msg
    = Noop
    | OnNewFlags Flags
    -- | ...


page shared =
    Spa.Page.element
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }
        |> Spa.Page.onNewFlags OnNewFlags
```

#### View

Each page returns a 'View msg', which can be anything you want as long as you
can provide a `map : (msg -> msg1) -> View msg -> View msg1` function, and
a function to convert the View into a Document msg.

A typical view type based on elm-ui can be:

```elm
{-| The application custom view type
-}
type alias View msg =
    { title : String
    , body : Element msg
    }


{-| we must have a map function for it
-}
map : (msg -> msg1) -> View msg -> View msg1
map tomsg view =
    { title = view.title
    , body = Element.map tomsg view.body
    }


{-| change the view into a Document
-}
toDocument : Shared -> View msg -> Document msg
toDocument _ view =
    { title = view.title
    , body = Element.layout [] view.body
    }
```

Note that using elm-ui is not a requirement, you can totally use Html instead.

### Finalize

Once all the pages are added to the application, we can change it into a record
suitable for the `Browser.application` function.

This operation is done by the `Spa.application` function, that takes the
parameters we described earlier, along with the `toDocument` function.

The first parameter is the view mapper (again).

```elm
-- ...
        |> Spa.application View.map
            { toRoute = Route.toRoute
            , protectPage = Route.toUrl >> Just >> Route.SignIn >> Route.toUrl
            , init = Shared.init
            , update = Shared.update
            , subscriptions = Shared.subscriptions
            , toDocument = toDocument
            }
        |> Browser.application
```

## Migrating an existing application

When porting an application to orus-io/elm-spa, the general plan is:

- add a standalone [PageStack](https://package.elm-lang.org/packages/orus-io/elm-spa/2.0.0/Spa-PageStack) in the root component of the application
- move the pages to the stack, one by one
- replace the root component with Spa.application

The details will vary depending on how the program is architecture, but
if it follows the principles of
[rtfeldman/elm-spa-example](https://github.com/rtfeldman/elm-spa-example/)
it should go smoothly.

To make thinks easier for everyone, we demonstrate the incremental
migration of elm-spa-example in this
[pull request](https://github.com/rtfeldman/elm-spa-example/pull/106).


## Acknowlegments

This package borrows brilliant ideas and concepts from many packages, but most
notably:

- [ryannhg/elm-spa](https://www.elm-spa.dev/), for the simple yet powerful idea
  of a Shared state and a Effect module
- [insurello/elm-ui-explorer](https://package.elm-lang.org/packages/insurello/elm-ui-explorer/latest/),
  for the mind-blowing pattern for building a generic complex type layer by
  layer, each layer nesting the model and message of the previous one.
- [Janiczek/cmd-extra](https://package.elm-lang.org/packages/Janiczek/cmd-extra/latest/),
  for the .withXXX and .addXXX API
- [rtfeldman/elm-spa-example](https://github.com/rtfeldman/elm-spa-example/)
  for being the general inspiration of a proper SPA architecture.
