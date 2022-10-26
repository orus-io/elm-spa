module Effect exposing
    ( Effect, none, batch, fromCmd, fromSharedCmd, fromShared, perform, attempt
    , map
    , with, withNone, withBatch, withCmd, withSharedCmd, withShared, withMap, withPerform, withAttempt
    , add, addBatch, addCmd, addSharedCmd, addShared, addMap, addPerform, addAttempt
    , toCmd, extractShared
    )

{-| This module provides an [`Effect`](#Effect) type that carries both Cmd and messages for
a shared update


# Create

@docs Effect, none, batch, fromCmd, fromSharedCmd, fromShared, perform, attempt


# Transform

@docs map


# Join effect to a model

These functions join an effect to a given model, for using pipeline syntax in
your 'update' functions

@docs with, withNone, withBatch, withCmd, withSharedCmd, withShared, withMap, withPerform, withAttempt


# Add effect to a (model, effect) pair

These functions add a new effect to a given (model, effect) pair, for using
pipeline syntax in your 'update' functions

@docs add, addBatch, addCmd, addSharedCmd, addShared, addMap, addPerform, addAttempt


# Applying effects

@docs toCmd, extractShared

-}

import Task exposing (Task)


{-| A collection of shared and platform effects
-}
type Effect sharedMsg msg
    = None
    | Cmd (Cmd msg)
    | SharedCmd (Cmd sharedMsg)
    | Shared sharedMsg
    | Batch (List (Effect sharedMsg msg))


{-| Tells that there are no effects
-}
none : Effect sharedMsg msg
none =
    None


{-| Batch effects. Similar to
[`Cmd.batch`](/packages/elm/core/latest/Platform-Cmd#batch)
-}
batch : List (Effect sharedMsg msg) -> Effect sharedMsg msg
batch =
    Batch


{-| Build an effect from a Cmd
-}
fromCmd : Cmd msg -> Effect sharedMsg msg
fromCmd =
    Cmd


{-| Build an effect from a shared Cmd. The result of this command will be handled
by the shared update no matter where it is emitted from
-}
fromSharedCmd : Cmd sharedMsg -> Effect sharedMsg msg
fromSharedCmd =
    SharedCmd


{-| Build an effect from a shared Msg. The message will be sent as-is to the
shared update
-}
fromShared : sharedMsg -> Effect sharedMsg msg
fromShared =
    Shared


{-| Transform the messages produced by an Effect. Similar to
[`Cmd.map`](/packages/elm/core/latest/Platform-Cmd#map).
-}
map : (a -> b) -> Effect sharedMsg a -> Effect sharedMsg b
map fn =
    flatten
        >> List.map
            (\eff ->
                case eff of
                    None ->
                        None

                    Cmd cmd ->
                        Cmd (Cmd.map fn cmd)

                    SharedCmd cmd ->
                        SharedCmd cmd

                    Shared msg ->
                        Shared msg

                    Batch _ ->
                        -- not supposed to happen thanks to 'flatten'
                        None
            )
        >> (\list ->
                case list of
                    [] ->
                        None

                    [ single ] ->
                        single

                    multiple ->
                        Batch multiple
           )


flattenHelper : List (Effect sharedMsg a) -> List (Effect sharedMsg a) -> List (Effect sharedMsg a)
flattenHelper queue flat =
    case queue of
        [] ->
            flat

        None :: tail ->
            flattenHelper tail flat

        (Batch list) :: tail ->
            flattenHelper (list ++ tail) flat

        any :: tail ->
            flattenHelper tail (any :: flat)


flatten : Effect sharedMsg a -> List (Effect sharedMsg a)
flatten effect =
    flattenHelper [ effect ] []


{-| Build an effect that performs a Task
-}
perform : (a -> msg) -> Task Never a -> Effect sharedMsg msg
perform tomsg task =
    Task.perform tomsg task
        |> fromCmd


{-| Build an effect that attempts a Task
-}
attempt : (Result x a -> msg) -> Task x a -> Effect sharedMsg msg
attempt tomsg task =
    Task.attempt tomsg task
        |> fromCmd


{-| Wraps the model with the given Effect
-}
with : Effect sharedMsg msg -> model -> ( model, Effect sharedMsg msg )
with effect model =
    ( model, effect )


{-| Wraps the model with Effect.none

    init : ( Model, Effect Msg )
    init =
        myModel
            |> Effect.withNone

-}
withNone : model -> ( model, Effect sharedMsg msg )
withNone model =
    ( model, none )


{-| Wraps the model with a list of Effect

    init : ( Model, Effect Msg )
    init =
        myModel
            |> Effect.withBatch [ someEffect, anotherEffect ]

-}
withBatch : List (Effect sharedMsg msg) -> model -> ( model, Effect sharedMsg msg )
withBatch effectList model =
    ( model, batch effectList )


{-| Wraps the model with a Cmd

    init : ( Model, Effect Msg )
    init =
        myModel
            |> Effect.withCmd someCmd

-}
withCmd : Cmd msg -> model -> ( model, Effect sharedMsg msg )
withCmd cmd model =
    ( model, fromCmd cmd )


{-| Wraps the model with a shared Cmd

    init : ( Model, Effect Msg )
    init =
        myModel
            |> Effect.withCmd Shared.refreshIdentity

-}
withSharedCmd : Cmd sharedMsg -> model -> ( model, Effect sharedMsg msg )
withSharedCmd cmd model =
    ( model, fromSharedCmd cmd )


{-| Wraps the model with a shared Msg

    init : ( Model, Effect Msg )
    init =
        myModel
            |> Effect.withCmd Shared.clearCache

-}
withShared : sharedMsg -> model -> ( model, Effect sharedMsg msg )
withShared shared model =
    ( model, fromShared shared )


{-| Wraps the model with a mapped effect. Should only be used in top-level
packages

    init : ( Model, Effect Msg )
    init =
        myModel
            |> Effect.withMap SharedMsg Shared.refreshIdentity

-}
withMap : (msg1 -> msg) -> Effect sharedMsg msg1 -> model -> ( model, Effect sharedMsg msg )
withMap mapper effect model =
    ( model, map mapper effect )


{-| Wraps the model with an effect that performs a Task
-}
withPerform : (a -> msg) -> Task Never a -> model -> ( model, Effect sharedMsg msg )
withPerform tomsg task model =
    ( model, perform tomsg task )


{-| Wraps the model with an effect that attempts a Task
-}
withAttempt : (Result x a -> msg) -> Task x a -> model -> ( model, Effect sharedMsg msg )
withAttempt tomsg task model =
    ( model, attempt tomsg task )


{-| Add a new Effect to an existing model-Effect pair
-}
add : Effect sharedMsg msg -> ( model, Effect sharedMsg msg ) -> ( model, Effect sharedMsg msg )
add nextEffect ( model, effect ) =
    ( model, batch [ effect, nextEffect ] )


{-| Add a list of new Effect to an existing model-Effect pair
-}
addBatch : List (Effect sharedMsg msg) -> ( model, Effect sharedMsg msg ) -> ( model, Effect sharedMsg msg )
addBatch nextEffectList ( model, effect ) =
    ( model, batch <| effect :: nextEffectList )


{-| Add a [`Cmd`](/packages/elm/core/latest/Platform-Cmd#Cmd) to an existing
model-Effect pair
-}
addCmd : Cmd msg -> ( model, Effect sharedMsg msg ) -> ( model, Effect sharedMsg msg )
addCmd =
    fromCmd >> add


{-| Add a shared [`Cmd`](/packages/elm/core/latest/Platform-Cmd#Cmd) to an existing
model-Effect pair

    ( model, effect )
        |> Effect.addShared Shared.renewToken

-}
addSharedCmd : Cmd sharedMsg -> ( model, Effect sharedMsg msg ) -> ( model, Effect sharedMsg msg )
addSharedCmd =
    fromSharedCmd >> add


{-| Add a new shared Msg to an existing model-Effect pair

    ( model, effect )
        |> Effect.addShared Shared.clearCache

-}
addShared : sharedMsg -> ( model, Effect sharedMsg msg ) -> ( model, Effect sharedMsg msg )
addShared =
    fromShared >> add


{-| Add a new mapped Effect to an existing model-Effect pair
-}
addMap : (msg1 -> msg) -> Effect sharedMsg msg1 -> ( model, Effect sharedMsg msg ) -> ( model, Effect sharedMsg msg )
addMap mapper effect =
    add (map mapper effect)


{-| Add an effect that performs a Task to an existing model-Effect pair
-}
addPerform : (a -> msg) -> Task Never a -> ( model, Effect sharedMsg msg ) -> ( model, Effect sharedMsg msg )
addPerform tomsg task =
    add (perform tomsg task)


{-| Add an effect that attempts a Task to an existing model-Effect pair
-}
addAttempt : (Result x a -> msg) -> Task x a -> ( model, Effect sharedMsg msg ) -> ( model, Effect sharedMsg msg )
addAttempt tomsg task =
    add (attempt tomsg task)


{-| Convert a collection of effects to a collection of
[`Cmd`](/packages/elm/core/latest/Platform-Cmd#Cmd)
-}
toCmd : ( sharedMsg -> msg, subMsg -> msg ) -> Effect sharedMsg subMsg -> Cmd msg
toCmd ( fromSharedMsg, fromSubMsg ) effect =
    case
        flatten effect
            |> List.filterMap
                (\e ->
                    case e of
                        None ->
                            Nothing

                        Cmd cmd ->
                            Just <| Cmd.map fromSubMsg cmd

                        SharedCmd cmd ->
                            Just <| Cmd.map fromSharedMsg cmd

                        Shared msg ->
                            Task.succeed msg
                                |> Task.perform fromSharedMsg
                                |> Just

                        Batch _ ->
                            -- not supposed to happen after a flatten
                            Nothing
                )
    of
        [] ->
            Cmd.none

        [ single ] ->
            single

        multiple ->
            Cmd.batch multiple


{-| Extract the Shared messages from an effect

Useful for an application that wants to apply Shared effects immediately instead
of using tasks (which is what [toCmd](#toCmd) does)

-}
extractShared : Effect sharedMsg msg -> ( List sharedMsg, Effect sharedMsg msg )
extractShared =
    flatten
        >> List.foldl
            (\effect ( sharedList, otherList ) ->
                case effect of
                    Shared sharedMsg ->
                        ( sharedMsg :: sharedList, otherList )

                    _ ->
                        ( sharedList, effect :: otherList )
            )
            ( [], [] )
        >> Tuple.mapSecond batch
