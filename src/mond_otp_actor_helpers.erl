-module(mond_otp_actor_helpers).

-export([
    monitor_process/1,
    demonitor_process/1,
    kill_process/1,
    wait_for_start/3,
    receive_forever/1,
    kill_self/1,
    exit_abnormal/1,
    call_timeout/1,
    convert_system_message/1
]).

monitor_process(Pid) ->
    erlang:monitor(process, Pid).

demonitor_process(MonitorRef) ->
    erlang:demonitor(MonitorRef, [flush]),
    unit.

kill_process(Pid) ->
    exit(Pid, kill),
    unit.

wait_for_start({subject, {subjectpayload, _Owner, Tag}}, MonitorRef, TimeoutMs) ->
    receive
        {Tag, Message} ->
            {ack, Message};
        {'DOWN', MonitorRef, process, _Pid, Reason} ->
            {mon, to_exit_reason(Reason)}
    after TimeoutMs ->
        starttimeout
    end;
wait_for_start({namedsubject, {name, _Name, Tag}}, MonitorRef, TimeoutMs) ->
    wait_for_start({subject, {subjectpayload, self(), Tag}}, MonitorRef, TimeoutMs).

receive_forever({subject, {subjectpayload, _Owner, Tag}}) ->
    receive
        {Tag, Message} -> Message
    end;
receive_forever({namedsubject, {name, _Name, Tag}}) ->
    receive_forever({subject, {subjectpayload, self(), Tag}}).

kill_self(_Unit) ->
    exit(self(), kill).

exit_abnormal(Reason) ->
    exit(self(), Reason).

call_timeout(_Unit) ->
    erlang:error({actor_call_timeout, <<"reply not received before timeout">>}).

to_exit_reason(normal) ->
    normal;
to_exit_reason(killed) ->
    killed;
to_exit_reason(kill) ->
    killed;
to_exit_reason(Reason) ->
    {abnormal, Reason}.

% TODO: support other system messages
%   {replace_state, StateFn}
%   {change_code, Mod, Vsn, Extra}
%   {terminate, Reason}
%   {debug, {log, Flag}}
%   {debug, {trace, Flag}}
%   {debug, {log_to_file, FileName}}
%   {debug, {statistics, Flag}}
%   {debug, no_debug}
%   {debug, {install, {Func, FuncState}}}
%   {debug, {install, {FuncId, Func, FuncState}}}
%   {debug, {remove, FuncOrId}}
convert_system_message({system, {From, Ref}, Request}) when is_pid(From) ->
    Reply = fun(Msg) ->
        case Ref of 
            [alias|Alias] = Tag when is_reference(Alias) ->
                erlang:send(Alias, {Tag, Msg});
            [[alias|Alias] | _] = Tag when is_reference(Alias) ->
                erlang:send(Alias, {Tag, Msg});
            _ ->
                erlang:send(From, {Ref, Msg})
        end,
        nil
    end,
    System = fun(Callback) ->
        {system, {Request, Callback}}
    end,
    case Request of
        get_status -> System(fun(Status) -> Reply(process_status(Status)) end);
        get_state -> System(fun(State) -> Reply({ok, State}) end);
        suspend -> System(fun() -> Reply(ok) end);
        resume -> System(fun() -> Reply(ok) end);
        Other -> {unexpected, Other}
    end.

process_status({status_info, Module, Parent, Mode, DebugState, State}) ->
     Data = [
         get(), Mode, Parent, DebugState,
         [{header, "Status for Gleam process " ++ pid_to_list(self())},
           {data, [
             {"Gleam behaviour", Module},
             {"Status", Mode},
             {"Parent", Parent}]},
          {data, [{"State", State}]}
         ]
     ],
     {status, self(), {module, Module}, Data}.
