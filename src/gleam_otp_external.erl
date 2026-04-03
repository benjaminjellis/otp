-module(gleam_otp_external).

-export([
    application_stopped/0,
    convert_system_message/1,
    identity/1,
    make_timeout/1,
    convert_erlang_start_error/1
]).

identity(X) ->
    X.

make_timeout(X) when is_integer(X), X < 0 ->
    infinity;
make_timeout(X) ->
    X.

convert_system_message({system, {From, Ref}, Request}) when is_pid(From) ->
    Reply = fun(Msg) ->
        case Ref of
            [alias | Alias] = Tag when is_reference(Alias) ->
                erlang:send(Alias, {Tag, Msg});
            [[alias | Alias] | _] = Tag when is_reference(Alias) ->
                erlang:send(Alias, {Tag, Msg});
            _ ->
                erlang:send(From, {Ref, Msg})
        end,
        unit
    end,
    System = fun(Callback) ->
        {system, {Request, Callback}}
    end,
    case Request of
        get_status ->
            {system, {getstatus, fun(Status) -> Reply(process_status(Status)) end}};
        get_state ->
            {system, {getstate, fun(State) -> Reply({ok, State}) end}};
        suspend ->
            System(fun(_) -> Reply(ok) end);
        resume ->
            System(fun(_) -> Reply(ok) end);
        Other ->
            {unexpected, Other}
    end.

process_status({statusinfo, Module, Parent, Mode, DebugState, State}) ->
    Data = [
        get(), Mode, Parent, DebugState,
        [{header, "Status for Mond process " ++ pid_to_list(self())},
         {data, [
             {"Mond behaviour", Module},
             {"Status", Mode},
             {"Parent", Parent}]},
         {data, [{"State", State}]}
        ]
    ],
    {status, self(), {module, Module}, Data};
process_status({status_info, Module, Parent, Mode, DebugState, State}) ->
    Data = [
        get(), Mode, Parent, DebugState,
        [{header, "Status for Mond process " ++ pid_to_list(self())},
         {data, [
             {"Mond behaviour", Module},
             {"Status", Mode},
             {"Parent", Parent}]},
         {data, [{"State", State}]}
        ]
    ],
    {status, self(), {module, Module}, Data}.

application_stopped() ->
    ok.

convert_erlang_start_error({already_started, _}) ->
    {initfailed, <<"already started">>};
convert_erlang_start_error({shutdown, _}) ->
    {initfailed, <<"shutdown">>};
convert_erlang_start_error(Term) ->
    {initexited, {abnormal, Term}}.
