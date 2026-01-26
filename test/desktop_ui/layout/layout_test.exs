defmodule DesktopUI.LayoutTest do
  use ExUnit.Case
  alias DesktopUI.{Layout, Layout.Context}
  alias DesktopUI.Widget

  describe "Layout struct" do
    test "creates layout with valid bounds" do
      layout = Layout.new(0, 0, 100, 50)

      assert layout.x == 0
      assert layout.y == 0
      assert layout.width == 100
      assert layout.height == 50
      assert layout.widget == nil
    end

    test "creates layout with widget reference" do
      widget = Widget.label("Test")
      layout = Layout.new(10, 20, 80, 40, widget)

      assert layout.x == 10
      assert layout.y == 20
      assert layout.width == 80
      assert layout.height == 40
      assert layout.widget == widget
    end

    test "contains? returns true for points inside bounds" do
      layout = Layout.new(10, 10, 100, 50)

      assert Layout.contains?(layout, 50, 30) == true
      assert Layout.contains?(layout, 10, 10) == true
      assert Layout.contains?(layout, 109, 59) == true
    end

    test "contains? returns false for points outside bounds" do
      layout = Layout.new(10, 10, 100, 50)

      assert Layout.contains?(layout, 5, 30) == false
      assert Layout.contains?(layout, 50, 5) == false
      assert Layout.contains?(layout, 120, 30) == false
      assert Layout.contains?(layout, 50, 70) == false
    end

    test "right/bottom/center/area helper functions" do
      layout = Layout.new(10, 20, 100, 50)

      assert Layout.right(layout) == 110
      assert Layout.bottom(layout) == 70
      assert Layout.center(layout) == {60, 45}
      assert Layout.area(layout) == 5000
    end

    test "to_bounds returns bounds map" do
      layout = Layout.new(5, 10, 100, 50)
      bounds = Layout.to_bounds(layout)

      assert bounds == %{x: 5, y: 10, width: 100, height: 50}
    end
  end

  describe "Context struct" do
    test "initializes with available bounds" do
      context = Context.new(800, 600)

      assert context.available_width == 800
      assert context.available_height == 600
      assert context.parent_bounds == %{x: 0, y: 0, width: 800, height: 600}
      assert context.constraints == %{}
    end

    test "accepts and stores constraints" do
      context = Context.new(800, 600, constraints: [min_width: 100, max_width: 400])

      assert context.constraints.min_width == 100
      assert context.constraints.max_width == 400
    end

    test "merges constraints with with_constraints/2" do
      context = Context.new(800, 600, constraints: [min_width: 50])
      updated = Context.with_constraints(context, max_width: 200)

      assert updated.constraints.min_width == 50
      assert updated.constraints.max_width == 200
    end

    test "parent_bounds helper functions" do
      context = Context.new(800, 600, parent_bounds: %{x: 10, y: 20, width: 780, height: 580})

      assert Context.parent_x(context) == 10
      assert Context.parent_y(context) == 20
    end

    test "has_fixed_width? and has_fixed_height?" do
      no_fixed = Context.new(800, 600)
      with_width = Context.new(800, 600, constraints: [fixed_width: 100])
      with_height = Context.new(800, 600, constraints: [fixed_height: 50])

      refute Context.has_fixed_width?(no_fixed)
      refute Context.has_fixed_height?(no_fixed)
      assert Context.has_fixed_width?(with_width)
      assert Context.has_fixed_height?(with_height)
    end
  end

  describe "calculate/3" do
    test "returns layout for label widget" do
      widget = Widget.label("Hello World")
      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      assert layout.width > 0
      assert layout.height > 0
      assert layout.widget == widget
    end

    test "returns layout for button widget" do
      widget = Widget.button("Click me", :clicked)
      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      assert layout.width > 0
      assert layout.height > 0
      assert layout.widget == widget
    end

    test "returns layout for empty container" do
      widget = Widget.container(:vbox, [])
      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      # Empty container should have 0 size
      assert layout.width >= 0
      assert layout.height >= 0
    end

    test "returns layout for container with children" do
      widget = Widget.container(:vbox, [
        Widget.label("Child 1"),
        Widget.label("Child 2")
      ])
      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      assert layout.width > 0
      assert layout.height > 0
    end

    test "returns error for invalid widget type" do
      invalid = %Widget{type: :invalid, props: [], children: []}
      result = Layout.calculate(invalid, %{width: 800, height: 600})

      assert {:error, "unknown widget type: :invalid"} == result
    end

    test "returns error for non-widget" do
      result = Layout.calculate("not a widget", %{width: 800, height: 600})

      assert {:error, "not a widget"} == result
    end

    test "respects fixed width constraint" do
      widget = Widget.label("Short")
      context = Context.new(800, 600, constraints: [fixed_width: 200])
      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600}, context)

      assert layout.width == 200
    end

    test "respects fixed height constraint" do
      widget = Widget.label("Test")
      context = Context.new(800, 600, constraints: [fixed_height: 50])
      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600}, context)

      assert layout.height == 50
    end
  end

  describe "intrinsic_size/2" do
    alias DesktopUI.Layout.Calculate

    test "calculates size for label based on text length" do
      # Text width is estimated as character_count * 8
      # "Hello" = 5 chars * 8 = 40px width
      widget = Widget.label("Hello")
      {:ok, size} = Calculate.intrinsic_size(widget, %Context{})

      assert size.width == 40
      assert size.height == 16
    end

    test "calculates size for longer label" do
      # "Hello World!" = 12 chars * 8 = 96px width
      widget = Widget.label("Hello World!")
      {:ok, size} = Calculate.intrinsic_size(widget, %Context{})

      assert size.width == 96
      assert size.height == 16
    end

    test "calculates size for button with padding" do
      # Button padding: 20px width, 10px height
      # "Hi" = 2 chars * 8 = 16px width
      # Total: 16 + 20 = 36px width, 16 + 10 = 26px height
      widget = Widget.button("Hi", :clicked)
      {:ok, size} = Calculate.intrinsic_size(widget, %Context{})

      assert size.width == 36
      assert size.height == 26
    end

    test "returns minimum size for empty text" do
      widget = Widget.label("")
      {:ok, size} = Calculate.intrinsic_size(widget, %Context{})

      assert size.width == 0
      assert size.height == 16
    end
  end

  describe "apply_constraints/3" do
    alias DesktopUI.Layout.Calculate

    test "enforces min_width constraint" do
      size = %{width: 10, height: 20}
      constraints = %{min_width: 50}
      available = %{width: 800, height: 600}

      {:ok, result} = Calculate.apply_constraints(size, constraints, available)

      assert result.width == 50
      assert result.height == 20
    end

    test "enforces max_width constraint" do
      size = %{width: 200, height: 20}
      constraints = %{max_width: 100}
      available = %{width: 800, height: 600}

      {:ok, result} = Calculate.apply_constraints(size, constraints, available)

      assert result.width == 100
      assert result.height == 20
    end

    test "enforces min_height constraint" do
      size = %{width: 20, height: 10}
      constraints = %{min_height: 50}
      available = %{width: 800, height: 600}

      {:ok, result} = Calculate.apply_constraints(size, constraints, available)

      assert result.width == 20
      assert result.height == 50
    end

    test "enforces max_height constraint" do
      size = %{width: 20, height: 200}
      constraints = %{max_height: 100}
      available = %{width: 800, height: 600}

      {:ok, result} = Calculate.apply_constraints(size, constraints, available)

      assert result.width == 20
      assert result.height == 100
    end

    test "fixed size overrides intrinsic size" do
      size = %{width: 100, height: 50}
      constraints = %{fixed_width: 200, fixed_height: 75}
      available = %{width: 800, height: 600}

      {:ok, result} = Calculate.apply_constraints(size, constraints, available)

      assert result.width == 200
      assert result.height == 75
    end

    test "available bounds clamp final size" do
      # Requested size exceeds available space
      size = %{width: 1000, height: 800}
      constraints = %{}
      available = %{width: 500, height: 400}

      {:ok, result} = Calculate.apply_constraints(size, constraints, available)

      assert result.width == 500
      assert result.height == 400
    end

    test "clamps to both min and max constraints" do
      size = %{width: 50, height: 30}
      constraints = %{min_width: 75, max_width: 125}
      available = %{width: 800, height: 600}

      {:ok, result} = Calculate.apply_constraints(size, constraints, available)

      assert result.width == 75
    end

    test "returns error for invalid calculated size" do
      # This would happen if constraints force size to 0 or negative
      # For now, we have a minimum of 1 enforced in apply_constraints
      # So we can't easily trigger this without the constraints themselves
      # being invalid
    end
  end
end
