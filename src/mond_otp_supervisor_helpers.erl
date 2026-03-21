-module(mond_otp_supervisor_helpers).

-export([
    start_static_supervisor/6,
    start_factory_supervisor/7,
    start_factory_child_callback/2,
    start_factory_child_pid/2,
    start_factory_child_name/2
]).

start_static_supervisor(Module, Strategy, Intensity, Period, AutoShutdown, Children) ->
    Flags = #{
        strategy => Strategy,
        intensity => Intensity,
        period => Period,
        auto_shutdown => AutoShutdown
    },
    Specs = static_child_specs(Module, Children, 0),
    supervisor:start_link(Module, {Flags, Specs}).

start_factory_supervisor(Module, Intensity, Period, Restart, Type, Shutdown, Template) ->
    Flags = #{
        strategy => simple_one_for_one,
        intensity => Intensity,
        period => Period
    },
    Child = #{
        id => 0,
        start => {?MODULE, start_factory_child_callback, [Template]},
        restart => Restart,
        type => Type,
        shutdown => make_timeout(Shutdown)
    },
    supervisor:start_link(Module, {Flags, [Child]}).

start_factory_child_callback(Template, Argument) ->
    case p_otp_factory_supervisor:start_child_callback(Template, Argument) of
        {ok, {pair, Pid, Data}} ->
            {ok, Pid, Data};
        {error, Reason} ->
            {error, Reason}
    end.

start_factory_child_pid(Supervisor, Argument) ->
    case supervisor:start_child(Supervisor, [Argument]) of
        {ok, Pid, Data} ->
            {ok, {pair, Pid, Data}};
        {error, Reason} ->
            {error, Reason}
    end.

start_factory_child_name(Name, Argument) ->
    case mond_process_helpers:process_named(Name) of
        {ok, Pid} ->
            start_factory_child_pid(Pid, Argument);
        {error, Reason} ->
            erlang:error({factory_supervisor_name_error, Reason})
    end.

static_child_specs(_Module, [], _Id) ->
    [];
static_child_specs(Module, [Child | Rest], Id) ->
    [static_child_spec(Module, Child, Id) | static_child_specs(Module, Rest, Id + 1)].

static_child_spec(Module, Child, Id) ->
    Start = maps:get(start, Child),
    Restart = maps:get(restart, Child),
    Significant = maps:get(significant, Child),
    Type = maps:get(type, Child),
    Shutdown = maps:get(shutdown, Child),
    #{
        id => Id,
        start => {Module, start_child_callback, [Start]},
        restart => Restart,
        significant => Significant,
        type => Type,
        shutdown => make_timeout(Shutdown)
    }.

make_timeout(Value) when is_integer(Value), Value < 0 ->
    infinity;
make_timeout(Value) ->
    Value.
