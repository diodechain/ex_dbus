defmodule ExDBus.Service do
  alias ExDBus.Builder
  alias ExDBus.Tree

  # defmacro __using__(opts) do
  #   service_name = Keyword.get(opts, :service, nil)

  #   quote do
  #     use GenServer

  #     @service_name unquote(service_name)
  #     @schema __MODULE__

  #     @before_compile ExDBus.Service

  #     def start_link(opts) do
  #       GenServer.start_link(
  #         __MODULE__,
  #         [
  #           name: __service__(:name),
  #           schema: __service__(:schema)
  #         ],
  #         opts
  #       )
  #     end

  #     def register_object(path) do
  #       GenServer.call(__MODULE__, {:register_object, path, __MODULE__})
  #     end

  #     def register_object(path, server_pid) when is_pid(server_pid) or is_atom(server_pid) do
  #       GenServer.call(__MODULE__, {:register_object, path, server_pid})
  #     end

  #     def unregister_object(path) do
  #       GenServer.call(__MODULE__, {:unregister_object, path})
  #     end

  #     def is_object_registered?(path) do
  #       GenServer.call(__MODULE__, {:is_object_registered, path})
  #     end

  #     # def reply({pid, from}, reply) do
  #     #   GenServer.cast(pid, {:reply, from, reply})
  #     # end

  #     # def signal(signal) do
  #     #   signal(signal, [])
  #     # end

  #     # def signal(signal, args) do
  #     #   signal(signal, args, [])
  #     # end

  #     # def signal(signal, args, options) do
  #     #   IO.inspect("Sending signal #{signal}")
  #     #   GenServer.cast(__MODULE__, {:signal, signal, args, options})
  #     # end

  #     # def test(p) do
  #     #   GenServer.call(__MODULE__, {:test, p})
  #     # end

  #     @impl true
  #     def init([_ | _] = opts) do
  #       IO.inspect(self(), label: "INIT PID")
  #       IO.inspect(opts, label: "INIT STACK")

  #       service_name = Keyword.get(opts, :name, nil)
  #       schema = Keyword.get(opts, :schema, nil)

  #       if service_name == nil do
  #         raise "Service requires the :name option"
  #       end

  #       if schema == nil do
  #         raise "Service requires the :schema option"
  #       end

  #       root = ExDBus.Service.get_root(schema)

  #       {:ok, {bus, service}} = register_service(self(), service_name)

  #       state = %{
  #         name: service_name,
  #         root: root,
  #         bus: bus,
  #         service: service,
  #         server: self(),
  #         registered_objects: %{}
  #       }

  #       register_objects(self(), state)

  #       {:ok, state}
  #     end

  #     @impl true
  #     def handle_call(request, from, state) do
  #       IO.inspect(from, label: "[CALL] Message from")
  #       IO.inspect(request, label: "[CALL] Message request")
  #       {:noreply, state}
  #     end

  #     @impl true
  #     def handle_cast(request, state) do
  #       IO.inspect(request, label: "[CAST] Request")
  #       {:noreply, state}
  #     end

  #     @impl true
  #     def handle_info(message, state) do
  #       IO.inspect(message, label: "----[INFO]-----")
  #       state = ExDBus.Service.handle_info(message, state, &dbus_method_call/2)
  #       {:noreply, state}
  #     end

  #     defp register_service(pid, service_name) do
  #       ExDBus.Service.register_service(pid, service_name)
  #     end

  #     defp register_objects(pid, state) do
  #       ExDBus.Service.register_objects(pid, state)
  #     end

  #     defp dbus_method_call(method, state) do
  #       ExDBus.Service.dbus_method_call(method, state)
  #     end

  #     defoverridable register_service: 2,
  #                    register_objects: 2,
  #                    dbus_method_call: 2
  #   end
  # end

  # defmacro __before_compile__(_env) do
  #   quote do
  #     def __service__(:name) do
  #       @service_name
  #     end

  #     def __service__(:schema) do
  #       @schema.__schema__()
  #     end
  #   end
  # end

  def start_link(name, schema, opts \\ []) do
    GenServer.start_link(
      __MODULE__,
      [
        name: name,
        schema: schema
      ],
      opts
    )
  end

  @impl true
  def init([_ | _] = opts) do
    IO.inspect(self(), label: "INIT PID")
    IO.inspect(opts, label: "INIT STACK")

    service_name = Keyword.get(opts, :name, nil)
    schema = Keyword.get(opts, :schema, nil)
    server = Keyword.get(opts, :server, nil)

    if service_name == nil do
      raise "Service requires the :name option"
    end

    if schema == nil do
      raise "Service requires the :schema option"
    end

    root = get_root(schema)

    {:ok, {bus, service}} = register_service(self(), service_name)

    state = %{
      name: service_name,
      root: root,
      bus: bus,
      service: service,
      server: server,
      registered_objects: %{}
    }

    {:ok, state}
  end

  def get_root(schema) when is_atom(schema) do
    schema.__schema__()
  end

  def get_root({:object, _, _} = root) do
    root
  end

  def get_root(_) do
    raise "Invalid :schema provided. Must be a module or a :object tree struct"
  end

  def register_object(service_pid, path) do
    GenServer.call(service_pid, {:register_object, path, service_pid})
  end

  def register_object(service_pid, path, server_pid)
      when is_pid(server_pid) or is_atom(server_pid) do
    GenServer.call(service_pid, {:register_object, path, server_pid})
  end

  def unregister_object(service_pid, path) do
    GenServer.call(service_pid, {:unregister_object, path})
  end

  def is_object_registered?(service_pid, path) do
    GenServer.call(service_pid, {:is_object_registered, path})
  end

  def call_method(pid, bus, path, interface, method, args) do
    GenServer.call(pid, {:call_method, bus, path, interface, method, args})
  end

  defp __register_object(%{registered_objects: objects} = state, path, pid) do
    # Do register
    objects = Map.put(objects, path, pid)
    Map.put(state, :registered_objects, objects)
  end

  defp __unregister_object(%{registered_objects: objects} = state, path) do
    # Do unregister
    objects = Map.delete(objects, path)
    Map.put(state, :registered_objects, objects)
  end

  defp __get_registered_object(%{registered_objects: objects}, path) do
    case Map.get(objects, path, nil) do
      nil ->
        {:error, "Object not registered"}

      pid ->
        if Process.alive?(pid) do
          {:ok, pid}
        else
          {:error, "Object service not alive"}
        end
    end
  end

  # handle_call

  @impl true
  def handle_call({:get_object, path}, _from, %{root: root} = state) do
    {:reply, Tree.find_path(root, path), state}
  end

  def handle_call({:get_interface, path, name}, _from, %{root: root} = state) do
    with {:ok, object} <- Tree.find_path(root, path) do
      {:reply, Tree.find_interface(object, name), state}
    else
      error -> {:reply, error, state}
    end
  end

  def handle_call(
        {:call_method, destination, path, interface, method, {signature, types, body}},
        from,
        %{bus: bus} = state
      ) do
    reply =
      GenServer.call(bus, {
        :call_method,
        destination,
        path,
        interface,
        method,
        {signature, types, body}
      })

    {:reply, reply, state}
    # Msg = dbus_message:call(Service, Path, IfaceName, Method),
    # case dbus_message:set_body(Method, Args, Msg) of
    #     #dbus_message{}=M2 ->
    #         case dbus_connection:call(Conn, M2) of
    #             {ok, #dbus_message{body=undefined}} ->
    #                 {reply, ok, State};
    #             {ok, #dbus_message{body=Res}} ->
    #                 {reply, {ok, Res}, State};
    #             {error, #dbus_message{body=Body}=Ret} ->
    #                 Code = dbus_message:get_field(?FIELD_ERROR_NAME, Ret),
    #                 {reply, {throw, {binary_to_atom(Code, utf8), Body}}, State}
    #         end;
    #     {error, Err} ->
    #         {reply, {error, Err}, State}
    # end.

    # :ok = :dbus_connection.cast(conn, msg)
  end

  def handle_call(
        {:register_object, path, server_pid},
        _from,
        state
      ) do
    case handle_call({:is_object_registered, path}, nil, state) do
      {:reply, false, state} ->
        {:reply, {:ok, server_pid}, __register_object(state, path, server_pid)}

      {:reply, true, state} ->
        {:reply, {:error, "Object path already registered to a server"}, state}
    end
  end

  def handle_call(
        {:unregister_object, path},
        _from,
        %{registered_objects: objects} = state
      ) do
    case handle_call({:is_object_registered, path}, nil, state) do
      {:reply, true, state} ->
        {:reply, {:ok, Map.get(objects, path)}, __unregister_object(state, path)}

      {:reply, false, state} ->
        {:reply, {:error, "Object path not registered"}, state}
    end
  end

  def handle_call({:is_object_registered, path}, _, %{registered_objects: objects} = state) do
    case Map.get(objects, path, nil) do
      nil ->
        {:reply, false, state}

      pid ->
        if Process.alive?(pid) do
          {:reply, true, state}
        else
          {:reply, false, __unregister_object(state, path)}
        end
    end
  end

  def handle_call({:replace_interface, path, interface}, _from, %{root: root} = state) do
    case Tree.replace_interface_at(root, path, interface) do
      {:ok, root} -> {:reply, :ok, Map.put(state, :root, root)}
      _ -> {:reply, :error, state}
    end
  end

  def handle_call(request, from, state) do
    IO.inspect(from, label: "[CALL] Message from")
    IO.inspect(request, label: "[CALL] Message request")
    {:noreply, state}
  end

  # handle_cast

  @impl true

  def handle_cast(request, state) do
    IO.inspect(request, label: "[CAST] Request")
    {:noreply, state}
  end

  # handle_info

  @impl true
  def handle_info({:dbus_method_call, msg, conn} = instr, state) do
    IO.inspect(msg, label: "----[INFO dbus_method_call]-----")
    path = ErlangDBus.Message.get_field(:path, msg)

    case __get_registered_object(state, path) do
      {:ok, handle} ->
        Process.send_after(handle, instr, 1, [])

      _ ->
        state = handle_dbus_method_call(msg, conn, state)
        {:noreply, state}
    end
  end

  def handle_info(message, state) do
    IO.inspect(message, label: "----[INFO]-----")
    {:noreply, state}
  end

  defp handle_dbus_method_call(msg, conn, state) do
    path = ErlangDBus.Message.get_field(:path, msg)
    interface = ErlangDBus.Message.get_field(:interface, msg)
    member = ErlangDBus.Message.get_field(:member, msg)

    signature =
      ErlangDBus.Message.find_field(:signature, msg)
      |> case do
        :undefined -> ""
        s -> s
      end

    body =
      case msg do
        {:dbus_message, _, :undefined} -> nil
        {:dbus_message, _, body} -> body
      end

    method = {path, interface, member, signature, body}

    reply =
      case exec_dbus_method_call(method, state) do
        :no_return ->
          :no_return

        {:ok, types, values} ->
          :dbus_message.return(msg, types, values)

        {:error, name, message} ->
          :dbus_message.error(msg, name, message)
      end

    unless reply == :no_return do
      :ok = :dbus_connection.cast(conn, reply)
    end

    state
  end

  def exec_dbus_method_call({path, interface_name, method_name, signature, args} = m, %{
        root: root
      }) do
    with {:object, {:ok, object}} <- {:object, Tree.find_path([root], path)},
         {:interface, {:ok, interface}} <-
           {:interface, Tree.find_interface(object, interface_name)},
         {:method, {:ok, method}} <-
           {:method, Tree.find_method(interface, method_name, signature)},
         {:callback, {:ok, callback}} <- {:callback, Tree.get_method_callback(method)} do
      call_method_callback(
        callback,
        method_name,
        args,
        %{
          node: object,
          path: path,
          interface: interface_name,
          method: method_name,
          signature: signature
        }
      )
    else
      {:object, _} ->
        {:error, "org.freedesktop.DBus.Error.UnknownObject",
         "No such object (#{path}) in the service"}

      {:interface, _} ->
        {:error, "org.freedesktop.DBus.Error.UnknownInterface",
         "Interface (#{interface_name}) not found at given path"}

      {:method, _} ->
        {:error, "org.freedesktop.DBus.Error.UnknownMethod",
         "Method (#{method_name}) not found on given interface"}

      {:callback, _} ->
        {:error, "org.freedesktop.DBus.Error.UnknownMethod",
         "Method not found on given interface"}
    end
  end

  def register_service(pid, service_name) do
    {:ok, bus} = ExDBus.Bus.start_link(:session)
    :ok = ExDBus.Bus.connect(bus, pid)
    :ok = ExDBus.Bus.register_service(bus, service_name, nil)
    {:ok, {bus, pid}}
  end

  defp call_method_callback(callback, method_name, args, context) when is_function(callback) do
    callback.(args, context)
  end

  defp call_method_callback({:call, pid, remote_method}, method_name, args, context) do
    GenServer.call(pid, {remote_method, method_name, args, context})
  end
end
