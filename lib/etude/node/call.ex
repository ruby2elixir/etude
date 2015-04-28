defmodule Etude.Node.Call do
  defstruct module: nil,
            function: nil,
            arguments: [],
            attrs: %{},
            line: nil

  alias Etude.Children
  import Etude.Vars
  import Etude.Utils

  defimpl Etude.Node, for: Etude.Node.Call do
    defdelegate name(node, opts), to: Etude.Node.Any
    defdelegate call(node, opts), to: Etude.Node.Any
    defdelegate assign(node, opts), to: Etude.Node.Any
    defdelegate prop(node, opts), to: Etude.Node.Any
    defdelegate var(node, opts), to: Etude.Node.Any

    def compile(node, opts) do
      name = Etude.Node.name(node, opts)
      arguments = node.arguments
      exec = "#{name}_exec" |> String.to_atom

      native = Etude.Utils.get_bin_or_atom(node.attrs, :native, false)

      defop node, opts, [:memoize], """
      #{Children.call(arguments, opts)},
      case #{exec}(#{Children.vars(arguments, opts, ", ")}#{op_args}) of
        nil ->
          ?DEBUG(<<"#{name} deps pending">>),
          {nil, #{state}};
        pending ->
          ?DEBUG(<<"#{name} call pending">>),
          {nil, #{state}};
        CallRes ->
          #{debug_res(name, "element(1, CallRes)", "call")},
          CallRes
      end
      """, Dict.put(Children.compile(arguments, opts), exec, compile_exec(exec, native, node, opts))
    end

    defp compile_exec(name, native, node, opts) do
      mod = escape(node.module)
      fun = escape(node.function)
      arguments = node.arguments
      """
      #{name}(#{Children.args(arguments, opts, ", ")}#{op_args}) ->
        _Args = [#{Children.vars(arguments, opts)}],
        _ID = #{compile_mfa_hash(mod, fun, arguments, "_Args")},
        case ?MEMO_GET(#{req}, _ID, call) of
          undefined ->
            #{debug_call(node.module, node.function, "_Args")},
      #{indent(exec_block(mod, fun, arguments, native, node.attrs, opts), 2)};
          Val ->
            {Val, #{state}}
        end;
      #{name}(#{Children.wildcard(arguments, opts, ", ")}#{op_args}) ->
        nil.
      """
    end

    defp exec_block(mod, fun, arguments, true, _, opts) do
      """
        Val = {#{ready}, #{mod}:#{fun}(#{Children.vars(arguments, opts)})},
        ?MEMO_PUT(#{req}, _ID, call, Val),
        {Val, #{state}}
      """
    end

    defp exec_block(mod, fun, _arguments, _, attrs, _opts) do
      """
        case #{resolve}(#{mod}, #{fun}, _Args, #{state}, self(), {erlang:make_ref(), _ID}, #{escape(attrs)}) of
          {ok, Pid} when is_pid(Pid) ->
            Ref = erlang:monitor(process, Pid),
            ?MEMO_PUT(#{req}, _ID, call, Ref),
            pending;
          {ok, Val} ->
            Out = {#{ready}, Val},
            ?MEMO_PUT(#{req}, _ID, call, Out),
            {Out, #{state}};
          {ok, Val, NewState} ->
            Out = {#{ready}, Val},
            ?MEMO_PUT(#{req}, _ID, call, Out),
            {Out, NewState}
        end;
      Ref when is_reference(Ref) ->
        pending
      """
    end
  end
end