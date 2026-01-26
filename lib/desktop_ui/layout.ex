defmodule DesktopUI.Layout do
  @moduledoc """
  Layout structure representing calculated widget bounds.

  Each layout contains the position and size of a widget within
  a container, along with a reference to the original widget.

  ## Layout Structure

  A layout contains:
  - `x` - X position in pixels (from left edge of parent)
  - `y` - Y position in pixels (from top edge of parent)
  - `width` - Width in pixels
  - `height` - Height in pixels
  - `widget` - Reference to the original widget (for hit testing, rendering)

  ## Examples

      iex> alias DesktopUI.Layout
      iex> Layout.new(0, 0, 100, 50)
      %Layout{x: 0, y: 0, width: 100, height: 50, widget: nil}

      iex> alias DesktopUI.{Layout, Widget}
      iex> widget = Widget.label("Hello")
      iex> Layout.new(10, 20, 80, 30, widget)
      %Layout{x: 10, y: 20, width: 80, height: 30, widget: widget}

  """

  defstruct [:x, :y, :width, :height, :widget]

  @type t :: %__MODULE__{
          x: non_neg_integer(),
          y: non_neg_integer(),
          width: pos_integer(),
          height: pos_integer(),
          widget: DesktopUI.Widget.t() | nil
        }

  @type bounds :: %{
          x: non_neg_integer(),
          y: non_neg_integer(),
          width: pos_integer(),
          height: pos_integer()
        }

  @doc """
  Creates a new layout with the given bounds.

  ## Parameters

  - `x` - X position in pixels
  - `y` - Y position in pixels
  - `width` - Width in pixels (must be positive)
  - `height` - Height in pixels (must be positive)
  - `widget` - Optional widget reference

  ## Examples

      iex> Layout.new(0, 0, 100, 50)
      %Layout{x: 0, y: 0, width: 100, height: 50, widget: nil}

      iex> alias DesktopUI.Widget
      iex> widget = Widget.label("Hello")
      iex> Layout.new(10, 10, 80, 40, widget)
      %Layout{x: 10, y: 10, width: 80, height: 40, widget: widget}

  """
  @spec new(non_neg_integer(), non_neg_integer(), pos_integer(), pos_integer(), DesktopUI.Widget.t() | nil) :: t()
  def new(x, y, width, height, widget \\ nil)

  def new(x, y, width, height, widget)
      when is_integer(x) and x >= 0 and is_integer(y) and y >= 0 and
           is_integer(width) and width > 0 and is_integer(height) and height > 0 do
    %__MODULE__{
      x: x,
      y: y,
      width: width,
      height: height,
      widget: widget
    }
  end

  @doc """
  Returns true if the given point (x, y) is within this layout's bounds.

  Uses inclusive bounds testing: points on the edge are considered inside.

  ## Parameters

  - `layout` - The layout to test
  - `x` - X coordinate to test
  - `y` - Y coordinate to test

  ## Examples

      iex> layout = Layout.new(10, 10, 100, 50)
      iex> Layout.contains?(layout, 50, 30)
      true

      iex> layout = Layout.new(10, 10, 100, 50)
      iex> Layout.contains?(layout, 5, 30)
      false

      iex> layout = Layout.new(0, 0, 100, 100)
      iex> Layout.contains?(layout, 100, 50)
      true

  """
  @spec contains?(t(), non_neg_integer(), non_neg_integer()) :: boolean()
  def contains?(%__MODULE__{} = layout, x, y) do
    x >= layout.x and x < layout.x + layout.width and
      y >= layout.y and y < layout.y + layout.height
  end

  @doc """
  Returns the right edge X coordinate of the layout.
  """
  @spec right(t()) :: non_neg_integer()
  def right(%__MODULE__{x: x, width: width}), do: x + width

  @doc """
  Returns the bottom edge Y coordinate of the layout.
  """
  @spec bottom(t()) :: non_neg_integer()
  def bottom(%__MODULE__{y: y, height: height}), do: y + height

  @doc """
  Returns the center point of the layout as {x, y}.
  """
  @spec center(t()) :: {non_neg_integer(), non_neg_integer()}
  def center(%__MODULE__{x: x, y: y, width: width, height: height}) do
    {x + div(width, 2), y + div(height, 2)}
  end

  @doc """
  Returns the area of the layout in square pixels.
  """
  @spec area(t()) :: pos_integer()
  def area(%__MODULE__{width: width, height: height}), do: width * height

  @doc """
  Creates a bounds map from this layout.
  """
  @spec to_bounds(t()) :: bounds()
  def to_bounds(%__MODULE__{} = layout) do
    %{x: layout.x, y: layout.y, width: layout.width, height: layout.height}
  end

  # Hit Testing API

  alias DesktopUI.Widget

  @doc """
  Hit test the layout tree to find the widget at the given position.

  This function traverses the layout tree to determine which widget contains
  the given point (x, y). For interactive widgets (buttons with on_click),
  returns the widget_id and on_click message.

  Returns `{:ok, %{widget_id: id, on_click: message}}` for interactive widgets,
  or `nil` if no widget was found at the position.

  ## Parameters

  - `layout` - The layout tree to search
  - `x` - X coordinate to test
  - `y` - Y coordinate to test

  ## Examples

      layout = Layout.calculate(widget, %{width: 800, height: 600})
      Layout.hit_test(layout, 100, 50)
      #=> {:ok, %{widget_id: :btn_click, on_click: :clicked}}

      Layout.hit_test(layout, 9999, 9999)
      #=> nil

  """
  @spec hit_test(t(), non_neg_integer(), non_neg_integer()) ::
    {:ok, %{widget_id: atom(), on_click: term()}} | nil
  def hit_test(%__MODULE__{} = layout, x, y) do
    hit_test_recursive(layout, x, y)
  end

  # Recursive hit test implementation
  defp hit_test_recursive(%__MODULE__{} = layout, x, y) do
    if contains?(layout, x, y) do
      # Point is within this layout's bounds
      case layout.widget do
        %Widget{type: :container} ->
          # For containers, search children first (reverse order for z-order)
          case search_children_for_hit(layout, x, y) do
            nil -> container_widget_info(layout.widget)
            result -> result
          end

        %Widget{type: :button} ->
          # Buttons are interactive
          button_widget_info(layout.widget)

        %Widget{type: :label} ->
          # Labels are not interactive
          nil

        %Widget{type: nil, children: children} when is_list(children) ->
          # Synthetic widget from layout calculation (nested container)
          # Search children for hit
          search_synthetic_children(children, x, y)

        %Widget{type: nil} ->
          # Other synthetic widgets without type - treat as non-interactive
          nil
      end
    else
      # Point is outside this layout
      nil
    end
  end

  # Search children for hit (reverse order for z-order: topmost first)
  defp search_children_for_hit(%__MODULE__{widget: %Widget{children: children}}, x, y) when is_list(children) do
    children
    |> Enum.reverse()
    |> Enum.reduce_while(nil, fn child_layout, _acc ->
      case hit_test_recursive(child_layout, x, y) do
        nil -> {:cont, nil}
        result -> {:halt, result}
      end
    end)
  end

  defp search_children_for_hit(%__MODULE__{}, _x, _y), do: nil

  # Search synthetic children (from nested container layouts)
  defp search_synthetic_children(children, x, y) when is_list(children) do
    children
    |> Enum.reverse()
    |> Enum.reduce_while(nil, fn child_layout, _acc ->
      case hit_test_recursive(child_layout, x, y) do
        nil -> {:cont, nil}
        result -> {:halt, result}
      end
    end)
  end

  defp search_synthetic_children(_, _x, _y), do: nil

  # Get widget info for button widgets
  defp button_widget_info(%Widget{id: id, props: props}) do
    on_click = Keyword.get(props, :on_click)

    if on_click != nil and id != nil do
      {:ok, %{widget_id: id, on_click: on_click}}
    else
      nil
    end
  end

  # Get widget info for container widgets (containers don't typically receive clicks)
  defp container_widget_info(%Widget{}), do: nil

  # Layout Calculation API

  alias DesktopUI.Layout.{Context, Calculate}

  @doc """
  Calculates the layout for a widget tree within the given bounds.

  Returns `{:ok, layout}` where layout contains explicit bounds,
  or `{:error, reason}` if layout fails.

  ## Parameters

  - `widget` - The widget tree to layout
  - `available_bounds` - Map with :width and :height of available space
  - `context` - Layout context with constraints (optional, uses defaults if nil)

  ## Examples

      iex> alias DesktopUI.{Layout, Widget}
      iex> widget = Widget.label("Hello World")
      iex> {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})
      iex> layout.width > 0
      true

      iex> alias DesktopUI.{Layout, Layout.Context, Widget}
      iex> widget = Widget.button("Click", :clicked)
      iex> context = Context.new(800, 600, constraints: [min_width: 100])
      iex> {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600}, context)

  """
  @spec calculate(DesktopUI.Widget.t(), %{width: pos_integer(), height: pos_integer()}, Context.t() | nil) :: layout_result()
  defdelegate calculate(widget, available_bounds, context \\ nil), to: Calculate

  @type layout_result :: {:ok, t()} | {:error, String.t()}
end
