module NewTopBar exposing (Model, Msg(FilterMsg, UserFetched), init, fetchUser, update, view)

import Concourse
import Concourse.User
import Html exposing (Html)
import Html.Attributes exposing (class, classList, href, id, src, type_, placeholder, value)
import Html.Events exposing (..)
import RemoteData exposing (RemoteData)


type alias Model =
    { user : RemoteData.WebData Concourse.User
    , query : String
    , showSearch : Bool
    }


type Msg
    = UserFetched (RemoteData.WebData Concourse.User)
    | FilterMsg String


init : Bool -> ( Model, Cmd Msg )
init showSearch =
    ( { user = RemoteData.Loading
      , query = ""
      , showSearch = showSearch
      }
    , fetchUser
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        FilterMsg query ->
            ( { model | query = query }, Cmd.none )

        UserFetched response ->
            ( { model | user = response }, Cmd.none )


showUserInfo : Model -> Html Msg
showUserInfo model =
    case model.user of
        RemoteData.NotAsked ->
            Html.text "n/a"

        RemoteData.Loading ->
            Html.text "loading"

        RemoteData.Success user ->
            Html.text user.team.name

        RemoteData.Failure _ ->
            Html.text "login"


view : Model -> Html Msg
view model =
    Html.div [ class "module-topbar" ]
        [ Html.div [ class "topbar-logo" ] [ Html.a [ class "logo-image-link", href "#" ] [] ]
        , Html.div [ classList [ ( "topbar-search", True ), ( "hidden", not model.showSearch ) ] ]
            [ Html.div
                [ class "topbar-search-form" ]
                [ Html.input
                    [ class "search-input-field"
                    , id "search-input-field"
                    , type_ "text"
                    , placeholder "search"
                    , onInput FilterMsg
                    , value model.query
                    ]
                    []
                , Html.span
                    [ class "search-clear-button"
                    , id "search-clear-button"
                    , onClick (FilterMsg "")
                    ]
                    []
                ]
            ]
        , Html.div [ class "topbar-login" ]
            [ Html.div [ class "topbar-user-info" ]
                [ showUserInfo model ]
            ]
        ]


fetchUser : Cmd Msg
fetchUser =
    Cmd.map UserFetched <|
        RemoteData.asCmd Concourse.User.fetchUser
