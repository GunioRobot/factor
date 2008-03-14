! Copyright (c) 2008 Slava Pestov
! See http://factorcode.org/license.txt for BSD license.
USING: accessors new-slots quotations assocs kernel splitting
base64 html.elements io combinators http.server
http.server.auth.providers http.server.auth.providers.null
http.server.actions http.server.components http.server.sessions
http.server.templating.fhtml http.server.validators
http.server.auth http sequences io.files namespaces hashtables
fry io.sockets combinators.cleave arrays threads locals
qualified ;
IN: http.server.auth.login
QUALIFIED: smtp

TUPLE: login users ;

SYMBOL: post-login-url
SYMBOL: login-failed?

! ! ! Login

: <login-form>
    "login" <form>
        "resource:extra/http/server/auth/login/login.fhtml" >>edit-template
        "username" <username>
            t >>required
            add-field
        "password" <password>
            t >>required
            add-field ;

: successful-login ( user -- response )
    logged-in-user sset
    post-login-url sget "" or f <permanent-redirect>
    f post-login-url sset ;

:: <login-action> ( -- action )
    [let | form [ <login-form> ] |
        <action>
            [ blank-values ] >>init

            [
                "text/html" <content>
                [ form edit-form ] >>body
            ] >>display

            [
                blank-values

                form validate-form

                "password" value "username" value
                login get users>> check-login [
                    successful-login
                ] [
                    login-failed? on
                    validation-failed
                ] if*
            ] >>submit
    ] ;

! ! ! New user registration

: <register-form> ( -- form )
    "register" <form>
        "resource:extra/http/server/auth/login/register.fhtml" >>edit-template
        "username" <username>
            t >>required
            add-field
        "realname" <string> add-field
        "password" <password>
            t >>required
            add-field
        "verify-password" <password>
            t >>required
            add-field
        "email" <email> add-field
        "captcha" <captcha> add-field ;

SYMBOL: password-mismatch?
SYMBOL: user-exists?

: same-password-twice ( -- )
    "password" value "verify-password" value = [ 
        password-mismatch? on
        validation-failed
    ] unless ;

:: <register-action> ( -- action )
    [let | form [ <register-form> ] |
        <action>
            [ blank-values ] >>init

            [
                "text/html" <content>
                [ form edit-form ] >>body
            ] >>display

            [
                blank-values

                form validate-form

                same-password-twice

                <user> values get [
                    "username" get >>username
                    "realname" get >>realname
                    "password" get >>password
                    "email" get >>email
                ] bind

                login get users>> new-user [
                    user-exists? on
                    validation-failed
                ] unless*

                successful-login
            ] >>submit
    ] ;

! ! ! Password recovery

SYMBOL: lost-password-from

: current-host ( -- string )
    request get host>> host-name or ;

: new-password-url ( user -- url )
    "new-password"
    swap [
        [ username>> "username" set ]
        [ ticket>> "ticket" set ]
        bi
    ] H{ } make-assoc
    derive-url ;

: password-email ( user -- email )
    smtp:<email>
        [ "[ " % current-host % " ] password recovery" % ] "" make >>subject
        lost-password-from get >>from
        over email>> 1array >>to
        [
            "This e-mail was sent by the application server on " % current-host % "\n" %
            "because somebody, maybe you, clicked on a ``recover password'' link in the\n" %
            "login form, and requested a new password for the user named ``" %
            over username>> % "''.\n" %
            "\n" %
            "If you believe that this request was legitimate, you may click the below link in\n" %
            "your browser to set a new password for your account:\n" %
            "\n" %
            swap new-password-url %
            "\n\n" %
            "Love,\n" %
            "\n" %
            "  FactorBot\n" %
        ] "" make >>body ;

: send-password-email ( user -- )
    '[ , password-email smtp:send-email ]
    "E-mail send thread" spawn drop ;

: <recover-form-1> ( -- form )
    "register" <form>
        "resource:extra/http/server/auth/login/recover-1.fhtml" >>edit-template
        "username" <username>
            t >>required
            add-field
        "email" <email>
            t >>required
            add-field
        "captcha" <captcha> add-field ;

:: <recover-action-1> ( -- action )
    [let | form [ <recover-form-1> ] |
        <action>
            [ blank-values ] >>init

            [
                "text/html" <content>
                [ form edit-form ] >>body
            ] >>display

            [
                blank-values

                form validate-form

                "email" value "username" value
                login get users>> issue-ticket [
                    send-password-email
                ] when*

                "resource:extra/http/server/auth/login/recover-2.fhtml" serve-template
            ] >>submit
    ] ;

: <recover-form-3>
    "new-password" <form>
        "resource:extra/http/server/auth/login/recover-3.fhtml" >>edit-template
        "username" <username> <hidden>
            t >>required
            add-field
        "password" <password>
            t >>required
            add-field
        "verify-password" <password>
            t >>required
            add-field
        "ticket" <string> <hidden>
            t >>required
            add-field ;

:: <recover-action-3> ( -- action )
    [let | form [ <recover-form-3> ] |
        <action>
            [
                { "username" [ v-required ] }
                { "ticket" [ v-required ] }
            ] >>get-params

            [
                [
                    "username" [ get ] keep set
                    "ticket" [ get ] keep set
                ] H{ } make-assoc values set
            ] >>init

            [
                "text/html" <content>
                [ <recover-form-3> edit-form ] >>body
            ] >>display

            [
                blank-values

                form validate-form

                same-password-twice

                "ticket" value
                "username" value
                login get users>> claim-ticket [
                    "password" value >>password
                    login get users>> update-user

                    "resource:extra/http/server/auth/login/recover-4.fhtml"
                    serve-template
                ] [
                    <400>
                ] if*
            ] >>submit
    ] ;

! ! ! Logout
: <logout-action> ( -- action )
    <action>
        [
            f logged-in-user sset
            "login" f <permanent-redirect>
        ] >>submit ;

! ! ! Authentication logic

TUPLE: protected responder ;

C: <protected> protected

M: protected call-responder ( path responder -- response )
    logged-in-user sget [ responder>> call-responder ] [
        2drop
        request get method>> { "GET" "HEAD" } member? [
            request get request-url post-login-url sset
            "login" f <permanent-redirect>
        ] [ <400> ] if
    ] if ;

M: login call-responder ( path responder -- response )
    dup login set
    delegate call-responder ;

: <login> ( responder -- auth )
    login <webapp>
        swap <protected> >>default
        <login-action> "login" add-responder
        <logout-action> "logout" add-responder
        no >>users ;

! ! ! Configuration

: allow-registration ( login -- login )
    <register-action> "register" add-responder ;

: allow-password-recovery ( login -- login )
    <recover-action-1> "recover-password" add-responder
    <recover-action-3> "new-password" add-responder ;

: allow-registration? ( -- ? )
    login get responders>> "register" swap key? ;

: allow-password-recovery? ( -- ? )
    login get responders>> "recover-password" swap key? ;