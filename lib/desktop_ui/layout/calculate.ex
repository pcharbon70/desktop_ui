defmodule DesktopUI.Layout.Calculate do
  @moduledoc """
  Layout calculation engine.

  Transforms widget trees into laid-out trees with explicit bounds.
  """

  alias DesktopUI.{Layout, Layout.Context, Widget}

  @type layout_result :: {:ok, Layout.t()} | {:error, String.t()}

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
      iex> widget = Widget.label("Hello")
      iex> {:ok, layout} = Layout.Calculate.calculate(widget, %{width: 800, height: 600})
      iex> layout.width > 0
      true

  """
  @spec calculate(Widget.t(), %{width: pos_integer(), height: pos_integer()}, Context.t() | nil) :: layout_result()
  def calculate(widget, available_bounds, context \\ nil)

  def calculate(%Widget{type: type} = widget, available_bounds, context) when type in [:label, :button] do
    context = normalize_context(context, available_bounds)
    layout_leaf(widget, available_bounds, context)
  end

  def calculate(%Widget{type: :container} = widget, available_bounds, context) do
    context = normalize_context(context, available_bounds)
    layout_container(widget, available_bounds, context)
  end

  def calculate(%Widget{type: type}, _available_bounds, _context) do
    {:error, "unknown widget type: #{inspect(type)}"}
  end

  def calculate(_other, _available_bounds, _context) do
    {:error, "not a widget"}
  end

  # Leaf Widget Layout

  defp layout_leaf(%Widget{} = widget, available_bounds, context) do
    with {:ok, intrinsic_size} <- intrinsic_size(widget, context),
         {:ok, constrained_size} <- apply_constraints(intrinsic_size, context.constraints, available_bounds),
         {:ok, position} <- calculate_position(widget, constrained_size, context) do
      layout = Layout.new(
        position.x,
        position.y,
        constrained_size.width,
        constrained_size.height,
        widget
      )

      {:ok, layout}
    end
  end

  # Container Layout (placeholder for sections 3.2 and 3.3)

  defp layout_container(%Widget{children: children} = widget, available_bounds, context) do
    # For now, containers just calculate intrinsic size from children
    # Full positioning logic comes in sections 3.2 (VBox) and 3.3 (HBox)
    with {:ok, intrinsic_size} <- container_intrinsic_size(children, context),
         {:ok, constrained_size} <- apply_constraints(intrinsic_size, context.constraints, available_bounds),
         {:ok, position} <- calculate_position(widget, constrained_size, context) do
      layout = Layout.new(
        position.x,
        position.y,
        constrained_size.width,
        constrained_size.height,
        widget
      )

      {:ok, layout}
    end
  end

  # Intrinsic Size Calculation

  @doc """
  Calculates the intrinsic (natural) size for a widget.

  For leaf widgets:
  - Label: Based on text length (character_count * char_width)
  - Button: Text size + button padding

  For containers:
  - Calculated from children (full implementation in 3.2, 3.3)

  """
  def intrinsic_size(%Widget{type: :label, props: props}, _context) do
    text = Keyword.get(props, :text, "")
    text_width = estimate_text_width(text)
    text_height = estimate_text_height(text)
    {:ok, %{width: text_width, height: text_height}}
  end

  def intrinsic_size(%Widget{type: :button, props: props}, _context) do
    text = Keyword.get(props, :text, "")
    text_width = estimate_text_width(text)
    text_height = estimate_text_height(text)

    # Button has padding around the text
    {pad_width, pad_height} = button_padding()

    {:ok, %{
      width: text_width + pad_width,
      height: text_height + pad_height
    }}
  end

  def intrinsic_size(%Widget{type: :container, children: children}, _context) when is_list(children) do
    # For now, containers calculate intrinsic size from children
    # Full implementation in sections 3.2 and 3.3
    container_intrinsic_size(children, %Context{})
  end

  def intrinsic_size(%Widget{type: :container, children: []}, _context) do
    {:ok, %{width: 0, height: 0}}
  end

  # Constraint Application

  @doc """
  Applies size constraints to a calculated size.

  Returns the final size after applying:
  1. Fixed size (if specified, overrides everything)
  2. Min/max constraints (clamps size)
  3. Available bounds (clamps to available space)

  """
  def apply_constraints(size, constraints, available_bounds) do
    width = apply_width_constraints(size.width, constraints, available_bounds.width)
    height = apply_height_constraints(size.height, constraints, available_bounds.height)

    if width > 0 and height > 0 do
      {:ok, %{width: width, height: height}}
    else
      {:error, "calculated size is invalid: width=#{width}, height=#{height}"}
    end
  end

  defp apply_width_constraints(intrinsic_width, constraints, available_width) do
    cond do
      # Fixed width overrides everything
      Map.has_key?(constraints, :fixed_width) ->
        constraints.fixed_width

      # Clamp to min/max bounds
      true ->
        min_width = Map.get(constraints, :min_width, 1)
        max_width = Map.get(constraints, :max_width, available_width)
        max_width = if max_width == :infinity, do: available_width, else: max_width

        intrinsic_width
        |> max(min_width)
        |> min(max_width)
        |> min(available_width)
    end
  end

  defp apply_height_constraints(intrinsic_height, constraints, available_height) do
    cond do
      # Fixed height overrides everything
      Map.has_key?(constraints, :fixed_height) ->
        constraints.fixed_height

      # Clamp to min/max bounds
      true ->
        min_height = Map.get(constraints, :min_height, 1)
        max_height = Map.get(constraints, :max_height, available_height)
        max_height = if max_height == :infinity, do: available_height, else: max_height

        intrinsic_height
        |> max(min_height)
        |> min(max_height)
        |> min(available_height)
    end
  end

  # Position Calculation

  defp calculate_position(%Widget{}, _size, %Context{} = context) do
    # For leaf widgets, position is at parent's origin
    # Containers will handle child positioning in sections 3.2 and 3.3
    {:ok, %{
      x: Context.parent_x(context),
      y: Context.parent_y(context)
    }}
  end

  # Container Intrinsic Size (placeholder)

  defp container_intrinsic_size(children, _context) when is_list(children) do
    # Simplified intrinsic size for containers
    # Full implementation in sections 3.2 and 3.3
    if children == [] do
      {:ok, %{width: 0, height: 0}}
    else
      # For now, return max of children's intrinsic sizes
      # This will be properly calculated in VBox/HBox implementations
      {max_width, max_height} =
        Enum.reduce(children, {0, 0}, fn child, {max_w, max_h} ->
          case intrinsic_size(child, %Context{}) do
            {:ok, %{width: w, height: h}} ->
              {max(max_w, w), max(max_h, h)}
            _ ->
              {max_w, max_h}
          end
        end)

      {:ok, %{width: max_width, height: max_height}}
    end
  end

  # Context Normalization

  defp normalize_context(nil, available_bounds) do
    Context.new(available_bounds.width, available_bounds.height)
  end

  defp normalize_context(%Context{} = context, _available_bounds) do
    context
  end

  # Text Size Estimation

  # Constants for text size estimation
  # These are temporary; real text measurement comes later
  @char_width 8
  @char_height 16

  defp estimate_text_width(text) when is_binary(text) do
    # Estimate based on character count
    # Each character is approximately 8 pixels wide
    String.length(text) * @char_width
  end

  defp estimate_text_height(_text) do
    # Fixed height for single-line text
    @char_height
  end

  # Button Padding

  defp button_padding do
    # Buttons have padding around the text
    # 20px horizontal (10px each side)
    # 10px vertical (5px each side)
    {20, 10}
  end
end
