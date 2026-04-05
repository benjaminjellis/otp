-module(otp_static_supervisor_ref).

-export([init/1, start_child_callback/1]).

init(StartData) ->
    apply(resolve_module(), init, [StartData]).

start_child_callback(Starter) ->
    apply(resolve_module(), start_child_callback, [Starter]).

resolve_module() ->
    case code:ensure_loaded(d_otp_static_supervisor) of
        {module, d_otp_static_supervisor} ->
            d_otp_static_supervisor;
        _ ->
            p_otp_static_supervisor
    end.
