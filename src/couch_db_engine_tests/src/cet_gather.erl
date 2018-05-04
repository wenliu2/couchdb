% Licensed under the Apache License, Version 2.0 (the "License"); you may not
% use this file except in compliance with the License. You may obtain a copy of
% the License at
%
%   http://www.apache.org/licenses/LICENSE-2.0
%
% Unless required by applicable law or agreed to in writing, software
% distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
% WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
% License for the specific language governing permissions and limitations under
% the License.

-module(cet_gather).


-export([
    module/1
]).


module(ModName) ->
    Exports = ModName:module_info(exports),

    SetupMod = get_setup_mod(ModName, Exports),
    TeardownMod = get_teardown_mod(ModName, Exports),
    SetupTest = get_fun(ModName, setup_test, 0, Exports),
    TeardownTest = get_fun(ModName, teardown_test, 1, Exports),

    RevTests = lists:foldl(fun({Fun, Arity}, Acc) ->
        case {atom_to_list(Fun), Arity} of
            {[$c, $e, $t, $_ | _], Arity} when Arity == 0; Arity == 1 ->
                TestFun = make_test_fun(ModName, Fun, Arity),
                [TestFun | Acc];
            _ ->
                Acc
        end
    end, [], Exports),
    Tests = lists:reverse(RevTests),

    {
        setup,
        spawn,
        SetupMod,
        TeardownMod,
        [
            {
                foreach,
                SetupTest,
                TeardownTest,
                Tests
            }
        ]
    }.


get_setup_mod(ModName, Exports) ->
    case lists:member({setup_mod, 0}, Exports) of
        true -> fun ModName:setup_mod/0;
        false -> fun cet_util:setup_mod/0
    end.


get_teardown_mod(ModName, Exports) ->
    case lists:member({teardown_mod, 1}, Exports) of
        true -> fun ModName:teardown_mod/1;
        false -> fun cet_util:teardown_mod/1
    end.


get_fun(ModName, FunName, Arity, Exports) ->
    case lists:member({FunName, Arity}, Exports) of
        true -> fun ModName:FunName/Arity;
        false when Arity == 0 -> fun() -> ok end;
        false when Arity == 1 -> fun(_) -> ok end
    end.


make_test_fun(Module, Fun, Arity) ->
    Name = atom_to_list(Fun),
    case Arity of
        0 ->
            fun(_) ->
                {timeout, 60, {Name, fun() ->
                    process_flag(trap_exit, true),
                    Module:Fun()
                end}}
            end;
        1 ->
            fun(Arg) ->
                {timeout, 60, {Name, fun() ->
                    process_flag(trap_exit, true),
                    Module:Fun(Arg)
                end}}
            end
    end.