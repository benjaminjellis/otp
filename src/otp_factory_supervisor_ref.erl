-module(otp_factory_supervisor_ref).

-export([init/1, start_child_callback/1, start_child_callback/2]).

init(StartData) ->
    apply(resolve_module(), init, [StartData]).

start_child_callback(Starter) ->
    apply(resolve_module(), start_child_callback, [Starter]).

start_child_callback(Starter, Argument) ->
    apply(resolve_module(), start_child_callback, [Starter, Argument]).

resolve_module() ->
    case code:ensure_loaded(d_otp_factory_supervisor) of
        {module, d_otp_factory_supervisor} ->
            d_otp_factory_supervisor;
        _ ->
            p_otp_factory_supervisor
    end.
