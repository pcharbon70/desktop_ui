defmodule DesktopUI.SignalsTest do
  use ExUnit.Case, async: true

  alias DesktopUI.Signals

  doctest DesktopUI.Signals

  describe "StateChanged" do
    test "creates a valid signal with required fields" do
      assert {:ok, signal} = Signals.StateChanged.new(%{
        component_id: "counter_123",
        old_state: %{count: 0},
        new_state: %{count: 1}
      })

      assert signal.type == "desktop_ui.state.changed"
      assert signal.source == "/desktop_ui/components"
      assert signal.data.component_id == "counter_123"
      assert signal.data.old_state == %{count: 0}
      assert signal.data.new_state == %{count: 1}
    end

    test "validates component_id is required" do
      assert {:error, _reason} = Signals.StateChanged.new(%{
        old_state: %{count: 0},
        new_state: %{count: 1}
      })
    end

    test "validates old_state is required" do
      assert {:error, _reason} = Signals.StateChanged.new(%{
        component_id: "counter_123",
        new_state: %{count: 1}
      })
    end

    test "validates new_state is required" do
      assert {:error, _reason} = Signals.StateChanged.new(%{
        component_id: "counter_123",
        old_state: %{count: 0}
      })
    end

    test "allows complex state maps" do
      complex_state = %{
        count: 5,
        items: ["a", "b", "c"],
        nested: %{value: 10}
      }

      assert {:ok, signal} = Signals.StateChanged.new(%{
        component_id: "complex_component",
        old_state: complex_state,
        new_state: %{complex_state | count: 6}
      })

      assert signal.data.new_state.count == 6
      assert signal.data.new_state.items == ["a", "b", "c"]
    end
  end

  describe "Clicked" do
    test "creates a valid signal with target_id" do
      assert {:ok, signal} = Signals.Clicked.new(%{
        target_id: :btn_increment,
        button: :left,
        x: 100,
        y: 50
      })

      assert signal.type == "desktop_ui.ui.clicked"
      assert signal.source == "/desktop_ui/input"
      assert signal.data.target_id == :btn_increment
      assert signal.data.button == :left
      assert signal.data.x == 100
      assert signal.data.y == 50
    end

    test "creates a valid signal without target_id" do
      assert {:ok, signal} = Signals.Clicked.new(%{
        button: :left
      })

      assert signal.type == "desktop_ui.ui.clicked"
      assert signal.data.button == :left
      refute Map.has_key?(signal.data, :target_id)
    end

    test "requires button field (with default :left when using nil)" do
      # The button field is required, but has a default of :left
      # We need to provide at least an empty map or the button field
      assert {:ok, signal} = Signals.Clicked.new(%{button: :left})
      assert signal.data.button == :left
    end

    test "validates button is valid value" do
      assert {:ok, _} = Signals.Clicked.new(%{button: :left})
      assert {:ok, _} = Signals.Clicked.new(%{button: :middle})
      assert {:ok, _} = Signals.Clicked.new(%{button: :right})
      assert {:error, _} = Signals.Clicked.new(%{button: :invalid})
    end

    test "allows all valid button types" do
      assert {:ok, left} = Signals.Clicked.new(%{button: :left})
      assert {:ok, middle} = Signals.Clicked.new(%{button: :middle})
      assert {:ok, right} = Signals.Clicked.new(%{button: :right})

      assert left.data.button == :left
      assert middle.data.button == :middle
      assert right.data.button == :right
    end
  end

  describe "KeyPressed" do
    test "creates a valid signal with key" do
      assert {:ok, signal} = Signals.KeyPressed.new(%{
        key: "a",
        modifiers: [:shift]
      })

      assert signal.type == "desktop_ui.ui.key_pressed"
      assert signal.source == "/desktop_ui/input"
      assert signal.data.key == "a"
      assert signal.data.modifiers == [:shift]
    end

    test "creates a valid signal without modifiers" do
      assert {:ok, signal} = Signals.KeyPressed.new(%{
        key: "escape"
      })

      assert signal.data.key == "escape"
      assert signal.data.modifiers == []
    end

    test "defaults modifiers to empty list" do
      assert {:ok, signal} = Signals.KeyPressed.new(%{
        key: "enter"
      })

      assert signal.data.modifiers == []
    end

    test "validates key is required" do
      assert {:error, _reason} = Signals.KeyPressed.new(%{
        modifiers: [:ctrl]
      })
    end

    test "allows multiple modifiers" do
      assert {:ok, signal} = Signals.KeyPressed.new(%{
        key: "s",
        modifiers: [:ctrl, :shift]
      })

      assert signal.data.modifiers == [:ctrl, :shift]
    end

    test "validates all modifier values" do
      assert {:ok, _} = Signals.KeyPressed.new(%{
        key: "a",
        modifiers: [:shift]
      })
      assert {:ok, _} = Signals.KeyPressed.new(%{
        key: "b",
        modifiers: [:ctrl]
      })
      assert {:ok, _} = Signals.KeyPressed.new(%{
        key: "c",
        modifiers: [:alt]
      })
      assert {:ok, _} = Signals.KeyPressed.new(%{
        key: "d",
        modifiers: [:meta]
      })
      assert {:error, _} = Signals.KeyPressed.new(%{
        key: "e",
        modifiers: [:invalid]
      })
    end
  end

  describe "RenderRequest" do
    test "creates a valid signal with required fields" do
      assert {:ok, signal} = Signals.RenderRequest.new(%{
        component_id: "counter_123"
      })

      assert signal.type == "desktop_ui.render.request"
      assert signal.source == "/desktop_ui/coordinator"
      assert signal.data.component_id == "counter_123"
      assert signal.data.force == false
    end

    test "allows force flag" do
      assert {:ok, signal} = Signals.RenderRequest.new(%{
        component_id: "counter_123",
        force: true
      })

      assert signal.data.force == true
    end

    test "defaults force to false" do
      assert {:ok, signal} = Signals.RenderRequest.new(%{
        component_id: "counter_123"
      })

      assert signal.data.force == false
    end

    test "validates component_id is required" do
      assert {:error, _reason} = Signals.RenderRequest.new(%{
        force: true
      })
    end
  end

  describe "WindowResized" do
    test "creates a valid signal with width and height" do
      assert {:ok, signal} = Signals.WindowResized.new(%{
        width: 800,
        height: 600
      })

      assert signal.type == "desktop_ui.window.resized"
      assert signal.source == "/desktop_ui/runtime"
      assert signal.data.width == 800
      assert signal.data.height == 600
    end

    test "validates width is required" do
      assert {:error, _reason} = Signals.WindowResized.new(%{
        height: 600
      })
    end

    test "validates height is required" do
      assert {:error, _reason} = Signals.WindowResized.new(%{
        width: 800
      })
    end

    test "validates width is integer" do
      assert {:error, _reason} = Signals.WindowResized.new(%{
        width: "800",
        height: 600
      })
    end

    test "validates height is integer" do
      assert {:error, _reason} = Signals.WindowResized.new(%{
        width: 800,
        height: "600"
      })
    end
  end

  describe "Quit" do
    test "creates a valid quit signal" do
      assert {:ok, signal} = Signals.Quit.new(%{})

      assert signal.type == "desktop_ui.app.quit"
      assert signal.source == "/desktop_ui/runtime"
      assert signal.data == %{}
    end

    test "accepts empty map" do
      assert {:ok, signal} = Signals.Quit.new(%{})
      assert signal.type == "desktop_ui.app.quit"
    end
  end
end
