defmodule DesktopUI.Layout.Box do
  @moduledoc """
  Shared box layout algorithms for VBox and HBox containers.

  This module contains common logic for laying out box containers,
  reducing duplication between vertical (VBox) and horizontal (HBox)
  layout algorithms.
  """

  alias DesktopUI.{Layout, Widget}
  alias DesktopUI.Layout.Calculate

  @doc """
  Calculate the total padding (padding * 2) from props.
  """
  @spec total_padding(keyword()) :: non_neg_integer()
  def total_padding(props) do
    padding = Keyword.get(props, :padding, 0)
    padding * 2
  end

  @doc """
  Extract common box layout props from widget props.

  Returns a map with:
  - `:spacing` - Space between children
  - `:padding` - Padding around container
  - `:align` - Alignment for children (defaults to :left for VBox, :top for HBox)
  - `:padding_total` - Total padding (padding * 2)

  Note: The default align is :left, but y_alignment will treat :left as :top.
  """
  @spec extract_props(keyword()) :: %{
          spacing: non_neg_integer(),
          padding: non_neg_integer(),
          align: atom(),
          padding_total: non_neg_integer()
        }
  def extract_props(props) do
    spacing = Keyword.get(props, :spacing, 0)
    padding = Keyword.get(props, :padding, 0)
    align = Keyword.get(props, :align, :left)
    padding_total = padding * 2

    %{spacing: spacing, padding: padding, align: align, padding_total: padding_total}
  end

  @doc """
  Calculate intrinsic sizes for all children in a container.

  Returns a list of size maps for each child.
  """
  @spec child_intrinsic_sizes(list(Widget.t()), map()) :: list(map())
  def child_intrinsic_sizes(children, context) do
    Enum.map(children, fn child ->
      case Calculate.intrinsic_size(child, context) do
        {:ok, size} -> size
        _ -> %{width: 0, height: 0}
      end
    end)
  end

  @doc """
  Calculate x alignment for child layouts.

  Used by VBox to position children horizontally.

  Supports :left, :center, :right alignment. Falls back to :left for unknown values.

  ## Parameters

  - `child_width` - Width of the child being positioned
  - `container_width` - Total container width (before padding)
  - `align` - Alignment (:left, :center, :right)
  - `padding` - Padding amount

  """
  @spec x_alignment(non_neg_integer(), non_neg_integer(), atom(), non_neg_integer()) ::
          non_neg_integer()
  def x_alignment(_child_width, _container_width, :left, padding), do: padding

  def x_alignment(child_width, container_width, :center, padding) do
    padding + div(max(container_width - child_width - 2 * padding, 0), 2)
  end

  def x_alignment(child_width, container_width, :right, padding) do
    # Right: position from right edge
    # x = padding + (container_width - padding*2 - child_width)
    #   = container_width - child_width - padding
    max(container_width - child_width - padding, padding)
  end

  # Fallback for unknown alignment values - use left alignment
  def x_alignment(child_width, container_width, _align, padding) do
    x_alignment(child_width, container_width, :left, padding)
  end

  @doc """
  Calculate y alignment for child layouts.

  Used by HBox to position children vertically.

  Supports :top, :center, :bottom alignment. Falls back to :top for unknown values.

  ## Parameters

  - `child_height` - Height of the child being positioned
  - `container_height` - Total container height (before padding)
  - `align` - Alignment (:top, :center, :bottom)
  - `padding` - Padding amount

  """
  @spec y_alignment(non_neg_integer(), non_neg_integer(), atom(), non_neg_integer()) ::
          non_neg_integer()
  def y_alignment(_child_height, _container_height, :top, padding), do: padding

  def y_alignment(child_height, container_height, :center, padding) do
    padding + div(max(container_height - child_height - 2 * padding, 0), 2)
  end

  def y_alignment(child_height, container_height, :bottom, padding) do
    # Bottom: position from bottom edge
    # y = padding + (container_height - padding*2 - child_height)
    #   = container_height - child_height - padding
    max(container_height - child_height - padding, padding)
  end

  # Fallback for unknown alignment values - use top alignment
  # Note: :left is treated as :top for HBox compatibility
  def y_alignment(child_height, container_height, align, padding) when align in [:left, nil] do
    y_alignment(child_height, container_height, :top, padding)
  end

  def y_alignment(child_height, container_height, _align, padding) do
    y_alignment(child_height, container_height, :top, padding)
  end

  @doc """
  Create a failed/minimal layout for a child that failed to layout.

  Used when child layout calculation returns an error.
  """
  @spec failed_layout(non_neg_integer(), non_neg_integer(), Widget.t()) :: Layout.t()
  def failed_layout(x, y, child) do
    Layout.new(x, y, 1, 1, child)
  end

  @doc """
  Create the final container layout with children.

  Used by both VBox and HBox to create the result.
  """
  @spec container_layout(
          non_neg_integer(),
          non_neg_integer(),
          pos_integer(),
          pos_integer(),
          list(Layout.t()),
          keyword()
        ) :: Layout.t()
  def container_layout(x, y, width, height, child_layouts, props) do
    Layout.new(x, y, width, height, %Widget{children: child_layouts, props: props})
  end
end
