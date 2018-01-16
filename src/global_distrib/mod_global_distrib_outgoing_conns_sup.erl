-module(mod_global_distrib_outgoing_conns_sup).

-behaviour(supervisor).

-include("ejabberd.hrl").

-export([start_link/0, init/1]).
-export([add_server/1, get_connection/1, ensure_server_started/1]).

%%--------------------------------------------------------------------
%% API
%%--------------------------------------------------------------------

-spec start_link() -> {ok, pid()} | {error, any()}.
start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

-spec add_server(Server :: ejabberd:lserver()) -> ok | {error, any()}.
add_server(Server) ->
    SupName = mod_global_distrib_utils:server_to_sup_name(Server),
    ServerSupSpec = #{
      id => SupName,
      start => {mod_global_distrib_server_sup, start_link, [Server]},
      restart => temporary,
      shutdown => 5000,
      type => supervisor,
      modules => dynamic
     },
    case supervisor:start_child(?MODULE, ServerSupSpec) of
        {ok, _} -> ok;
        Error -> Error
    end.

-spec get_connection(Server :: ejabberd:lserver()) -> pid().
get_connection(Server) ->
    ensure_server_started(Server),
    mod_global_distrib_server_sup:get_connection(Server).

%%--------------------------------------------------------------------
%% supervisor callback
%%--------------------------------------------------------------------

init(_) ->
    SupFlags = #{ strategy => one_for_one, intensity => 5, period => 5 },
    RefresherSpec = #{
      id => mod_global_distrib_hosts_refresher,
      start => {mod_global_distrib_hosts_refresher, start_link, []},
      restart => temporary, % to change
      shutdown => 5000
    },
    {ok, {SupFlags, [RefresherSpec]}}.

%%--------------------------------------------------------------------
%% Helpers
%%--------------------------------------------------------------------

ensure_server_started(Server) ->
  case whereis(mod_global_distrib_utils:server_to_sup_name(Server)) of
    undefined ->
      ?DEBUG("Host ~p didn't have a corresponding supervisor", [Server]),
      ok = add_server(Server);
    _ -> ok
  end,
  ok.
