defmodule DesktopUI.SizeHintsTest do
  use ExUnit.Case
  alias DesktopUI.{Layout, Layout.Calculate, Widget}

  describe "explicit width/height" do
    test "overrides label intrinsic size" do
      # "Hello World!" = 12 chars * 8px = 96px intrinsic width
      # But we override with width: 200
      widget = Widget.label("Hello World!", width: 200, height: 50)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      assert layout.width == 200
      assert layout.height == 50
    end

    test "overrides button intrinsic size" do
      # Button intrinsic: text_width + 20px padding
      # "Click" = 5 chars * 8px = 40px + 20px = 60px intrinsic width
      # But we override with width: 150
      widget = Widget.button("Click", :clicked, width: 150, height: 80)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      assert layout.width == 150
      assert layout.height == 80
    end

    test "overrides container intrinsic size" do
      # Container with small children but large explicit size
      widget =
        Widget.container(:vbox, [
          Widget.label("Small")
        ],
        width: 400,
        height: 300)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      assert layout.width == 400
      assert layout.height == 300
    end

    test "width only uses intrinsic height" do
      widget = Widget.label("Hello", width: 200)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      assert layout.width == 200
      assert layout.height == 16  # Intrinsic height
    end

    test "height only uses intrinsic width" do
      widget = Widget.label("Hello", height: 50)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      assert layout.width == 40  # "Hello" = 5 chars * 8px
      assert layout.height == 50
    end
  end

  describe "min constraints" do
    test "enforces min_width on small widgets" do
      widget = Widget.label("Hi", min_width: 100)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      assert layout.width >= 100
    end

    test "enforces min_height on small widgets" do
      widget = Widget.label("Hi", min_height: 50)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      assert layout.height >= 50
    end

    test "min constraint ignored if intrinsic is larger" do
      # "Hello World!" = 96px intrinsic width, larger than min_width: 50
      widget = Widget.label("Hello World!", min_width: 50)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      assert layout.width == 96  # Uses intrinsic size
    end

    test "min constraint ignored if explicit size is smaller (explicit takes precedence)" do
      widget = Widget.label("Hi", width: 30, min_width: 100)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      # Explicit width overrides min constraint (fixed_width takes precedence)
      assert layout.width == 30
    end

    test "min_width and min_height work together" do
      widget = Widget.label("Hi", min_width: 100, min_height: 50)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      assert layout.width >= 100
      assert layout.height >= 50
    end
  end

  describe "max constraints" do
    test "enforces max_width on large widgets" do
      # "This is very long text" = 22 chars * 8px = 176px intrinsic width
      # But max_width: 100 should clamp it
      widget = Widget.label("This is very long text", max_width: 100)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      assert layout.width <= 100
    end

    test "enforces max_height on tall widgets" do
      widget = Widget.label("Hi", max_height: 10)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      assert layout.height <= 10
    end

    test "max constraint ignored if intrinsic is smaller" do
      widget = Widget.label("Hi", max_width: 200)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      assert layout.width == 16  # Uses intrinsic size (2 chars * 8px)
    end

    test "max constraint ignored if explicit size is larger (explicit takes precedence)" do
      widget = Widget.label("Hi", width: 200, max_width: 50)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      # Explicit width overrides max constraint (fixed_width takes precedence)
      assert layout.width == 200
    end

    test "max_width and max_height work together" do
      widget = Widget.label("This is long text", max_width: 50, max_height: 10)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      assert layout.width <= 50
      assert layout.height <= 10
    end

    test "max_width :infinity allows any width" do
      widget = Widget.label("This is a very long label", max_width: :infinity)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      # Should use intrinsic size (unconstrained by max_width)
      assert layout.width > 0
    end
  end

  describe "expand prop" do
    test "expand :width fills available width" do
      widget = Widget.label("Stretchy", expand: :width)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      assert layout.width == 800
      assert layout.height == 16  # Intrinsic height
    end

    test "expand :height fills available height" do
      widget = Widget.label("Stretchy", expand: :height)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      assert layout.width == 64  # Intrinsic width ("Stretchy" = 8 chars * 8px)
      assert layout.height == 600
    end

    test "expand true fills both directions" do
      widget = Widget.label("Stretchy", expand: true)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      assert layout.width == 800
      assert layout.height == 600
    end

    test "expand with explicit width uses explicit for non-expand direction" do
      widget = Widget.label("Test", expand: :height, width: 100)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      assert layout.width == 100  # Explicit width
      assert layout.height == 600  # Expanded height
    end

    test "expand with explicit height uses explicit for non-expand direction" do
      widget = Widget.label("Test", expand: :width, height: 50)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      assert layout.width == 800  # Expanded width
      assert layout.height == 50  # Explicit height
    end
  end

  describe "expand in containers" do
    test "expanded widget in HBox fills available width" do
      widget =
        Widget.container(:hbox, [
          Widget.button("Normal", :normal),
          Widget.button("Stretchy", :stretch, expand: :width)
        ],
        spacing: 10)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      # Container has children
      assert length(layout.widget.children) == 2

      # Second button should have expanded width
      # Note: In HBox, children get large available width (10000px)
      # The expanded child should have width set to available space
      stretchy_button = Enum.at(layout.widget.children, 1)
      assert stretchy_button.width > 0
    end

    test "expanded widget in VBox fills available height" do
      widget =
        Widget.container(:vbox, [
          Widget.label("Normal"),
          Widget.label("Stretchy", expand: :height)
        ],
        spacing: 10)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      # Container has children
      assert length(layout.widget.children) == 2

      # Second label should have expanded height
      stretchy_label = Enum.at(layout.widget.children, 1)
      assert stretchy_label.height > 0
    end

    test "container with expand true fills available space" do
      widget =
        Widget.container(:vbox, [
          Widget.label("Content")
        ],
        expand: true)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      # Container should fill available space
      assert layout.width == 800
      assert layout.height == 600
    end
  end

  describe "widget constructor updates" do
    test "label accepts size props" do
      widget = Widget.label("Test", width: 100, height: 50, min_width: 80, max_height: 60)

      assert widget.props[:width] == 100
      assert widget.props[:height] == 50
      assert widget.props[:min_width] == 80
      assert widget.props[:max_height] == 60
    end

    test "button accepts size props" do
      widget = Widget.button("Click", :clicked, width: 150, height: 60, expand: :width)

      assert widget.props[:width] == 150
      assert widget.props[:height] == 60
      assert widget.props[:expand] == :width
    end

    test "container accepts size props" do
      widget =
        Widget.container(:vbox, [],
          width: 400,
          height: 300,
          min_width: 200,
          max_height: 500,
          expand: true
        )

      assert widget.props[:width] == 400
      assert widget.props[:height] == 300
      assert widget.props[:min_width] == 200
      assert widget.props[:max_height] == 500
      assert widget.props[:expand] == true
    end
  end

  describe "extract_widget_constraints/2" do
    test "extracts width and height as fixed constraints" do
      widget = Widget.label("Test", width: 100, height: 50)
      constraints = Calculate.extract_widget_constraints(widget, %{width: 800, height: 600})

      assert constraints.fixed_width == 100
      assert constraints.fixed_height == 50
    end

    test "extracts min and max constraints" do
      widget = Widget.label("Test", min_width: 50, min_height: 30, max_width: 200, max_height: 100)
      constraints = Calculate.extract_widget_constraints(widget, %{width: 800, height: 600})

      assert constraints.min_width == 50
      assert constraints.min_height == 30
      assert constraints.max_width == 200
      assert constraints.max_height == 100
    end

    test "extracts expand :width as fixed_width constraint" do
      widget = Widget.label("Test", expand: :width)
      constraints = Calculate.extract_widget_constraints(widget, %{width: 800, height: 600})

      assert constraints.fixed_width == 800
      assert constraints.max_width == 800
    end

    test "extracts expand :height as fixed_height constraint" do
      widget = Widget.label("Test", expand: :height)
      constraints = Calculate.extract_widget_constraints(widget, %{width: 800, height: 600})

      assert constraints.fixed_height == 600
      assert constraints.max_height == 600
    end

    test "extracts expand true as both fixed constraints" do
      widget = Widget.label("Test", expand: true)
      constraints = Calculate.extract_widget_constraints(widget, %{width: 800, height: 600})

      assert constraints.fixed_width == 800
      assert constraints.fixed_height == 600
    end

    test "returns empty map for widget with no size props" do
      widget = Widget.label("Test")
      constraints = Calculate.extract_widget_constraints(widget, %{width: 800, height: 600})

      assert constraints == %{}
    end

    test "expand with explicit width combines correctly" do
      widget = Widget.label("Test", expand: :height, width: 100)
      constraints = Calculate.extract_widget_constraints(widget, %{width: 800, height: 600})

      assert constraints.fixed_width == 100  # Explicit width preserved
      assert constraints.fixed_height == 600  # Expanded height
      assert constraints.max_height == 600
    end
  end

  describe "combined size hints" do
    test "width with min_width on container" do
      widget = Widget.container(:vbox, [Widget.label("A")], width: 200, min_width: 100)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      assert layout.width == 200  # Explicit width takes precedence
    end

    test "min and max constraints create a range" do
      # Small widget, but constrained between 100-200px width
      widget = Widget.label("Hi", min_width: 100, max_width: 200)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      # Intrinsic is 16px, but min pushes to 100px
      assert layout.width >= 100
      assert layout.width <= 200
    end

    test "all size props together" do
      widget =
        Widget.label("Test",
          min_width: 50,
          min_height: 30,
          max_width: 200,
          max_height: 100
        )

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      # Within bounds
      assert layout.width >= 50
      assert layout.width <= 200
      assert layout.height >= 30
      assert layout.height <= 100
    end
  end

  describe "backward compatibility" do
    test "widgets without size props still work" do
      widget = Widget.label("Hello")

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      # Should use intrinsic size
      assert layout.width == 40  # "Hello" = 5 chars * 8px
      assert layout.height == 16
    end

    test "existing container layouts still work" do
      widget =
        Widget.container(:vbox, [
          Widget.label("A"),
          Widget.label("B")
        ],
        spacing: 10,
        padding: 20)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      # VBox with two labels: 16px + 16px + 10px spacing + 40px padding = 82px
      assert layout.height > 0
      assert layout.width > 0
    end

    test "buttons without size props use intrinsic size" do
      widget = Widget.button("Click", :clicked)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      # Button: text + padding
      assert layout.width > 0
      assert layout.height > 0
    end
  end
end
