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

  # Container Layout

  defp layout_container(%Widget{props: props} = widget, available_bounds, context) do
    layout_type = Keyword.get(props, :layout)

    case layout_type do
      :vbox ->
        layout_vbox(widget, available_bounds, context)

      :hbox ->
        # HBox is implemented in section 3.3
        layout_container_fallback(widget, available_bounds, context)

      _ ->
        # Fallback for containers without explicit layout type
        layout_container_fallback(widget, available_bounds, context)
    end
  end

  # Fallback container layout (used for hbox and untyped containers)
  defp layout_container_fallback(%Widget{children: children} = widget, available_bounds, context) do
    # For now, non-vbox containers just calculate intrinsic size from children
    # Full positioning logic for hbox comes in section 3.3
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

  # VBox Layout Algorithm

  defp layout_vbox(%Widget{children: children, props: props}, available_bounds, context) do
    spacing = Keyword.get(props, :spacing, 0)
    padding = Keyword.get(props, :padding, 0)
    align = Keyword.get(props, :align, :left)

    # Calculate available space for children (after padding)
    padding_total = padding * 2
    child_available_width = max(available_bounds.width - padding_total, 0)
    _child_available_height = max(available_bounds.height - padding_total, 0)

    # Calculate intrinsic size for all children
    child_intrinsic_sizes =
      Enum.map(children, fn child ->
        case intrinsic_size(child, context) do
          {:ok, size} -> size
          _ -> %{width: 0, height: 0}
        end
      end)

    # Calculate intrinsic container size
    max_child_width = Enum.reduce(child_intrinsic_sizes, 0, fn size, acc -> max(acc, size.width) end)
    total_child_height = Enum.reduce(child_intrinsic_sizes, 0, fn size, acc -> acc + size.height end)
    spacing_height = spacing * max(length(children) - 1, 0)

    intrinsic_width = max_child_width + padding_total
    intrinsic_height = total_child_height + spacing_height + padding_total

    intrinsic_size = %{width: intrinsic_width, height: intrinsic_height}

    # Apply constraints to get final container size
    with {:ok, constrained_size} <- apply_constraints(intrinsic_size, context.constraints, available_bounds),
         {:ok, position} <- calculate_position(%Widget{props: props}, constrained_size, context) do

      # Layout each child
      child_layouts =
        layout_vbox_children(
          children,
          child_intrinsic_sizes,
          spacing,
          padding,
          child_available_width,
          align,
          context
        )

      # Create container layout
      container_layout = Layout.new(
        position.x,
        position.y,
        constrained_size.width,
        constrained_size.height,
        %Widget{children: child_layouts, props: props}
      )

      {:ok, container_layout}
    end
  end

  defp layout_vbox_children(children, intrinsic_sizes, spacing, padding, available_width, align, context) do
    # Layout each child vertically, accumulating y position
    {layouts, _y_offset} =
      Enum.map_reduce(
        Enum.zip(children, intrinsic_sizes),
        padding,
        fn {child, _intrinsic_size}, y_offset ->
          # Calculate child's layout - give it sufficient height
          # Use a large value for available height since VBox doesn't constrain child height
          child_available_bounds = %{width: available_width, height: 10000}

          case calculate(child, child_available_bounds, context) do
            {:ok, child_layout} ->
              # Calculate x position based on alignment
              x_offset = calculate_vbox_x_alignment(child_layout.width, available_width, align, padding)
              positioned_layout = %{child_layout | x: x_offset, y: y_offset}

              # Next y position = current y + child height + spacing
              new_y_offset = y_offset + child_layout.height + spacing

              {positioned_layout, new_y_offset}

            {:error, _reason} ->
              # Return a minimal layout for failed children (use 1x1 to pass guard)
              failed_layout = Layout.new(padding, y_offset, 1, 1, child)
              {failed_layout, y_offset}
          end
        end
      )

    layouts
  end

  defp calculate_vbox_x_alignment(_child_width, _available_width, :left, padding) do
    padding
  end

  defp calculate_vbox_x_alignment(child_width, available_width, :center, padding) do
    padding + div(max(available_width - child_width, 0), 2)
  end

  defp calculate_vbox_x_alignment(child_width, available_width, :right, padding) do
    padding + max(available_width - child_width, 0)
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

  def intrinsic_size(%Widget{type: :container, props: props, children: children}, context) when is_list(children) do
    layout_type = Keyword.get(props, :layout)

    case layout_type do
      :vbox ->
        vbox_intrinsic_size(children, props, context)

      :hbox ->
        # HBox is implemented in section 3.3
        container_intrinsic_size(children, context)

      _ ->
        # Fallback for untyped containers
        container_intrinsic_size(children, context)
    end
  end

  def intrinsic_size(%Widget{type: :container, children: []}, _context) do
    {:ok, %{width: 0, height: 0}}
  end

  # VBox intrinsic size calculation
  defp vbox_intrinsic_size(children, props, context) do
    spacing = Keyword.get(props, :spacing, 0)
    padding = Keyword.get(props, :padding, 0)

    # Calculate intrinsic size for all children
    child_intrinsic_sizes =
      Enum.map(children, fn child ->
        case intrinsic_size(child, context) do
          {:ok, size} -> size
          _ -> %{width: 0, height: 0}
        end
      end)

    # Calculate intrinsic container size
    max_child_width = Enum.reduce(child_intrinsic_sizes, 0, fn size, acc -> max(acc, size.width) end)
    total_child_height = Enum.reduce(child_intrinsic_sizes, 0, fn size, acc -> acc + size.height end)
    spacing_height = spacing * max(length(children) - 1, 0)

    intrinsic_width = max_child_width + padding * 2
    intrinsic_height = total_child_height + spacing_height + padding * 2

    {:ok, %{width: intrinsic_width, height: intrinsic_height}}
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
