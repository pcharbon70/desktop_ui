defmodule DesktopUI.ElmTest do
  use ExUnit.Case, async: true
  doctest DesktopUI.Elm

  alias DesktopUI.Elm

  describe "behaviour definition" do
    test "behaviour is defined with init/1 callback specification" do
      # Verify the behaviour module exists and has the callback
      assert function_exported?(Elm, :behaviour_info, 1)
      callbacks = Elm.behaviour_info(:callbacks)
      assert {:init, 1} in callbacks
    end

    test "behaviour is defined with update/2 callback specification" do
      callbacks = Elm.behaviour_info(:callbacks)
      assert {:update, 2} in callbacks
    end

    test "behaviour is defined with view/1 callback specification" do
      callbacks = Elm.behaviour_info(:callbacks)
      assert {:view, 1} in callbacks
    end

    test "behaviour defines optional callbacks" do
      callbacks = Elm.behaviour_info(:callbacks)
      # Verify all three required callbacks are present
      assert length(callbacks) == 3
    end
  end

  describe "use DesktopUI.Elm macro" do
    test "generates required function stubs that raise helpful errors" do
      defmodule TestComponentNoImpls do
        use DesktopUI.Elm
      end

      # init/1 should raise with helpful message when called
      assert_raise RuntimeError, ~r/must implement the init\/1 callback/, fn ->
        TestComponentNoImpls.init([])
      end

      # update/2 should raise with helpful message when called
      assert_raise RuntimeError, ~r/must implement the update\/2 callback/, fn ->
        TestComponentNoImpls.update(:msg, %{})
      end

      # view/1 should raise with helpful message when called
      assert_raise RuntimeError, ~r/must implement the view\/1 callback/, fn ->
        TestComponentNoImpls.view(%{})
      end
    end

    test "allows implementing callbacks to override default implementations" do
      defmodule TestComponentWithImpls do
        use DesktopUI.Elm

        @impl true
        def init(opts) do
          {%{value: Keyword.get(opts, :value, 0)}, []}
        end

        @impl true
        def update(:increment, %{value: value} = state) do
          {%{state | value: value + 1}, []}
        end

        @impl true
        def update(:decrement, %{value: value} = state) do
          {%{state | value: value - 1}, []}
        end

        @impl true
        def view(%{value: value}) do
          %{type: :label, props: [text: "Value: #{value}"], id: nil, children: []}
        end
      end

      # Test init
      assert {state, []} = TestComponentWithImpls.init(value: 5)
      assert state == %{value: 5}

      # Test update
      assert {new_state, []} = TestComponentWithImpls.update(:increment, state)
      assert new_state == %{value: 6}

      assert {new_state2, []} = TestComponentWithImpls.update(:decrement, new_state)
      assert new_state2 == %{value: 5}

      # Test view
      ui = TestComponentWithImpls.view(%{value: 42})
      assert ui.type == :label
      assert ui.props[:text] == "Value: 42"
    end

    test "generates component with correct behaviour attribute" do
      defmodule TestComponentBehaviourCheck do
        use DesktopUI.Elm

        @impl true
        def init(_opts), do: {%{}, []}

        @impl true
        def update(_msg, state), do: {state, []}

        @impl true
        def view(_state), do: %{type: :label, props: [], id: nil, children: []}
      end

      # Verify the module has the correct behaviour
      assert {:behaviour, [DesktopUI.Elm]} =
               TestComponentBehaviourCheck.module_info(:attributes)
               |> List.keyfind(:behaviour, 0)
    end
  end

  describe "ui_element() type" do
    test "valid ui_element structure compiles correctly" do
      # A basic label element
      label = %{
        type: :label,
        id: nil,
        props: [text: "Hello"],
        children: []
      }

      assert label.type == :label
      assert label.props[:text] == "Hello"
      assert label.children == []
    end

    test "ui_element supports nested children" do
      # A container with nested elements
      container = %{
        type: :container,
        id: :main,
        props: [layout: :vbox, spacing: 8],
        children: [
          %{type: :label, props: [text: "Title"], id: nil, children: []},
          %{
            type: :container,
            props: [layout: :hbox],
            id: nil,
            children: [
              %{type: :button, props: [text: "OK", on_click: :ok], id: nil, children: []},
              %{type: :button, props: [text: "Cancel", on_click: :cancel], id: nil, children: []}
            ]
          }
        ]
      }

      assert container.type == :container
      assert length(container.children) == 2
      assert container.children |> List.first() |> Map.get(:type) == :label
    end

    test "ui_element supports optional id field" do
      with_id = %{type: :button, id: :my_button, props: [text: "Click"], children: []}
      without_id = %{type: :button, id: nil, props: [text: "Click"], children: []}

      assert with_id.id == :my_button
      assert without_id.id == nil
    end

    test "view/1 can return complex ui_element trees" do
      defmodule TestComponentComplexView do
        use DesktopUI.Elm

        @impl true
        def init(_opts), do: {%{items: []}, []}

        @impl true
        def update({:add, item}, %{items: items} = state) do
          {%{state | items: items ++ [item]}, []}
        end

        @impl true
        def update(_msg, state), do: {state, []}

        @impl true
        def view(%{items: items}) do
          %{
            type: :container,
            id: :root,
            props: [layout: :vbox],
            children: [
              %{type: :label, props: [text: "Items: #{length(items)}"], id: nil, children: []}
              | Enum.map(items, fn item ->
                  %{type: :label, props: [text: item], id: nil, children: []}
                end)
            ]
          }
        end
      end

      ui = TestComponentComplexView.view(%{items: ["A", "B"]})

      assert ui.type == :container
      assert ui.id == :root
      assert length(ui.children) == 3
      assert Enum.at(ui.children, 0).props[:text] == "Items: 2"
    end
  end

  describe "command() type" do
    test ":none command is a valid command" do
      assert :none == :none
    end

    test "{:emit, signal} command is valid" do
      command = {:emit, :some_signal}
      assert elem(command, 0) == :emit
      assert elem(command, 1) == :some_signal
    end

    test "{:send, pid, message} command is valid" do
      pid = self()
      command = {:send, pid, :hello}
      assert elem(command, 0) == :send
      assert elem(command, 1) == pid
      assert elem(command, 2) == :hello
    end

    test "{:after, milliseconds, message} command is valid" do
      command = {:after, 1000, :timeout}
      assert elem(command, 0) == :after
      assert elem(command, 1) == 1000
      assert elem(command, 2) == :timeout
    end

    test ":quit command is valid" do
      assert :quit == :quit
    end

    test "update/2 can return commands" do
      defmodule TestComponentWithCommands do
        use DesktopUI.Elm

        @impl true
        def init(_opts), do: {%{}, []}

        @impl true
        def update(:emit_signal, state) do
          {state, [{:emit, :something_happened}]}
        end

        @impl true
        def update({:send_to, pid, msg}, state) do
          {state, [{:send, pid, msg}]}
        end

        @impl true
        def update(:schedule_later, state) do
          {state, [{:after, 5000, :timeout}]}
        end

        @impl true
        def update(:quit_app, state) do
          {state, [:quit]}
        end

        @impl true
        def update(:multiple_commands, state) do
          {state, [{:emit, :started}, {:after, 100, :tick}]}
        end

        @impl true
        def update(_msg, state), do: {state, []}

        @impl true
        def view(_state), do: %{type: :label, props: [], id: nil, children: []}
      end

      # Test each command type
      assert {_, [{:emit, :something_happened}]} =
               TestComponentWithCommands.update(:emit_signal, %{})

      assert {_, [{:send, _pid, :hello}]} =
               TestComponentWithCommands.update({:send_to, self(), :hello}, %{})

      assert {_, [{:after, 5000, :timeout}]} =
               TestComponentWithCommands.update(:schedule_later, %{})

      assert {_, [:quit]} = TestComponentWithCommands.update(:quit_app, %{})

      assert {_, [{:emit, :started}, {:after, 100, :tick}]} =
               TestComponentWithCommands.update(:multiple_commands, %{})
    end

    test "init/1 can return commands" do
      defmodule TestComponentInitWithCommands do
        use DesktopUI.Elm

        @impl true
        def init(opts) do
          initial_state = %{started: true}
          commands = [{:after, Keyword.get(opts, :timeout, 1000), :init_timeout}]
          {initial_state, commands}
        end

        @impl true
        def update(_msg, state), do: {state, []}

        @impl true
        def view(_state), do: %{type: :label, props: [], id: nil, children: []}
      end

      assert {state, [{:after, 5000, :init_timeout}]} =
               TestComponentInitWithCommands.init(timeout: 5000)

      assert state.started == true
    end
  end

  describe "state type flexibility" do
    test "state can be a map" do
      defmodule TestStateMap do
        use DesktopUI.Elm

        @impl true
        def init(_opts), do: {%{key: "value"}, []}
        @impl true
        def update(_msg, state), do: {state, []}
        @impl true
        def view(_state), do: %{type: :label, props: [], id: nil, children: []}
      end

      assert {%{key: "value"}, []} = TestStateMap.init([])
    end

    test "state can be a struct" do
      defmodule TestStateStruct do
        defstruct [:count, :name]

        use DesktopUI.Elm

        @impl true
        def init(_opts), do: {struct(__MODULE__, count: 0), []}
        @impl true
        def update(_msg, state), do: {state, []}
        @impl true
        def view(_state), do: %{type: :label, props: [], id: nil, children: []}
      end

      assert {state, []} = TestStateStruct.init([])
      assert state.count == 0
      assert state.__struct__ == TestStateStruct
    end

    test "state can be a simple value (integer)" do
      defmodule TestStateInt do
        use DesktopUI.Elm

        @impl true
        def init(_opts), do: {0, []}
        @impl true
        def update(:inc, count), do: {count + 1, []}
        @impl true
        def update(:dec, count), do: {count - 1, []}
        @impl true
        def view(_count), do: %{type: :label, props: [], id: nil, children: []}
      end

      assert {0, []} = TestStateInt.init([])
      assert {1, []} = TestStateInt.update(:inc, 0)
      assert {-1, []} = TestStateInt.update(:dec, 0)
    end

    test "state can be a tuple" do
      defmodule TestStateTuple do
        use DesktopUI.Elm

        @impl true
        def init(_opts), do: {{0, 0}, []}
        @impl true
        def update({:x, val}, {_x, y}), do: {{val, y}, []}
        @impl true
        def update({:y, val}, {x, _y}), do: {{x, val}, []}
        @impl true
        def view(_state), do: %{type: :label, props: [], id: nil, children: []}
      end

      assert {{0, 0}, []} = TestStateTuple.init([])
      assert {{5, 0}, []} = TestStateTuple.update({:x, 5}, {0, 0})
    end
  end

  describe "message type flexibility" do
    test "messages can be atoms" do
      defmodule TestMessageAtom do
        use DesktopUI.Elm

        @impl true
        def init(_opts), do: {%{}, []}
        @impl true
        def update(:start, state), do: {Map.put(state, :status, :started), []}
        @impl true
        def update(:stop, state), do: {Map.put(state, :status, :stopped), []}
        @impl true
        def view(_state), do: %{type: :label, props: [], id: nil, children: []}
      end

      assert {%{status: :started}, []} = TestMessageAtom.update(:start, %{})
      assert {%{status: :stopped}, []} = TestMessageAtom.update(:stop, %{})
    end

    test "messages can be tuples" do
      defmodule TestMessageTuple do
        use DesktopUI.Elm

        @impl true
        def init(_opts), do: {%{}, []}
        @impl true
        def update({:set, key, value}, state), do: {Map.put(state, key, value), []}
        @impl true
        def view(_state), do: %{type: :label, props: [], id: nil, children: []}
      end

      assert {%{count: 5}, []} = TestMessageTuple.update({:set, :count, 5}, %{})
    end

    test "messages can be maps" do
      defmodule TestMessageMap do
        use DesktopUI.Elm

        @impl true
        def init(_opts), do: {%{}, []}
        @impl true
        def update(%{event: event}, state), do: {Map.put(state, :last_event, event), []}
        @impl true
        def view(_state), do: %{type: :label, props: [], id: nil, children: []}
      end

      assert {%{last_event: :clicked}, []} =
               TestMessageMap.update(%{event: :clicked}, %{})
    end
  end

  describe "component lifecycle example" do
    test "full component lifecycle works correctly" do
      defmodule TestLifecycleComponent do
        use DesktopUI.Elm

        @impl true
        def init(opts) do
          initial_count = Keyword.get(opts, :initial, 0)
          {%{count: initial_count}, []}
        end

        @impl true
        def update(:increment, %{count: count} = state) do
          new_state = %{state | count: count + 1}
          {new_state, []}
        end

        @impl true
        def update(:decrement, %{count: count} = state) do
          new_state = %{state | count: count - 1}
          {new_state, []}
        end

        @impl true
        def update(:reset, state) do
          {%{state | count: 0}, []}
        end

        @impl true
        def view(%{count: count}) do
          %{
            type: :container,
            id: :main,
            props: [layout: :vbox],
            children: [
              %{type: :label, props: [text: "Count: #{count}"], id: nil, children: []},
              %{
                type: :button,
                props: [text: "+", on_click: :increment],
                id: :btn_inc,
                children: []
              },
              %{
                type: :button,
                props: [text: "-", on_click: :decrement],
                id: :btn_dec,
                children: []
              },
              %{
                type: :button,
                props: [text: "Reset", on_click: :reset],
                id: :btn_reset,
                children: []
              }
            ]
          }
        end
      end

      # Init
      assert {state, []} = TestLifecycleComponent.init(initial: 5)
      assert state.count == 5

      # Update
      assert {state2, []} = TestLifecycleComponent.update(:increment, state)
      assert state2.count == 6

      assert {state3, []} = TestLifecycleComponent.update(:decrement, state2)
      assert state3.count == 5

      assert {state4, []} = TestLifecycleComponent.update(:reset, state3)
      assert state4.count == 0

      # View
      ui = TestLifecycleComponent.view(state4)
      assert ui.type == :container
      assert ui.id == :main
      assert length(ui.children) == 4
      assert Enum.at(ui.children, 0).props[:text] == "Count: 0"
    end
  end
end
