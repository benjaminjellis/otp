-module(otp_test_helpers).

-export([unwrap_sys_get_state/1]).

unwrap_sys_get_state({ok, State}) ->
    State;
unwrap_sys_get_state(State) ->
    State.
