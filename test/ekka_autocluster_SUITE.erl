%%%===================================================================
%%% Copyright (c) 2013-2017 EMQ Enterprise, Inc. (http://emqtt.io)
%%%
%%% Licensed under the Apache License, Version 2.0 (the "License");
%%% you may not use this file except in compliance with the License.
%%% You may obtain a copy of the License at
%%%
%%%     http://www.apache.org/licenses/LICENSE-2.0
%%%
%%% Unless required by applicable law or agreed to in writing, software
%%% distributed under the License is distributed on an "AS IS" BASIS,
%%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%%% See the License for the specific language governing permissions and
%%% limitations under the License.
%%%===================================================================

-module(ekka_autocluster_SUITE).

-compile(export_all).

-include("ekka.hrl").

-include_lib("eunit/include/eunit.hrl").

-include_lib("common_test/include/ct.hrl").

-define(NODES, ['ekka_ct@127.0.0.1', 'ekka_ct1@127.0.0.1', 'ekka_ct2@127.0.0.1']).

all() ->
    [{group, autocluster}].

groups() ->
    [{autocluster, [sequence], [t_autocluster_static, t_autocluster_mcast]}].

init_per_testcase(t_autocluster_static, Config) ->
    application:set_env(ekka, cluster_discovery, {static, strategy_options(static)}),
    {ok, _} = ekka:start(),
    ekka_autocluster:bootstrap(),
    Config;

init_per_testcase(t_autocluster_mcast, Config) ->
    application:set_env(ekka, cluster_discovery, {mcast, strategy_options(mcast)}),
    {ok, _} = ekka:start(),
    ekka_autocluster:bootstrap(),
    Config;

init_per_testcase(_TestCase, Config) ->
    Config.

end_per_testcase(_TestCase, _Config) ->
    ekka:stop(),
    ekka_mnesia:ensure_stopped().

strategy_options(static) ->
    [{seeds, ?NODES}];

strategy_options(mcast) ->
    [{addr, {239,192,0,1}}, {ports, [4369,4370,4371]},
     {iface, {0,0,0,0}}, {ttl,1}, {loop,true}].

t_autocluster_static(Config) ->
    t_autocluster(static, Config).

t_autocluster_mcast(Config) ->
    t_autocluster(mcast, Config).

t_autocluster(Strategy, Config) ->
    Node1 = start_and_cluster(Strategy, ekka_ct1),
    timer:sleep(500),
    Node2 = start_and_cluster(Strategy, ekka_ct2),
    timer:sleep(500),
    ?assertEqual(lists:usort(?NODES), lists:usort(ekka_mnesia:running_nodes())),
    remove_and_stop(Node1),
    remove_and_stop(Node2).

start_and_cluster(Strategy, Name) ->
    Node = ekka_test:start_slave(ekka, Name),
    ekka_test:wait_running(Node),
    rpc:call(Node, application, set_env,
             [ekka, cluster_discovery, {Strategy, strategy_options(Strategy)}]),
    true = ekka:is_running(Node, ekka),
    rpc:call(Node, ekka_autocluster, bootstrap, []),
    Node.

remove_and_stop(Node) ->
    ekka:force_leave(Node),
    ekka_test:stop_slave(Node).

